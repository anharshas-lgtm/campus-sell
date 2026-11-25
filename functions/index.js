const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
initializeApp();
// ==========================================
// 1. NOTIFY NEW CAMPUSSELL AD
// ==========================================
exports.notifyNewAd = onDocumentCreated("ads/{adId}", async (event) => {
  const ad = event.data.data();
  if (!ad || !ad.campusId) return;
  // Topic for CampusSell notifications
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
// ==========================================
// 2. NOTIFY NEW CAMPUS BOARD POST
// ==========================================
exports.notifyNewBoardPost = onDocumentCreated("board_posts/{postId}", async (event) => {
  const post = event.data.data();
  if (!post || !post.campusId || post.isActive === false) return;
  // Version-gated topic: only app versions >= 2.0.0 subscribe to *_board_v2
  const topic = `campus_${post.campusId.replace(/[^a-zA-Z0-9]/g, "_")}_board_v2`;
  const message = {
    notification: {
      title: `📢 ${post.title}`,
      body: post.summary && post.summary.length > 0
        ? post.summary
        : `New ${post.category || "board"} update from ${post.postedByName || "Campus"}`,
    },
    data: {
      type: "board_post",
      postId: event.params.postId,
      campusId: post.campusId,
    },
    android: {
      notification: {
        channelId: "campus_board_channel",
      },
    },
    topic: topic,
  };
  await getMessaging().send(message);
});