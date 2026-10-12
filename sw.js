// Weekly Direction service worker: lets the home-screen app open with no signal.
const CACHE='wd-v18';
const FB='https://www.gstatic.com/firebasejs/10.12.2/';
const SHELL=['./','./index.html','./manifest.json','./apple-touch-icon.png','./icon-192.png','./icon-512.png'];
const SDK=[FB+'firebase-app.js',FB+'firebase-auth.js',FB+'firebase-firestore.js'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(async c=>{await c.addAll(SHELL);await Promise.all(SDK.map(u=>c.add(new Request(u,{mode:'cors'})).catch(()=>{})))}).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
const CDN=['www.gstatic.com','fonts.googleapis.com','fonts.gstatic.com'];
self.addEventListener('fetch',e=>{
  const r=e.request;if(r.method!=='GET')return;const u=new URL(r.url);
  if(u.origin===location.origin){ // app files: fresh when online, cached when not
    e.respondWith(fetch(r).then(res=>{if(res.ok){const cp=res.clone();caches.open(CACHE).then(c=>c.put(r,cp))}return res})
      .catch(()=>caches.match(r,{ignoreSearch:true}).then(m=>m||caches.match('./index.html'))));return}
  if(CDN.includes(u.hostname)&&(u.hostname!=='www.gstatic.com'||u.pathname.startsWith('/firebasejs/'))){ // fonts and pinned SDK: cache first
    e.respondWith(caches.match(r).then(m=>m||fetch(r).then(res=>{if(res.ok||res.type==='opaque'){const cp=res.clone();caches.open(CACHE).then(c=>c.put(r,cp))}return res})))}
  // everything else (Firestore, sign-in) goes straight to the network; Firestore keeps its own offline copy
});
