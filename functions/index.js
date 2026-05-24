const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated, onDocumentUpdated, onDocumentWritten} = require("firebase-functions/v2/firestore");
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

exports.notifyOnPrivateMessageCreated = onDocumentCreated(
  {
    document: "private_chats/{chatId}/messages/{messageId}",
    region: "europe-west1",
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      console.warn("No snapshot data for private message event.");
      return;
    }

    const messageDoc = snapshot.data();
    if (!messageDoc) {
      console.warn("Private message document is empty.");
      return;
    }

    const chatId = String(event.params.chatId || "").trim();
    const messageId = String(event.params.messageId || "").trim();
    const senderId = String(messageDoc.senderId || "").trim();
    const senderPseudo = String(messageDoc.senderPseudo || "").trim();
    const text = String(messageDoc.text || "").trim();
    const type = String(messageDoc.type || "").trim();

    if (!chatId || !senderId) {
      console.warn("Missing chatId or senderId on private message.", {messageId});
      return;
    }

    if (type === "system") {
      console.log("System private message, skipping notification.", {chatId, messageId});
      return;
    }

    const chatSnap = await db.collection("private_chats").doc(chatId).get();

    if (!chatSnap.exists) {
      console.warn("Private chat not found.", {chatId, messageId});
      return;
    }

    const participantIds = chatSnap.data()?.participantIds || [];
    const recipientId = participantIds.find((uid) => uid !== senderId);

    if (!recipientId) {
      console.log("No recipient found for private message.", {chatId, messageId});
      return;
    }

    const notificationTitle = senderPseudo || "Nouveau message";
    const notificationBody = text.length > 100 ? text.substring(0, 100) + "…" : text;

    await sendPushToUser({
      userId: recipientId,
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: {
        type: "private_message_created",
        chatId,
        senderPseudo,
      },
      logContext: {
        trigger: "notifyOnPrivateMessageCreated",
        chatId,
        messageId,
      },
    });
  }
);

exports.notifyOnOwnerPendingActivity = onDocumentUpdated(
  {
    document: "activities/{activityId}",
    region: "europe-west1",
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    if (!after) {
      console.warn("Missing after data on activity update.", {
        activityId: event.params.activityId,
      });
      return;
    }

    if (before?.ownerPending !== false || after.ownerPending !== true) {
      return;
    }

    const activityId = String(event.params.activityId || "").trim();
    const activityTitle = String(after.title || "").trim();
    const createdById = String(after.createdById || "").trim();
    const participantCount = Number(after.participantCount || 0);

    if (participantCount <= 0) {
      console.log("No participants on owner pending activity.", {activityId});
      return;
    }

    const participantsSnap = await db
      .collection("activities")
      .doc(activityId)
      .collection("participants")
      .get();

    const recipientIds = participantsSnap.docs
      .map((doc) => String(doc.id || "").trim())
      .filter((userId) => userId && userId !== createdById);

    if (recipientIds.length === 0) {
      console.log("No recipients for owner pending notification.", {activityId});
      return;
    }

    const notificationTitle = "Organisateur recherché";
    const notificationBody = activityTitle
      ? `L'organisateur de «${activityTitle}» a quitté. Tu peux reprendre le rôle !`
      : "L'organisateur d'une activité a quitté. Tu peux reprendre le rôle !";

    for (const userId of recipientIds) {
      await sendPushToUser({
        userId,
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          type: "owner_pending",
          activityId,
        },
        logContext: {
          trigger: "notifyOnOwnerPendingActivity",
          activityId,
        },
      });
    }
  }
);

