import {Miniflare,Response} from 'miniflare';
import {generateKeyPairSync,randomBytes,sign,createHash} from 'node:crypto';
import {readFile,stat,mkdir} from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require=createRequire(new URL('../../ancient-nest-web/package.json',import.meta.url));const {chromium}=require('@playwright/test');const AxeBuilder=require('@axe-core/playwright').default;
const site='https://ancientnest.test',web=new URL('../../ancient-nest-web/out',import.meta.url).pathname;const pair=generateKeyPairSync('rsa',{modulusLength:2048});
const types={'.html':'text/html','.css':'text/css','.js':'application/javascript','.png':'image/png','.webp':'image/webp','.jpg':'image/jpeg','.svg':'image/svg+xml','.ttf':'font/ttf','.txt':'text/plain'};
const mf=new Miniflare({modules:true,scriptPath:new URL('../dist/worker.js',import.meta.url).pathname,compatibilityDate:'2026-08-06',d1Databases:{ACCOUNTS_DB:'browser-db'},bindings:{SITE_ORIGIN:site,CODE_PEPPER:randomBytes(32).toString('hex'),COORDINATOR_API_KEY:'browser-only-coordinator-secret-12345678901234567890',ACCOUNT_SIGNING_KEY:pair.privateKey.export({format:'pem',type:'pkcs8'}).toString()},outboundService:async()=>new Response('is_valid:true\n'),serviceBindings:{ASSETS:async req=>{let pathname=decodeURIComponent(new URL(req.url).pathname);if(pathname.includes('..'))return new Response('Not found',{status:404});let file=path.join(web,pathname);try{if((await stat(file)).isDirectory())file=path.join(file,'index.html');return new Response(await readFile(file),{headers:{'Content-Type':types[path.extname(file)]||'application/octet-stream'}});}catch{return new Response(await readFile(web+'/404.html'),{status:404,headers:{'Content-Type':'text/html'}});}}}});
let browser;let checks=0;
try{
 const db=await mf.getD1Database('ACCOUNTS_DB');await db.exec((await readFile(new URL('../migrations/0001_accounts.sql',import.meta.url),'utf8')).replace(/\n/g,' '));await db.exec((await readFile(new URL('../migrations/0002_match_stats.sql',import.meta.url),'utf8')).replace(/^--.*$/mg,'').replace(/\n/g,' '));
await db.exec((await readFile(new URL('../migrations/0003_playlist_stats.sql',import.meta.url),'utf8')).replace(/^--.*$/mg,'').replace(/\n/g,' '));
await db.exec((await readFile(new URL('../migrations/0004_rank_review.sql',import.meta.url),'utf8')).replace(/^--.*$/mg,'').replace(/\n/g,' '));
 for(const route of ['/','/game/','/play/','/community/','/news/','/profile/','/profile/demo/','/account/','/status/','/privacy/','/terms/','/news/development-update/','/news/networking-update/','/news/website-launch/']){const response=await mf.dispatchFetch(site+route);assert.equal(response.status,200,route);const html=await response.text();assert.match(html,/<main[^>]+id="main-content"/);assert.match(html,/rel="canonical"/);assert.match(html,/property="og:title"/);assert.match(html,/name="twitter:card"/);checks+=5;}
 for(const route of ['/sitemap.xml','/robots.txt','/icons/nest.svg','/icons/apple-touch-icon.png','/images/sanctuary.webp','/images/annu.webp','/images/naki.webp','/images/social-preview.jpg','/fonts/body.ttf','/fonts/display.ttf']){assert.equal((await mf.dispatchFetch(site+route)).status,200,route);checks++;}assert.equal((await mf.dispatchFetch(site+'/nonexistent-route')).status,404);checks++;
 const start=await mf.dispatchFetch(site+'/api/auth/steam',{redirect:'manual'});const callback=new URL(new URL(start.headers.get('location')).searchParams.get('openid.return_to'));
 const data={'openid.ns':'http://specs.openid.net/auth/2.0','openid.mode':'id_res','openid.op_endpoint':'https://steamcommunity.com/openid/login','openid.claimed_id':'https://steamcommunity.com/openid/id/76561198000000099','openid.identity':'https://steamcommunity.com/openid/id/76561198000000099','openid.return_to':callback.toString(),'openid.response_nonce':new Date().toISOString().replace(/\.\d{3}Z$/,'Z')+randomBytes(8).toString('hex'),'openid.assoc_handle':'fixture','openid.signed':'op_endpoint,claimed_id,identity,return_to,response_nonce,assoc_handle','openid.sig':'fixture'};
 for(const[k,v]of Object.entries(data))callback.searchParams.set(k,v);
 const result=await mf.dispatchFetch(callback.toString(),{headers:{Cookie:start.headers.get('set-cookie').split(';')[0]},redirect:'manual'});assert.equal(result.status,303);const cookie=/__Host-an_session=([^;, ]+)/.exec(result.headers.get('set-cookie'))[1];
 browser=await chromium.launch({executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE||'/usr/bin/chromium',args:['--no-sandbox','--disable-dev-shm-usage']});await mkdir('verification',{recursive:true});
 for(const width of [375,768,1024,1440]){
  const context=await browser.newContext({viewport:{width,height:1000}});await context.route(site+'/**',async route=>{const req=route.request();const response=await mf.dispatchFetch(req.url(),{method:req.method(),headers:req.headers(),body:req.postDataBuffer()||undefined,redirect:'manual'});await route.fulfill({status:response.status,headers:Object.fromEntries(response.headers),body:Buffer.from(await response.arrayBuffer())});});
  const page=await context.newPage();await page.goto(site+'/account/',{waitUntil:'networkidle'});await page.getByRole('link',{name:'Sign in with Steam',exact:true}).waitFor();assert.equal(await page.getByRole('link',{name:'Sign in with Steam',exact:true}).getAttribute('href'),'/api/auth/steam');checks++;
  let axe=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa']).analyze();assert.deepEqual(axe.violations.map(v=>v.id),[]);checks++;
  await context.addCookies([{name:'__Host-an_session',value:cookie,url:site,secure:true,httpOnly:true,sameSite:'Lax'}]);await page.reload({waitUntil:'networkidle'});await page.getByLabel('Your username',{exact:true}).waitFor();await page.getByLabel('Your username',{exact:true}).fill(width===375?'WebTester':'WebTesterWide');await page.getByRole('button',{name:'Save username',exact:true}).click();await page.getByText('Username updated.',{exact:false}).waitFor();checks++;
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);checks++;
  const game=generateKeyPairSync('rsa',{modulusLength:2048});const pem=game.publicKey.export({type:'spki',format:'pem'}).toString();const started=await mf.dispatchFetch(site+'/api/game/link/start',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({public_key:pem})});const link=await started.json();
  await page.getByLabel('Game link code',{exact:true}).fill(link.user_code);await page.getByRole('button',{name:'Check code',exact:true}).click();await page.getByText(link.key_fingerprint,{exact:true}).waitFor();assert.equal(await page.getByRole('button',{name:'Approve game connection'}).isDisabled(),true);checks++;
  await page.getByRole('checkbox').check();await page.getByRole('button',{name:'Approve game connection'}).click();await page.getByText('Approved. Return to the game',{exact:false}).waitFor();checks++;
  const claim=await mf.dispatchFetch(site+'/api/game/link/poll',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({device_secret:link.device_secret,signature:sign('RSA-SHA256',Buffer.from(link.challenge),game.privateKey).toString('base64')})});const native=await claim.json();assert.equal(native.status,'linked');checks++;
  await page.getByRole('button',{name:'Refresh device list',exact:true}).click();await page.getByRole('button',{name:'Unlink game',exact:true}).waitFor();checks++;
  axe=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa']).analyze();assert.deepEqual(axe.violations.map(v=>v.id),[]);checks++;
  await page.screenshot({path:`verification/account-${width}.png`,fullPage:true});
  await page.getByRole('button',{name:'Unlink game',exact:true}).click();await page.getByText('Game installation unlinked.',{exact:true}).waitFor();checks++;
  const revoked=await mf.dispatchFetch(site+'/api/game/verify',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({assertion:native.assertion,key_hash:createHash('sha256').update(pem).digest('hex')})});assert.equal(revoked.status,401);checks++;
  await page.goto(site+'/profile/',{waitUntil:'networkidle'});await page.getByText('Forgebound I',{exact:true}).waitFor();assert.equal(await page.getByText('1,642',{exact:true}).count(),0);checks++;
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);checks++;
  const own=await db.prepare('SELECT id FROM accounts WHERE steam_id=?').bind('76561198000000099').first();const opponent=crypto.randomUUID();await db.prepare('INSERT INTO accounts(id,steam_id,username,username_key,created_at) VALUES(?,?,?,?,?)').bind(opponent,'7656119800000'+width,'Opponent'+width,'opponent'+width,1).run();
  const match_id=crypto.randomUUID();const call=async(action,data)=>mf.dispatchFetch(site+'/api/internal/matches/'+action,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer browser-only-coordinator-secret-12345678901234567890'},body:JSON.stringify(data)});
  assert.equal((await call('register',{match_id,scope:'matchmaking',game_type:'team_deathmatch',hosting:'player_hosted',map_id:'sanctuary',authority_id:'test-host',roster:[{account_id:own.id,team:0},{account_id:opponent,team:1}]})).status,200);
  assert.equal((await call('result',{match_id,epoch:1,authority_id:'test-host',winner_team:0,players:[own.id,opponent].map((account_id,i)=>({account_id,kills:i?2:10,deaths:i?10:2,assists:1,flags_captured:0,flags_stopped:0}))})).status,200);
  await page.getByRole('button',{name:'Refresh statistics',exact:true}).click();await page.getByRole('table').waitFor();await page.getByText('sanctuary · player hosted',{exact:true}).first().waitFor();checks++;
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);checks++;
  axe=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa']).analyze();assert.deepEqual(axe.violations.map(v=>v.id),[]);checks++;
  await page.screenshot({path:`verification/profile-${width}.png`,fullPage:true});
  for(const route of ['/','/game/','/play/','/community/','/news/','/profile/demo/','/status/','/privacy/','/terms/','/news/development-update/','/news/networking-update/','/news/website-launch/']){
   const response=await page.goto(site+route,{waitUntil:'networkidle'});assert.equal(response.status(),200,route);checks++;
   if(route==='/game/'&&(width===375||width===1440))await page.screenshot({path:`verification/game-story-${width}.png`,fullPage:true});
   assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true,route+' overflow');checks++;
   assert.equal(await page.locator('main h1').count(),1,route);checks++;
   const accessibility=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa']).analyze();assert.deepEqual(accessibility.violations.map(v=>v.id),[],route);checks++;
  }
  if(width<1024){await page.goto(site,{waitUntil:'networkidle'});const toggle=page.locator('.menu-toggle');await toggle.click();assert.equal(await toggle.getAttribute('aria-expanded'),'true');await page.keyboard.press('Escape');assert.equal(await toggle.getAttribute('aria-expanded'),'false');await toggle.click();await page.getByRole('navigation',{name:'Mobile navigation'}).getByRole('link',{name:'Game',exact:true}).click();assert.equal(await toggle.getAttribute('aria-expanded'),'false');checks+=3;}

  console.log('PASS account browser width',width);await context.close();
 }
 console.log('ACCOUNT BROWSER:',checks,'checks passed; Steam provider simulated; actual D1/Worker and browser UI.');
}finally{await browser?.close();await mf.dispose();}
