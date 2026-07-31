const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { AccessToken, EgressClient } = require("livekit-server-sdk");
const crypto = require("crypto");

// --------------------
// Define Secrets
// --------------------
const livekitApiKey = defineSecret("LIVEKIT_API_KEY");
const livekitApiSecret = defineSecret("LIVEKIT_API_SECRET");

// --------------------
// Helper: Hash Room Name
// --------------------
function hashRoomName(input) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

// --------------------
// Generate LiveKit Token
// --------------------
exports.generateLiveKitToken = onCall({ secrets: [livekitApiKey, livekitApiSecret] }, async (request) => {
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
    const apiKey = livekitApiKey.value();
    const apiSecret = livekitApiSecret.value();

    if (!apiKey || !apiSecret) {
      throw new HttpsError("internal", "LiveKit API configuration is missing.");
    }

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
// Start Automated YouTube Egress
// --------------------
exports.startAutomatedRecording = onCall({ 
  secrets: [
    livekitApiKey, 
    livekitApiSecret, 
    "YOUTUBE_CLIENT_ID", 
    "YOUTUBE_CLIENT_SECRET", 
    "YOUTUBE_REFRESH_TOKEN"
  ] 
}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { courseId } = request.data;
  if (!courseId) throw new HttpsError("invalid-argument", "Course ID required.");

  const uid = request.auth.uid;

  try {
    const courseSnap = await admin.firestore().collection("courses").doc(courseId).get();
    if (!courseSnap.exists) throw new HttpsError("not-found", "Course not found.");
    
    const courseData = courseSnap.data();
    if (courseData.teacherId !== uid) {
      throw new HttpsError("permission-denied", "Only the teacher can start recording.");
    }

    const today = new Date().toISOString().split('T')[0];
    const rawSeed = `Calligro_${courseId}_SecureSalt2026_${today}`;
    const secureRoomName = `CG_${hashRoomName(rawSeed).substring(0, 40)}`;

    const egressClient = new EgressClient(
      "https://calligro-54copltu.livekit.cloud",
      livekitApiKey.value(),
      livekitApiSecret.value()
    );

    // Don't start another if one is already active
    const activeEgresses = await egressClient.listEgress({ roomName: secureRoomName });
    if (activeEgresses.length > 0) {
      return { status: "already_recording", message: "Recording is already active." };
    }

    const { setupYouTubeLiveStream } = require("./youtube");
    const { rtmpUrl, videoId } = await setupYouTubeLiveStream(courseId, courseData.title);

    // Generate a dedicated read-only Egress Token
    const egressToken = new AccessToken(livekitApiKey.value(), livekitApiSecret.value(), {
      identity: `egress_${courseId}`,
      name: "Recording Bot",
      ttl: "4h",
    });
    egressToken.addGrant({
      roomJoin: true,
      room: secureRoomName,
      canPublish: false,
      canSubscribe: true,
      hidden: true, // Hide from other participants
    });
    const tokenString = await egressToken.toJwt();

    // The custom URL must be publicly accessible by LiveKit's cloud servers.
    const customLayoutUrl = `https://calligro-app.web.app/courses/${courseId}/recording?token=${tokenString}`;

    const streamOutput = {
      protocol: 0, // RTMP
      urls: [rtmpUrl]
    };

    const egressInfo = await egressClient.startWebEgress(
      customLayoutUrl,
      streamOutput,
      { roomName: secureRoomName }
    );

    return { 
      status: "started", 
      egressId: egressInfo.egressId,
      videoId: videoId
    };
  } catch (error) {
    console.error("LiveKit Egress Error:", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to start LiveKit Egress.");
  }
});
