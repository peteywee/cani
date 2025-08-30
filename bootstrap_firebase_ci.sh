#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
mkdir -p "$ROOT/scripts" "$ROOT/functions/src" "$ROOT/.github/workflows"

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

echo "== Writing helper scripts =="

# scripts/set-env.sh
cat <<'EOF' > "$ROOT/scripts/set-env.sh"
#!/usr/bin/env bash
set -euo pipefail
env="${1:-dev}"
case "$env" in
  dev)  firebase use default  ;;
  prod) firebase use prod     ;;
  *) echo "usage: $0 [dev|prod]"; exit 1 ;;
esac
firebase use
EOF
chmod +x "$ROOT/scripts/set-env.sh"

echo "== Writing GitHub Actions workflow =="

# .github/workflows/firebase-deploy.yml
cat <<'EOF' > "$ROOT/.github/workflows/firebase-deploy.yml"
name: Firebase Deploy

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install dependencies
        run: |
          if [ -f package.json ]; then npm ci; fi
          if [ -f functions/package.json ]; then (cd functions && npm ci); fi

      - name: Build app (if script exists)
        run: |
          if [ -f package.json ] && jq -e '.scripts.build' package.json >/dev/null; then npm run build; fi

      - name: Preview deploy on PR
        if: github.event_name == 'pull_request'
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT_JSON }}'
          projectId: cani-dev-ws
          channelId: pr-${{ github.event.number }}

      - name: Deploy Hosting + Functions on main (dev)
        if: github.ref == 'refs/heads/main'
        run: |
          echo "${{ secrets.FIREBASE_SERVICE_ACCOUNT_JSON }}" > $HOME/sa.json
          npm i -g firebase-tools
          firebase use cani-dev-ws --token "$(jq -r .private_key_id $HOME/sa.json >/dev/null 2>&1 || echo '')" || true
          firebase deploy --only firestore:rules,storage:rules --project cani-dev-ws --token "$(jq -r .private_key_id $HOME/sa.json >/dev/null 2>&1 || echo '')" || true
          (cd functions && npm run build)
          firebase deploy --only functions,hosting --project cani-dev-ws --token "$(jq -r .private_key_id $HOME/sa.json >/dev/null 2>&1 || echo '')"
EOF

echo "== Writing .gitignore =="
cat <<'EOF' > "$ROOT/.gitignore"
# Node
node_modules/
npm-debug.log*
pnpm-lock.yaml
yarn.lock
dist/
.build/
.cache/

# Firebase
.firebase/
firebase-debug.log

# Functions
functions/lib/
functions/node_modules/

# Local env
.env
.env.*
!.env.example

# Secrets – DO NOT COMMIT
sa.json
*.key.json
EOF

echo "== Bootstrap complete =="
echo "Next:"
echo "  1) cd functions && npm install && npm run build && cd .."
echo "  2) firebase use --add (default=cani-dev-ws, prod=cani-prod-ws)"
echo "  3) Commit & push"
echo "  4) Create a minimal service account and add it to GitHub secrets (see instructions printed below)"
