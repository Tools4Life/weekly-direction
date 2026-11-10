// Tidy spoken words: the iOS app sends a transcript he dictated while planning or reviewing a week; this returns the same
// words cleaned up (fillers, repeats and false starts removed), never a summary. Same sign-in check and key as summarize.
//   { mode: "vision" | "reflection", text } -> { text }
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const OPENAI_API_KEY = defineSecret('OPENAI_API_KEY');
const cleanKey = () => String(OPENAI_API_KEY.value() || '').replace(/[^A-Za-z0-9_\-]/g, '');
const MODELS = ['gpt-5.4-mini', 'gpt-5-mini', 'gpt-4.1-mini']; // newest first; falls back if a name is refused
const DAY_REQ = 40, MAX_CHARS = 20000;
const RULES = `You are an editor for a man's private spoken notes. He dictated them; the transcript is rough.
Clean it up, do not rewrite it:
- Remove filler (um, uh, you know, like, I mean), false starts, and stutters.
- Where he says the same thing more than once, keep it once, in his clearest wording.
- Drop fragments that make no sense or trail off into nothing.
- Fix grammar and punctuation so it reads as plain sentences.
Keep it his: first person, his own words, phrases, tone and every concrete detail (names, places, habits, scripture, times).
Do not summarize, generalize, or shorten for its own sake. Do not add ideas, advice, encouragement, interpretation or anything he did not say.`;
const VISION = `${RULES}
The note is his vision for a week. Return only the cleaned text: short paragraphs, a blank line between them where the subject changes. No headings, lists or quotes.`;
const REFLECTION = `${RULES}
The note is his reflection on the week that just ended. Return only the cleaned text: short paragraphs, a blank line between them where the subject changes. No headings, lists or quotes.`;
const today = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York' }).format(new Date());

exports.tidy = onRequest({ cors: true, region: 'us-central1', secrets: [OPENAI_API_KEY], timeoutSeconds: 60, maxInstances: 3 }, async (req, res) => {
  try { await handle(req, res); } catch (e) { console.error('tidy crashed', e); if (!res.headersSent) res.status(500).json({ error: 'Server error.', detail: String(e && e.message || e).slice(0, 200) }); }
});
async function handle(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });
  let uid;
  try { uid = (await admin.auth().verifyIdToken(String(req.get('Authorization') || '').replace(/^Bearer /, ''))).uid; }
  catch (e) { return res.status(401).json({ error: 'Sign in again.' }); }
  const b = req.body || {}, text = String(b.text || '').trim().slice(0, MAX_CHARS), system = b.mode === 'reflection' ? REFLECTION : VISION;
  if (text.length < 8) return res.status(400).json({ error: 'Not enough to tidy.' });
  const ref = admin.firestore().collection('_voice').doc(uid + '_tidy'), day = today();
  const ok = await admin.firestore().runTransaction(async tx => {
    const s = await tx.get(ref), u = s.exists && s.data().day === day ? s.data() : { day, n: 0 };
    if (u.n + 1 > DAY_REQ) return false; tx.set(ref, { day, n: u.n + 1 }); return true;
  });
  if (!ok) return res.status(429).json({ error: 'Daily limit reached.' });
  let last = '';
  for (const model of MODELS) {
    const r = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST', headers: { Authorization: `Bearer ${cleanKey()}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model, messages: [{ role: 'system', content: system }, { role: 'user', content: text }] })
    });
    if (r.ok) { const out = String((await r.json()).choices?.[0]?.message?.content || '').trim(); if (out) return res.json({ text: out, model }); last = 'empty'; continue; }
    last = `${r.status} ${(await r.text()).slice(0, 300)}`; console.warn('tidy', model, last);
    if (r.status === 401 || r.status === 429 || r.status >= 500) break;
  }
  res.status(502).json({ error: 'Tidy failed.', detail: last });
}
