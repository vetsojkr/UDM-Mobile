// functions/index.js
// ═══════════════════════════════════════════════════════════════════════════
// CLOUD FUNCTION — Suppression utilisateur Firebase Auth
// ═══════════════════════════════════════════════════════════════════════════
//
// DÉPLOIEMENT (1 seule fois) :
// 1. Dans le terminal, à la racine de votre projet Firebase :
//    npm install -g firebase-tools
//    firebase login
//    cd functions && npm install
//    firebase deploy --only functions
//
// ═══════════════════════════════════════════════════════════════════════════

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Supprime un utilisateur de Firebase Authentication.
 * Appelée depuis Flutter via FirebaseFunctions.instance.httpsCallable('deleteAuthUser')
 * Nécessite que l'appelant ait le rôle 'admin' dans Firestore.
 */
exports.deleteAuthUser = functions.https.onCall(async (data, context) => {
  // 1. Vérifier authentification
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Vous devez être connecté."
    );
  }

  // 2. Vérifier rôle admin
  const callerDoc = await admin
    .firestore()
    .collection("utilisateurs")
    .doc(context.auth.uid)
    .get();

  if (!callerDoc.exists || callerDoc.data().role !== "admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Réservé aux administrateurs."
    );
  }

  // 3. Valider l'argument
  const { userId } = data;
  if (!userId || typeof userId !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "userId invalide."
    );
  }

  // 4. Supprimer de Firebase Auth
  try {
    await admin.auth().deleteUser(userId);
    console.log(`Auth user ${userId} supprimé avec succès.`);
    return { success: true };
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      // Déjà supprimé — pas une erreur
      return { success: true, message: "Déjà inexistant." };
    }
    console.error("Erreur suppression auth:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});