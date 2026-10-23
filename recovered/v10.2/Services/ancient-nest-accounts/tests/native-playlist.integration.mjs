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
 const url=await mf.ready;const dataRoot=new URL('../verification/native-101-userdata',import.meta.url).pathname;await mkdir(dataRoot,{recursive:true});
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
 console.log('NATIVE PLAYLIST INTEGRATION: signed game link, browser approval, refreshed account session and authenticated 3v3 gamer card passed. Steam provider was simulated.');
}finally{child?.kill();await mf.dispose();}
