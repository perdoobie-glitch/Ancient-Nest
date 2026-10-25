import { fileURLToPath } from "node:url";
import { test } from "node:test";
import assert from "node:assert/strict";
import { Miniflare } from "miniflare";
import { webcrypto } from "node:crypto";
import { VERSION } from "../dist/core.js";
const pause = (ms) => new Promise((r) => setTimeout(r, ms));
const pem = (bytes) =>
  "-----BEGIN PUBLIC KEY-----\n" +
  Buffer.from(bytes)
    .toString("base64")
    .match(/.{1,64}/g)
    .join("\n") +
  "\n-----END PUBLIC KEY-----\n";
async function setup(options = {}) {
  const mf = new Miniflare({
    modules: true,
    scriptPath: fileURLToPath(new URL("../dist/worker.js", import.meta.url)),
    compatibilityDate: "2026-08-06",
    durableObjects: {
      MATCHMAKER: { className: "Matchmaker", useSQLite: true },
    },
    bindings: { ALLOW_GUESTS: "true", LOCAL_TEST: "true", VOTE_SECONDS: "1" },
    ...options,
  });
  await mf.ready;
  return mf;
}
async function client(mf, playlist = "duel_1v1", accountAssertion = "", lobbyOnly = true) {
  const key = await webcrypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const response = await mf.dispatchFetch("http://localhost/v1/matchmaking", {
    headers: { Upgrade: "websocket" },
  });
  const ws = response.webSocket;
  assert(ws);
  ws.accept();
  const events = [];
  const wait = async (type) => {
    const until = Date.now() + 10000;
    while (Date.now() < until) {
      const e = events.findLast((e) => e.type === type);
      if (e) return e;
      await pause(20);
    }
    throw Error("Missing " + type + " " + JSON.stringify(events));
  };
  ws.addEventListener("message", async (event) => {
    const p = JSON.parse(event.data);
    events.push(p);
    if (p.type === "challenge")
      ws.send(
        JSON.stringify({
          type: "proof",
          signature: Buffer.from(
            await webcrypto.subtle.sign(
              "RSASSA-PKCS1-v1_5",
              key.privateKey,
              new TextEncoder().encode(p.nonce),
            ),
          ).toString("base64"),
        }),
      );
  });
  ws.send(
    JSON.stringify({
      type: "hello",
      lobby_only: lobbyOnly,
      version: VERSION,
      playlist,
      public_key: pem(await webcrypto.subtle.exportKey("spki", key.publicKey)),
      name: "Test",
      account_assertion: accountAssertion,
    }),
  );
  const hello = await wait("hello");
  return { ws, events, wait, user: hello.player };
}

async function action(c,type,extra={},reply="party") {
 const start=c.events.length;c.ws.send(JSON.stringify({type:"party_"+type,...extra}));
 const until=Date.now()+6000;
 while(Date.now()<until){const e=c.events.slice(start).findLast(e=>e.type===reply);if(e)return e;await pause(10);}
 throw Error("No "+reply+" after "+type+": "+JSON.stringify(c.events.slice(start)));
}
async function party(c){return c.wait("party");}
async function closeAll(mf,cs){try {for(const c of cs){try{c.ws.close();}catch{}}}finally{await mf.dispose();}}

