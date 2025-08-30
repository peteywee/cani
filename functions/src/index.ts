import * as functions from "firebase-functions";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

initializeApp();

export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  const db = getFirestore();
  const uid = user.uid;
  const email = user.email ?? "";
  const displayName = user.displayName ?? "";

  await db.collection("users").doc(uid).set({
    uid,
    email,
    displayName,
    role: "staff",
    createdAt: new Date().toISOString(),
    onboarded: false
  });
});
