/**
 * Calligro — recording transcoding (720p / 480p / 360p renditions in Cloudflare R2)
 *
 * Flow:
 *   recording doc becomes status "ready"  (LiveKit confirmed the MP4 / web upload finished)
 *     → onRecordingReady            enqueues one Cloud Task per missing rendition
 *     → transcodeRendition (task)   ffmpeg one rendition, upload to R2, record its key
 *     → when all renditions exist   transcodingStatus = "completed"
 *
 * Why tasks: event triggers are capped at 9 minutes, a 1-hour class needs longer.
 * Each rendition gets its own 30-minute task, retried once, at most 3 running at once
 * (2 CPUs each → 6 CPUs, within the region quota).
 *
 * The source is read through a short-lived SIGNED URL (works with a private bucket).
 * Playback of renditions goes through getRecordingPlaybackUrl (signed per quality).
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onTaskDispatched } = require("firebase-functions/v2/tasks");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { getFunctions } = require("firebase-admin/functions");
const { PutObjectCommand, GetObjectCommand, DeleteObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const fs = require("fs");
const { BUCKET, makeS3, runFfmpeg, withRelay, writeConcatList, joinParts, removeFiles } = require("./media.js");
const path = require("path");
const os = require("os");

const r2AccessKey = defineSecret("CLOUDFLARE_R2_ACCESS_KEY");
const r2SecretKey = defineSecret("CLOUDFLARE_R2_SECRET_KEY");
const r2Endpoint = defineSecret("CLOUDFLARE_R2_ENDPOINT");
const r2PublicUrl = defineSecret("CLOUDFLARE_R2_PUBLIC_URL");

const REGION = "us-central1";
const QUEUE_FUNCTION = "transcoder-transcodeRendition";
const MAX_ATTEMPTS = 2;

/**
 * A task may run 30 minutes at most (the Cloud Tasks limit), which is not enough to
 * convert a 2-3 hour class in one go. Longer recordings are converted in pieces of
 * this length (each its own task) and then joined without re-encoding.
 */
const CHUNK_SECONDS = 1200;

const RENDITIONS = {
  "720p": { height: 720, videoBitrate: "1400k", audioBitrate: "128k" },
  "480p": { height: 480, videoBitrate: "700k", audioBitrate: "96k" },
  "360p": { height: 360, videoBitrate: "350k", audioBitrate: "64k" },
};

// ─────────────────────────────────────────────────────────────────────────────
// Helpers (exported for tests)
// ─────────────────────────────────────────────────────────────────────────────

/** R2 key of a rendition, next to the original: ".../recording-c1-123_720p.mp4". */
function renditionKey(r2FilePath, label) {
  return `${r2FilePath.replace(/\.(mp4|webm|mov)$/i, "")}_${label}.mp4`;
}

/** Recording length in seconds (LiveKit nanoseconds in old documents); 0 if unknown. */
function durationSeconds(recording) {
  const raw = Number(recording.duration) || 0;
  return raw > 100000000 ? raw / 1e9 : raw;
}

/** Number of pieces a rendition is converted in (1 = the whole file in one task). */
function partCount(recording) {
  return Math.max(1, Math.ceil(durationSeconds(recording) / CHUNK_SECONDS));
}

/** R2 key of one piece of a rendition (deleted once the pieces are joined). */
function partKey(r2FilePath, label, part) {
  return renditionKey(r2FilePath, label).replace(/\.mp4$/, `.part${part}.ts`);
}

/** Renditions not produced yet for this recording. */
function missingRenditions(recording) {
  const done = recording.renditionKeys || {};
  return Object.keys(RENDITIONS).filter((label) => !done[label]);
}

function readSecrets() {
  return {
    accessKey: r2AccessKey.value(),
    secretKey: r2SecretKey.value(),
    endpoint: r2Endpoint.value(),
    publicUrl: r2PublicUrl.value(),
  };
}

function recordingRef(courseId, recordingId) {
  return admin.firestore().collection("courses").doc(courseId).collection("recordings").doc(recordingId);
}

