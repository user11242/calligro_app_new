/**
 * The recording safety net: a class recording must never silently disappear.
 *
 * How a class is protected (see docs/RECORDING_SAFETY.md for the whole picture):
 *
 *  1. Two outputs at once. The recorder (LiveKit egress on the Contabo server) writes
 *     the normal MP4 AND the same video as 6-second pieces that are uploaded to R2
 *     WHILE the class runs. The MP4 only reaches R2 when the class ends, so a crash
 *     loses it; the pieces up to the crash are already safe.
 *  2. Verify, don't trust. When the recorder reports "finished", the MP4 must really
 *     be in R2. Otherwise — or when the recorder reports "failed", or never reports at
 *     all — the recording enters RECOVERY instead of being hidden:
 *       checking   wait (up to BACKUP_WAIT_MS) for the MP4 to arrive from the
 *                  Contabo backup folder, which the server's sync job uploads;
 *       rebuilding rebuild the recording from the pieces (task: rebuildRecording);
 *       recovered  the recording is back in the course's list;
 *       manual     pieces exist but need a manual rebuild (admin alerted;
 *                  recording_service/rebuild_recording.sh does it);
 *       lost       nothing usable exists (admin alerted).
 *     activeRecordings/{egressId}.status: "recovering" → "completed" | "needs_manual" | "lost".
 *     While in recovery the recording is hidden (status "failed"), so no app ever
 *     shows an unplayable lesson; it reappears as "ready" once recovered.
 *  3. If the recorder dies while the teacher is still teaching, a new recorder starts at
 *     once for the rest of the class (livekit.js restartRecordingIfTeacherInClass,
 *     at most 3 times an hour).
 *  4. A watchdog (every 15 minutes) finds recordings the recorder never reported on,
 *     moves recoveries along, alerts admins when a scheduled class ended with no
 *     recording, and deletes the pieces 7 days after a recording is safely stored.
 *  5. The Contabo server reports its own problems (disk almost full, recorder down,
 *     backup files not uploading) to recordingServerAlert.
 *
 * Only sessions started by this version carry `safetyNet: true`; older ones keep
 * their old handling.
 */
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onTaskDispatched } = require("firebase-functions/v2/tasks");
const { defineSecret } = require("firebase-functions/params");
const { getFunctions } = require("firebase-admin/functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");
const {
  PutObjectCommand, GetObjectCommand, HeadObjectCommand, ListObjectsV2Command, DeleteObjectCommand,
} = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const { EgressClient, RoomServiceClient } = require("livekit-server-sdk");
const { BUCKET, makeS3, withRelay, writeConcatList, joinParts, removeFiles } = require("./media.js");
const schedule = require("./schedule.js");
const { notifyAdmins } = require("./notifications.js");

const livekitApiKey = defineSecret("LIVEKIT_API_KEY");
const livekitApiSecret = defineSecret("LIVEKIT_API_SECRET");
const r2AccessKey = defineSecret("CLOUDFLARE_R2_ACCESS_KEY");
const r2SecretKey = defineSecret("CLOUDFLARE_R2_SECRET_KEY");
const r2Endpoint = defineSecret("CLOUDFLARE_R2_ENDPOINT");
const r2PublicUrl = defineSecret("CLOUDFLARE_R2_PUBLIC_URL");

const LIVEKIT_URL = process.env.LIVEKIT_URL || "https://194.163.184.20.nip.io";
const REGION = "us-central1";
const REBUILD_QUEUE = "recordingSafety-rebuildRecording";

const MIN = 60 * 1000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;

