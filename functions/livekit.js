const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { AccessToken, EgressClient, RoomServiceClient, EncodingOptionsPreset, TrackSource } = require("livekit-server-sdk");
const { S3Client, PutObjectCommand, HeadObjectCommand, GetObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const crypto = require("crypto");

// --------------------
// Environment & Constants
// --------------------
const LIVEKIT_URL = process.env.LIVEKIT_URL || "https://194.163.184.20.nip.io";
const LIVEKIT_WSS_URL = process.env.LIVEKIT_WSS_URL || "wss://194.163.184.20.nip.io";
const LIVEKIT_WEBHOOK_URL = process.env.LIVEKIT_WEBHOOK_URL || "https://livekit-livekitwebhook-yc7sgeqhya-uc.a.run.app";
const ROOM_SALT = process.env.ROOM_SALT || "Calligro_SecureSalt2026";

// --------------------
// Define Secrets
// --------------------
const livekitApiKey = defineSecret("LIVEKIT_API_KEY");
const livekitApiSecret = defineSecret("LIVEKIT_API_SECRET");
const r2AccessKey = defineSecret("CLOUDFLARE_R2_ACCESS_KEY");
const r2SecretKey = defineSecret("CLOUDFLARE_R2_SECRET_KEY");
const r2Endpoint = defineSecret("CLOUDFLARE_R2_ENDPOINT");
const r2PublicUrl = defineSecret("CLOUDFLARE_R2_PUBLIC_URL");

// --------------------
// Helper: Hash Room Name
// --------------------
function hashRoomName(input) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

// --------------------
// Helper: Get Deterministic Secure Room Name for a Course
// --------------------
function getSecureRoomName(courseId) {
  const rawSeed = `${ROOM_SALT}_${courseId}`;
  return `CG_${hashRoomName(rawSeed).substring(0, 40)}`;
}

// --------------------
// Helper: Kick blocks last as long as a token does, then expire automatically
// --------------------
const KICK_BLOCK_MS = 4 * 60 * 60 * 1000; // matches the 4h token TTL

function isBlockActive(blockData) {
  if (!blockData) return false;
  const expiresAt = blockData.expiresAt;
  const expiresMs = expiresAt && expiresAt.toMillis ? expiresAt.toMillis() : Number(expiresAt) || 0;
  return expiresMs > Date.now();
}

// --------------------
// Helper: Is this LiveKit participant a moderator (teacher/admin)?
// Metadata is set server-side in the token and cannot be changed by the participant
// (canUpdateOwnMetadata: false), so it is a trustworthy role source.
// --------------------
function isModeratorParticipant(participant) {
  try {
    return JSON.parse(participant.metadata || "{}").role === "moderator";
  } catch (_) {
    return false;
  }
}

// --------------------
// Generate LiveKit Token
// --------------------
exports.generateLiveKitToken = onCall({ 
  secrets: [livekitApiKey, livekitApiSecret],
  cpu: 1,
  memory: "512MiB",
  concurrency: 80,
  maxInstances: 20,
}, async (request) => {
  // 1. Verify Authentication
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in to join a classroom.");
  }

  const { courseId, source } = request.data;
  if (!courseId) {
    throw new HttpsError("invalid-argument", "Course ID is required.");
  }

  const uid = request.auth.uid;

  try {
    // 2. Fetch User and Course Data
    const [userSnap, courseSnap] = await Promise.all([
      admin.firestore().collection("users").doc(uid).get(),
      admin.firestore().collection("courses").doc(courseId).get(),
    ]);

    if (!courseSnap.exists) {
      throw new HttpsError("not-found", "Course not found.");
    }

    const courseData = courseSnap.data();
    const userData = userSnap.exists ? userSnap.data() : { name: "Unknown User" };
    
    const isTeacher = courseData.teacherId === uid;
    const isEnrolled = courseData.enrolledStudents && courseData.enrolledStudents.includes(uid);
    const isAdmin = userData.role === "admin";

    // 3. Verify Access
    if (!isTeacher && !isEnrolled && !isAdmin) {
      throw new HttpsError("permission-denied", "You are not enrolled in this course.");
    }

    // 4. Room Name Generation
    const secureRoomName = getSecureRoomName(courseId);

    // 🔒 SEC-KICK: Verify participant has not been kicked/blocked from this active session.
    // The room name is deterministic per course, so blocks MUST expire — otherwise a kick
    // would lock the student out of every future class of the course.
    const cleanUid = uid.replace(/_mobile$/, "");
    try {
      const blockedSnap = await admin.firestore()
        .collection("activeRooms").doc(secureRoomName)
        .collection("blockedParticipants").doc(cleanUid)
        .get();
      if (!isTeacher && !isAdmin && blockedSnap.exists && isBlockActive(blockedSnap.data())) {
        throw new HttpsError("permission-denied", "You have been removed from this classroom session by the instructor.");
      }
    } catch (blockErr) {
      if (blockErr instanceof HttpsError) throw blockErr;
      // non-fatal if subcollection lookup fails
    }

    // Map room → course so the attendance webhook works for every class,
    // not only recorded ones (activeRooms was previously written only on recording start).
    try {
      await admin.firestore().collection("activeRooms").doc(secureRoomName)
        .set({ courseId: courseId, roomName: secureRoomName }, { merge: true });
    } catch (mapErr) {
      console.warn("Could not write room→course mapping:", mapErr.message);
    }

    // 5. Generate Token
    const apiKey = livekitApiKey.value();
    const apiSecret = livekitApiSecret.value();

    const participantName = userData.name || userData.displayName || "Student";
    
    // Create LiveKit Access Token
    const finalIdentity = (isTeacher && source === 'mobile') ? `${uid}_mobile` : uid;
    const at = new AccessToken(apiKey, apiSecret, {
      identity: finalIdentity,
      name: participantName,
      ttl: "4h",
    });

    const isModerator = isTeacher || isAdmin;
    
    let grant = {
      roomJoin: true,
      room: secureRoomName,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
      roomAdmin: isModerator,
      canUpdateOwnMetadata: false, // 🔒 SEC-1: Student cannot modify their own metadata or role
    };

    // 🔒 SEC-2: Only moderators can share screens. Students can only publish mic & camera
    if (!isModerator) {
      grant.canPublishSources = [TrackSource.CAMERA, TrackSource.MICROPHONE];
    }

    at.addGrant(grant);

    const metadata = JSON.stringify({
      role: isModerator ? "moderator" : "participant",
      teacherId: courseData.teacherId,
      uid: uid,
      avatar: userData.photoUrl || userData.photoURL || null,
    });
    at.metadata = metadata;

    const token = await at.toJwt();

    return {
      token,
      roomName: secureRoomName,
      serverUrl: LIVEKIT_WSS_URL,
      teacherId: courseData.teacherId,
    };
  } catch (error) {
    console.error("LiveKit Token Generation Error:", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to generate classroom access token.");
  }
});

// --------------------
// Server-Side Moderation (Teacher Only)
// --------------------
exports.moderateParticipant = onCall({ 
  secrets: [livekitApiKey, livekitApiSecret, r2PublicUrl],
  cpu: 1,
  memory: "512MiB",
  maxInstances: 10,
  concurrency: 80,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { courseId, targetIdentity, action } = request.data;
  if (!courseId || !action) {
    throw new HttpsError("invalid-argument", "courseId and action are required.");
  }

  const uid = request.auth.uid;

  // The course teacher may do everything; a platform admin may moderate
  // STUDENTS (mute, camera, mute all, remove) but not record or end the class.
  const courseSnap = await admin.firestore().collection("courses").doc(courseId).get();
  if (!courseSnap.exists) throw new HttpsError("not-found", "Course not found.");
  const courseData = courseSnap.data();
  const isCourseTeacher = courseData.teacherId === uid;
  let isPlatformAdmin = false;
  if (!isCourseTeacher) {
    const callerSnap = await admin.firestore().collection("users").doc(uid).get();
    isPlatformAdmin = callerSnap.exists && callerSnap.data().role === "admin";
  }
  const ADMIN_ACTIONS = ["mute_mic", "mute_camera", "mute_all", "kick"];
  if (!isCourseTeacher && !(isPlatformAdmin && ADMIN_ACTIONS.includes(action))) {
    throw new HttpsError("permission-denied", "Only the teacher can moderate participants.");
  }

  const today = new Date().toISOString().split('T')[0];
  const secureRoomName = getSecureRoomName(courseId);

  const roomService = new RoomServiceClient(
    LIVEKIT_URL,
    livekitApiKey.value(),
    livekitApiSecret.value()
  );

  // ---------- STOP RECORDING & CLOSE ROOM ----------
  if (action === "stop_recording" || action === "end_room") {
    const egressClient = new EgressClient(
      LIVEKIT_URL,
      livekitApiKey.value(),
      livekitApiSecret.value()
    );

    try {
      // 1. Stop active LiveKit Egress recordings
      const egresses = await egressClient.listEgress({ roomName: secureRoomName });
      const toStop = egresses.filter(e => e.status <= 1);
      if (toStop.length > 0) {
        await Promise.all(toStop.map(e => egressClient.stopEgress(e.egressId)));
      }

      // 2. 🔒 End the room on LiveKit server so all connected participants are removed.
      // ONLY for an explicit "end_room": "stop_recording" is also sent when the teacher's
      // app closes or leaves, and that must not kick every student out of the class.
      if (action === "end_room") {
        // Give the egress a few seconds of live media to flush and finalize the MP4
        // before the room (and its tracks) disappear.
        if (toStop.length > 0) {
          await new Promise(resolve => setTimeout(resolve, 4000));
        }
        try {
          await roomService.deleteRoom(secureRoomName);
          console.log(`✅ Deleted room ${secureRoomName} on LiveKit server`);
        } catch (delErr) {
          console.warn("deleteRoom notice:", delErr.message);
        }
      }
      // 3. Resolve the exact session(s) being stopped.
      // Sessions are keyed by the egress (recording) id, NOT by date, so two classes on the
      // same day never overwrite or pick up each other's recording.
      const sessions = [];
      for (const e of toStop) {
        const recSnap = await admin.firestore().collection("activeRecordings").doc(e.egressId).get();
        // Skip recordings the webhook already reported as failed (no usable file)
        if (recSnap.exists && recSnap.data().r2FilePath && recSnap.data().status !== "failed") {
          sessions.push({ ...recSnap.data(), egressId: e.egressId });
        }
      }
      if (sessions.length === 0) {
        // Fallback: the latest recording started in this room (e.g. egress already ended on its own)
        const roomSnap = await admin.firestore().collection("activeRooms").doc(secureRoomName).get();
        if (roomSnap.exists && roomSnap.data().egressId && roomSnap.data().status === "active") {
          sessions.push(roomSnap.data());
        }
      }

      await admin.firestore()
        .collection("activeRooms").doc(secureRoomName)
        .set({ status: "ended", endedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });

      // 4. Save recordings + update tracking records (idempotent; the webhook may also write later)
      for (const sessionData of sessions) {
        try {
          const { r2FilePath, egressId, startedAt, sessionId } = sessionData;

          let durationSeconds = 0;
          if (startedAt) {
            const startMs = startedAt.toMillis ? startedAt.toMillis() : startedAt;
            durationSeconds = Math.max(1, Math.round((Date.now() - startMs) / 1000));
          }

          // videoUrl/qualities kept ONLY for older app versions already installed.
          // Current clients play via getRecordingPlaybackUrl (signed, expiring URLs).
          const fullUrl = `${r2PublicUrl.value().replace(/\/$/, "")}/${r2FilePath}`;
          const recordingPayload = {
            egressId: egressId,
            roomName: sessionData.roomName || secureRoomName,
            videoUrl: fullUrl,
            qualities: { "1080p": fullUrl, "720p": fullUrl, "480p": fullUrl, "360p": fullUrl },
            r2FilePath: r2FilePath,
            recordedAt: startedAt || admin.firestore.FieldValue.serverTimestamp(),
            duration: durationSeconds,
          };
          if (sessionId) recordingPayload.sessionId = sessionId;

          await admin.firestore()
            .collection("courses").doc(courseId)
            .collection("recordings").doc(egressId)
            .set(recordingPayload, { merge: true });

          const writes = [
            admin.firestore().collection("activeRecordings").doc(egressId).set({
              status: "completed",
              endedAt: admin.firestore.FieldValue.serverTimestamp(),
              duration: durationSeconds,
            }, { merge: true }),
          ];
          if (sessionId) {
            writes.push(admin.firestore()
              .collection("courses").doc(courseId)
              .collection("activeSessions").doc(sessionId)
              .set({ status: "ended", endedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true }));
          }
          await Promise.all(writes);
        } catch (saveErr) {
          console.error("⚠️ Failed to update recording status:", saveErr);
        }
      }

      return { status: "stopped", count: toStop.length };
    } catch (error) {
      console.error("Stop egress error:", error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", "Failed to stop recording.");
    }
  }

  // ---------- MUTE ALL STUDENTS ----------
  if (action === "mute_all") {
    try {
      const participants = await roomService.listParticipants(secureRoomName);
      let mutedCount = 0;
      for (const p of participants) {
        if (isModeratorParticipant(p)) continue;
        for (const track of p.tracks) {
          if (track.type === 0 && !track.muted) { // AUDIO = 0
            await roomService.mutePublishedTrack(secureRoomName, p.identity, track.sid, true);
            mutedCount++;
          }
        }
      }
      return { success: true, action: "muted_all", count: mutedCount };
    } catch (error) {
      console.error("Mute-all error:", error);
      throw new HttpsError("internal", "Failed to mute participants.");
    }
  }

  // ---------- PARTICIPANT MODERATION ----------
  if (!targetIdentity) {
    throw new HttpsError("invalid-argument", "targetIdentity is required for moderation actions.");
  }

  try {
    // Never let a moderator (teacher's other device, platform admin) be muted or kicked
    const target = await roomService.getParticipant(secureRoomName, targetIdentity);
    if (isModeratorParticipant(target)) {
      throw new HttpsError("permission-denied", "Moderators cannot be muted or removed.");
    }

    if (action === "mute_mic") {
      for (const track of target.tracks) {
        if (track.type === 0) { // AUDIO = 0
          await roomService.mutePublishedTrack(secureRoomName, targetIdentity, track.sid, true);
          break;
        }
      }
      return { success: true, action: "muted_mic" };
    }

    if (action === "mute_camera") {
      for (const track of target.tracks) {
        if (track.type === 1) { // VIDEO = 1
          await roomService.mutePublishedTrack(secureRoomName, targetIdentity, track.sid, true);
          break;
        }
      }
      return { success: true, action: "muted_camera" };
    }

    if (action === "kick") {
      // 🔒 SEC-KICK: Write the block BEFORE removing, so the student cannot grab a
      // fresh token in the gap between removal and the block being saved.
      const cleanTargetUid = targetIdentity.replace(/_mobile$/, "");
      await admin.firestore()
        .collection("activeRooms").doc(secureRoomName)
        .collection("blockedParticipants").doc(cleanTargetUid)
        .set({
          blockedAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + KICK_BLOCK_MS),
          reason: isCourseTeacher ? "kicked_by_teacher" : "kicked_by_admin",
        });

      await roomService.removeParticipant(secureRoomName, targetIdentity);

      return { success: true, action: "kicked" };
    }

    throw new HttpsError("invalid-argument", `Unknown action: ${action}`);
  } catch (error) {
    console.error("Moderation error:", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Moderation action failed.");
  }
});

// --------------------
// Start Automated R2 Recording (Track Composite — teacher cam + mic)
// --------------------
exports.startAutomatedRecording = onCall({ 
  secrets: [
    livekitApiKey, 
    livekitApiSecret, 
    r2AccessKey,
    r2SecretKey,
    r2Endpoint
  ],
  cpu: 1,
  memory: "512MiB",
  maxInstances: 10,
  concurrency: 80,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { courseId, audioTrackId, videoTrackId, orientation } = request.data;
  if (!courseId) throw new HttpsError("invalid-argument", "Course ID required.");
  if (!audioTrackId || !videoTrackId) throw new HttpsError("invalid-argument", "Track IDs required.");

  const uid = request.auth.uid;

  try {
    const courseSnap = await admin.firestore().collection("courses").doc(courseId).get();
    if (!courseSnap.exists) throw new HttpsError("not-found", "Course not found.");
    
    const courseData = courseSnap.data();
    // Only the teacher can start the recording
    if (courseData.teacherId !== uid) {
      throw new HttpsError("permission-denied", "Only the teacher can start recording.");
    }

    const today = new Date().toISOString().split('T')[0];
    const secureRoomName = getSecureRoomName(courseId);

    const egressClient = new EgressClient(
      LIVEKIT_URL,
      livekitApiKey.value(),
      livekitApiSecret.value()
    );

    // Don't start another egress if one is already active for this room
    const activeEgresses = await egressClient.listEgress({ roomName: secureRoomName });
    const activeOnes = activeEgresses.filter(e => e.status <= 1); // 0=Starting, 1=Active
    if (activeOnes.length > 0) {
      return { status: "already_recording", egressId: activeOnes[0].egressId };
    }

    const timestamp = Date.now();
    const filepath = `courses/${courseId}/recordings/recording-${courseId}-${timestamp}.mp4`;

    const fileOutput = {
      fileType: 0, // FileType.MP4 (0)
      filepath: filepath,
      output: {
        case: "s3",
        value: {
          accessKey: r2AccessKey.value(),
          secret: r2SecretKey.value(),
          endpoint: r2Endpoint.value(),
          bucket: "calligro-recordings",
          region: "auto",
          forcePathStyle: true
        }
      }
    };

    // Choose preset based on orientation (default to portrait if not specified)
    const preset = orientation === 'landscape' 
        ? EncodingOptionsPreset.H264_1080P_30 
        : EncodingOptionsPreset.PORTRAIT_H264_1080P_30;

    console.log(`Starting recording for room=${secureRoomName}, audio=${audioTrackId}, video=${videoTrackId}, orientation=${orientation}, preset=${preset}`);

    // Resolve teacher participant identity in the room
    let teacherIdentity = `${uid}_mobile`;
    try {
      const roomService = new RoomServiceClient(
        LIVEKIT_URL,
        livekitApiKey.value(),
        livekitApiSecret.value()
      );
      const participants = await roomService.listParticipants(secureRoomName);
      const foundTeacher = participants.find(p => p.identity.startsWith(uid));
      if (foundTeacher) {
        teacherIdentity = foundTeacher.identity;
      }
    } catch (listErr) {
      console.warn("Could not list room participants, using default identity:", listErr);
    }

    // Resilient Egress Strategy:
    // 1. Try ParticipantEgress first (binds to teacher identity, resilient to phone call / track republishes)
    // 2. Fall back to TrackCompositeEgress if ParticipantEgress is unsupported or fails
    let egressInfo;
    try {
      console.log(`Attempting ParticipantEgress: room=${secureRoomName}, identity=${teacherIdentity}`);
      egressInfo = await egressClient.startParticipantEgress(
        secureRoomName,
        teacherIdentity,
        fileOutput,
        {
          encodingOptions: preset,
          screenShare: false,
          webhooks: [{
            url: LIVEKIT_WEBHOOK_URL
          }]
        }
      );
    } catch (partErr) {
      console.warn(`ParticipantEgress failed (${partErr.message}), falling back to TrackCompositeEgress`);
      egressInfo = await egressClient.startTrackCompositeEgress(
        secureRoomName,
        fileOutput,
        {
          audioTrackId: audioTrackId,
          videoTrackId: videoTrackId,
          encodingOptions: preset,
          webhooks: [{
            url: LIVEKIT_WEBHOOK_URL
          }]
        }
      );
    }

    // Store egressId in Firestore across multiple indices for fail-safe retrieval
    const sessionId = `${courseId}_${timestamp}`;
    const sessionPayload = {
      sessionId: sessionId,
      egressId: egressInfo.egressId,
      roomName: secureRoomName,
      r2FilePath: filepath,
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      teacherId: uid,
      courseId: courseId,
      status: "active",
    };

    // 1. Course specific session, keyed uniquely by sessionId (never by date — two classes
    //    on the same day must not overwrite each other)
    await admin.firestore().collection("courses").doc(courseId).collection("activeSessions").doc(sessionId).set(sessionPayload, { merge: true });

    // 2. Global direct O(1) key lookups (Zero index dependencies)
    await Promise.all([
      admin.firestore().collection("activeRecordings").doc(egressInfo.egressId).set(sessionPayload, { merge: true }),
      admin.firestore().collection("activeRooms").doc(secureRoomName).set(sessionPayload, { merge: true }),
    ]);

    return { 
      status: "started", 
      egressId: egressInfo.egressId
    };
  } catch (error) {
    console.error("LiveKit Egress Error:", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to start LiveKit Egress.");
  }
});

// --------------------
// LiveKit Webhook Receiver
// --------------------
const { onRequest } = require("firebase-functions/v2/https");
const { WebhookReceiver } = require("livekit-server-sdk");

exports.livekitWebhook = onRequest({
  secrets: [livekitApiKey, livekitApiSecret, r2PublicUrl]
}, async (req, res) => {
  try {
    const receiver = new WebhookReceiver(
      livekitApiKey.value(),
      livekitApiSecret.value()
    );
    
    // Use rawBody to preserve the exact payload for the sha256 checksum
    if (!req.rawBody && !req.body) {
      return res.status(400).send("Missing body");
    }
    const bodyString = req.rawBody ? req.rawBody.toString('utf8') : req.body;
    const authHeader = req.headers.authorization || req.headers.Authorization;

    const event = await receiver.receive(bodyString, authHeader);
    console.log("LiveKit Webhook Received:", event.event);

    // ── Handle egress_ended: Finalize recordings and qualities ──
    if (event.event === "egress_ended") {
      const egressInfo = event.egressInfo;
      const egressId = egressInfo.egressId;
      console.log(`Egress ${egressId} ended with status ${egressInfo.status}`);

      // 1. Direct O(1) Key Lookup first
      let sessionData = null;
      let courseId = null;
      let sessionDocRef = null;

      const directActiveDoc = await admin.firestore().collection("activeRecordings").doc(egressId).get();
      if (directActiveDoc && directActiveDoc.exists) {
        sessionData = directActiveDoc.data();
        courseId = sessionData.courseId;
        sessionDocRef = directActiveDoc.ref;
      } else {
        try {
          const activeSessionsSnapshot = await admin.firestore().collectionGroup("activeSessions")
            .where("egressId", "==", egressId)
            .limit(1)
            .get();
          if (activeSessionsSnapshot && !activeSessionsSnapshot.empty) {
            const sessionDoc = activeSessionsSnapshot.docs[0];
            sessionData = sessionDoc.data();
            courseId = sessionDoc.ref.parent.parent.id;
            sessionDocRef = sessionDoc.ref;
          }
        } catch (cgErr) {
          console.warn("collectionGroup lookup error:", cgErr.message);
        }
      }

      if (sessionData && courseId) {
        // Calculate exact duration from fileResults if available
        let durationSeconds = 0;
        try {
          if (egressInfo.fileResults && egressInfo.fileResults.length > 0 && egressInfo.fileResults[0].duration) {
            const durNs = BigInt(egressInfo.fileResults[0].duration);
            durationSeconds = Math.max(1, Math.round(Number(durNs / 1000000000n)));
            console.log(`Exact duration from fileResults: ${durationSeconds}s`);
          } else if (sessionData.startedAt) {
            const startMs = sessionData.startedAt.toMillis ? sessionData.startedAt.toMillis() : sessionData.startedAt;
            durationSeconds = Math.max(1, Math.round((Date.now() - startMs) / 1000));
            console.log(`Duration from session startedAt: ${durationSeconds}s`);
          }
        } catch (durErr) {
          console.error("Error calculating duration:", durErr);
        }
        
        // EgressStatus: 3 = COMPLETE, 6 = LIMIT_REACHED (file is valid, just capped).
        // 4 = FAILED, 5 = ABORTED → no usable file.
        const succeeded = [3, 6, "EGRESS_COMPLETE", "EGRESS_LIMIT_REACHED"].includes(egressInfo.status);
        if (succeeded) {
          const publicDomain = r2PublicUrl.value().replace(/\/$/, "");
          const r2FilePath = sessionData.r2FilePath;
          const fullUrl = `${publicDomain}/${r2FilePath}`;

          const qualities = {
            "1080p": fullUrl,
            "720p": fullUrl,
            "480p": fullUrl,
            "360p": fullUrl,
          };

          // Save the recording to subcollection "recordings" under course
          await admin.firestore().collection("courses").doc(courseId).collection("recordings").doc(egressId).set({
            egressId: egressId,
            roomName: sessionData.roomName,
            videoUrl: fullUrl,
            r2FilePath: r2FilePath,
            recordedAt: sessionData.startedAt || admin.firestore.FieldValue.serverTimestamp(),
            duration: durationSeconds,
            qualities: qualities,
            status: "ready",
          }, { merge: true });

          await Promise.all([
            admin.firestore().collection("activeRecordings").doc(egressId).set({
              status: "completed",
              endedAt: admin.firestore.FieldValue.serverTimestamp(),
              videoUrl: fullUrl,
              duration: durationSeconds,
              qualities: qualities,
            }, { merge: true }),
            sessionDocRef ? sessionDocRef.update({ status: "completed", videoUrl: fullUrl }).catch(() => {}) : Promise.resolve(),
          ]);

          console.log(`Successfully saved recording URL: ${fullUrl}, duration: ${durationSeconds}s`);
        } else {
          if (sessionDocRef) await sessionDocRef.update({ status: "failed", error: egressInfo.error || null }).catch(() => {});
          // The stop path may already have written a recording doc for this egress.
          // Mark it failed so clients hide it instead of showing an unplayable lesson.
          const recRef = admin.firestore().collection("courses").doc(courseId).collection("recordings").doc(egressId);
          const recSnap = await recRef.get();
          if (recSnap.exists) {
            await recRef.set({ status: "failed", error: egressInfo.error || null }, { merge: true });
          }
          // Close the room's "active recording" pointer too, otherwise a later stop_recording
          // (or room_finished) falls back to it and re-saves this broken recording as playable.
          if (sessionData.roomName) {
            const roomRef = admin.firestore().collection("activeRooms").doc(sessionData.roomName);
            const roomSnap = await roomRef.get();
            if (roomSnap.exists && roomSnap.data().egressId === egressId) {
              await roomRef.set({ status: "failed" }, { merge: true });
            }
          }
          console.error(`Egress ${egressId} failed: ${egressInfo.error}`);
        }
      } else {
        console.warn(`No active session found for egressId ${egressId}`);
      }
    }

    // ── Handle room_finished: Clean up and ensure recording is finalized ──
    if (event.event === "room_finished") {
      const roomName = event.room ? event.room.name : null;
      if (roomName) {
        console.log(`Room finished: ${roomName} — checking active recordings`);
        try {
          const roomDoc = await admin.firestore().collection("activeRooms").doc(roomName).get();
          if (roomDoc.exists) {
            const data = roomDoc.data();
            const currentStatus = data.status;
            if (currentStatus === "active" || currentStatus === "recording" || currentStatus === "stopping") {
              const courseId = data.courseId;
              const egressId = data.egressId;
              const r2FilePath = data.r2FilePath;
              if (courseId && egressId && r2FilePath) {
                const publicDomain = r2PublicUrl.value().replace(/\/$/, "");
                const fullUrl = `${publicDomain}/${r2FilePath}`;
                const startMs = data.startedAt?.toMillis ? data.startedAt.toMillis() : Date.now();
                const durationSeconds = Math.max(1, Math.round((Date.now() - startMs) / 1000));
                const qualities = {
                  "1080p": fullUrl,
                  "720p": fullUrl,
                  "480p": fullUrl,
                  "360p": fullUrl,
                };

                await admin.firestore().collection("courses").doc(courseId).collection("recordings").doc(egressId).set({
                  egressId: egressId,
                  roomName: roomName,
                  videoUrl: fullUrl,
                  r2FilePath: r2FilePath,
                  recordedAt: data.startedAt || admin.firestore.FieldValue.serverTimestamp(),
                  duration: durationSeconds,
                  qualities: qualities,
                }, { merge: true });

                await roomDoc.ref.set({ status: "ended" }, { merge: true });
                console.log(`🛡️ Finalized recording on room_finished for ${roomName}`);
              }
            }
          }
        } catch (rfErr) {
          console.error("Error processing room_finished recording finalization:", rfErr);
        }
      }
    }

    // ── Handle participant_joined & participant_left: Real attendance tracking ──
    if (event.event === "participant_joined" || event.event === "participant_left") {
      const roomName = event.room ? event.room.name : null;
      const participant = event.participant;
      if (roomName && participant && participant.identity) {
        try {
          const roomSnap = await admin.firestore().collection("activeRooms").doc(roomName).get();
          const courseId = roomSnap.exists ? roomSnap.data().courseId : null;
          if (courseId) {
            const cleanUid = participant.identity.replace(/_mobile$/, "");
            const today = new Date().toISOString().split('T')[0];
            const partDocRef = admin.firestore()
              .collection("courses").doc(courseId)
              .collection("meetingAttendance").doc(today)
              .collection("participants").doc(cleanUid);

            if (event.event === "participant_joined") {
              const partSnap = await partDocRef.get();
              if (!partSnap.exists || !partSnap.data().firstJoinedAt) {
                await partDocRef.set({
                  name: participant.name || "Student",
                  identity: participant.identity,
                  firstJoinedAt: admin.firestore.FieldValue.serverTimestamp(),
                  lastJoinedAt: admin.firestore.FieldValue.serverTimestamp(),
                  isOnline: true,
                }, { merge: true });
              } else {
                await partDocRef.set({
                  lastJoinedAt: admin.firestore.FieldValue.serverTimestamp(),
                  isOnline: true,
                }, { merge: true });
              }
            } else {
              await partDocRef.set({
                leftAt: admin.firestore.FieldValue.serverTimestamp(),
                isOnline: false,
              }, { merge: true });
            }
          }
        } catch (attErr) {
          console.warn("Attendance webhook error:", attErr.message);
        }
      }
    }

    res.status(200).send("ok");
  } catch (error) {
    console.error("Error processing LiveKit webhook:", error);
    res.status(400).send("Webhook error");
  }
});

// --------------------
// Generate Presigned Upload URL (Teacher only, strictly for video)
// --------------------
exports.generateR2UploadUrl = onCall({
  secrets: [r2AccessKey, r2SecretKey, r2Endpoint],
  cpu: 1,
  memory: "256MiB",
  maxInstances: 10,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { courseId, contentType = "video/webm" } = request.data;
  if (!courseId) throw new HttpsError("invalid-argument", "courseId is required.");

  // 🔒 SEC-MIME: Only allow video content types (prevents HTML/JS uploads)
  const ALLOWED_MIME_TYPES = ["video/mp4", "video/webm", "video/quicktime"];
  if (!ALLOWED_MIME_TYPES.includes(contentType)) {
    throw new HttpsError("invalid-argument", "Invalid content type. Only video uploads (mp4, webm, mov) are allowed.");
  }

  const uid = request.auth.uid;
  
  // Verify the caller is the teacher of this course
  const courseSnap = await admin.firestore().collection("courses").doc(courseId).get();
  if (!courseSnap.exists) throw new HttpsError("not-found", "Course not found.");
  if (courseSnap.data().teacherId !== uid) {
    throw new HttpsError("permission-denied", "Only the teacher can upload recordings.");
  }

  const s3Client = new S3Client({
    region: "auto",
    endpoint: r2Endpoint.value(),
    credentials: {
      accessKeyId: r2AccessKey.value(),
      secretAccessKey: r2SecretKey.value(),
    },
  });

  const timestamp = Date.now();
  const fileExtension = { "video/mp4": "mp4", "video/webm": "webm", "video/quicktime": "mov" }[contentType];
  const r2FilePath = `courses/${courseId}/recordings/web_recording_${timestamp}.${fileExtension}`;

  const command = new PutObjectCommand({
    Bucket: "calligro-recordings",
    Key: r2FilePath,
    ContentType: contentType,
  });

  // URL valid for 3 hours to allow slow uploads
  const uploadUrl = await getSignedUrl(s3Client, command, { expiresIn: 3600 * 3 });

  return { uploadUrl, r2FilePath };
});

// --------------------
// Save Recording Metadata (Teacher only, validates path prefix)
// --------------------
exports.saveRecordingMetadata = onCall({
  secrets: [r2PublicUrl],
  cpu: 0.5,
  memory: "256MiB",
  maxInstances: 10,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { courseId, r2FilePath, duration } = request.data;
  if (!courseId || !r2FilePath) throw new HttpsError("invalid-argument", "Missing arguments.");

  // 🔒 SEC-PATH: Prevent directory traversal and validate storage path prefix
  // Only this course's folder is accepted (the old shared "records/" prefix is no longer used
  // by any upload path and would let a teacher register files outside their course).
  if (r2FilePath.includes("..") || r2FilePath.startsWith("/") || !r2FilePath.startsWith(`courses/${courseId}/recordings/`)) {
    throw new HttpsError("invalid-argument", "Invalid storage path prefix.");
  }

  const uid = request.auth.uid;
  const courseSnap = await admin.firestore().collection("courses").doc(courseId).get();
  if (!courseSnap.exists) throw new HttpsError("not-found", "Course not found.");
  if (courseSnap.data().teacherId !== uid) {
    throw new HttpsError("permission-denied", "Only the teacher can save recordings.");
  }

  const today = new Date().toISOString().split('T')[0];
  const publicUrlBase = r2PublicUrl.value().endsWith('/') ? r2PublicUrl.value().slice(0, -1) : r2PublicUrl.value();
  const videoUrl = `${publicUrlBase}/${r2FilePath}`;

  await admin.firestore().collection("courses").doc(courseId).collection("recordings").add({
    roomName: `CG_Manual_${today}`,
    videoUrl: videoUrl,
    r2FilePath: r2FilePath,
    recordedAt: admin.firestore.FieldValue.serverTimestamp(),
    duration: duration || 0,
    source: "web_client",
    status: "ready", // the browser finished uploading the file → safe to transcode
    qualities: {
      "1080p": videoUrl,
      "720p": videoUrl,
      "480p": videoUrl,
      "360p": videoUrl,
    },
  });

  return { success: true, videoUrl };
});

// --------------------
// Reconcile / Self-Heal Recordings
// Automatically checks Cloudflare R2 for completed recordings with access control
// --------------------
exports.reconcileCourseRecordings = onCall({
  secrets: [r2AccessKey, r2SecretKey, r2Endpoint, r2PublicUrl, livekitApiKey, livekitApiSecret],
  cpu: 1,
  memory: "512MiB",
  maxInstances: 10,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { courseId } = request.data;
  if (!courseId) throw new HttpsError("invalid-argument", "courseId is required.");

  const uid = request.auth.uid;

  // 🔒 SEC-ACCESS: Verify the user is enrolled, teacher, or admin
  const [userSnap, courseSnap] = await Promise.all([
    admin.firestore().collection("users").doc(uid).get(),
    admin.firestore().collection("courses").doc(courseId).get(),
  ]);

  if (!courseSnap.exists) throw new HttpsError("not-found", "Course not found.");
  const courseData = courseSnap.data();
  const userData = userSnap.exists ? userSnap.data() : {};
  const isTeacher = courseData.teacherId === uid;
  const isAdmin = userData.role === "admin";
  const isEnrolled = courseData.enrolledStudents && courseData.enrolledStudents.includes(uid);

  if (!isTeacher && !isAdmin && !isEnrolled) {
    throw new HttpsError("permission-denied", "You are not authorized to access recordings for this course.");
  }

  try {
    const s3Client = new S3Client({
      region: "auto",
      endpoint: r2Endpoint.value(),
      credentials: {
        accessKeyId: r2AccessKey.value(),
        secretAccessKey: r2SecretKey.value(),
      },
    });

    const publicDomain = r2PublicUrl.value().replace(/\/$/, "");
    let recoveredCount = 0;

    // Fetch recent activeSessions for this course
    const sessionsSnap = await admin.firestore()
      .collection("courses").doc(courseId)
      .collection("activeSessions")
      .orderBy("startedAt", "desc")
      .limit(10)
      .get();

    for (const sessionDoc of sessionsSnap.docs) {
      const sessionData = sessionDoc.data();
      const egressId = sessionData.egressId;
      const r2FilePath = sessionData.r2FilePath;
      if (!egressId || !r2FilePath) continue;

      // Check if already in recordings
      const recDoc = await admin.firestore()
        .collection("courses").doc(courseId)
        .collection("recordings").doc(egressId)
        .get();

      if (!recDoc.exists) {
        // Verify if file actually exists in R2
        try {
          const headCmd = new HeadObjectCommand({
            Bucket: "calligro-recordings",
            Key: r2FilePath,
          });
          const headRes = await s3Client.send(headCmd);

          if (headRes && headRes.ContentLength && headRes.ContentLength > 1024) {
            // Recovery can run days later, so "now - startedAt" would be wrong. Use the session's
            // own end time when known; otherwise leave duration unknown (0 = not shown).
            const startMs = sessionData.startedAt?.toMillis ? sessionData.startedAt.toMillis() : null;
            const endMs = sessionData.endedAt?.toMillis ? sessionData.endedAt.toMillis() : null;
            const durationSeconds = (startMs && endMs && endMs > startMs) ? Math.round((endMs - startMs) / 1000) : 0;
            const fullUrl = `${publicDomain}/${r2FilePath}`;

            const qualities = {
              "1080p": fullUrl,
              "720p": fullUrl,
              "480p": fullUrl,
              "360p": fullUrl,
            };

            await admin.firestore()
              .collection("courses").doc(courseId)
              .collection("recordings").doc(egressId)
              .set({
                egressId: egressId,
                roomName: sessionData.roomName || `Course_${courseId}`,
                videoUrl: fullUrl,
                r2FilePath: r2FilePath,
                recordedAt: sessionData.startedAt || admin.firestore.FieldValue.serverTimestamp(),
                duration: durationSeconds,
                recovered: true,
                status: "ready", // file verified in R2
                qualities: qualities,
              }, { merge: true });

            await sessionDoc.ref.set({ status: "recovered", videoUrl: fullUrl }, { merge: true });
            recoveredCount++;
            console.log(`🛡️ Recovered missing recording: ${fullUrl}`);
          }
        } catch (s3Err) {
          console.warn(`S3 head check for ${r2FilePath}:`, s3Err.message);
        }
      }
    }

    return { success: true, recoveredCount };
  } catch (error) {
    console.error("Reconciliation error:", error);
    return { success: false, error: error.message };
  }
});

// --------------------
// Get Secure Presigned Playback URL (Enrolled/Teacher only)
// --------------------
exports.getRecordingPlaybackUrl = onCall({
  secrets: [r2AccessKey, r2SecretKey, r2Endpoint],
  cpu: 0.5,
  memory: "256MiB",
  maxInstances: 20,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const { courseId, recordingId } = request.data;
  if (!courseId || !recordingId) throw new HttpsError("invalid-argument", "courseId and recordingId are required.");

  const uid = request.auth.uid;
  const [userSnap, courseSnap, recordingSnap] = await Promise.all([
    admin.firestore().collection("users").doc(uid).get(),
    admin.firestore().collection("courses").doc(courseId).get(),
    // 🔒 The file path comes from THIS course's recording document, never from the client.
    // Otherwise a student enrolled in one course could request any other course's file.
    admin.firestore().collection("courses").doc(courseId).collection("recordings").doc(recordingId).get(),
  ]);

  if (!courseSnap.exists) throw new HttpsError("not-found", "Course not found.");
  const courseData = courseSnap.data();
  const userData = userSnap.exists ? userSnap.data() : {};
  const isTeacher = courseData.teacherId === uid;
  const isAdmin = userData.role === "admin";
  const isEnrolled = courseData.enrolledStudents && courseData.enrolledStudents.includes(uid);

  if (!isTeacher && !isAdmin && !isEnrolled) {
    throw new HttpsError("permission-denied", "You do not have permission to play recordings for this course.");
  }

  if (!recordingSnap.exists || !recordingSnap.data().r2FilePath) {
    throw new HttpsError("not-found", "Recording not found.");
  }
  const r2FilePath = recordingSnap.data().r2FilePath;

  const s3Client = new S3Client({
    region: "auto",
    endpoint: r2Endpoint.value(),
    credentials: {
      accessKeyId: r2AccessKey.value(),
      secretAccessKey: r2SecretKey.value(),
    },
  });

  const command = new GetObjectCommand({
    Bucket: "calligro-recordings",
    Key: r2FilePath,
  });

  const playbackUrl = await getSignedUrl(s3Client, command, { expiresIn: 3600 * 3 });

  // Signed URL per transcoded rendition (720p/480p/360p) when available.
  // Keys are re-checked to stay inside this course's folder.
  const qualities = { "1080p": playbackUrl };
  const renditionKeys = recordingSnap.data().renditionKeys || {};
  for (const [label, key] of Object.entries(renditionKeys)) {
    if (typeof key !== "string" || key.includes("..") || !key.startsWith(`courses/${courseId}/recordings/`)) continue;
    qualities[label] = await getSignedUrl(s3Client, new GetObjectCommand({ Bucket: "calligro-recordings", Key: key }),
      { expiresIn: 3600 * 3 });
  }
  return { success: true, playbackUrl, qualities };
});
