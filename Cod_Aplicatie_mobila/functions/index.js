///**
// * Import function triggers from their respective submodules:
// *
// * const {onCall} = require("firebase-functions/v2/https");
// * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
// *
// * See a full list of supported triggers at https://firebase.google.com/docs/functions
// */
//
//const {onRequest} = require("firebase-functions/v2/https");
//const logger = require("firebase-functions/logger");
//
//// Create and deploy your first functions
//// https://firebase.google.com/docs/functions/get-starteda
//
//// exports.helloWorld = onRequest((request, response) => {
////   logger.info("Hello logs!", {structuredData: true});
////   response.send("Hello from Firebase!");
//// });

const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
exports.notifyAccessGranted = functions.database
  .ref("/case/{codCasa}/acces")
  .onWrite((change, context) => {
    const after = change.after.val();
    const codCasa = context.params.codCasa;

    if (after === true) {
      const payload = {
        notification: {
          title: "Atenție! Acces permis",
          body: `Accesul către casa ${codCasa} a fost activat!`,
        },
        topic: codCasa,
      };

      return admin.messaging().send(payload)
        .then((response) => {
          console.log(`Notificare trimisă pentru ${codCasa}:`, response);
        })
        .catch((error) => {
          console.error(`Eroare la notificare pentru ${codCasa}:`, error);
        });
    }

    return null;
  });