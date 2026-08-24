const admin = require('firebase-admin');
admin.initializeApp();
async function run() {
  const coursesSnap = await admin.firestore().collection('courses').get();
  for (const doc of coursesSnap.docs) {
    const recs = await doc.ref.collection('recordings').get();
    if (!recs.empty) {
      console.log(`Course ${doc.id} ('${doc.data().courseName}') has ${recs.size} recordings`);
    }
  }
}
run().then(()=>process.exit(0)).catch(e=>console.error(e));
