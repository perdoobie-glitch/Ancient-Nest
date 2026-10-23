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
  await action(a,"join",{code:old});await action(b,"search");a.ws.close();await pause(100);
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
