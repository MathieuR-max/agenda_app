const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({maxInstances: 10});

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

    const toUserId = String(invitation.toUserId || "").trim();
    const activityTitle = String(invitation.activityTitle || "").trim();
    const fromUserPseudo = String(invitation.fromUserPseudo || "").trim();
    const status = String(invitation.status || "").trim();

    if (!toUserId) {
      console.warn("Missing toUserId on invitation.", {invitationId: snapshot.id});
      return;
    }

    if (status && status !== "pending") {
      console.log("Invitation is not pending, skipping notification.", {
        invitationId: snapshot.id,
        status,
      });
      return;
    }

    const devicesSnapshot = await admin
      .firestore()
      .collection("users")
      .doc(toUserId)
      .collection("devices")
      .get();

    if (devicesSnapshot.empty) {
      console.log("No device tokens found for user.", {toUserId});
      return;
    }

    const tokens = devicesSnapshot.docs
      .map((doc) => {
        const data = doc.data() || {};
        return String(data.token || "").trim();
      })
      .filter((token) => token.length > 0);

    if (tokens.length === 0) {
      console.log("No valid FCM tokens found for user.", {toUserId});
      return;
    }

    const title = "Nouvelle invitation";
    const body = activityTitle
      ? `Tu as reçu une invitation pour ${activityTitle}`
      : "Tu as reçu une nouvelle invitation";

    const message = {
      tokens,
      notification: {
        title,
        body,
      },
      data: {
        type: "activity_invitation",
        invitationId: snapshot.id,
        activityId: String(invitation.activityId || ""),
        toUserId,
        fromUserId: String(invitation.fromUserId || ""),
        fromUserPseudo,
      },
      android: {
        priority: "high",
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    console.log("Invitation notification sent.", {
      invitationId: snapshot.id,
      toUserId,
      successCount: response.successCount,
      failureCount: response.failureCount,
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
          token: tokens[index],
          code,
          message: result.error?.message || "",
        });
      }
    });

    if (tokensToDelete.length > 0) {
      const batch = admin.firestore().batch();

      devicesSnapshot.docs.forEach((doc) => {
        const token = String(doc.data()?.token || "").trim();
        if (tokensToDelete.includes(token)) {
          batch.delete(doc.ref);
        }
      });

      await batch.commit();

      console.log("Invalid tokens removed.", {
        removedCount: tokensToDelete.length,
        toUserId,
      });
    }
  }
);