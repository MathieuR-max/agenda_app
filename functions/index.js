const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({maxInstances: 10});

const db = admin.firestore();
const messaging = admin.messaging();

async function getUserDeviceDocs(userId) {
  if (!userId) return [];

  const snapshot = await db
    .collection("users")
    .doc(userId)
    .collection("devices")
    .get();

  return snapshot.docs;
}

function extractValidTokens(deviceDocs) {
  return deviceDocs
    .map((doc) => {
      const data = doc.data() || {};
      return String(data.token || "").trim();
    })
    .filter((token) => token.length > 0);
}

async function cleanupInvalidTokens(deviceDocs, invalidTokens, logContext = {}) {
  if (!invalidTokens.length) return;

  const batch = db.batch();

  deviceDocs.forEach((doc) => {
    const token = String(doc.data()?.token || "").trim();
    if (invalidTokens.includes(token)) {
      batch.delete(doc.ref);
    }
  });

  await batch.commit();

  console.log("Invalid tokens removed.", {
    removedCount: invalidTokens.length,
    ...logContext,
  });
}

async function sendPushToUser({userId, notification, data, logContext = {}}) {
  if (!userId) return;

  const deviceDocs = await getUserDeviceDocs(userId);

  if (deviceDocs.length === 0) {
    console.log("No device docs found for user.", {userId, ...logContext});
    return;
  }

  const tokens = extractValidTokens(deviceDocs);

  if (tokens.length === 0) {
    console.log("No valid FCM tokens found for user.", {userId, ...logContext});
    return;
  }

  const message = {
    tokens,
    notification,
    data,
    android: {
      priority: "high",
    },
  };

  const response = await messaging.sendEachForMulticast(message);

  console.log("Push sent.", {
    userId,
    successCount: response.successCount,
    failureCount: response.failureCount,
    ...logContext,
  });

  const tokensToDelete = [];

  response.responses.forEach((result, index) => {
    if (!result.success) {
      const code = result.error?.code || "";

      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        tokensToDelete.push(tokens[index]);
      }

      console.warn("FCM send failure.", {
        userId,
        token: tokens[index],
        code,
        message: result.error?.message || "",
        ...logContext,
      });
    }
  });

  await cleanupInvalidTokens(deviceDocs, tokensToDelete, {
    userId,
    ...logContext,
  });
}

exports.notifyOnActivityInvitationCreated = onDocumentCreated(
  {
    document: "activity_invitations/{invitationId}",
    region: "europe-west1",
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      console.warn("No snapshot data for invitation event.");
      return;
    }

    const invitation = snapshot.data();
    if (!invitation) {
      console.warn("Invitation document is empty.");
      return;
    }

    const invitationId = snapshot.id;
    const toUserId = String(invitation.toUserId || "").trim();
    const activityId = String(invitation.activityId || "").trim();
    const activityTitle = String(invitation.activityTitle || "").trim();
    const fromUserId = String(invitation.fromUserId || "").trim();
    const fromUserPseudo = String(invitation.fromUserPseudo || "").trim();
    const status = String(invitation.status || "").trim();

    if (!toUserId) {
      console.warn("Missing toUserId on invitation.", {invitationId});
      return;
    }

    if (status && status !== "pending") {
      console.log("Invitation is not pending, skipping notification.", {
        invitationId,
        status,
      });
      return;
    }

    const title = "Nouvelle invitation";
    const body = activityTitle
      ? `Tu as reçu une invitation pour ${activityTitle}`
      : "Tu as reçu une nouvelle invitation";

    await sendPushToUser({
      userId: toUserId,
      notification: {
        title,
        body,
      },
      data: {
        type: "activity_invitation_created",
        invitationId,
        activityId,
        toUserId,
        fromUserId,
        fromUserPseudo,
      },
      logContext: {
        trigger: "notifyOnActivityInvitationCreated",
        invitationId,
        activityId,
      },
    });
  }
);

