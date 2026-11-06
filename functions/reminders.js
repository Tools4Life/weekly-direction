// Pure reminder logic (no Firebase): which notifications are due between two instants for one user.
// Kept separate so it can be tested without a server.
const pad = n => String(n).padStart(2, '0');
// wall-clock parts of an instant in an IANA time zone
function parts(ms, tz) {
  const f = new Intl.DateTimeFormat('en-US', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', weekday: 'short', hour12: false });
  const o = {}; for (const p of f.formatToParts(new Date(ms))) o[p.type] = p.value;
  const dow = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(o.weekday);
  return { key: `${o.year}-${o.month}-${o.day}`, h: +o.hour % 24, m: +o.minute, dow };
}
// instant of a wall-clock time (yyyy-mm-dd, HH:MM) in tz
function at(key, hhmm, tz) {
  const [y, mo, d] = key.split('-').map(Number), [h, mi] = hhmm.split(':').map(Number);
  let guess = Date.UTC(y, mo - 1, d, h, mi);
  for (let i = 0; i < 3; i++) { const p = parts(guess, tz), diff = (Date.UTC(y, mo - 1, d, h, mi) - Date.UTC(+p.key.slice(0, 4), +p.key.slice(5, 7) - 1, +p.key.slice(8), p.h, p.m)); if (!diff) break; guess += diff; }
  return guess;
}
const onDay = (c, dow) => !c.days || (c.days === 'wd') === (dow > 0 && dow < 6);
const clock = t => { const [h, m] = t.split(':').map(Number); return `${h % 12 || 12}:${pad(m)} ${h < 12 ? 'am' : 'pm'}`; };
// from, to: instants (ms); week: the active week doc; settings: app settings; prefs: which kinds are on; tz: user's zone
function dueReminders({ from, to, week, settings, prefs, tz }) {
  const out = []; if (!week) return out;
  const p = parts(to, tz), k = p.key, dn = (week.done || {})[k] || {}, runs = (week.runs || {})[k] || {};
  const sealedKey = parts(week.sealedAt, tz).key; if (k < sealedKey) return out;
  const habits = (week.commitments || []).filter(c => onDay(c, p.dow));
  const open = c => !dn[c.id] && !dn[c.id + '@fail'];
  const inWin = t => t > from && t <= to;
  if (prefs.startBy !== false) for (const c of habits) if (c.by && open(c) && !runs[c.id]) {
    const t = at(k, c.by, tz) - 15 * 60e3;
    if (inWin(t)) out.push({ id: `by:${k}:${c.id}`, title: c.name, body: `Start by ${clock(c.by)} — 15 minutes left.` });
  }
  if (prefs.timer !== false) for (const c of week.commitments || []) { const r = runs[c.id]; if (r && c.min && !dn[c.id]) { const t = r + c.min * 60e3; if (inWin(t)) out.push({ id: `timer:${k}:${c.id}`, title: `${c.name} · done`, body: `Your ${c.min}-minute timer finished.` }); } }
  if (prefs.evening !== false) { const t = at(k, '21:00', tz), left = habits.filter(open); if (inWin(t) && left.length) out.push({ id: `eve:${k}`, title: 'Today isn’t finished', body: `${left.length} habit${left.length > 1 ? 's' : ''} still open: ${left.map(c => c.name).join(', ')}.` }); }
  if (prefs.review !== false) { const cd = settings.closeDay ?? 6, ch = settings.closeHour ?? 17; if (p.dow === cd) { const t = at(k, `${pad(ch)}:00`, tz); if (inWin(t)) out.push({ id: `rev:${k}`, title: 'Weekly review', body: `“${week.focus}” is ready to close. Reflect, answer your questions, and plan the next week.` }); } }
  return out;
}
module.exports = { dueReminders, parts, at };