/** Length of one live piece (seconds). */
const SEGMENT_SECONDS = 6;
/** Pieces live under recording-segments/<courseId>/<timestamp>/ (one R2 lifecycle rule covers them). */
const SEGMENTS_ROOT = "recording-segments";
/** A file smaller than this is not a usable recording. */
const MIN_FILE_BYTES = 1024;
/** How long to wait for the MP4 to come back from the Contabo backup before using the pieces. */
const BACKUP_WAIT_MS = 30 * MIN;
/** The recorder's "finished" message normally arrives within seconds; after this it is missing. */
const WEBHOOK_GRACE_MS = 10 * MIN;
/** A recording started less than this ago is left alone by the watchdog. */
const FRESH_MS = 20 * MIN;
/** A recorder joins its class within seconds; before this it may simply not be there yet. */
const RECORDER_JOIN_GRACE_MS = 2 * MIN;
/** No class is this long: a recorder still running after this is stuck and gets stopped. */
const MAX_RECORDING_MS = 8 * HOUR;
/** Joined in memory (/tmp is RAM): above this the rebuild is left to a person. */
const MAX_REBUILD_BYTES = 6 * 1024 * 1024 * 1024;
/** Pieces are deleted this long after the recording is safely stored. */
const KEEP_SEGMENTS_MS = 7 * DAY;
/** A rebuild still unfinished after this is reported. */
const REBUILD_STUCK_MS = 3 * HOUR;
/** Students may join until 30 min after a class; the check runs for classes whose window closed 30–50 min ago. */
const NO_RECORDING_WINDOW = { from: 50 * MIN, to: 30 * MIN };
/** A recording counts for a class if it started in [start - 15 min, end + 30 min]. */
const CLASS_MATCH = { before: 15 * MIN, after: 30 * MIN };
const ALERT_MAX_SKEW_MS = 10 * MIN;
const SERVER_ALERT_KINDS = ["disk_low", "recorder_down", "backup_waiting"];

// LiveKit EgressStatus
const EGRESS = { STARTING: 0, ACTIVE: 1, ENDING: 2, COMPLETE: 3, FAILED: 4, ABORTED: 5, LIMIT_REACHED: 6 };
const EGRESS_NAMES = {
  EGRESS_STARTING: 0, EGRESS_ACTIVE: 1, EGRESS_ENDING: 2, EGRESS_COMPLETE: 3,
  EGRESS_FAILED: 4, EGRESS_ABORTED: 5, EGRESS_LIMIT_REACHED: 6,
};

// ─────────────────────────────────────────────────────────────────────────────
// Pure helpers
// ─────────────────────────────────────────────────────────────────────────────

const db = () => admin.firestore();
const toMs = (v) => {
  if (v == null) return null;
  if (typeof v.toMillis === "function") return v.toMillis();
  if (typeof v === "number") return v;
  return null;
};
const egressStatus = (s) => (typeof s === "number" ? s : EGRESS_NAMES[s] ?? null);
const isRunning = (s) => s === EGRESS.STARTING || s === EGRESS.ACTIVE || s === EGRESS.ENDING;
const isSuccess = (s) => s === EGRESS.COMPLETE || s === EGRESS.LIMIT_REACHED;

/** LiveKit times are nanoseconds (bigint / numeric string); returns ms or null. */
function nanosToMs(v) {
  if (v == null || v === "" || v === 0 || v === "0") return null;
  try {
    const ms = Number(BigInt(v) / 1000000n);
    return ms > 0 ? ms : null;
  } catch (_) {
    return null;
  }
}

/** Exact length in seconds from the recorder's file result, if it reported one. */
function fileDurationSeconds(egressInfo) {
  try {
    const d = egressInfo && egressInfo.fileResults && egressInfo.fileResults[0] && egressInfo.fileResults[0].duration;
    if (!d) return 0;
    return Math.max(1, Math.round(Number(BigInt(d) / 1000000000n)));
  } catch (_) {
    return 0;
  }
}

/**
 * Is this recorder really in its class? A recorder joins the room as a hidden participant
 * named after its egress id. False only when LiveKit answered and it is not there (or the
 * room is gone); if LiveKit cannot be asked, it is assumed present.
 */
async function recorderInRoom(roomService, roomName, egressId) {
  try {
    const people = await roomService.listParticipants(roomName);
    return (people || []).some((p) => p.identity === egressId);
  } catch (err) {
    if (/not.?found|does not exist/i.test(`${err.code || ""} ${err.message || ""}`)) return false; // room closed
    return true;
  }
}

/**
 * LiveKit lists [egress] as running, but its recorder has left the class: it was killed
 * (crash, restart, out of memory) before it could report. LiveKit then keeps it "active"
 * forever, so the "recording ended" webhook never comes. Recorders younger than
 * RECORDER_JOIN_GRACE_MS are never called dead.
 */
async function isDeadRecorder(roomService, egress, startedAtMs, now) {
  if (!egress || !isRunning(egressStatus(egress.status))) return false;
  const started = nanosToMs(egress.startedAt) || startedAtMs;
  if (!started || now - started < RECORDER_JOIN_GRACE_MS) return false;
  return !(await recorderInRoom(roomService, egress.roomName, egress.egressId));
}