exports.notifyOnActivityMessageCreated = onDocumentCreated(
  {
    document: "activities/{activityId}/messages/{messageId}",
    region: "europe-west1",
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      console.warn("No snapshot data for activity message event.");
      return;
    }

    const messageDoc = snapshot.data();
    if (!messageDoc) {
      console.warn("Activity message document is empty.");
      return;
    }

    const activityId = String(event.params.activityId || "").trim();
    const messageId = String(event.params.messageId || "").trim();
    const senderId = String(messageDoc.senderId || "").trim();
    const senderPseudo = String(messageDoc.senderPseudo || "").trim();
    const text = String(messageDoc.text || "").trim();
    const type = String(messageDoc.type || "").trim();

    if (!activityId) {
      console.warn("Missing activityId on activity message event.", {messageId});
      return;
    }

    if (!senderId) {
      console.warn("Missing senderId on activity message.", {activityId, messageId});
      return;
    }

    if (type === "system") {
      console.log("System activity message, skipping notification.", {
        activityId,
        messageId,
      });
      return;
    }

    const activityRef = db.collection("activities").doc(activityId);
    const activitySnap = await activityRef.get();

    if (!activitySnap.exists) {
      console.warn("Activity not found for message notification.", {
        activityId,
        messageId,
      });
      return;
    }

    const activity = activitySnap.data() || {};
    const activityTitle = String(activity.title || "").trim();
    const ownerId = String(activity.ownerId || "").trim();

    const participantsSnap = await activityRef.collection("participants").get();

    const recipientIds = new Set();

    if (ownerId && ownerId !== senderId) {
      recipientIds.add(ownerId);
    }

    participantsSnap.docs.forEach((doc) => {
      const userId = String(doc.id || "").trim();
      if (userId && userId !== senderId) {
        recipientIds.add(userId);
      }
    });

    if (recipientIds.size === 0) {
      console.log("No recipients for activity message notification.", {
        activityId,
        messageId,
      });
      return;
    }

    const notificationTitle = activityTitle || "Nouveau message";
    const notificationBody = senderPseudo
      ? `${senderPseudo} : ${text || "a envoyé un message"}`
      : text || "Nouveau message dans une activité";

    for (const userId of recipientIds) {
      await sendPushToUser({
        userId,
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          type: "activity_message_created",
          activityId,
          messageId,
          senderId,
          senderPseudo,
        },
        logContext: {
          trigger: "notifyOnActivityMessageCreated",
          activityId,
          messageId,
        },
      });
    }
  }
);

exports.notifyOnGroupMessageCreated = onDocumentCreated(
  {
    document: "groups/{groupId}/messages/{messageId}",
    region: "europe-west1",
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      console.warn("No snapshot data for group message event.");
      return;
    }

    const messageDoc = snapshot.data();
    if (!messageDoc) {
      console.warn("Group message document is empty.");
      return;
    }

    const groupId = String(event.params.groupId || "").trim();
    const messageId = String(event.params.messageId || "").trim();
    const senderId = String(messageDoc.senderId || "").trim();
    const senderPseudo = String(messageDoc.senderPseudo || "").trim();
    const text = String(messageDoc.text || "").trim();
    const type = String(messageDoc.type || "").trim();

    if (!groupId) {
      console.warn("Missing groupId on group message event.", {messageId});
      return;
    }

    if (!senderId) {
      console.warn("Missing senderId on group message.", {groupId, messageId});
      return;
    }

    if (type === "system") {
      console.log("System group message, skipping notification.", {
        groupId,
        messageId,
      });
      return;
    }

    const groupRef = db.collection("groups").doc(groupId);
    const groupSnap = await groupRef.get();

    if (!groupSnap.exists) {
      console.warn("Group not found for message notification.", {
        groupId,
        messageId,
      });
      return;
    }

    const group = groupSnap.data() || {};
    const groupName = String(group.name || "").trim();

    const membersSnap = await groupRef.collection("members").get();

    const recipientIds = membersSnap.docs
      .map((doc) => String(doc.id || "").trim())
      .filter((userId) => userId && userId !== senderId);

    if (recipientIds.length === 0) {
      console.log("No recipients for group message notification.", {
        groupId,
        messageId,
      });
      return;
    }

    const notificationTitle = groupName || "Nouveau message";
    const notificationBody = senderPseudo
      ? `${senderPseudo} : ${text || "a envoyé un message"}`
      : text || "Nouveau message dans un groupe";

    for (const userId of recipientIds) {
      await sendPushToUser({
        userId,
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          type: "group_message_created",
          groupId,
          messageId,
          senderId,
          senderPseudo,
        },
        logContext: {
          trigger: "notifyOnGroupMessageCreated",
          groupId,
          messageId,
        },
      });
    }
  }
);