import { fileURLToPath } from "node:url";
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Miniflare} from 'miniflare';
import {checkServer,masterOrigin} from '../scripts/check-server.mjs';
const make=(bindings={})=>new Miniflare({modules:true,scriptPath:fileURLToPath(new URL('../dist/worker.js',import.meta.url)),compatibilityDate:'2026-08-06',host:'127.0.0.1',port:0,durableObjects:{MATCHMAKER:{className:'Matchmaker',useSQLite:true}},bindings:{ALLOW_GUESTS:'true',LOCAL_TEST:'true',...bindings}});
test('setup URL parser accepts master URLs and rejects credentials and remote HTTP',()=>{
 assert.equal(masterOrigin('wss://master.example.com/v1/matchmaking'),'https://master.example.com');
 assert.equal(masterOrigin('https://master.example.com/health'),'https://master.example.com');
 for(const url of ['http://master.example.com','https://key@master.example.com','https://master.example.com/account','https://master.example.com/?token=secret'])assert.throws(()=>masterOrigin(url));
});
test('fresh guest Worker passes real health, readiness and WebSocket identity/party checks',async()=>{
 const mf=make();try{
  const origin=(await mf.ready).origin;const result=await checkServer(origin,{output:()=>{}});assert.equal(result.passed,true,JSON.stringify(result));
  assert(result.checks.some(x=>x.message.includes('opened a party')));
  assert(result.checks.some(x=>x.status==='WARN'&&x.message.includes('TURN')));
  const ready=await (await mf.dispatchFetch('http://localhost/ready')).json();assert.equal(ready.version,'10.5-discord2');assert.equal(ready.ready,true);assert.equal(ready.checks.auth_mode,'guest');
  assert.equal((await mf.dispatchFetch('http://localhost/ready',{method:'POST'})).status,405);
  for(const field of ['private','nonce','public_key','credential'])assert(!JSON.stringify(ready).includes(field));
 }finally{await mf.dispose();}
});
test('production Worker without account bridge fails setup validation clearly',async()=>{
 const mf=make({ALLOW_GUESTS:'false'});try{
  const result=await checkServer((await mf.ready).origin,{output:()=>{}});assert.equal(result.passed,false);assert(result.checks.some(x=>x.status==='FAIL'&&x.message.includes('account bridge')));
 }finally{await mf.dispose();}
});
test('configured account mode checks challenge without bypassing login',async()=>{
 const mf=make({ALLOW_GUESTS:'false',ACCOUNT_API:'https://accounts.example.com',COORDINATOR_API_KEY:'test-only-no-external-call'});try{
  const result=await checkServer((await mf.ready).origin,{output:()=>{}});assert.equal(result.passed,true,JSON.stringify(result));assert(result.checks.some(x=>x.status==='NOTE'&&x.message.includes('link your game')));assert(!result.checks.some(x=>x.message.includes('opened a party')));
 }finally{await mf.dispose();}
});
