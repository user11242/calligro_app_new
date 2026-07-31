const { google } = require('googleapis');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

const ytClientId = defineSecret("YOUTUBE_CLIENT_ID");
const ytClientSecret = defineSecret("YOUTUBE_CLIENT_SECRET");
const ytRefreshToken = defineSecret("YOUTUBE_REFRESH_TOKEN");

/**
 * Get an authenticated YouTube API client
 */
async function getYouTubeClient() {
  const oauth2Client = new google.auth.OAuth2(
    ytClientId.value(),
    ytClientSecret.value(),
    "https://developers.google.com/oauthplayground" // Standard redirect for manual token generation
  );

  oauth2Client.setCredentials({
    refresh_token: ytRefreshToken.value(),
  });

  return google.youtube({
    version: 'v3',
    auth: oauth2Client
  });
}

/**
 * Gets the Playlist ID for a course, creating it if it doesn't exist.
 */
async function getOrCreateCoursePlaylist(courseId, courseName) {
  const db = admin.firestore();
  const courseRef = db.collection('courses').doc(courseId);
  const courseDoc = await courseRef.get();

  if (!courseDoc.exists) throw new Error("Course not found");

  let playlistId = courseDoc.data().youtubePlaylistId;

  if (playlistId) {
    return playlistId;
  }

  // Playlist doesn't exist, create it
  const youtube = await getYouTubeClient();
  const response = await youtube.playlists.insert({
    part: 'snippet,status',
    requestBody: {
      snippet: {
        title: `Calligro Course: ${courseName || courseId}`,
        description: 'Automated recordings for Calligro classes.',
      },
      status: {
        privacyStatus: 'unlisted', // Only enrolled students get the link
      },
    },
  });

  playlistId = response.data.id;
  
  // Save to Firestore
  await courseRef.update({ youtubePlaylistId: playlistId });
  
  return playlistId;
}

/**
 * Creates a Live Broadcast, Live Stream, binds them, and adds to playlist.
 * Returns the RTMP Stream URL.
 */
async function setupYouTubeLiveStream(courseId, courseName) {
  const youtube = await getYouTubeClient();
  const dateStr = new Date().toLocaleString();
  const title = `Live Class: ${courseName || courseId} - ${dateStr}`;

  // 1. Create Broadcast
  const broadcastRes = await youtube.liveBroadcasts.insert({
    part: 'snippet,status,contentDetails',
    requestBody: {
      snippet: {
        title: title,
        scheduledStartTime: new Date().toISOString(),
      },
      status: {
        privacyStatus: 'unlisted', // Keeps it hidden from public channel
        selfDeclaredMadeForKids: false,
      },
      contentDetails: {
        enableAutoStart: true, // Auto starts when Egress sends data!
        enableAutoStop: true, // Auto stops when Egress ends!
        monitorStream: { enableMonitorStream: false },
        enableDvr: true,
      }
    }
  });
  const broadcastId = broadcastRes.data.id;
  const videoId = broadcastRes.data.id; // Broadcast ID is the Video ID

  // 2. Create Stream
  const streamRes = await youtube.liveStreams.insert({
    part: 'snippet,cdn',
    requestBody: {
      snippet: {
        title: `Stream for ${title}`
      },
      cdn: {
        frameRate: '60fps',
        ingestionType: 'rtmp',
        resolution: '1080p'
      }
    }
  });
  const streamId = streamRes.data.id;
  const streamName = streamRes.data.cdn.ingestionInfo.streamName;
  const ingestionAddress = streamRes.data.cdn.ingestionInfo.ingestionAddress;
  
  const rtmpUrl = `${ingestionAddress}/${streamName}`;

  // 3. Bind Stream to Broadcast
  await youtube.liveBroadcasts.bind({
    id: broadcastId,
    part: 'id,contentDetails',
    streamId: streamId,
  });

  // 4. Add Broadcast Video to Course Playlist
  const playlistId = await getOrCreateCoursePlaylist(courseId, courseName);
  await youtube.playlistItems.insert({
    part: 'snippet',
    requestBody: {
      snippet: {
        playlistId: playlistId,
        resourceId: {
          kind: 'youtube#video',
          videoId: videoId,
        }
      }
    }
  });

  // 5. Save the Broadcast info to Firestore for students to view later
  await admin.firestore()
    .collection('courses').doc(courseId)
    .collection('recordings').doc(broadcastId)
    .set({
      videoId: videoId,
      title: title,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      type: "youtube_vod"
    });

  return { rtmpUrl, videoId };
}

module.exports = {
  setupYouTubeLiveStream,
};