/** Where a session's live pieces go. */
function segmentsPrefixFor(courseId, timestamp) {
  return `${SEGMENTS_ROOT}/${courseId}/${timestamp}/`;
}

/** The recorder's second output: 6-second MPEG-TS pieces uploaded during the class. */
function segmentOutput(prefix, s3) {
  return {
    filenamePrefix: `${prefix}seg`,
    playlistName: `${prefix}index`,
    segmentDuration: SEGMENT_SECONDS,
    output: { case: "s3", value: s3 },
  };
}

/** Number at the end of a piece name ("…/seg_00012.ts" → 12); -1 if none. */
function segmentIndex(key) {
  const m = /(\d+)\.ts$/.exec(key);
  return m ? Number(m[1]) : -1;
}

/** Where the rebuilt recording goes (next to the original, inside the course folder). */
function rebuiltPathFor(session) {
  const base = session.r2FilePath || `courses/${session.courseId}/recordings/recording-${session.courseId}-${Date.now()}.mp4`;
  return base.replace(/\.(mp4|webm|mov)$/i, "") + "-rebuilt.mp4";
}

function publicUrlFor(publicBase, key) {
  return `${String(publicBase).replace(/\/$/, "")}/${key}`;
}

/** The legacy public quality map older app versions still read. */
function legacyQualities(url) {
  return { "1080p": url, "720p": url, "480p": url, "360p": url };
}

