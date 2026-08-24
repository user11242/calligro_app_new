const admin = require("firebase-admin");
admin.initializeApp({ projectId: "calligro-bcfb2" });
async function run() {
  const db = admin.firestore();
  const snap = await db.collectionGroup("recordings").orderBy("recordedAt", "desc").limit(1).get();
  snap.forEach(doc => console.log(doc.data()));
}
run();