test("browser lists public custom lobbies, enforces capacity and owner start, then starts unranked WebRTC",async()=>{
 const mf=await setup(),cs=[];
 try{
  const a=await client(mf),b=await client(mf),c=await client(mf);cs.push(a,b,c);
  assert((await party(a)).server_browser_supported);
  assert.match((await action(a,"custom_create",{name:"Bad",mode:9,map:0,matchup:0,capacity:2},"party_error")).reason,/valid/);
  const created=await action(a,"custom_create",{name:"Mirror Duel",mode:2,map:4,matchup:2,capacity:2});
  assert.equal(created.custom.name,"Mirror Duel");
  assert.match((await action(a,"custom_start",{},"party_error")).reason,/two players/);
  const list=await action(b,"browse",{},"server_list");
  assert.deepEqual(Object.keys(list.lobbies[0]).sort(),["capacity","code","host","map","matchup","mode","name","players"].sort());
  assert.equal(list.lobbies[0].code,created.code);
  await action(a,"privacy",{privacy:"private"});
  assert.equal((await action(b,"browse",{},"server_list")).lobbies.length,0);
  await action(a,"privacy",{privacy:"open"});
  assert.equal((await action(b,"join",{code:created.code})).members.length,2);
  assert.match((await action(c,"join",{code:created.code},"party_error")).reason,/full/);
  assert.match((await action(b,"custom_start",{},"party_error")).reason,/owner/);
  assert.match((await action(a,"search",{},"party_error")).reason,/Start Game/);
  await action(a,"custom_start");
  const probe=await a.wait("collect_telemetry");
  assert.equal(probe.config.custom,true);assert.equal(probe.config.map,4);assert.equal(probe.config.matchup,2);
  assert.deepEqual(Object.values(probe.roster).map(m=>m.faction).sort(),[0,1]);
  assert.equal((await action(c,"browse",{},"server_list")).lobbies.length,0);
  assert.match((await action(c,"join",{code:created.code},"party_error")).reason,/Cancel search|already/);
  for(const player of [a,b]){const other=player===a?b:a;player.ws.send(JSON.stringify({type:"telemetry",epoch:probe.epoch,round:probe.round,routes:{[other.user]:{rtts:Array(50).fill(20),bytes:120000,seconds:1.5}}}));}
  await Promise.race([a.wait("host_offer"),b.wait("host_offer")]);
  const host=[a,b].find(player=>player.events.some(e=>e.type==="host_offer"));
  const offer=host.events.findLast(e=>e.type==="host_offer");assert.equal(offer.config.custom,true);
  assert(!a.events.some(e=>e.type==="voting"));host.ws.send(JSON.stringify({type:"host_ready",epoch:offer.epoch}));
  for(const player of [a,b]){await player.wait("connect");player.ws.send(JSON.stringify({type:"loaded",epoch:offer.epoch}));}
  await a.wait("resume");await b.wait("resume");
  const heartbeat=setInterval(()=>{for(const player of [a,b])player.ws.send(JSON.stringify({type:"heartbeat",epoch:offer.epoch}));},500);
  try{
   host.ws.send(JSON.stringify({type:"complete",epoch:offer.epoch}));
   const until=Date.now()+16000;
   while(Date.now()<until&&!a.events.some(e=>e.type==="return_queue"))await pause(100);
   assert(a.events.some(e=>e.type==="return_queue"),"Custom completion returns to its lobby");
   assert(!a.events.some(e=>e.type==="result_status"&&e.status==="pending_review"));
   const restored=await action(a,"sync");assert.equal(restored.searching,false);assert.equal(restored.custom.name,"Mirror Duel");
  }finally{clearInterval(heartbeat);}
 }finally{await closeAll(mf,cs);}
});

test("TURN failure returns both players to a retryable party and recovery uses one credential request",async()=>{
 const ids=["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"];
 let working=false,turnCalls=0;
 const mf=await setup({bindings:{ALLOW_GUESTS:"false",LOCAL_TEST:"true",ACCOUNT_API:"https://account.test",COORDINATOR_API_KEY:"fixture-coordinator-key-12345678901234567890",TURN_KEY_ID:"fixture-turn-id",TURN_KEY_API_TOKEN:"fixture-token-not-a-real-secret"},outboundService:async req=>{
  const url=new URL(req.url);
  if(url.hostname==='rtc.live.cloudflare.com'){
   turnCalls++;return working?Response.json({iceServers:[{urls:['turn:turn.cloudflare.com:3478?transport=udp'],username:'fixture-user',credential:'fixture-credential'}]},{status:201}):new Response('provider response must not be exposed',{status:403});
  }
  const data=await req.json();
  if(url.pathname==='/api/game/verify')return Response.json({valid:true,account_id:data.assertion,key_hash:data.key_hash,username:ids.indexOf(data.assertion)?'Friend':'Player'});
  if(url.pathname==='/api/game/profile')return Response.json({playlists:{}});
  if(url.pathname==='/api/internal/players/ratings')return Response.json({ratings:Object.fromEntries(data.account_ids.map(id=>[id,Object.fromEntries(['duel_1v1','doubles_2v2','tactical_3v3','arena_4v4','bomb_defuse_5v5'].map(p=>[p,1]))]))});
  throw Error('Unexpected fixture route');
 }}),cs=[];
 try{
  for(const id of ids)cs.push(await client(mf,'duel_1v1',id));
  await action(cs[0],'search');await action(cs[1],'search');
  for(const c of cs){
   const error=await c.wait('party_error');assert.match(error.reason,/TURN.*HTTP 403/);
   assert.equal((await party(c)).searching,false);
   assert(!JSON.stringify(error).includes('fixture-token')&&!JSON.stringify(error).includes('provider response'));
   assert(!c.events.some(e=>e.type==='collect_telemetry'));
  }
  working=true;
  await action(cs[0],'search');await action(cs[1],'search');
  for(const c of cs)assert.equal(Object.keys((await c.wait('collect_telemetry')).roster).length,2);
  assert.equal(turnCalls,2);
 }finally{await closeAll(mf,cs);}
});