/** Encoding settings shared by whole files and pieces (so joined pieces match). */
function encodeArgs(height, videoBitrate, audioBitrate) {
  return [
    "-vf", `scale=-2:${height}`, // -2 keeps aspect ratio with an even width (H.264)
    "-c:v", "libx264", "-preset", "veryfast", "-crf", "26",
    "-b:v", videoBitrate, "-maxrate", videoBitrate, "-bufsize", `${parseInt(videoBitrate, 10) * 2}k`,
    "-c:a", "aac", "-b:a", audioBitrate,
  ];
}

const INPUT_RECONNECT = ["-reconnect", "1", "-reconnect_streamed", "1", "-reconnect_delay_max", "5"];

/** Whole file: input URL → local MP4 at the given height. */
function transcodeStream(inputUrl, outputPath, height, videoBitrate, audioBitrate) {
  return runFfmpeg([
    "-y", ...INPUT_RECONNECT,
    "-i", inputUrl,
    ...encodeArgs(height, videoBitrate, audioBitrate),
    "-movflags", "+faststart",
    outputPath,
  ]);
}

/** One piece: [start, start+length) of the input → local MPEG-TS (joins cleanly). */
function transcodePart(inputUrl, outputPath, start, length, height, videoBitrate, audioBitrate) {
  return runFfmpeg([
    "-y", ...INPUT_RECONNECT,
    "-ss", String(start), "-t", String(length), // before -i: seek, don't decode from the start
    "-i", inputUrl,
    ...encodeArgs(height, videoBitrate, audioBitrate),
    "-f", "mpegts",
    outputPath,
  ]);
}

/** Enqueues one task per missing rendition and marks the recording "queued". */
async function enqueueTranscoding(courseId, recordingId, recording) {
  const missing = missingRenditions(recording);
  if (missing.length === 0) return 0;
  const queue = getFunctions().taskQueue(`locations/${REGION}/functions/${QUEUE_FUNCTION}`);
  const parts = partCount(recording);
  const tasks = [];
  for (const label of missing) {
    if (parts === 1) {
      tasks.push({ courseId, recordingId, label });
      continue;
    }
    const done = (recording.renditionParts || {})[label] || {};
    for (let part = 0; part < parts; part++) {
      if (!done[part]) tasks.push({ courseId, recordingId, label, part, parts });
    }
  }
  await Promise.all(tasks.map((task) => queue.enqueue(task)));
  await recordingRef(courseId, recordingId).set(
    { transcodingStatus: "queued", transcodeError: null },
    { merge: true });
  return tasks.length;
}

/**
 * Produces ONE rendition. Idempotent: does nothing if it already exists, if the
 * recording is gone, or if the recording failed.
 * Returns "skipped" | "done" (all renditions now exist → "completed").
 */
async function processRendition({ courseId, recordingId, label, part, parts }, secrets) {
  if (Number.isInteger(parts) && parts > 1) {
    return processPart({ courseId, recordingId, label, part, parts }, secrets);
  }
  const spec = RENDITIONS[label];
  if (!spec) throw new Error(`Unknown rendition "${label}"`);

  const ref = recordingRef(courseId, recordingId);
  const snap = await ref.get();
  if (!snap.exists) return "skipped";
  const recording = snap.data();
  if (recording.status === "failed" || !recording.r2FilePath) return "skipped";
  if ((recording.renditionKeys || {})[label]) return "skipped";

  await ref.set({ transcodingStatus: "processing" }, { merge: true });

  const s3 = makeS3(secrets);
  // Read the original through a signed URL so this keeps working with a private bucket.
  const inputUrl = await getSignedUrl(s3, new GetObjectCommand({ Bucket: BUCKET, Key: recording.r2FilePath }),
    { expiresIn: 2 * 3600 });
  const localOutput = path.join(os.tmpdir(), `transcode_${recordingId}_${label}.mp4`);
  const key = renditionKey(recording.r2FilePath, label);

  try {
    await withRelay((local) =>
      transcodeStream(local(inputUrl), localOutput, spec.height, spec.videoBitrate, spec.audioBitrate));
    await s3.send(new PutObjectCommand({
      Bucket: BUCKET, Key: key, Body: fs.createReadStream(localOutput), ContentType: "video/mp4",
    }));
  } finally {
    removeFiles(localOutput);
  }

  await recordRendition(ref, label, key, secrets);
  return "done";
}

