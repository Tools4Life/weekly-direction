// Weekly Direction push server (Firebase Cloud Functions, 2nd gen).
//  - vapidKey: returns the public Web Push key (generated once and kept in Firestore, server-only).
//  - sendReminders: every minute, sends any reminders that came due since the last run.
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const webpush = require('web-push');
const { dueReminders } = require('./reminders');
admin.initializeApp();
const db = admin.firestore();
const KEYS = db.doc('_server/webpush'); // not under users/: client rules don't reach it

async function keys() {
  const s = await KEYS.get();
  if (s.exists && s.data().publicKey) return s.data();
  const k = webpush.generateVAPIDKeys(), v = { publicKey: k.publicKey, privateKey: k.privateKey, lastRun: Date.now() };
  await KEYS.set(v, { merge: true }); return v;
}

exports.vapidKey = onRequest({ cors: true, region: 'us-central1' }, async (req, res) => {
  const k = await keys(); res.set('Cache-Control', 'public, max-age=3600').json({ publicKey: k.publicKey });
});

exports.sendReminders = onSchedule({ schedule: 'every 1 minutes', region: 'us-central1', timeZone: 'America/New_York' }, async () => {
  const k = await keys(), now = Date.now(), from = Math.max(k.lastRun || now - 60e3, now - 10 * 60e3);
  await KEYS.set({ lastRun: now }, { merge: true });
  webpush.setVapidDetails('mailto:noreply@tools4life.app', k.publicKey, k.privateKey);
  const users = await db.collection('users').listDocuments();
  for (const u of users) {
    const base = u.collection('weeklyDirection'), pushRef = base.doc('push'), ps = await pushRef.get();
    if (!ps.exists) continue; const push = ps.data(); const subs = Object.fromEntries(Object.entries(push.subs || {}).filter(([, v]) => v && v.endpoint));
    if (!Object.keys(subs).length) continue;
    const [ss, wk] = await Promise.all([base.doc('settings').get(), base.doc('data').collection('weeks').where('status', '==', 'active').limit(1).get()]);
    const week = wk.empty ? null : wk.docs[0].data();
    const due = dueReminders({ from, to: now, week, settings: ss.exists ? ss.data() : {}, prefs: push.prefs || {}, tz: push.tz || 'America/New_York' });
    const sent = push.sent || {}, fresh = due.filter(n => !sent[n.id]); if (!fresh.length) continue;
    const dead = [];
    for (const n of fresh) for (const [sid, sub] of Object.entries(subs)) {
      try { await webpush.sendNotification(sub, JSON.stringify({ title: n.title, body: n.body, tag: n.id })); }
      catch (e) { if (e.statusCode === 404 || e.statusCode === 410) dead.push(sid); else console.error('push failed', sid, e.statusCode, e.body); }
    }
    const upd = {}; fresh.forEach(n => { upd[`sent.${n.id}`] = now; }); [...new Set(dead)].forEach(sid => { upd[`subs.${sid}`] = admin.firestore.FieldValue.delete(); });
    // keep the sent log small: drop entries older than 3 days
    Object.entries(sent).forEach(([id, t]) => { if (t < now - 3 * 864e5) upd[`sent.${id}`] = admin.firestore.FieldValue.delete(); });
    await pushRef.update(upd);
  }
});
