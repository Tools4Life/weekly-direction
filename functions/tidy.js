// Tidy spoken words: the iOS app sends a transcript he dictated while planning or reviewing a week; this returns the same
// words cleaned up (fillers, repeats and false starts removed), never a summary. Same sign-in check and key as summarize.
//   { mode: "vision" | "reflection", text } -> { text }
//   { mode: "rate", text, questions }       -> { ratings: [{ v: 1 | 0 | -1 | null, quote }] } one per question; a proposal he confirms in the app
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
const RATE = `You read one week of a man's private reflection. He asks himself the same numbered questions every week to see whether areas of his life are getting better or worse.
For each question decide what HE says about that area this week: "better", "same", "worse", or "none" when he did not speak to it.
Judge only from what he actually said. Mixed or unclear is "same". Never guess from tone, and never rate an area he did not mention: that is "none".
For each rating give "quote": the one sentence of his, word for word and at most 160 characters, that the rating rests on ("" for "none").
Return JSON only: {"ratings": [{"v": "better" | "same" | "worse" | "none", "quote": string}, ...]} with exactly one entry per question, in order.`;
const today = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York' }).format(new Date());

exports.tidy = onRequest({ cors: true, region: 'us-central1', secrets: [OPENAI_API_KEY], timeoutSeconds: 60, maxInstances: 3 }, async (req, res) => {
  try { await handle(req, res); } catch (e) { console.error('tidy crashed', e); if (!res.headersSent) res.status(500).json({ error: 'Server error.', detail: String(e && e.message || e).slice(0, 200) }); }
});
async function handle(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });
  let uid;
  try { uid = (await admin.auth().verifyIdToken(String(req.get('Authorization') || '').replace(/^Bearer /, ''))).uid; }
  catch (e) { return res.status(401).json({ error: 'Sign in again.' }); }
  const b = req.body || {}, text = String(b.text || '').trim().slice(0, MAX_CHARS), rate = b.mode === 'rate', system = rate ? RATE : b.mode === 'reflection' ? REFLECTION : VISION;
  const questions = rate ? (Array.isArray(b.questions) ? b.questions : []).map(q => String(q).slice(0, 300)).slice(0, 6) : [];
  if (rate && !questions.length) return res.status(400).json({ error: 'No questions.' });
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
      body: JSON.stringify({ model, messages: [{ role: 'system', content: system }, { role: 'user', content: rate ? `Questions:\n${questions.map((q, i) => `${i + 1}. ${q}`).join('\n')}\n\nHis reflection:\n${text}` : text }],
        ...(rate ? { response_format: { type: 'json_object' } } : {}) })
    });
    if (r.ok) {
      const out = String((await r.json()).choices?.[0]?.message?.content || '').trim();
      if (!out) { last = 'empty'; continue; }
      if (!rate) return res.json({ text: out, model });
      let j; try { j = JSON.parse(out); } catch (e) { last = 'bad json'; continue; }
      const val = { better: 1, same: 0, worse: -1 };
      const ratings = questions.map((_, i) => { const x = (Array.isArray(j.ratings) ? j.ratings[i] : null) || {}, v = val[String(x.v).toLowerCase()];
        return { v: v === undefined ? null : v, quote: v === undefined ? '' : String(x.quote || '').replace(/\s+/g, ' ').trim().slice(0, 200) }; });
      return res.json({ ratings, model });
    }
    last = `${r.status} ${(await r.text()).slice(0, 300)}`; console.warn('tidy', model, last);
    if (r.status === 401 || r.status === 429 || r.status >= 500) break;
  }
  res.status(502).json({ error: 'Tidy failed.', detail: last });
}