/** Saves a finished rendition; marks the recording completed once all exist. */
async function recordRendition(ref, label, key, secrets) {
  const publicUrl = `${secrets.publicUrl.replace(/\/$/, "")}/${key}`;
  // Nested merge: each task adds only its own rendition.
  // `qualities` (public URLs) is kept for older app versions only.
  await ref.set({ renditionKeys: { [label]: key }, qualities: { [label]: publicUrl } }, { merge: true });

  const after = (await ref.get()).data();
  if (missingRenditions(after).length === 0) {
    await ref.set({
      transcoded: true,
      transcodingStatus: "completed",
      transcodedAt: admin.firestore.FieldValue.serverTimestamp(),
      transcodeError: null,
    }, { merge: true });
  }
}

/**
 * One piece of a long recording. Idempotent. The task that finds every piece present
 * joins them into the rendition (if two finish at once both join: same result).
 * Returns "skipped" | "part" | "done".
 */
async function processPart({ courseId, recordingId, label, part, parts }, secrets) {
  const spec = RENDITIONS[label];
  if (!spec) throw new Error(`Unknown rendition "${label}"`);
  if (!Number.isInteger(part) || part < 0 || part >= parts) throw new Error(`Invalid piece ${part}/${parts}`);

  const ref = recordingRef(courseId, recordingId);
  const snap = await ref.get();
  if (!snap.exists) return "skipped";
  const recording = snap.data();
  if (recording.status === "failed" || !recording.r2FilePath) return "skipped";
  if ((recording.renditionKeys || {})[label]) return "skipped";

  const s3 = makeS3(secrets);
  const signed = (key) => getSignedUrl(s3, new GetObjectCommand({ Bucket: BUCKET, Key: key }), { expiresIn: 2 * 3600 });

  if (!((recording.renditionParts || {})[label] || {})[part]) {
    await ref.set({ transcodingStatus: "processing" }, { merge: true });
    const localPart = path.join(os.tmpdir(), `transcode_${recordingId}_${label}_part${part}.ts`);
    const key = partKey(recording.r2FilePath, label, part);
    try {
      const inputUrl = await signed(recording.r2FilePath);
      await withRelay((local) => transcodePart(local(inputUrl), localPart, part * CHUNK_SECONDS, CHUNK_SECONDS,
        spec.height, spec.videoBitrate, spec.audioBitrate));
      await s3.send(new PutObjectCommand({
        Bucket: BUCKET, Key: key, Body: fs.createReadStream(localPart), ContentType: "video/mp2t",
      }));
    } finally {
      removeFiles(localPart);
    }
    await ref.set({ renditionParts: { [label]: { [part]: key } } }, { merge: true });
  }

  const now = (await ref.get()).data();
  const done = (now.renditionParts || {})[label] || {};
  const keys = [];
  for (let i = 0; i < parts; i++) keys.push(done[i]);
  if (keys.some((k) => !k) || (now.renditionKeys || {})[label]) return "part";

  // Every piece exists: join them, in order, into the normal rendition file.
  const listPath = path.join(os.tmpdir(), `transcode_${recordingId}_${label}_list.txt`);
  const localOutput = path.join(os.tmpdir(), `transcode_${recordingId}_${label}.mp4`);
  const key = renditionKey(recording.r2FilePath, label);
  try {
    const urls = await Promise.all(keys.map(signed));
    await withRelay((local) => {
      writeConcatList(listPath, urls.map(local));
      return joinParts(listPath, localOutput);
    });
    await s3.send(new PutObjectCommand({
      Bucket: BUCKET, Key: key, Body: fs.createReadStream(localOutput), ContentType: "video/mp4",
    }));
  } finally {
    removeFiles(listPath, localOutput);
  }
  await recordRendition(ref, label, key, secrets);

  // The pieces are no longer needed (best effort: a leftover piece only costs storage).
  await Promise.all(keys.map((k) => s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: k }))
    .catch((e) => console.warn(`Could not delete piece ${k}:`, e.message))));
  return "done";
}

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Functions
// ─────────────────────────────────────────────────────────────────────────────

