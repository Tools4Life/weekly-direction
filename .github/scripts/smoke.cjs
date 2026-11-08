// Smoke test for Weekly Direction. Loads the app with sample data (no Firebase), walks every screen and the main
// actions, and fails on any page error or a broken service worker. Run before every push:
//   node .github/scripts/smoke.cjs        (needs Playwright with Chromium installed)
// Install the pre-push hook once per clone:  git config core.hooksPath .githooks
const path = require('path'), fs = require('fs');
let chromium;
try { ({ chromium } = require('playwright')); } catch (e) { console.error('smoke: Playwright not available — install it (npm i -g playwright && npx playwright install chromium)'); process.exit(2); }
const root = path.resolve(__dirname, '..', '..'), url = 'file://' + path.join(root, 'index.html');
const fail = [];
// 1) service worker must be intact
const sw = fs.readFileSync(path.join(root, 'sw.js'), 'utf8');
if (sw.length < 500 || !/addEventListener\('fetch'/.test(sw) || !/const CACHE='wd-v\d+'/.test(sw)) fail.push('sw.js is empty or broken');
try { new Function(sw); } catch (e) { fail.push('sw.js does not parse: ' + e.message); }
const T = x => new Date(x).getTime();
const mock = now => ({ settings: { cafOn: false }, prayers: [{ id: 'p1', text: 'Provision', icon: 'money', created: 1, body: 'Lord, provide.\n\nAmen.' }, { id: 'p2', text: 'No notes', icon: 'health', created: 2, body: '' }],
  weeks: [
    { id: 'w3', focus: 'Law', sealedAt: now - 3 * 864e5, status: 'active', planThoughts: 'Vision text.', liveRefl: 'So far.', qs: null,
      commitments: [{ id: 'a', name: 'Morning devotion', icon: 'sun', min: 10, by: '23:59', about: 'Quiet.' }, { id: 'b', name: 'Work review', icon: 'briefcase', days: 'wd', by: '00:01' }, { id: 'g', name: 'Guard my eyes', icon: 'eye' }],
      marks: {}, done: {}, runs: {} },
    { id: 'w1', focus: 'Word', sealedAt: now - 12 * 864e5, status: 'closed', closedAt: now - 5 * 864e5, percentage: 80, planThoughts: 'Stay in the Word.', reflection: 'Are temptations weaker, or easier to refuse?\nYes.\n\nGood week.',
      commitments: [{ id: 'x', name: 'Read', icon: 'book', by: '06:30' }], marks: {}, done: {} }] });
(async () => {
  const b = await chromium.launch();
  for (const theme of ['dark', 'light']) {
    const p = await b.newPage({ viewport: { width: 390, height: 844 } }); p.setDefaultTimeout(3000);
    p.on('pageerror', e => fail.push(`[${theme}] page error: ${e.message}`));
    p.on('dialog', d => d.accept());
    // fixed Wednesday morning, so the sample week always covers "today" whatever day the test runs
    const now = T('2026-11-11T10:00:00'), m = mock(now); m.settings.theme = theme;
    await p.clock.install({ time: now });
    await p.addInitScript(m => { window.__WD_MOCK = m; }, m);
    await p.goto(url); await p.waitForTimeout(900);
    const step = async (name, fn) => { try { await fn(); await p.waitForTimeout(350); } catch (e) { fail.push(`[${theme}] ${name}: ${e.message.split('\n')[0]}`); } };
    if (!(await p.$('.hcard'))) { fail.push(`[${theme}] app did not start (no habit cards on the home screen)`); await p.close(); continue; }
    await step('check a habit', () => p.click('[data-h=g]'));
    await step('habit details', async () => { await p.click('[data-hd=a]'); await p.waitForTimeout(400); await p.click('#hbDone'); });
    await step('start timer', async () => { await p.click('[data-h=a]'); await p.waitForTimeout(500); await p.click('#fcClose'); });
    await step('vision page', async () => { await p.click('.trow .focus'); await p.waitForTimeout(400); await p.click('#visClose'); });
    await step('reflect tab: mic + this week', async () => { await p.click('[data-tab=prayer]'); await p.waitForTimeout(400); if (!(await p.isVisible('#vcMic'))) throw new Error('mic button missing on Reflect'); if (!(await p.isVisible('#rfScroll'))) throw new Error('this week page missing'); });
    await step('prayer tab + read', async () => { await p.click('[data-tab=prayer]'); await p.waitForTimeout(400); await p.click('[data-rv=p]'); await p.waitForTimeout(300); if (await p.isVisible('#vcMic')) throw new Error('mic should hide on Prayer'); await p.click('[data-p="p1"]'); await p.waitForTimeout(400); await p.click('#pvDone'); await p.click('[data-rv=j]'); await p.waitForTimeout(300); if (!(await p.isVisible('#vcMic'))) throw new Error('mic missing on Journal'); });
    await step('progress tab', () => p.click('[data-tab=history]'));
    await step('week stats', async () => { await p.click('#pgHero'); await p.waitForTimeout(500); await p.click('#stVis'); await p.waitForTimeout(400); await p.click('#visClose'); await p.waitForTimeout(350); await p.click('#stClose'); });
    await step('all-time stats', async () => { await p.click('#pgHero'); await p.waitForTimeout(400); await p.click('[data-sv=all]'); await p.waitForTimeout(500); await p.click('[data-sv=week]'); await p.waitForTimeout(300); await p.click('#stClose'); await p.waitForTimeout(350); });
    await step('past week stats', async () => { await p.click('[data-w=w1]'); await p.waitForTimeout(400); await p.click('#stClose'); await p.waitForTimeout(350); });
    await step('reflect', async () => { await p.click('[data-tab=prayer]'); await p.waitForTimeout(300); await p.click('.rfnow [data-tg]'); await p.waitForTimeout(450); await p.click('[data-rfw]'); await p.waitForTimeout(500); await p.fill('#jrText', 'Smoke entry'); await p.click('#jrDone'); await p.waitForTimeout(400); if (!(await p.textContent('#rfWeek')).includes('Smoke entry')) throw new Error('new entry not added'); });
    await step('settings', async () => { await p.click('[data-tab=week]'); await p.waitForTimeout(300); await p.click('[data-gear]'); await p.waitForTimeout(300); await p.click('#stDone'); });
    await step('re-plan screen', async () => { await p.click('[data-gear]'); await p.waitForTimeout(300); await p.click('#stReplan'); await p.waitForTimeout(500); });
    await p.close();
  }
  await b.close();
  if (fail.length) { console.error('SMOKE TEST FAILED:\n - ' + fail.join('\n - ')); process.exit(1); }
  console.log('smoke test passed');
})();
