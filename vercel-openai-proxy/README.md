# Vercel OpenAI proxy (Firebase Auth)

Keeps **OpenAI_API_KEY** on Vercel only. Your Flutter app sends the user’s **Firebase ID token**; this API verifies it, then calls OpenAI.

## 1. Install and run locally

```bash
cd vercel-openai-proxy
npm install
cp .env.example .env
# Edit .env: OPENAI_API_KEY, FIREBASE_SERVICE_ACCOUNT_JSON, optionally SKIP_AUTH=true
npm run dev
```

Test (with `SKIP_AUTH=true` in `.env` for local only):

```bash
curl -s -X POST http://localhost:3000/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer dummy" \
  -d '{"messages":[{"role":"user","content":"Say hi in 5 words"}]}'
```

## 2. Deploy to Vercel

### Option A — Vercel CLI

```bash
npm i -g vercel
cd vercel-openai-proxy
vercel login
vercel link   # create/link project
vercel env add OPENAI_API_KEY     # paste key, choose Production (+ Preview if you want)
vercel env add OPENAI_MODEL       # optional: gpt-4o-mini
vercel env add FIREBASE_SERVICE_ACCOUNT_JSON
# Paste the **entire** service account JSON as one line (see below)
vercel --prod
```

### Option B — GitHub + Vercel dashboard

1. Push this folder to a GitHub repo (or monorepo path).
2. Vercel → **Add New Project** → import repo; **Root Directory** = `vercel-openai-proxy` if nested.
3. **Settings → Environment Variables**:
   - `OPENAI_API_KEY` = your OpenAI secret key  
   - `OPENAI_MODEL` = e.g. `gpt-4o-mini` (optional)  
   - `FIREBASE_SERVICE_ACCOUNT_JSON` = full JSON string (see below)
4. Deploy.

## 3. Firebase service account JSON on Vercel

1. [Firebase Console](https://console.firebase.google.com) → your project → **Project settings** (gear) → **Service accounts**.
2. **Generate new private key** → download JSON.
3. Minify to **one line** (no line breaks) and paste into Vercel as `FIREBASE_SERVICE_ACCOUNT_JSON`.

Example (structure only — use your real file):

```json
{"type":"service_account","project_id":"xxx","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"firebase-adminsdk-...@....iam.gserviceaccount.com",...}
```

**Do not** commit this file to git.

## 4. Flutter: call the API

Replace `YOUR_VERCEL_URL` with `https://your-project.vercel.app` (no trailing slash).

```dart
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

Future<String> askOpenAi(List<Map<String, String>> messages) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not signed in');
  final token = await user.getIdToken();

  final uri = Uri.parse('https://YOUR_VERCEL_URL/api/chat');
  final res = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({'messages': messages}),
  );

  if (res.statusCode != 200) {
    throw Exception('API ${res.statusCode}: ${res.body}');
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  return data['text'] as String? ?? '';
}
```

Example messages:

```dart
final reply = await askOpenAi([
  {'role': 'user', 'content': 'Summarize budgeting in one sentence.'},
]);
```

For **Flutter web**, CORS is enabled on this route for simple cases; lock it down to your domain in production if needed.

## 5. Security checklist

- Never put `OPENAI_API_KEY` in the Flutter app.
- Do not set `SKIP_AUTH=true` in Vercel production.
- Add **rate limiting** (e.g. Upstash, Cloudflare) if abuse is a concern.
- Set **billing alerts** on OpenAI.

## API contract

**POST** `/api/chat`

Headers:

- `Authorization: Bearer <Firebase ID token>`
- `Content-Type: application/json`

Body:

```json
{
  "messages": [
    { "role": "system", "content": "You are a helpful assistant." },
    { "role": "user", "content": "Hello" }
  ]
}
```

Success **200**:

```json
{
  "text": "...",
  "model": "gpt-4o-mini",
  "usage": { "prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0 }
}
```
