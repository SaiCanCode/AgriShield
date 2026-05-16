# firebase_provision

This folder contains helpers to provision device tokens and Realtime Database rules for AgriShield.

Files:
- `firebase_database.rules.json` — Realtime Database rules (Option A: custom tokens)
- `index.js` — lightweight token issuer (Express). Expects `ISSUER_SECRET` env var and Google credentials via environment.
- `package.json` — Node 18 dependencies.

Quick start (local):

1. Install deps:

```bash
cd firebase_provision
npm install
```

2. Set credentials and secret (recommended: use a service account or run on GCP Cloud Run/Cloud Function with appropriate service account):

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
export ISSUER_SECRET=some-secret
node index.js
```

3. Mint a token:

```bash
curl -X POST http://localhost:3000/mint -H "x-issuer-secret: some-secret" -H "Content-Type: application/json" -d '{"nodeId":"testnode"}'
```

4. Exchange the returned custom token for an ID token using the Identity Toolkit REST API with your Web API Key (see README notes in repo root).

Deploy: prefer Cloud Run or Cloud Functions; ensure environment secret is set and the service account has `firebaseadminsdk` privileges.
