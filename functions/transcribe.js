// Voice reflections: the app posts a recording here; this checks it's you, then asks OpenAI for the text.
// The OpenAI key lives only in Secret Manager (OPENAI_API_KEY), never in the app.
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const OPENAI_API_KEY = defineSecret('OPENAI_API_KEY');
// keys pasted through notes/terminals can pick up spaces, line breaks or invisible characters
const cleanKey = () => String(OPENAI_API_KEY.value() || '').replace(/[^A-Za-z0-9_\-]/g, '');
const MODELS = ['gpt-transcribe', 'gpt-4o-transcribe']; // newest first; falls back if the first is refused
const MAX_BYTES = 15 * 1024 * 1024, MAX_SEC = 12 * 60, DAY_SEC = 90 * 60, DAY_REQ = 60;
// words it should expect, so they come out spelled right
const HINTS = 'A personal weekly reflection, spoken by a Christian man about his walk with God, work in construction, family and church. ' +
  'Expect Bible book names and terms such as Genesis, Psalms, Proverbs, Ecclesiastes, Isaiah, Habakkuk, Romans, Corinthians, Galatians, Ephesians, Philippians, Thessalonians, Hebrews, scripture, devotion, repentance, sanctification, grace.';
const ext = t => /mp4|m4a|aac/.test(t) ? 'm4a' : /webm/.test(t) ? 'webm' : /ogg/.test(t) ? 'ogg' : /wav/.test(t) ? 'wav' : /mpeg|mp3/.test(t) ? 'mp3' : 'm4a';
const today = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York' }).format(new Date());

exports.transcribe = onRequest({ cors: true, region: 'us-central1', secrets: [OPENAI_API_KEY], timeoutSeconds: 120, memory: '512MiB', maxInstances: 3 }, async (req, res) => {
  try { await handle(req, res); } catch (e) { console.error('transcribe crashed', e); if (!res.headersSent) res.status(500).json({ error: 'Server error.', detail: String(e && e.message || e).slice(0, 200) }); }
});
async function handle(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });
  let uid;
  try { uid = (await admin.auth().verifyIdToken(String(req.get('Authorization') || '').replace(/^Bearer /, ''))).uid; }
  catch (e) { return res.status(401).json({ error: 'Sign in again.' }); }
  const body = req.rawBody, type = String(req.get('Content-Type') || 'audio/mp4').split(';')[0];
  if (!body || !body.length) return res.status(400).json({ error: 'No audio.' });
  if (body.length > MAX_BYTES) return res.status(413).json({ error: 'Recording too long.' });
  const sec = Math.min(MAX_SEC, Math.max(1, Math.round(+req.get('X-Duration') || body.length / 8000)));
  // daily cap so a stolen sign-in can't run up the bill
  const ref = admin.firestore().collection('_voice').doc(uid), day = today();
  const ok = await admin.firestore().runTransaction(async tx => {
    const s = await tx.get(ref), u = s.exists && s.data().day === day ? s.data() : { day, sec: 0, n: 0 };
    if (u.sec + sec > DAY_SEC || u.n + 1 > DAY_REQ) return false;
    tx.set(ref, { day, sec: u.sec + sec, n: u.n + 1 }, { merge: true }); return true;
  });
  if (!ok) return res.status(429).json({ error: 'Daily voice limit reached.' });
  let last = '';
  for (const model of MODELS) {
    const fd = new FormData();
    fd.append('file', new Blob([body], { type }), `reflection.${ext(type)}`);
    fd.append('model', model); fd.append('prompt', HINTS); fd.append('response_format', 'json');
    const r = await fetch('https://api.openai.com/v1/audio/transcriptions', { method: 'POST', headers: { Authorization: `Bearer ${cleanKey()}` }, body: fd });
    if (r.ok) { const j = await r.json(); return res.json({ text: String(j.text || '').trim(), model }); }
    last = `${r.status} ${(await r.text()).slice(0, 300)}`; console.warn('transcribe', model, last);
    if (r.status === 401 || r.status === 429 || r.status >= 500) break; // key/billing/outage: another model won't help
  }
  res.status(502).json({ error: 'Transcription failed.', detail: last });
}