function readR2Secrets() {
  return {
    accessKey: r2AccessKey.value(),
    secretKey: r2SecretKey.value(),
    endpoint: r2Endpoint.value(),
    publicUrl: r2PublicUrl.value(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// R2
// ─────────────────────────────────────────────────────────────────────────────

/** Size of an R2 object in bytes, or 0 if it does not exist. */
async function objectSize(s3, key) {
  if (!key) return 0;
  try {
    const head = await s3.send(new HeadObjectCommand({ Bucket: BUCKET, Key: key }));
    return Number(head && head.ContentLength) || 0;
  } catch (_) {
    return 0;
  }
}

/** Every live piece of a session, in recording order: [{ key, size }]. */
async function listSegments(s3, prefix) {
  if (!prefix) return [];
  const out = [];
  let token;
  do {
    const page = await s3.send(new ListObjectsV2Command({ Bucket: BUCKET, Prefix: prefix, ContinuationToken: token }));
    for (const o of page.Contents || []) {
      if (o.Key.endsWith(".ts") && segmentIndex(o.Key) >= 0) out.push({ key: o.Key, size: Number(o.Size) || 0 });
    }
    token = page.IsTruncated ? page.NextContinuationToken : undefined;
  } while (token);
  return out.sort((a, b) => segmentIndex(a.key) - segmentIndex(b.key));
}

/** Deletes everything under a session's piece folder (pieces + playlists). */
async function deletePrefix(s3, prefix) {
  if (!prefix || !prefix.startsWith(`${SEGMENTS_ROOT}/`)) throw new Error(`Refusing to delete outside ${SEGMENTS_ROOT}/: ${prefix}`);
  // List everything first, then delete: never change a listing while paging through it.
  const keys = [];
  let token;
  do {
    const page = await s3.send(new ListObjectsV2Command({ Bucket: BUCKET, Prefix: prefix, ContinuationToken: token }));
    for (const o of page.Contents || []) keys.push(o.Key);
    token = page.IsTruncated ? page.NextContinuationToken : undefined;
  } while (token);
  for (const key of keys) await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: key }));
  return keys.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Firestore state changes
// ─────────────────────────────────────────────────────────────────────────────

const recordingRef = (courseId, egressId) =>
  db().collection("courses").doc(courseId).collection("recordings").doc(egressId);
const egressRef = (egressId) => db().collection("activeRecordings").doc(egressId);
/** Updates the course's own session record (older sessions may have no id: then nothing to do). */
async function markSession(session, status) {
  if (!session.courseId || !session.sessionId) return;
  await db().collection("courses").doc(session.courseId).collection("activeSessions").doc(session.sessionId)
    .set({ status }, { merge: true })
    .catch((e) => console.warn(`Session ${session.sessionId} not updated:`, e.message));
}

/** Closes the room's "active recording" pointer, only if it still points at THIS recording. */
async function closeRoomPointer(roomName, egressId, status = "ended") {
  if (!roomName) return;
  const ref = db().collection("activeRooms").doc(roomName);
  const snap = await ref.get();
  if (snap.exists && snap.data().egressId === egressId) await ref.set({ status }, { merge: true });
}

/**
 * Puts a recording in the course's list as playable ("ready" also starts the smaller
 * qualities) and marks the session finished. [extra] adds fields to the recording.
 */
async function saveReadyRecording({ session, egressId, r2FilePath, durationSeconds, publicBase, extra = {} }) {
  const courseId = session.courseId;
  const url = publicUrlFor(publicBase, r2FilePath);
  // videoUrl/qualities: public links kept ONLY for app versions already installed.
  await recordingRef(courseId, egressId).set({
    egressId,
    roomName: session.roomName,
    videoUrl: url,
    r2FilePath,
    recordedAt: session.startedAt || admin.firestore.FieldValue.serverTimestamp(),
    duration: durationSeconds,
    qualities: legacyQualities(url),
    status: "ready",
    ...extra,
  }, { merge: true });

  const egressUpdate = {
    status: "completed",
    endedAt: admin.firestore.FieldValue.serverTimestamp(),
    videoUrl: url,
    duration: durationSeconds,
    qualities: legacyQualities(url),
  };
  if (session.safetyNet && session.segmentsPrefix) {
    egressUpdate.segmentsCleanup = "pending";
    egressUpdate.storedAtMs = Date.now();
  }
  await egressRef(egressId).set(egressUpdate, { merge: true });
  await closeRoomPointer(session.roomName, egressId);
  await markSession(session, "completed");
}

/**
 * Something is wrong with this recording (file missing, recorder failed or silent):
 * hide it and start recovery. The watchdog takes it from here.
 */
async function beginRecovery({ session, egressId, reason }) {
  const courseId = session.courseId;
  await egressRef(egressId).set({
    status: "recovering",
    recovery: { state: "checking", reason, since: Date.now() },
  }, { merge: true });
  const rec = await recordingRef(courseId, egressId).get();
  if (rec.exists) {
    // Hidden from every app version until it is recovered (it comes back as "ready").
    await recordingRef(courseId, egressId).set({ status: "failed", recoveryStatus: "checking" }, { merge: true });
  }
  await markSession(session, "recovering");
  // Close the room pointer so room_finished / stop_recording never re-save this as playable.
  await closeRoomPointer(session.roomName, egressId, "recovering");
  console.warn(`🛟 Recording ${egressId} (course ${courseId}) entered recovery: ${reason}`);
}

async function courseTitle(courseId) {
  const snap = await db().collection("courses").doc(courseId).get();
  const c = snap.exists ? snap.data() : {};
  return c.title || c.courseName || c.courseTitle || courseId;
}

/** "2026-11-14 18:00 UTC" — admins read it next to the class schedule. */
function classTime(ms) {
  if (!ms) return "?";
  return new Date(ms).toISOString().slice(0, 16).replace("T", " ") + " UTC";
}

async function alertAdmins(kind, { key, courseId, startedAtMs, detail }) {
  const params = {
    courseName: courseId ? await courseTitle(courseId) : "",
    time: classTime(startedAtMs),
    detail: detail || "",
  };
  await notifyAdmins({
    key,
    type: `recording_${kind}`,
    titleKey: `recording_${kind}_title`,
    bodyKey: `recording_${kind}_body`,
    params,
    payload: courseId ? { courseId } : {},
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Recovery steps
// ─────────────────────────────────────────────────────────────────────────────

async function enqueueRebuild(egressId) {
  const queue = getFunctions().taskQueue(`locations/${REGION}/functions/${REBUILD_QUEUE}`);
  await queue.enqueue({ egressId });
}

/** One watchdog step for a recording in recovery. Returns what happened. */
async function advanceRecovery(egressId, session, s3, secrets, now) {
  const recovery = session.recovery || {};
  const startedAtMs = toMs(session.startedAt);

  if (recovery.state === "checking") {
    // 1. The MP4 may have arrived after all (uploaded from the Contabo backup folder).
    const bytes = await objectSize(s3, session.r2FilePath);
    if (bytes >= MIN_FILE_BYTES) {
      const end = recovery.egressEndedAtMs || recovery.since || now;
      const duration = startedAtMs ? Math.max(1, Math.round((end - startedAtMs) / 1000)) : 0;
      await saveReadyRecording({
        session, egressId, r2FilePath: session.r2FilePath, durationSeconds: duration,
        publicBase: secrets.publicUrl, extra: { recovered: true, recoveredFrom: "backup", recoveryStatus: "recovered" },
      });
      await egressRef(egressId).set({ recovery: { ...recovery, state: "recovered", at: now } }, { merge: true });
      await markSession(session, "recovered");
      await alertAdmins("recovered", { key: `rec_recovered_${egressId}`, courseId: session.courseId, startedAtMs, detail: "backup" });
      return "recovered_file";
    }
    if (now - (recovery.since || now) < BACKUP_WAIT_MS) return "waiting_for_backup";

    // 2. Use the live pieces.
    const segments = await listSegments(s3, session.segmentsPrefix);
    if (segments.length === 0) {
      await egressRef(egressId).set({ status: "lost", recovery: { ...recovery, state: "lost", at: now } }, { merge: true });
      await markSession(session, "failed");
      await alertAdmins("lost", { key: `rec_lost_${egressId}`, courseId: session.courseId, startedAtMs, detail: recovery.reason });
      return "lost";
    }
    const total = segments.reduce((n, s) => n + s.size, 0);
    if (total > MAX_REBUILD_BYTES) {
      await egressRef(egressId).set({
        status: "needs_manual", recovery: { ...recovery, state: "manual", at: now, segments: segments.length },
      }, { merge: true });
      await alertAdmins("manual", {
        key: `rec_manual_${egressId}`, courseId: session.courseId, startedAtMs,
        detail: `${session.segmentsPrefix} (${segments.length}) → ${rebuiltPathFor(session)}`,
      });
      return "manual";
    }
    await egressRef(egressId).set({
      recovery: { ...recovery, state: "rebuilding", rebuildQueuedAt: now, segments: segments.length },
    }, { merge: true });
    await enqueueRebuild(egressId);
    return "rebuild_queued";
  }

  if (recovery.state === "manual") {
    // Rebuilt by hand (recording_service/scripts/rebuild_recording.sh uploads it here).
    const target = rebuiltPathFor(session);
    if ((await objectSize(s3, target)) < MIN_FILE_BYTES) return "waiting_for_manual";
    const segments = await listSegments(s3, session.segmentsPrefix);
    await saveReadyRecording({
      session, egressId, r2FilePath: target, durationSeconds: segments.length * SEGMENT_SECONDS,
      publicBase: secrets.publicUrl, extra: { recovered: true, recoveredFrom: "manual", recoveryStatus: "recovered" },
    });
    await egressRef(egressId).set({ recovery: { ...recovery, state: "recovered", at: now } }, { merge: true });
    await markSession(session, "recovered");
    await alertAdmins("recovered", { key: `rec_recovered_${egressId}`, courseId: session.courseId, startedAtMs, detail: "manual" });
    return "recovered_manual";
  }

  if (recovery.state === "rebuilding" && !recovery.stuckAlerted && now - (recovery.rebuildQueuedAt || now) > REBUILD_STUCK_MS) {
    await egressRef(egressId).set({ recovery: { ...recovery, stuckAlerted: true } }, { merge: true });
    await alertAdmins("manual", {
      key: `rec_stuck_${egressId}`, courseId: session.courseId, startedAtMs,
      detail: `${session.segmentsPrefix} → ${rebuiltPathFor(session)}`,
    });
    return "rebuild_stuck";
  }
  return "nothing";
}

/** The recorder never reported on this recording: find out what happened. */
async function checkActiveRecording(egressId, session, egressClient, s3, secrets, now, roomService) {
  const startedAtMs = toMs(session.startedAt);

  let egress = null;
  try {
    const list = await egressClient.listEgress({ egressId });
    egress = (list || []).find((e) => e.egressId === egressId) || null;
  } catch (err) {
    console.warn(`Watchdog could not ask LiveKit about ${egressId}:`, err.message);
    return "livekit_unreachable"; // try again next run; the server's own health check reports outages
  }
  const status = egress ? egressStatus(egress.status) : null;

  if (egress && isRunning(status)) {
    const dead = await isDeadRecorder(roomService, { roomName: session.roomName, ...egress }, startedAtMs, now);
    if (!dead) {
      if (startedAtMs && now - startedAtMs > MAX_RECORDING_MS) {
        await egressClient.stopEgress(egressId).catch((e) => console.warn("Stop of a stuck recorder failed:", e.message));
        return "stopped_stuck";
      }
      return "running";
    }
    // Killed without reporting: try to tidy LiveKit's stale entry (it usually times out), then recover.
    console.warn(`🛟 Recorder ${egressId} left the class but LiveKit still lists it as running`);
    await egressClient.stopEgress(egressId).catch(() => {});
    return recoverAndRestart(egressId, session, "recorder_lost", null);
  }
  // Ended recently: its webhook is normally handling it.
  if (startedAtMs && now - startedAtMs < FRESH_MS) return "fresh";

  const endedMs = egress ? nanosToMs(egress.endedAt) || nanosToMs(egress.updatedAt) : null;
  if (endedMs && now - endedMs < WEBHOOK_GRACE_MS) return "waiting_for_webhook";

  // Finished properly but its report never arrived: save it if the file is really there.
  if (egress && isSuccess(status) && (await objectSize(s3, session.r2FilePath)) >= MIN_FILE_BYTES) {
    const duration = fileDurationSeconds(egress) ||
      (startedAtMs && endedMs ? Math.max(1, Math.round((endedMs - startedAtMs) / 1000)) : 0);
    await saveReadyRecording({ session, egressId, r2FilePath: session.r2FilePath, durationSeconds: duration, publicBase: secrets.publicUrl });
    return "saved_missed_report";
  }

  return recoverAndRestart(egressId, session,
    !egress ? "recorder_lost" : isSuccess(status) ? "file_missing" : "recorder_failed", endedMs);
}

/** Starts recovering a lost recording and, if the class is still going, records the rest of it. */
async function recoverAndRestart(egressId, session, reason, endedMs) {
  await beginRecovery({ session: { ...session, egressId }, egressId, reason });
  if (endedMs) await egressRef(egressId).set({ recovery: { egressEndedAtMs: endedMs } }, { merge: true });
  // Lazy require: livekit.js requires this file.
  try {
    const restart = await require("./livekit.js")._internal.restartRecordingIfTeacherInClass(session.courseId, session.teacherId);
    if (restart === "restarted") return "recovery_started_and_restarted";
  } catch (err) {
    console.error("🛟 Could not restart the recorder:", err.message);
  }
  return "recovery_started";
}

/** Deletes the pieces of recordings safely stored more than 7 days ago. */
async function cleanupSegments(doc, s3, now) {
  const data = doc.data();
  if (!data.storedAtMs || now - data.storedAtMs < KEEP_SEGMENTS_MS) return "kept";
  const rec = await recordingRef(data.courseId, doc.id).get();
  const recording = rec.exists ? rec.data() : null;
  // Only once the stored recording is confirmed: ready and its file really in R2.
  if (!recording || recording.status !== "ready" || (await objectSize(s3, recording.r2FilePath)) < MIN_FILE_BYTES) {
    await doc.ref.set({ segmentsCleanup: "kept_unverified" }, { merge: true });
    console.warn(`Pieces of ${doc.id} kept: the stored recording could not be verified.`);
    return "kept_unverified";
  }
  const deleted = await deletePrefix(s3, data.segmentsPrefix);
  await doc.ref.set({ segmentsCleanup: "done", segmentsDeleted: deleted }, { merge: true });
  return "deleted";
}

/** Scheduled classes whose join window closed 30–50 min ago and that have no recording. */
async function checkUnrecordedClasses(now) {
  const courses = await db().collection("courses").get();
  let alerted = 0;
  for (const doc of courses.docs) {
    const course = doc.data();
    if (!course.teacherId || !Array.isArray(course.enrolledStudents) || course.enrolledStudents.length === 0) continue;
    let classes;
    try {
      classes = schedule.sessions(schedule.scheduleOf(course, 0)); // the course's own time zone
    } catch (_) {
      continue;
    }
    const due = classes.filter((c) => c.end > now - NO_RECORDING_WINDOW.from && c.end <= now - NO_RECORDING_WINDOW.to);
    if (due.length === 0) continue;
    const started = (await doc.ref.collection("activeSessions").get()).docs
      .map((d) => toMs(d.data().startedAt))
      .filter((t) => t != null);
    for (const c of due) {
      const recorded = started.some((t) => t >= c.start - CLASS_MATCH.before && t <= c.end + CLASS_MATCH.after);
      if (recorded) continue;
      await alertAdmins("missing", { key: `rec_missing_${doc.id}_${c.start}`, courseId: doc.id, startedAtMs: c.start });
      alerted++;
    }
  }
  return alerted;
}

// ─────────────────────────────────────────────────────────────────────────────
// Rebuild (heavy: joins every piece into one MP4)
// ─────────────────────────────────────────────────────────────────────────────

async function rebuild(egressId, secrets) {
  const snap = await egressRef(egressId).get();
  if (!snap.exists) return "skipped";
  const session = snap.data();
  const recovery = session.recovery || {};
  if (recovery.state !== "rebuilding") return "skipped";

  const s3 = makeS3(secrets);
  const segments = await listSegments(s3, session.segmentsPrefix);
  if (segments.length === 0) throw new Error(`No pieces under ${session.segmentsPrefix}`);

  const sign = (key) => getSignedUrl(s3, new GetObjectCommand({ Bucket: BUCKET, Key: key }), { expiresIn: 3 * 3600 });
  const listPath = path.join(os.tmpdir(), `rebuild_${egressId}_list.txt`);
  const localOutput = path.join(os.tmpdir(), `rebuild_${egressId}.mp4`);
  const target = rebuiltPathFor(session);
  try {
    const urls = await Promise.all(segments.map((s) => sign(s.key)));
    await withRelay((local) => {
      writeConcatList(listPath, urls.map(local));
      return joinParts(listPath, localOutput);
    });
    await s3.send(new PutObjectCommand({
      Bucket: BUCKET, Key: target, Body: fs.createReadStream(localOutput), ContentType: "video/mp4",
    }));
  } finally {
    removeFiles(listPath, localOutput);
  }

  await saveReadyRecording({
    session, egressId, r2FilePath: target,
    durationSeconds: segments.length * SEGMENT_SECONDS,
    publicBase: secrets.publicUrl,
    extra: { recovered: true, recoveredFrom: "pieces", recoveryStatus: "recovered" },
  });
  await egressRef(egressId).set({ recovery: { ...recovery, state: "recovered", at: Date.now() } }, { merge: true });
  await markSession(session, "recovered");
  await alertAdmins("recovered", {
    key: `rec_recovered_${egressId}`, courseId: session.courseId, startedAtMs: toMs(session.startedAt), detail: "pieces",
  });
  return "recovered";
}

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Functions
// ─────────────────────────────────────────────────────────────────────────────

/** Background worker: rebuilds one recording from its live pieces. */
exports.rebuildRecording = onTaskDispatched({
  secrets: [r2AccessKey, r2SecretKey, r2Endpoint, r2PublicUrl],
  region: REGION,
  cpu: 2,
  memory: "8GiB", // /tmp is RAM: a 2-3 hour 1080p class joined is several GB
  timeoutSeconds: 1800,
  maxInstances: 2,
  retryConfig: { maxAttempts: 3, minBackoffSeconds: 120 },
  rateLimits: { maxConcurrentDispatches: 2 },
}, async (req) => {
  const { egressId } = req.data || {};
  if (!egressId) {
    console.error("Invalid rebuild task payload:", req.data);
    return;
  }
  try {
    console.log(`Rebuild ${egressId}: ${await rebuild(egressId, readR2Secrets())}`);
  } catch (err) {
    const finalAttempt = (req.retryCount || 0) >= 2;
    console.error(`Rebuild ${egressId} failed (final=${finalAttempt}):`, err.message);
    if (!finalAttempt) throw err;
    const snap = await egressRef(egressId).get();
    const session = snap.exists ? snap.data() : {};
    await egressRef(egressId).set({
      status: "needs_manual", recovery: { ...(session.recovery || {}), state: "manual", error: err.message },
    }, { merge: true });
    await alertAdmins("manual", {
      key: `rec_manual_${egressId}`, courseId: session.courseId, startedAtMs: toMs(session.startedAt),
      detail: `${session.segmentsPrefix} → ${rebuiltPathFor(session)}`,
    });
  }
});

/** Every 5 minutes: no recording is left unchecked (a dead recorder costs at most ~5 min of class). */
exports.recordingWatchdog = onSchedule({
  schedule: "every 5 minutes",
  region: REGION,
  timeoutSeconds: 540,
  memory: "512MiB",
  maxInstances: 1,
  secrets: [livekitApiKey, livekitApiSecret, r2AccessKey, r2SecretKey, r2Endpoint, r2PublicUrl],
}, async () => {
  const now = Date.now();
  const secrets = readR2Secrets();
  const s3 = makeS3(secrets);
  const egressClient = new EgressClient(LIVEKIT_URL, livekitApiKey.value(), livekitApiSecret.value());
  const roomService = new RoomServiceClient(LIVEKIT_URL, livekitApiKey.value(), livekitApiSecret.value());
  const report = {};
  const count = (k) => { report[k] = (report[k] || 0) + 1; };
  const safely = async (label, fn) => {
    try {
      count(await fn());
    } catch (err) {
      count("error");
      console.error(`Watchdog step failed (${label}):`, err);
    }
  };

  const active = await db().collection("activeRecordings").where("safetyNet", "==", true).where("status", "==", "active").get();
  for (const doc of active.docs) {
    await safely(doc.id, () => checkActiveRecording(doc.id, { ...doc.data(), egressId: doc.id }, egressClient, s3, secrets, now, roomService));
  }

  for (const status of ["recovering", "needs_manual"]) {
    const docs = await db().collection("activeRecordings").where("status", "==", status).get();
    for (const doc of docs.docs) {
      await safely(doc.id, () => advanceRecovery(doc.id, { ...doc.data(), egressId: doc.id }, s3, secrets, now));
    }
  }

  const cleanup = await db().collection("activeRecordings").where("segmentsCleanup", "==", "pending").limit(25).get();
  for (const doc of cleanup.docs) await safely(doc.id, () => cleanupSegments(doc, s3, now));

  await safely("unrecorded", async () => `missing_alerts_${await checkUnrecordedClasses(now)}`);
  console.log("Recording watchdog:", JSON.stringify(report));
});

/**
 * The Contabo server reports its own problems here (scripts/safety_check.sh).
 * Signed with the LiveKit API secret (HMAC-SHA256 of the raw body), so nobody else can.
 */
exports.recordingServerAlert = onRequest({
  region: REGION,
  secrets: [livekitApiSecret],
  maxInstances: 2,
}, async (req, res) => {
  if (req.method !== "POST") return res.status(405).send("POST only");
  const raw = req.rawBody ? req.rawBody.toString("utf8") : "";
  const given = String(req.headers["x-calligro-signature"] || "");
  const expected = crypto.createHmac("sha256", livekitApiSecret.value()).update(raw).digest("hex");
  const valid = given.length === expected.length &&
    crypto.timingSafeEqual(Buffer.from(given), Buffer.from(expected));
  if (!valid) return res.status(401).send("Bad signature");

  let body;
  try {
    body = JSON.parse(raw);
  } catch (_) {
    return res.status(400).send("Bad JSON");
  }
  const at = Number(body.at) * 1000;
  if (!at || Math.abs(Date.now() - at) > ALERT_MAX_SKEW_MS) return res.status(400).send("Stale");
  if (!SERVER_ALERT_KINDS.includes(body.kind)) return res.status(400).send("Unknown kind");

  // At most one alert per problem per hour (the server checks every 5 minutes).
  const hour = Math.floor(Date.now() / HOUR);
  await notifyAdmins({
    key: `rec_server_${body.kind}_${hour}`,
    type: "recording_server",
    titleKey: "recording_server_title",
    bodyKey: `recording_server_${body.kind}_body`,
    params: { detail: String(body.detail || "").slice(0, 200) },
    payload: {},
  });
  return res.status(200).send("ok");
});

// Shared with livekit.js (start + webhook) and used by tests.
exports.helpers = {
  SEGMENT_SECONDS, SEGMENTS_ROOT, MIN_FILE_BYTES, BACKUP_WAIT_MS, WEBHOOK_GRACE_MS, FRESH_MS, MAX_RECORDING_MS,
  MAX_REBUILD_BYTES, KEEP_SEGMENTS_MS, REBUILD_STUCK_MS, REBUILD_QUEUE,
  segmentsPrefixFor, segmentOutput, segmentIndex, rebuiltPathFor, nanosToMs, fileDurationSeconds,
  objectSize, saveReadyRecording, beginRecovery, makeS3, isDeadRecorder,
};
