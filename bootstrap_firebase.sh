#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

echo "== Writing Firebase config =="

# firebase.json
cat <<'EOF' > "$ROOT/firebase.json"
{
  "hosting": {
    "public": "dist",
    "ignore": ["**/.*", "**/node_modules/**"],
    "cleanUrls": true,
    "trailingSlash": false,
    "rewrites": [{ "source": "**", "destination": "/index.html" }],
    "headers": [
      {
        "source": "**",
        "headers": [
          { "key": "X-Frame-Options", "value": "DENY" },
          { "key": "X-Content-Type-Options", "value": "nosniff" },
          { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
          { "key": "Permissions-Policy", "value": "geolocation=(), microphone=(), camera=()" }
        ]
      },
      {
        "source": "**/*.@(js|css|woff2|svg|png|jpg|jpeg|gif|webp)",
        "headers": [
          { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
        ]
      },
      {
        "source": "/index.html",
        "headers": [
          { "key": "Cache-Control", "value": "no-store" }
        ]
      }
    ]
  },
  "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" },
  "storage": { "rules": "storage.rules" },
  "emulators": {
    "ui": { "enabled": true },
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "storage": { "port": 9199 },
    "hosting": { "port": 5000 }
  }
}
EOF

# .firebaserc
cat <<'EOF' > "$ROOT/.firebaserc"
{
  "projects": {
    "default": "cani-dev-ws",
    "prod": "cani-prod-ws"
  }
}
EOF

# firestore.rules
cat <<'EOF' > "$ROOT/firestore.rules"
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() { return request.auth != null; }

    match /users/{uid} {
      allow read, update, delete: if isSignedIn() && request.auth.uid == uid;
      allow create: if isSignedIn() && request.auth.uid == uid;
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
EOF

# firestore.indexes.json
cat <<'EOF' > "$ROOT/firestore.indexes.json"
{
  "indexes": [],
  "fieldOverrides": []
}
EOF

# storage.rules
cat <<'EOF' > "$ROOT/storage.rules"
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isSignedIn() { return request.auth != null; }

    match /users/{uid}/{allPaths=**} {
      allow read, write: if isSignedIn() && request.auth.uid == uid;
    }

    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
EOF

echo "== Writing Functions skeleton =="

mkdir -p "$ROOT/functions/src"

# functions/package.json
cat <<'EOF' > "$ROOT/functions/package.json"
{
  "name": "cani-functions",
  "private": true,
  "engines": { "node": "20" },
  "type": "module",
  "scripts": {
    "build": "tsc -p tsconfig.json",
    "serve": "firebase emulators:start --only functions,firestore,auth,storage,hosting",
    "deploy": "firebase deploy --only functions",
    "lint": "eslint ."
  },
  "dependencies": {
    "firebase-admin": "^12.6.0",
    "firebase-functions": "^5.0.1"
  },
  "devDependencies": {
    "typescript": "^5.5.4",
    "@types/node": "^20.12.12",
    "eslint": "^9.9.0"
  }
}
EOF

# functions/tsconfig.json
cat <<'EOF' > "$ROOT/functions/tsconfig.json"
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "outDir": "lib",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true
  },
  "include": ["src"]
}
EOF

# functions/src/index.ts
cat <<'EOF' > "$ROOT/functions/src/index.ts"
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
EOF

echo "== Done. Config + Functions written =="
echo "Next steps:"
echo "  cd functions && npm install && npm run build"
echo "  cd .."
echo "  firebase deploy --only firestore:rules,storage:rules,functions,hosting"
