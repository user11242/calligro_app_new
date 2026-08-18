const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { AccessToken, EgressClient, RoomServiceClient, EncodingOptionsPreset } = require("livekit-server-sdk");
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const crypto = require("crypto");

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
// Generate LiveKit Token
// --------------------
exports.generateLiveKitToken = onCall({ 
  secrets: [livekitApiKey, livekitApiSecret],
  cpu: 0.333,
  memory: "256MiB",
  maxInstances: 10,
}, async (request) => {
  // 1. Verify Authentication
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in to join a classroom.");
  }

  const { courseId } = request.data;
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

    // 4. Room Name Generation (Securely hash the room name to prevent guessing)
    const today = new Date().toISOString().split('T')[0];
    const rawSeed = `Calligro_${courseId}_SecureSalt2026_${today}`;
    const secureRoomName = `CG_${hashRoomName(rawSeed).substring(0, 40)}`;

    // 5. Generate Token
    const apiKey = "APICFTjxXVwXvnq";
    const apiSecret = "K9sVYI1DJMlneZVOZ98zqecYYS1fuGFYrUUEQ3CXtYoA";

    const participantName = userData.name || userData.displayName || "Student";
    
    // Create LiveKit Access Token
    const at = new AccessToken(apiKey, apiSecret, {
      identity: uid,
      name: participantName,
      ttl: "4h",
    });

    const isModerator = isTeacher || isAdmin;
    
    at.addGrant({
      roomJoin: true,
      room: secureRoomName,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
      roomAdmin: isModerator,
      canUpdateOwnMetadata: true,
    });

    const metadata = JSON.stringify({
      role: isModerator ? "moderator" : "participant",
      avatar: userData.photoUrl || userData.photoURL || null,
    });
    at.metadata = metadata;

    const token = await at.toJwt();

    // 6. Attendance Logging 
    try {
      await admin.firestore()
        .collection("courses").doc(courseId)
        .collection("meetingAttendance").doc(today)
        .collection("participants").doc(uid)
        .set({
          name: participantName,
          role: isModerator ? "teacher" : "student",
          joinedAt: admin.firestore.FieldValue.serverTimestamp(),
          // We don't overwrite leftAt if it exists (they might be rejoining)
        }, { merge: true });
    } catch (attErr) {
      console.warn("Failed to log attendance:", attErr);
    }

    return {
      token,
      roomName: secureRoomName,
      serverUrl: "wss://calligro-54copltu.livekit.cloud",
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
  secrets: [livekitApiKey, livekitApiSecret],
  cpu: 0.333,
  memory: "256MiB",
  maxInstances: 1,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { courseId, targetIdentity, action } = request.data;
  if (!courseId || !action) {
    throw new HttpsError("invalid-argument", "courseId and action are required.");
  }

  const uid = request.auth.uid;

  // Verify the caller is the teacher of this course
  const courseSnap = await admin.firestore().collection("courses").doc(courseId).get();
  if (!courseSnap.exists) throw new HttpsError("not-found", "Course not found.");
  const courseData = courseSnap.data();
  if (courseData.teacherId !== uid) {
    throw new HttpsError("permission-denied", "Only the teacher can moderate participants.");
  }

  const today = new Date().toISOString().split('T')[0];
  const rawSeed = `Calligro_${courseId}_SecureSalt2026_${today}`;
  const secureRoomName = `CG_${hashRoomName(rawSeed).substring(0, 40)}`;

  // ---------- STOP RECORDING ----------
  if (action === "stop_recording") {
    const egressClient = new EgressClient(
      "https://calligro-54copltu.livekit.cloud",
      livekitApiKey.value(),
      livekitApiSecret.value()
    );
    const roomService = new RoomServiceClient(
      "https://calligro-54copltu.livekit.cloud",
      livekitApiKey.value(),
      livekitApiSecret.value()
    );
    try {
      const egresses = await egressClient.listEgress({ roomName: secureRoomName });
      const toStop = egresses.filter(e => e.status <= 1);
      if (toStop.length > 0) {
        await Promise.all(toStop.map(e => egressClient.stopEgress(e.egressId)));
      }
      await admin.firestore()
        .collection("courses").doc(courseId)
        .collection("activeSessions").doc(today)
        .set({ status: "ended", endedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      // Delete the room to disconnect all participants cleanly
      try { await roomService.deleteRoom(secureRoomName); } catch (_) {}
      return { status: "stopped", count: toStop.length };
    } catch (error) {
      console.error("Stop egress error:", error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", "Failed to stop recording.");
    }
  }

  // ---------- PARTICIPANT MODERATION ----------
  if (!targetIdentity) {
    throw new HttpsError("invalid-argument", "targetIdentity is required for moderation actions.");
  }

  const roomService = new RoomServiceClient(
    "https://calligro-54copltu.livekit.cloud",
    livekitApiKey.value(),
    livekitApiSecret.value()
  );

  try {
    if (action === "mute_mic") {
      // Get participant's tracks and mute the microphone track
      const participant = await roomService.getParticipant(secureRoomName, targetIdentity);
      for (const track of participant.tracks) {
        if (track.type === 0) { // AUDIO = 0
          await roomService.mutePublishedTrack(secureRoomName, targetIdentity, track.sid, true);
          break;
        }
      }
      return { success: true, action: "muted_mic" };
    }

    if (action === "mute_camera") {
      const participant = await roomService.getParticipant(secureRoomName, targetIdentity);
      for (const track of participant.tracks) {
        if (track.type === 1) { // VIDEO = 1
          await roomService.mutePublishedTrack(secureRoomName, targetIdentity, track.sid, true);
          break;
        }
      }
      return { success: true, action: "muted_camera" };
    }

    if (action === "kick") {
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
  cpu: 0.333,
  memory: "256MiB",
  maxInstances: 1,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { courseId, audioTrackId, videoTrackId } = request.data;
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
    const rawSeed = `Calligro_${courseId}_SecureSalt2026_${today}`;
    const secureRoomName = `CG_${hashRoomName(rawSeed).substring(0, 40)}`;

    const egressClient = new EgressClient(
      "http://96.30.198.187:7880",
      "APICFTjxXVwXvnq",
      "K9sVYI1DJMlneZVOZ98zqecYYS1fuGFYrUUEQ3CXtYoA"
    );

    // Don't start another egress if one is already active for this room
    const activeEgresses = await egressClient.listEgress({ roomName: secureRoomName });
    const activeOnes = activeEgresses.filter(e => e.status <= 1); // 0=Starting, 1=Active
    if (activeOnes.length > 0) {
      return { status: "already_recording", egressId: activeOnes[0].egressId };
    }

    const timestamp = Date.now();
    const filepath = `tmp/recording-${courseId}-${timestamp}.mp4`;

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

    // Use TrackCompositeEgress to completely bypass the headless browser (saves 95% CPU)
    const egressInfo = await egressClient.startTrackCompositeEgress(
      secureRoomName,
      fileOutput,
      audioTrackId,
      videoTrackId,
      {
        options: {
          preset: EncodingOptionsPreset.PORTRAIT_H264_1080P_30
        },
        webhooks: [{
          url: "https://livekit-livekitwebhook-yc7sgeqhya-uc.a.run.app"
        }]
      }
    );

    // Store egressId in Firestore so we can track it
    const today2 = new Date().toISOString().split('T')[0];
    await admin.firestore()
      .collection("courses").doc(courseId)
      .collection("activeSessions").doc(today2)
      .set({
        egressId: egressInfo.egressId,
        roomName: secureRoomName,
        r2FilePath: filepath, // save the path so webhook can construct the full URL later
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "active",
      }, { merge: true });

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
      "APICFTjxXVwXvnq",
      "K9sVYI1DJMlneZVOZ98zqecYYS1fuGFYrUUEQ3CXtYoA"
    );
    
    // Use rawBody to preserve the exact payload for the sha256 checksum
    const bodyString = req.rawBody ? req.rawBody.toString('utf8') : req.body;
    const authHeader = req.headers.authorization || req.headers.Authorization;

    const event = await receiver.receive(bodyString, authHeader);
    console.log("LiveKit Webhook Received:", event.event);

    if (event.event === "egress_ended") {
      const egressInfo = event.egressInfo;
      const egressId = egressInfo.egressId;
      console.log(`Egress ${egressId} ended with status ${egressInfo.status}`);

      // Search for the active session in Firestore to update it
      // Since we don't know the courseId directly from the webhook, we can query by egressId
      const activeSessionsSnapshot = await admin.firestore().collectionGroup("activeSessions")
        .where("egressId", "==", egressId)
        .limit(1)
        .get();

      if (!activeSessionsSnapshot.empty) {
        const sessionDoc = activeSessionsSnapshot.docs[0];
        const data = sessionDoc.data();
        const courseId = sessionDoc.ref.parent.parent.id;
        
        if (egressInfo.status === 3 || egressInfo.status === "EGRESS_COMPLETE") {
          // Construct the full public URL
          const publicDomain = r2PublicUrl.value().replace(/\/$/, ""); // remove trailing slash
          const r2FilePath = data.r2FilePath;
          const fullUrl = `${publicDomain}/${r2FilePath}`;

          // Save the recording to a subcollection "recordings" under the course using egressId as the document ID (idempotent)
          await admin.firestore().collection("courses").doc(courseId).collection("recordings").doc(egressId).set({
            egressId: egressId,
            roomName: data.roomName,
            videoUrl: fullUrl,
            r2FilePath: r2FilePath,
            recordedAt: data.startedAt || admin.firestore.FieldValue.serverTimestamp(),
            duration: egressInfo.details?.timeElapsed || 0
          }, { merge: true });
          
          // Also update the activeSession status
          await sessionDoc.ref.update({ status: "completed", videoUrl: fullUrl });
          console.log(`Successfully saved recording URL: ${fullUrl}`);
        } else {
          await sessionDoc.ref.update({ status: "failed", error: egressInfo.error });
          console.error(`Egress ${egressId} failed: ${egressInfo.error}`);
        }
      } else {
        console.warn(`No active session found for egressId ${egressId}`);
      }
    }

    res.status(200).send("ok");
  } catch (error) {
    console.error("Error processing LiveKit webhook:", error);
    res.status(400).send("Webhook error");
  }
});

exports.generateR2UploadUrl = onCall({
  secrets: [r2AccessKey, r2SecretKey, r2Endpoint],
  cpu: 0.333,
  memory: "256MiB",
  maxInstances: 10,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { courseId, contentType = "video/webm" } = request.data;
  if (!courseId) throw new HttpsError("invalid-argument", "courseId is required.");

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

  const timestamp = new Date().getTime();
  const fileExtension = contentType.includes("mp4") ? "mp4" : "webm";
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

exports.saveRecordingMetadata = onCall({
  secrets: [r2PublicUrl],
  cpu: 0.166,
  memory: "256MiB",
  maxInstances: 10,
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { courseId, r2FilePath, duration } = request.data;
  if (!courseId || !r2FilePath) throw new HttpsError("invalid-argument", "Missing arguments.");

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
    source: "web_client"
  });

  return { success: true, videoUrl };
});
