const admin = require('firebase-admin');
const serviceAccount = require('./web_portal/service-account.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
async function check() {
  const courses = await db.collection('courses').get();
  for (let c of courses.docs) {
    const recs = await c.ref.collection('recordings').get();
    if (!recs.empty) console.log(c.id, "has", recs.size, "recordings");
  }
}
check();