test("lobby privacy is leader-controlled, blocks code-only joins and rotates private invitations",async()=>{
 const mf=await setup(),cs=[];
 try{
  const a=await client(mf,"tactical_3v3"),b=await client(mf,"tactical_3v3"),c=await client(mf,"tactical_3v3");cs.push(a,b,c);
  const initial=await party(a);assert.equal(initial.privacy,"open");assert(initial.lobby_privacy_supported);
  const closed=await action(a,"privacy",{privacy:"private"});assert.match(closed.invite_token,/^[a-f0-9]{32}$/);assert.notEqual(closed.invite_token,initial.invite_token);
  assert.match((await action(b,"join",{code:closed.code},"party_error")).reason,/private/);
  assert.match((await action(b,"join",{code:closed.code,invite_token:"wrong"},"party_error")).reason,/private/);
  assert.equal((await action(b,"join",{code:closed.code,invite_token:closed.invite_token})).members.length,2);
  assert.match((await action(b,"privacy",{privacy:"open"},"party_error")).reason,/leader/);
  await action(b,"leave");
  const refreshed=await action(a,"sync");assert.notEqual(refreshed.invite_token,closed.invite_token);
  assert.match((await action(c,"join",{code:closed.code,invite_token:closed.invite_token},"party_error")).reason,/private/);
  assert.match((await action(a,"privacy",{privacy:"invalid"},"party_error")).reason,/Invalid/);
  assert.equal((await action(a,"privacy",{privacy:"open"})).privacy,"open");
  assert.equal((await action(c,"join",{code:closed.code})).members.length,2);
  await action(a,"search");assert.match((await action(a,"privacy",{privacy:"private"},"party_error")).reason,/Cancel search/);
 }finally{await closeAll(mf,cs);}
});