exports.geocodeActivityOnWrite = onDocumentWritten(
  {
    document: "activities/{activityId}",
    region: "europe-west1",
  },
  async (event) => {
    try {
      const afterSnap = event.data?.after;

      if (!afterSnap || !afterSnap.exists) {
        return;
      }

      const activityId = String(event.params.activityId || "").trim();
      const data = afterSnap.data() || {};

      const address = String(data.address || "").trim();
      if (!address) {
        return;
      }

      const geocodedAddress = String(data.geocodedAddress || "").trim();
      const hasCoords = data.latitude != null && data.longitude != null;

      if (address === geocodedAddress && hasCoords) {
        return;
      }

      const url = `https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${encodeURIComponent(address)}`;

      const response = await fetch(url, {
        headers: {"User-Agent": "AgendaSocialApp/1.0"},
      });

      if (!response.ok) {
        console.error("Nominatim HTTP error.", {
          activityId,
          address,
          status: response.status,
        });
        await afterSnap.ref.update({geocodeStatus: "failed"});
        return;
      }

      const results = await response.json();

      if (!Array.isArray(results) || results.length === 0) {
        console.error("Nominatim no results.", {activityId, address});
        await afterSnap.ref.update({geocodeStatus: "failed"});
        return;
      }

      const lat = parseFloat(results[0].lat);
      const lon = parseFloat(results[0].lon);

      await afterSnap.ref.update({
        latitude: lat,
        longitude: lon,
        geocodedAddress: address,
        geocodedAt: new Date(),
        geocodeStatus: "ok",
      });

      console.log("Geocoding success.", {
        activityId,
        geocodedAddress: address,
        lat,
        lon,
      });
    } catch (e) {
      console.error("geocodeActivityOnWrite unexpected error.", {
        activityId: event.params?.activityId,
        error: String(e),
      });
    }
  }
);

exports.matchSearchesOnActivityCreated = onDocumentCreated(
  {
    document: "activities/{activityId}",
    region: "europe-west1",
  },
  async (event) => {
    try {
      const snapshot = event.data;
      if (!snapshot) return;

      const activityId = String(event.params.activityId || "").trim();
      const activity = snapshot.data() || {};

      // 1. GARDES
      if (activity.visibility !== "public") return;
      if (activity.status === "cancelled" || activity.status === "done") return;

      const actStartTs = activity.startDateTime;
      const actEndTs = activity.endDateTime;
      if (!actStartTs || !actEndTs) return;

      const actStart = actStartTs.toMillis();
      const actEnd = actEndTs.toMillis();
      if (actStart < Date.now()) return;

      const actCategory = String(activity.category || "").trim();
      const actOwnerId = String(activity.ownerId || "").trim();
      const actCreatedById = String(activity.createdById || "").trim();
      const actTitle = String(activity.title || "").trim();

      // 2. RÉCUPÉRER LES RECHERCHES
      const searchesSnap = await db.collection("searches").limit(200).get();

      for (const searchDoc of searchesSnap.docs) {
        const search = searchDoc.data() || {};
        const searchId = searchDoc.id;
        const searchUserId = String(search.userId || "").trim();

        // a. catégorie
        if (String(search.category || "").trim() !== actCategory) continue;

        // b/c. pas l'organisateur ni le créateur
        if (!searchUserId) continue;
        if (searchUserId === actOwnerId) continue;
        if (searchUserId === actCreatedById) continue;

        // d. chevauchement temporel
        const searchStartTs = search.startDateTime;
        const searchEndTs = search.endDateTime;
        if (!searchStartTs || !searchEndTs) continue;

        const searchStart = searchStartTs.toMillis();
        const searchEnd = searchEndTs.toMillis();
        if (!(actStart < searchEnd && actEnd > searchStart)) continue;

        // e. dédoublonnage
        const existingSnap = await db
          .collection("users")
          .doc(searchUserId)
          .collection("notifications")
          .where("activityId", "==", activityId)
          .where("searchId", "==", searchId)
          .limit(1)
          .get();

        if (!existingSnap.empty) continue;

        // 3. CRÉER LA NOTIFICATION
        await db
          .collection("users")
          .doc(searchUserId)
          .collection("notifications")
          .add({
            type: "activity_match",
            title: "Nouvelle activité trouvée",
            body: "Une activité correspond à votre recherche",
            activityId,
            activityTitle: actTitle,
            searchId,
            category: actCategory,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

        console.log("activity_match notification created.", {
          activityId,
          searchId,
          searchUserId,
        });
      }
    } catch (e) {
      console.error("matchSearchesOnActivityCreated error.", {
        activityId: event.params?.activityId,
        error: String(e),
      });
    }
  }
);