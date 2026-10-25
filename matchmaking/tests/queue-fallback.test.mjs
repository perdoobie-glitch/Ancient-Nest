import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Miniflare} from 'miniflare';
import {webcrypto} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {VERSION} from '../dist/core.js';
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const pem=bytes=>'-----BEGIN PUBLIC KEY-----\n'+Buffer.from(bytes).toString('base64').match(/.{1,64}/g).join('\n')+'\n-----END PUBLIC KEY-----\n';
async function client(mf,keys,options={}){
 keys??=await webcrypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
 const ws=(await mf.dispatchFetch('http://localhost/v1/matchmaking',{headers:{Upgrade:'websocket'}})).webSocket;ws.accept();const events=[];
 ws.addEventListener('message',async e=>{if(e.data==='nest-pong')return;const p=JSON.parse(e.data);events.push(p);if(p.type==='challenge')ws.send(JSON.stringify({type:'proof',signature:Buffer.from(await webcrypto.subtle.sign('RSASSA-PKCS1-v1_5',keys.privateKey,new TextEncoder().encode(p.nonce))).toString('base64')}));});
 ws.send(JSON.stringify({type:'hello',version:VERSION,playlist:'tactical_3v3',public_key:pem(await webcrypto.subtle.exportKey('spki',keys.publicKey)),name:'Fallback',...options}));
 const expected=options.lobby_only?'party':'queue';
 const until=Date.now()+10000;while(!events.some(e=>e.type===expected)&&Date.now()<until)await pause(10);
 assert(events.some(e=>e.type===expected),JSON.stringify(events));return {ws,events,keys,queue:events.findLast(e=>e.type==='queue')};
}
test('existing Worker fallback authenticates, rate limits, cancels idempotently and preserves a reconnect ticket',async()=>{
 const mf=new Miniflare({modules:true,scriptPath:fileURLToPath(new URL('../dist/worker.js',import.meta.url)),compatibilityDate:'2026-08-06',durableObjects:{MATCHMAKER:{className:'Matchmaker',useSQLite:true}},bindings:{ALLOW_GUESTS:'true',LOCAL_TEST:'true'}});
 const sockets=[];
 try{
  const a=await client(mf);sockets.push(a.ws);
  const poll=(ticket,operation='status')=>mf.dispatchFetch('http://localhost/v1/queue/status',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({ticket,operation})});
  assert.equal((await poll('tampered')).status,401);
  const first=await poll(a.queue.queue_token);assert.equal(first.status,200);assert.equal((await first.json()).state,'queued');
  const limited=await poll(a.queue.queue_token);assert.equal(limited.status,429);assert.equal(limited.headers.get('Retry-After'),'2');
  a.ws.close(1012,'temporary control outage');await pause(30);
  const b=await client(mf,a.keys);sockets.push(b.ws);assert.equal(b.queue.connected,1,'Reconnect does not duplicate queue membership');
  const cancelled=await poll(b.queue.queue_token,'cancel');assert.equal(cancelled.status,200);assert.equal((await cancelled.json()).state,'cancelled');
  const tooLarge=await mf.dispatchFetch('http://localhost/v1/queue/status',{method:'POST',body:'x'.repeat(9000)});assert.equal(tooLarge.status,413);
 }finally{for(const ws of sockets)try{ws.close()}catch{}await mf.dispose();}
});

test('explicit fresh connection changes playlist while unexpected reconnect preserves party',async()=>{
 const mf=new Miniflare({modules:true,scriptPath:fileURLToPath(new URL('../dist/worker.js',import.meta.url)),compatibilityDate:'2026-08-06',durableObjects:{MATCHMAKER:{className:'Matchmaker',useSQLite:true}},bindings:{ALLOW_GUESTS:'true',LOCAL_TEST:'true'}});
 const sockets=[];
 try{
  const a=await client(mf,null,{lobby_only:true,playlist:'duel_1v1'});sockets.push(a.ws);
  const original=a.events.findLast(e=>e.type==='party');a.ws.close(1012,'outage');await pause(30);
  const b=await client(mf,a.keys,{lobby_only:true,playlist:'doubles_2v2'});sockets.push(b.ws);
  assert.equal(b.events.findLast(e=>e.type==='party').code,original.code);
  b.ws.close(1012,'explicit departure socket race');await pause(30);
  const c=await client(mf,a.keys,{lobby_only:true,playlist:'doubles_2v2',resume:false});sockets.push(c.ws);
  assert.equal(c.events.findLast(e=>e.type==='party').playlist,'doubles_2v2');
  assert.notEqual(c.events.findLast(e=>e.type==='party').code,original.code);
 }finally{for(const ws of sockets)try{ws.close()}catch{}await mf.dispose();}
});
