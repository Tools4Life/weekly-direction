// Live words while recording: hands the app a one-minute OpenAI key for a realtime transcription session.
// The app streams the mic straight to OpenAI over WebRTC; the long-lived key never leaves Secret Manager.
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const OPENAI_API_KEY = defineSecret('OPENAI_API_KEY');
const cleanKey = () => String(OPENAI_API_KEY.value() || '').replace(/[^A-Za-z0-9_\-]/g, '');
const DAY_LIVE = 60; // sessions per day
const today = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York' }).format(new Date());
// newest first: the streaming model takes no turn detection; the older one uses the default (speech pauses)
const TRIES = [
  { model: 'gpt-live-transcribe', input: { transcription: { model: 'gpt-live-transcribe' }, turn_detection: null } },
  { model: 'gpt-4o-transcribe', input: { transcription: { model: 'gpt-4o-transcribe', language: 'en' } } },
];

exports.liveToken = onRequest({ cors: true, region: 'us-central1', secrets: [OPENAI_API_KEY], timeoutSeconds: 20, maxInstances: 3 }, async (req, res) => {
  try { await handle(req, res); } catch (e) { console.error('liveToken crashed', e); if (!res.headersSent) res.status(500).json({ error: 'Server error.', detail: String(e && e.message || e).slice(0, 200) }); }
});
async function handle(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });
  let uid;
  try { uid = (await admin.auth().verifyIdToken(String(req.get('Authorization') || '').replace(/^Bearer /, ''))).uid; }
  catch (e) { return res.status(401).json({ error: 'Sign in again.' }); }
  const ref = admin.firestore().collection('_voice').doc(uid), day = today();
  const ok = await admin.firestore().runTransaction(async tx => {
    const s = await tx.get(ref), d = s.exists ? s.data() : {}, n = d.liveDay === day ? d.live || 0 : 0;
    if (n + 1 > DAY_LIVE) return false;
    tx.set(ref, { liveDay: day, live: n + 1 }, { merge: true }); return true;
  });
  if (!ok) return res.status(429).json({ error: 'Daily live limit reached.' });
  let last = '';
  for (const t of TRIES) {
    const body = { expires_after: { anchor: 'created_at', seconds: 60 }, session: { type: 'transcription', audio: { input: t.input } } };
    const r = await fetch('https://api.openai.com/v1/realtime/client_secrets', { method: 'POST', headers: { Authorization: `Bearer ${cleanKey()}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    if (r.ok) { const j = await r.json(); return res.json({ value: j.value || (j.client_secret && j.client_secret.value), model: t.model }); }
    last = `${r.status} ${(await r.text()).slice(0, 300)}`; console.warn('liveToken', t.model, last);
    if (r.status === 401 || r.status === 429 || r.status >= 500) break;
  }
  res.status(502).json({ error: 'Live words unavailable.', detail: last });
}