test("party opens without searching; team-size limit, leadership and repeated search enforced",async()=>{
 const mf=await setup(),cs=[];
 try{
  const a=await client(mf,"doubles_2v2"),b=await client(mf,"doubles_2v2"),c=await client(mf,"doubles_2v2");cs.push(a,b,c);
  const pa=await party(a);await pause(100);
  assert(!a.events.some(e=>e.type==="queue"||e.type==="collect_telemetry"));
  const joined=await action(b,"join",{code:pa.code.toLowerCase()});assert.equal(joined.members.length,2);
  assert.match((await action(c,"join",{code:pa.code},"party_error")).reason,/full/);
  assert.match((await action(b,"search",{},"party_error")).reason,/leader/);
  assert.match((await action(a,"playlist",{playlist:"duel_1v1"},"party_error")).reason,/enough/);
  assert.equal((await action(a,"search")).searching,true);
  await a.wait("queue");
  a.ws.send(JSON.stringify({type:"party_search"}));await pause(100);
  assert(!a.events.some(e=>e.type==="collect_telemetry"));
  assert.match((await action(c,"join",{code:pa.code},"party_error")).reason,/Cancel/);
  assert.match((await action(a,"playlist",{playlist:"arena_4v4"},"party_error")).reason,/Cancel/);
  const stopped=await action(a,"cancel");assert.equal(stopped.searching,false);assert.equal(stopped.members.length,2);
  assert.equal((await action(a,"playlist",{playlist:"tactical_3v3"})).playlist,"tactical_3v3");
  assert.equal((await action(c,"join",{code:pa.code})).members.length,3);
 }finally{await closeAll(mf,cs);}
});
test("three-player party plus two-player party and solo create balanced 3v3 without splitting friends",async()=>{
 const mf=await setup(),cs=[];
 try{
  for(let i=0;i<6;i++)cs.push(await client(mf,"tactical_3v3"));
  const codeA=(await party(cs[0])).code,codeB=(await party(cs[3])).code;
  await action(cs[1],"join",{code:codeA});await action(cs[4],"join",{code:codeB});await action(cs[5],"join",{code:codeB});
  await action(cs[0],"search");await action(cs[2],"search");await pause(100);
  assert(!cs.some(c=>c.events.some(e=>e.type==="collect_telemetry")));
  await action(cs[3],"search");const probe=await cs[0].wait("collect_telemetry");
  assert.equal(Object.keys(probe.roster).length,6);
  const side=c=>probe.roster[c.user].faction;
  assert.equal(side(cs[0]),side(cs[1]));assert.equal(side(cs[0]),side(cs[2]));
  assert.equal(side(cs[3]),side(cs[4]));assert.equal(side(cs[3]),side(cs[5]));assert.notEqual(side(cs[0]),side(cs[3]));
  assert.match((await action(cs[0],"cancel",{},"party_error")).reason,/during a match/);
 }finally{await closeAll(mf,cs);}
});
test("leaving cancels whole-party search and transfers leader; invite errors preserve connection",async()=>{
 const mf=await setup(),cs=[];
 try{
  const a=await client(mf,"tactical_3v3"),b=await client(mf,"tactical_3v3");cs.push(a,b);
  const old=(await party(a)).code;await action(b,"join",{code:old});await action(a,"search");
  const fresh=await action(a,"leave");assert.notEqual(fresh.code,old);
  const remaining=await party(b);assert.equal(remaining.leader,b.user);assert.equal(remaining.searching,false);assert.equal(remaining.members.length,1);
  assert.match((await action(a,"join",{code:"BADCODE"},"party_error")).reason,/not found/);
  assert.equal((await action(a,"sync")).leader,a.user);
  await action(a,"join",{code:old});await action(b,"search");a.ws.send(JSON.stringify({type:"leave_match"}));await pause(30);a.ws.close();await pause(100);
  const final=await party(b);assert.equal(final.searching,false);assert.equal(final.members.length,1);assert.equal(final.leader,b.user);
 }finally{await closeAll(mf,cs);}
});
test("two full five-player parties form ten-player match with each party on one team",async()=>{
 const mf=await setup(),cs=[];
 try{
  for(let i=0;i<10;i++)cs.push(await client(mf,"bomb_defuse_5v5"));
  const a=(await party(cs[0])).code,b=(await party(cs[5])).code;
  for(let i=1;i<5;i++)await action(cs[i],"join",{code:a});
  for(let i=6;i<10;i++)await action(cs[i],"join",{code:b});
  await action(cs[0],"search");await action(cs[5],"search");const event=await cs[0].wait("collect_telemetry");
  assert.equal(Object.keys(event.roster).length,10);
  assert.equal(new Set(cs.slice(0,5).map(c=>event.roster[c.user].faction)).size,1);
  assert.equal(new Set(cs.slice(5).map(c=>event.roster[c.user].faction)).size,1);
  assert.notEqual(event.roster[cs[0].user].faction,event.roster[cs[5].user].faction);
 }finally{await closeAll(mf,cs);}
});

test("search refreshes server-owned playlist Elo and preserves ratings above 3200",async()=>{
 const ids=["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"],lookups=[];
 const key="test-coordinator-private-key-12345678901234567890123456";
 const ratings=Object.fromEntries(ids.map(id=>[id,Object.fromEntries(["duel_1v1","doubles_2v2","tactical_3v3","arena_4v4","bomb_defuse_5v5"].map(p=>[p,p==='duel_1v1'?4100:1]))]));
 const mf=await setup({bindings:{ALLOW_GUESTS:"false",LOCAL_TEST:"true",ACCOUNT_API:"https://account.test",COORDINATOR_API_KEY:key},outboundService:async req=>{
  const data=await req.json(),path=new URL(req.url).pathname;
  if(path==='/api/game/verify')return Response.json({valid:true,account_id:data.assertion,key_hash:data.key_hash,username:'Verified'});
  if(path==='/api/game/profile')return Response.json({rp:99,playlists:Object.fromEntries(Object.keys(ratings[ids[0]]).map(p=>[p,{elo:200}]))});
  assert.equal(path,'/api/internal/players/ratings');assert.equal(req.headers.get('Authorization'),'Bearer '+key);lookups.push(data.account_ids);return Response.json({ratings});
 }}),cs=[];
 try{
  for(const id of ids)cs.push(await client(mf,'duel_1v1',id));
  await action(cs[0],'search');await action(cs[1],'search');const probe=await cs[0].wait('collect_telemetry');
  assert.equal(lookups.length,2);for(const member of Object.values(probe.roster))assert.equal(member.rating.human,4100);
 }finally{await closeAll(mf,cs);}
});
