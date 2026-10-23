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
async function client(mf, playlist = "duel_1v1", accountAssertion = "") {
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

import {snapshot} from "../dist/monitor.js";
const monitorKey="test-only-monitor-key-0123456789-not-for-production";
test("monitor requires dedicated bearer token and exposes no private coordination data",async()=>{
 const mf=await setup({bindings:{ALLOW_GUESTS:"true",LOCAL_TEST:"true",VOTE_SECONDS:"1",MONITOR_TOKEN:monitorKey}});const clients=[];
 const read=()=>mf.dispatchFetch("http://localhost/api/monitor",{headers:{Authorization:"Bearer "+monitorKey}});
 try{
  assert.equal((await mf.dispatchFetch("http://localhost/api/monitor")).status,401);
  assert.equal((await mf.dispatchFetch("http://localhost/api/monitor",{headers:{Authorization:"Bearer incorrect"}})).status,401);
  assert.equal((await mf.dispatchFetch("http://localhost/api/monitor",{method:"POST"})).status,405);
  let response=await read();assert.equal(response.headers.get("Cache-Control"),"no-store");let view=await response.json();assert.equal(view.summary.online_players,0);assert.equal(view.playlists.length,5);assert.equal(view.offline_practice,"not tracked");
  const a=await client(mf);clients.push(a);await pause(100);view=await (await read()).json();assert.equal(view.summary.online_players,1);assert.equal(view.summary.queued_players,1);
  const b=await client(mf);clients.push(b);const probe=await a.wait("collect_telemetry");view=await (await read()).json();assert.equal(view.matches.length,1);assert.equal(view.summary.forming_matches,1);assert.equal(view.matches[0].online,2);
  for(const c of clients){const peer=c===a?b:a;c.ws.send(JSON.stringify({type:"telemetry",epoch:probe.epoch,round:probe.round,routes:{[peer.user]:{rtts:Array(50).fill(20),bytes:120000,seconds:1.5}}}));}
  const vote=await a.wait("voting");for(const c of clients)c.ws.send(JSON.stringify({type:"vote",epoch:vote.epoch,stage:"setup",mode:0,map:0}));
  await Promise.race(clients.map(c=>c.wait("host_offer")));const host=clients.find(c=>c.events.some(e=>e.type==="host_offer"));const offer=host.events.findLast(e=>e.type==="host_offer");host.ws.send(JSON.stringify({type:"host_ready",epoch:offer.epoch}));
  for(const c of clients){await c.wait("connect");c.ws.send(JSON.stringify({type:"loaded",epoch:offer.epoch}));}
  await a.wait("resume");host.ws.send(JSON.stringify({type:"heartbeat",epoch:offer.epoch,live:{scores:[7,3],elapsed:25}}));await pause(100);
  response=await read();view=await response.json();assert.equal(view.summary.playing_matches,1);assert.equal(view.game_types.find(m=>m.id===0).playing,1);assert.deepEqual(view.matches[0].live.scores,[7,3]);assert.equal(view.summary.started,1);
  const raw=JSON.stringify(view);for(const field of ["public_key","iceServers","grant","account_assertion","nonce",monitorKey])assert(!raw.includes(field));
  const peer=clients.find(c=>c!==host);peer.ws.close();await pause(100);view=await (await read()).json();assert.equal(view.summary.disconnected_slots,1);assert.equal(view.matches[0].online,1);
 }finally{for(const c of clients){try{c.ws.close();}catch{}}await mf.dispose();}
});
test("monitor is unavailable until a sufficiently long key is configured",async()=>{
 const mf=await setup();try{assert.equal((await mf.dispatchFetch("http://localhost/api/monitor")).status,503);}finally{await mf.dispose();}
});
test("snapshot counts stale sockets as disconnected, excludes completed rooms from active totals and preserves recent history",()=>{
 const room={id:"match",playlist:"duel_1v1",phase:"complete",config:{mode:2,map:0},epoch:1,authority:"a",born:10,roster:{a:{name:"A",faction:0},b:{name:"B",faction:1}}};
 const view=snapshot([room],[{user:"a",seen:100,build:VERSION},{user:"b",seen:70,build:VERSION}],[{members:["a"],playlist:"duel_1v1"},{members:["gone"],playlist:"duel_1v1"}],[{id:"recent"}],{started:1,finished:1,failed:0},101,{});
 assert.equal(view.summary.online_players,1);assert.equal(view.summary.parties,1);assert.equal(view.matches[0].disconnected,1);assert.equal(view.summary.disconnected_slots,0);assert.equal(view.summary.playing_matches,0);assert.equal(view.recent[0].id,"recent");
});
