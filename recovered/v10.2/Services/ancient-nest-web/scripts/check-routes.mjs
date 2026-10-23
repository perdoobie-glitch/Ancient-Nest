import assert from 'node:assert/strict';
const base=process.env.TEST_BASE_URL||'http://127.0.0.1:3100';
const routes=['/','/game','/play','/community','/news','/profile','/profile/demo','/account','/status','/privacy','/terms','/news/development-update','/news/networking-update','/news/website-launch'];
let checks=0;
for(const route of routes){
 const res=await fetch(base+route);assert.equal(res.status,200,route);checks++;
 const text=await res.text();assert.match(text,/<main[^>]+id="main-content"/,route+' main');checks++;
 assert.match(text,/<h1[ >]/,route+' heading');checks++;
 assert.match(text,/rel="canonical"/,route+' canonical');checks++;
 assert.match(text,/property="og:title"/,route+' og title');checks++;
 assert.match(text,/property="og:image"/,route+' og image');checks++;
 assert.match(text,/name="twitter:card"/,route+' social');checks++;
 if(route==='/account'){assert.match(text,/Account|account/);assert.doesNotMatch(text,/<input[^>]*type="password"/);checks+=2;}
 if(route==='/profile/demo'){assert.match(text,/Mock data/);assert.match(text,/1\.25/);checks+=2;}
 console.log('PASS',route);
}
for(const route of ['/sitemap.xml','/robots.txt','/icons/nest.svg','/icons/apple-touch-icon.png','/images/sanctuary.webp','/images/annu.webp','/images/naki.webp','/images/social-preview.jpg','/images/rank-forgebound-iii.png','/fonts/body.ttf','/fonts/display.ttf']){const res=await fetch(base+route);assert.equal(res.status,200,route);checks++;}
const unknown=await fetch(base+'/this-page-does-not-exist');assert.equal(unknown.status,404);checks++;
const sitemap=await(await fetch(base+'/sitemap.xml')).text();assert.match(sitemap,/ancientnest\.net\/play/);assert.doesNotMatch(sitemap,/\/profile/);checks+=2;
const robots=await(await fetch(base+'/robots.txt')).text();assert.match(robots,/Sitemap:/);checks++;
console.log(`ROUTE CHECKS: ${checks} passed`);
