const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");
const data = require("./universities.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function uploadCampuses() {
  let batch = db.batch();
  let count = 0;
  let batchCount = 0;

  for (const item of data) {
    // ── Auto Firestore ID — no duplicate check ────────────────────
    const docRef = db.collection("campuses").doc();

    batch.set(docRef, {
      name: item.university,
      state: item.state,
      district: item.district,
      colleges: item.colleges || [],
    });

    count++;
    batchCount++;

    // ── New batch every 499 ───────────────────────────────────────
    if (batchCount === 499) {
      await batch.commit();
      console.log(`✅ Uploaded ${count} so far...`);
      batch = db.batch();
      batchCount = 0;
    }
  }

  // ── Commit remaining ──────────────────────────────────────────────
  if (batchCount > 0) {
    await batch.commit();
  }

  console.log(`✅ Done! Total uploaded: ${count} campuses`);
  process.exit(0);
}

uploadCampuses().catch((err) => {
  console.error("❌ Error:", err);
  process.exit(1);
});