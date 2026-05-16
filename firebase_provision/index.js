const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');

// Expect credentials to be provided via environment (GOOGLE_APPLICATION_CREDENTIALS
// or deployed as a Cloud Function with proper service account).
try {
  admin.initializeApp();
} catch (e) {
  console.error('Firebase admin init error', e);
}

const app = express();
app.use(bodyParser.json());

// Simple auth for the issuer endpoint: set ISSUER_SECRET env var
function checkIssuerAuth(req, res, next) {
  const secret = process.env.ISSUER_SECRET || '';
  const header = req.get('x-issuer-secret') || '';
  if (!secret || header !== secret) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  next();
}

// POST /mint { nodeId }
app.post('/mint', checkIssuerAuth, async (req, res) => {
  const { nodeId } = req.body || {};
  if (!nodeId) return res.status(400).json({ error: 'missing nodeId' });

  try {
    const uid = `device:${nodeId}`;
    const additionalClaims = { device_id: nodeId };
    const token = await admin.auth().createCustomToken(uid, additionalClaims);
    return res.json({ token });
  } catch (err) {
    console.error('mint error', err);
    return res.status(500).json({ error: 'internal' });
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Device token issuer running on ${port}`));
