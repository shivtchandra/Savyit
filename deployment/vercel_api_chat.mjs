/**
 * Example Vercel Node serverless route for POST /api/chat
 *
 * Setup:
 * 1. Copy this file to your Vercel repo as: api/chat.mjs  (→ https://<domain>/api/chat)
 * 2. npm install firebase-admin
 * 3. Vercel env (Production):
 *    - FIREBASE_SERVICE_ACCOUNT_JSON = entire downloaded service account JSON (one var)
 *    - OPENAI_API_KEY = sk-...
 *
 * Common 401 fix: JSON pasted in Vercel often stores private_key with literal \n two-char
 * sequences. firebase-admin needs real newlines — we normalize below.
 */

import admin from 'firebase-admin';

function parseServiceAccount() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw?.trim()) {
    throw new Error('Missing FIREBASE_SERVICE_ACCOUNT_JSON');
  }
  // Strip BOM / accidental whitespace from Vercel UI paste
  const trimmed = raw.trim().replace(/^\uFEFF/, '');
  let cred;
  try {
    cred = JSON.parse(trimmed);
  } catch (e) {
    throw new Error(
      `FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON: ${e?.message || e}`,
    );
  }
  if (typeof cred.private_key === 'string' && cred.private_key.includes('\\n')) {
    cred.private_key = cred.private_key.replace(/\\n/g, '\n');
  }
  if (!cred.project_id || !cred.client_email || !cred.private_key) {
    throw new Error(
      'Service account JSON missing project_id, client_email, or private_key',
    );
  }
  return cred;
}

function ensureFirebaseAdmin() {
  if (admin.apps.length) return;
  const cred = parseServiceAccount();
  console.info('[api/chat] Firebase Admin init for project_id=', cred.project_id);
  admin.initializeApp({
    credential: admin.credential.cert(cred),
  });
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const authz = req.headers.authorization || req.headers.Authorization;
  console.info(
    '[api/chat] authorization header present=',
    Boolean(authz),
    'length=',
    authz?.length ?? 0,
  );
  if (!authz?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing Authorization Bearer token' });
    return;
  }
  const idToken = authz.slice(7).trim();
  if (!idToken) {
    res.status(401).json({ error: 'Empty Bearer token' });
    return;
  }
  console.info('[api/chat] idToken length=', idToken.length);

  try {
    ensureFirebaseAdmin();
  } catch (e) {
    // Bad env JSON / private key — fix Vercel FIREBASE_SERVICE_ACCOUNT_JSON (not a client token issue).
    console.error('[api/chat] Firebase Admin init failed:', e?.code, e?.message || e);
    res.status(500).json({
      error: 'Server Firebase configuration invalid',
      detail: process.env.VERCEL_ENV === 'production' ? undefined : String(e?.message || e),
    });
    return;
  }

  try {
    await admin.auth().verifyIdToken(idToken);
  } catch (e) {
    console.error(
      '[api/chat] verifyIdToken failed:',
      e?.code || e?.errorInfo?.code,
      e?.message || e,
    );
    res.status(401).json({ error: 'Invalid or expired token' });
    return;
  }

  let payload;
  try {
    if (req.body && typeof req.body === 'object' && !Buffer.isBuffer(req.body)) {
      payload = req.body;
    } else {
      const raw =
        typeof req.body === 'string' ? req.body : await readBody(req);
      payload = JSON.parse(raw || '{}');
    }
  } catch (e) {
    res.status(400).json({ error: 'Invalid JSON body' });
    return;
  }

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey?.trim()) {
    res.status(500).json({ error: 'Server missing OPENAI_API_KEY' });
    return;
  }

  try {
    const upstream = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });
    const text = await upstream.text();
    res
      .status(upstream.status)
      .setHeader('Content-Type', 'application/json')
      .send(text);
  } catch (e) {
    console.error('[api/chat] OpenAI fetch failed:', e);
    res.status(502).json({ error: String(e?.message || e) });
  }
}
