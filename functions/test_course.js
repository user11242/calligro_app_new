const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function run() {
  const doc = await db.collection("courses").doc("ux4G2l3vYg2DHxKAiO4d").get();
  console.log(doc.data());
}

run();