/** Starts transcoding when a recording becomes "ready" (its file is complete). */
exports.onRecordingReady = onDocumentWritten({
  document: "courses/{courseId}/recordings/{recordingId}",
  region: REGION,
  maxInstances: 5,
}, async (event) => {
  const before = event.data && event.data.before && event.data.before.exists ? event.data.before.data() : null;
  const after = event.data && event.data.after && event.data.after.exists ? event.data.after.data() : null;
  if (!after || after.status !== "ready" || (before && before.status === "ready")) return null;
  if (!after.r2FilePath) return null;
  if (["queued", "processing", "completed"].includes(after.transcodingStatus)) return null;

  const { courseId, recordingId } = event.params;
  const count = await enqueueTranscoding(courseId, recordingId, after);
  console.log(`🎬 Queued ${count} rendition(s) for ${courseId}/${recordingId}`);
  return null;
});

/** Background worker: one rendition per task (30 min, retried once). */
exports.transcodeRendition = onTaskDispatched({
  secrets: [r2AccessKey, r2SecretKey, r2Endpoint, r2PublicUrl],
  region: REGION,
  cpu: 2,
  memory: "4GiB", // /tmp lives in memory: a long class's joined 720p file is >1 GB
  timeoutSeconds: 1800,
  maxInstances: 3,
  retryConfig: { maxAttempts: MAX_ATTEMPTS, minBackoffSeconds: 60 },
  rateLimits: { maxConcurrentDispatches: 3 },
}, async (req) => {
  const { courseId, recordingId, label, part, parts } = req.data || {};
  if (!courseId || !recordingId || !RENDITIONS[label]) {
    console.error("Invalid transcode task payload:", req.data);
    return; // don't retry a malformed task
  }
  try {
    const result = await processRendition({ courseId, recordingId, label, part, parts }, readSecrets());
    console.log(`Rendition ${label} for ${recordingId}: ${result}`);
  } catch (err) {
    const finalAttempt = (req.retryCount || 0) >= MAX_ATTEMPTS - 1;
    console.error(`Rendition ${label} for ${recordingId} failed (final=${finalAttempt}):`, err.message);
    if (!finalAttempt) throw err; // let Cloud Tasks retry
    // Original file stays playable; only the extra quality is missing.
    await recordingRef(courseId, recordingId).set(
      { transcodingStatus: "failed", transcodeError: `${label}: ${err.message}` },
      { merge: true });
  }
});

/** Manual (re)transcode — course teacher or platform admin only. Returns immediately. */
exports.transcodeRecording = onCall({
  region: REGION,
  maxInstances: 5,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { courseId, recordingId } = request.data || {};
  if (!courseId || !recordingId) {
    throw new HttpsError("invalid-argument", "courseId and recordingId are required.");
  }

  const uid = request.auth.uid;
  const [userSnap, courseSnap] = await Promise.all([
    admin.firestore().collection("users").doc(uid).get(),
    admin.firestore().collection("courses").doc(courseId).get(),
  ]);
  if (!courseSnap.exists) throw new HttpsError("not-found", "Course not found.");
  const isTeacher = courseSnap.data().teacherId === uid;
  const isAdmin = userSnap.exists && userSnap.data().role === "admin";
  if (!isTeacher && !isAdmin) {
    throw new HttpsError("permission-denied", "Only the course teacher can transcode recordings.");
  }

  const recSnap = await recordingRef(courseId, recordingId).get();
  if (!recSnap.exists || !recSnap.data().r2FilePath) throw new HttpsError("not-found", "Recording not found.");
  const recording = recSnap.data();
  if (recording.status === "failed") {
    throw new HttpsError("failed-precondition", "This recording failed and has no usable file.");
  }
  if (missingRenditions(recording).length === 0) {
    return { success: true, alreadyTranscoded: true, queued: 0 };
  }
  if (["queued", "processing"].includes(recording.transcodingStatus)) {
    return { success: true, alreadyQueued: true, queued: 0 };
  }
  const queued = await enqueueTranscoding(courseId, recordingId, recording);
  return { success: true, queued };
});

// Internal helpers for unit tests only (not deployed as functions).
if (process.env.NODE_ENV === "test") {
  exports._test = { RENDITIONS, CHUNK_SECONDS, renditionKey, partKey, partCount, missingRenditions, transcodePart, joinParts, processRendition, enqueueTranscoding, QUEUE_FUNCTION };
}
