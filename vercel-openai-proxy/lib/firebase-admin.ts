import * as admin from "firebase-admin";

let initialized = false;

export function getFirebaseAdmin(): typeof admin {
  if (initialized && admin.apps.length) {
    return admin;
  }

  const skip =
    process.env.SKIP_AUTH === "true" && process.env.NODE_ENV !== "production";
  if (skip) {
    return admin;
  }

  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) {
    throw new Error("Missing FIREBASE_SERVICE_ACCOUNT_JSON");
  }

  const cred = JSON.parse(raw) as admin.ServiceAccount;
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(cred),
    });
  }
  initialized = true;
  return admin;
}

export async function verifyFirebaseIdToken(
  idToken: string
): Promise<admin.auth.DecodedIdToken> {
  const skip =
    process.env.SKIP_AUTH === "true" && process.env.NODE_ENV !== "production";
  if (skip) {
    return { uid: "dev" } as admin.auth.DecodedIdToken;
  }
  const app = getFirebaseAdmin();
  return app.auth().verifyIdToken(idToken);
}
