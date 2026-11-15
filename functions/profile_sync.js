/**
 * Keeps the copies of a user's name / photo up to date after they edit their
 * profile: their courses, community posts, comments and replies.
 *
 * Runs on the server with a BulkWriter, so there is no 500-write batch limit
 * and the app's save stays instant. (Before, the app rewrote everything in
 * one batch, which failed for active users and skipped replies.)
 */
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

/** Only a name or photo change needs the copies refreshed. */
function profileCopyChanged(before = {}, after = {}) {
  return (before.name || "") !== (after.name || "") || (before.photoUrl || "") !== (after.photoUrl || "");
}

/**
 * Rewrites every copy of [uid]'s name / photo. Returns how many documents of
 * each kind were updated.
 */
async function syncProfileCopies(db, uid, profile) {
  const name = profile.name || "";
  const photo = profile.photoUrl || "";
  const targets = [
    ["courses", db.collection("courses").where("teacherId", "==", uid), { teacherName: name, teacherProfilePic: photo }],
    ["posts", db.collection("community_posts").where("userId", "==", uid), { userName: name, userImageUrl: photo }],
    ["comments", db.collectionGroup("comments").where("userId", "==", uid), { userName: name, userPhotoUrl: photo }],
    ["replies", db.collectionGroup("replies").where("userId", "==", uid), { userName: name, userPhotoUrl: photo }],
  ];

  const writer = db.bulkWriter();
  const counts = {};
  for (const [kind, query, fields] of targets) {
    try {
      const snap = await query.get();
      counts[kind] = snap.size;
      snap.docs.forEach((d) => writer.update(d.ref, fields));
    } catch (e) {
      // e.g. a missing collection-group index: log it, still update the rest.
      console.error(`syncProfileCopies: ${kind} for ${uid} failed`, e);
      counts[kind] = 0;
    }
  }
  await writer.close();
  return counts;
}

const syncProfileCopiesOnUpdate = onDocumentUpdated("users/{uid}", async (event) => {
  const before = event.data.before.data() || {};
  const after = event.data.after.data() || {};
  if (!profileCopyChanged(before, after)) return null;
  const counts = await syncProfileCopies(admin.firestore(), event.params.uid, after);
  console.log(`Profile copies of ${event.params.uid} updated`, counts);
  return null;
});

module.exports = { syncProfileCopies, profileCopyChanged, syncProfileCopiesOnUpdate };
