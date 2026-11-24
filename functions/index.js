const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.notifyNewAd = onDocumentCreated("ads/{adId}", async (event) => {
  const ad = event.data.data();

  if (!ad || !ad.campusId) return;

  // Topic matches what Flutter subscribes to
  const topic = `campus_${ad.campusId.replace(/[^a-zA-Z0-9]/g, "_")}`;

  const message = {
    notification: {
      title: `New item on CampusSell 🛍️`,
      body: `${ad.postedByName} posted "${ad.title}" for ₹${ad.price}`,
    },
    data: {
      adId: event.params.adId,
      campusId: ad.campusId,
    },
    topic: topic,
  };

  await getMessaging().send(message);
});