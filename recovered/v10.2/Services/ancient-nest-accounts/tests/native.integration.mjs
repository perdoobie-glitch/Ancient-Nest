import {Miniflare,Response} from 'miniflare';
import {generateKeyPairSync,randomBytes,createPrivateKey,sign} from 'node:crypto';
import {readFile,mkdir} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
const gameProject=process.env.ANCIENT_NEST_GAME_PROJECT;assert.ok(gameProject,'Set ANCIENT_NEST_GAME_PROJECT to a full patched Godot project before this optional integration test.');
const origin='https://ancientnest.test';const key=generateKeyPairSync('rsa',{modulusLength:2048});
const mf=new Miniflare({modules:true,scriptPath:new URL('../dist/worker.js',import.meta.url).pathname,compatibilityDate:'2026-08-06',d1Databases:{ACCOUNTS_DB:'native-db'},bindings:{SITE_ORIGIN:origin,CODE_PEPPER:randomBytes(32).toString('hex'),ACCOUNT_SIGNING_KEY:key.privateKey.export({format:'pem',type:'pkcs8'}).toString()},outboundService:async()=>new Response('is_valid:true\n')});
let child;
try{
 const db=await mf.getD1Database('ACCOUNTS_DB');await db.exec((await readFile(new URL('../migrations/0001_accounts.sql',import.meta.url),'utf8')).replace(/\n/g,' '));await db.exec((await readFile(new URL('../migrations/0002_match_stats.sql',import.meta.url),'utf8')).replace(/^--.*$/mg,'').replace(/\n/g,' '));
await db.exec((await readFile(new URL('../migrations/0003_playlist_stats.sql',import.meta.url),'utf8')).replace(/^--.*$/mg,'').replace(/\n/g,' '));
await db.exec((await readFile(new URL('../migrations/0004_rank_review.sql',import.meta.url),'utf8')).replace(/^--.*$/mg,'').replace(/\n/g,' '));
 const start=await mf.dispatchFetch(origin+'/api/auth/steam',{redirect:'manual'});const callback=new URL(new URL(start.headers.get('location')).searchParams.get('openid.return_to'));
 const fields={'openid.ns':'http://specs.openid.net/auth/2.0','openid.mode':'id_res','openid.op_endpoint':'https://steamcommunity.com/openid/login','openid.claimed_id':'https://steamcommunity.com/openid/id/76561198000000088','openid.identity':'https://steamcommunity.com/openid/id/76561198000000088','openid.return_to':callback.toString(),'openid.response_nonce':new Date().toISOString().replace(/\.\d{3}Z$/,'Z')+randomBytes(8).toString('hex'),'openid.assoc_handle':'fixture','openid.signed':'op_endpoint,claimed_id,identity,return_to,response_nonce,assoc_handle','openid.sig':'fixture'};
 for(const [name,value] of Object.entries(fields))callback.searchParams.set(name,value);
 const response=await mf.dispatchFetch(callback.toString(),{redirect:'manual',headers:{Cookie:start.headers.get('set-cookie').split(';')[0]}});assert.equal(response.status,303);
 const cookie=/__Host-an_session=([^;, ]+)/.exec(response.headers.get('set-cookie'))[0];
 const me=await(await mf.dispatchFetch(origin+'/api/account',{headers:{Cookie:cookie}})).json();
 const post=async(path,data)=>mf.dispatchFetch(origin+path,{method:'POST',headers:{'Content-Type':'application/json','Origin':origin,'X-CSRF-Token':me.csrf,Cookie:cookie},body:JSON.stringify(data)});
 assert.equal((await post('/api/account/username',{username:'NativeTester'})).status,200);
 const url=await mf.ready;const dataRoot=new URL('../verification/native-userdata',import.meta.url).pathname;await mkdir(dataRoot,{recursive:true});
 child=spawn('godot',['--headless','--path',gameProject,'--script','res://tests/account_link_native.gd','--',url.origin],{env:{...process.env,XDG_DATA_HOME:dataRoot}});
 let all='',success,approval=Promise.resolve();
 child.stdout.setEncoding('utf8');child.stderr.setEncoding('utf8');child.stderr.on('data',s=>process.stderr.write(s));
 child.stdout.on('data',s=>{all+=s;process.stdout.write(s);for(const line of s.split('\n')){
  if(line.startsWith('NATIVE_LINK_READY ')){const value=JSON.parse(line.slice(18));approval=post('/api/game/link/approve',{code:value.code,fingerprint:value.fingerprint}).then(r=>assert.equal(r.status,200));}
  if(line.startsWith('NATIVE_LINK_SUCCESS '))success=JSON.parse(line.slice(20));
 }});
 const timeout=setTimeout(()=>child.kill('SIGTERM'),35000);const code=await new Promise(resolve=>child.once('exit',resolve));clearTimeout(timeout);await approval;
 assert.equal(code,0,all);assert.ok(success,'Native client did not report success');
 const details=JSON.parse(await readFile(success.path,'utf8'));const verify=await post('/api/game/verify',{assertion:details.assertion,key_hash:details.key_hash});assert.equal(verify.status,200);const info=await verify.json();assert.equal(info.account_id,me.account.id);assert.equal(info.username,'NativeTester');
 const nativePrivate=createPrivateKey(await readFile(dataRoot+'/godot/app_userdata/Ancient Nest/hybrid_identity.key'));
 // Match the native key's exact original serialization used by the account service.
 const storedDevice=await db.prepare('SELECT public_key FROM game_devices WHERE key_hash=?').bind(details.key_hash).first();
 const hub=spawn('python',[gameProject+'/services/hybrid/server.py','--bind','127.0.0.1','--port','18890','--udp-bind','127.0.0.1','--udp-port','18891','--state',new URL('../verification/native-hub-state',import.meta.url).pathname,'--account-api',url.origin,'--require-accounts'],{cwd:gameProject+'/services/hybrid'});
 let hubReady=false;hub.stdout.setEncoding('utf8');hub.stdout.on('data',s=>{if(s.includes('hub listening'))hubReady=true;});hub.stderr.on('data',s=>process.stderr.write(s));
 try{
  const deadline=Date.now()+8000;while(!hubReady&&Date.now()<deadline)await new Promise(r=>setTimeout(r,50));assert.ok(hubReady,'Hub failed to start');
  async function join(token,expectAccount){return new Promise((resolve,reject)=>{const ws=new WebSocket('ws://127.0.0.1:18890');const timer=setTimeout(()=>{ws.close();reject(Error('Account hub admission timeout'));},7000);ws.onopen=()=>ws.send(JSON.stringify({type:'hello',version:'40.0-chatgpt-hybrid1',name:'ForgedName',public_key:storedDevice.public_key,account_assertion:token,rating:{human:3200,practice:3200},local_ips:[]}));ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.type==='challenge')ws.send(JSON.stringify({type:'proof',signature:sign('RSA-SHA256',Buffer.from(m.nonce),nativePrivate).toString('base64')}));if(m.type==='hello'||m.type==='failed'){clearTimeout(timer);ws.close();resolve(m);}};ws.onerror=()=>{clearTimeout(timer);reject(Error('Hub websocket failed'));};});}
  const accepted=await join(details.assertion,true);assert.equal(accepted.type,'hello');assert.equal(accepted.player,'account:'+me.account.id);
  await new Promise(r=>setTimeout(r,150));const rejected=await join('',false);assert.equal(rejected.type,'failed');console.log('ACCOUNT HUB: verified account admitted under stable account ID; missing account assertion rejected.');
 }finally{hub.kill('SIGTERM');await new Promise(r=>hub.once('exit',r));}
 console.log('NATIVE ACCOUNT INTEGRATION: game RSA proof, website approval, one-time claim, persistent link, native refresh, username and backend introspection passed. Steam provider was simulated.');
}finally{child?.kill();await mf.dispose();}
