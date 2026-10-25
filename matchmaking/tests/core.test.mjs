import { test } from "node:test";
import assert from "node:assert/strict";
import { rankHosts, snapshotTicksForHost, majority, balancedTeams, PLAYLISTS } from "../dist/core.js";
const people = ["a", "b", "c", "d", "e", "f"];
test("snapshot rate uses actual outgoing routes, room size and CPU headroom",()=>{
 const capacity={cpu_p95_ms:4,logical_cpus:8,samples:180};
 const reports={a:{b:{bytes:500000,seconds:1}},b:{a:{bytes:70000,seconds:1}}};
 assert.equal(snapshotTicksForHost("a",["a","b"],reports,capacity),2,"Slow host upload cannot be hidden by fast incoming traffic");
 reports.b.a.bytes=200000;
 assert.equal(snapshotTicksForHost("a",["a","b"],reports,capacity),2,"Default remains 30 Hz even on fast links");
 assert.equal(snapshotTicksForHost("a",["a","b"],reports,capacity,60),1,"Explicit fast two-player link permits 60 Hz");
 assert.equal(snapshotTicksForHost("a",["a","b"],reports,{...capacity,cpu_p95_ms:11}),2,"Busy host retains 30 Hz");
 assert.equal(snapshotTicksForHost("a",["a","b"],reports),2,"Missing CPU measurement cannot enable 60 Hz");
 const room=["a","b","c","d","e","f","g","h","i","j"];
 const all=Object.fromEntries(room.filter(p=>p!=="a").map(p=>[p,{a:{bytes:70000,seconds:1}}]));
 assert.equal(snapshotTicksForHost("a",room,all,capacity),3,"Large room on a marginal upload retains 20 Hz");
 for(const p of room.filter(p=>p!=="a"))all[p].a.bytes=180000;
 assert.equal(snapshotTicksForHost("a",room,all,capacity),2,"Moderate upload supports 30 Hz");
 for(const p of room.filter(p=>p!=="a"))all[p].a.bytes=350000;
 assert.equal(snapshotTicksForHost("a",room,all,capacity,60),1,"Explicit large room requires more upload headroom for 60 Hz");
 delete all.j;
 assert.equal(snapshotTicksForHost("a",room,all,capacity),3,"Missing outgoing route selects conservative cadence");
});
const fixture = () =>
  Object.fromEntries(
    people.map((observer) => [
      observer,
      Object.fromEntries(
        people
          .filter((p) => p !== observer)
          .map((p) => [
            p,
            {
              rtts: Array(50).fill(p === "f" ? 10 : 50),
              bytes: 120000,
              seconds: 1.5,
            },
          ]),
      ),
    ]),
  );
test("compares the whole measurement batch, not first candidate", () =>
  assert.equal(rankHosts(people, fixture())[0], "f"));
test("unreachable candidate is excluded", () => {
  const r = fixture();
  delete r.a.f;
  assert.notEqual(rankHosts(people, r)[0], "f");
});
test("nonfinite telemetry is rejected", () => {
  const r = fixture();
  r.a.f.rtts[0] = NaN;
  assert(!rankHosts(people, r).includes("f"));
});
test("unstable upload rejected", () => {
  const r = fixture();
  r.a.f.bytes = 100;
  assert(!rankHosts(people, r).includes("f"));
});
test("small probe losses stay eligible; excessive loss excludes a host", () => {
 const r=fixture();r.a.f.rtts=Array(45).fill(10);
 assert(rankHosts(people,r).includes("f"));r.a.f.rtts.pop();assert(!rankHosts(people,r).includes("f"));
});
test("ten-player pool with two missed replies per route elects a host", () => {
 const ids=Array.from({length:10},(_,i)=>String(i));
 const reports=Object.fromEntries(ids.map(a=>[a,Object.fromEntries(ids.filter(b=>b!==a).map(b=>[b,{rtts:Array(48).fill(b==="9"?20:45),bytes:118000,seconds:1.5}]))]));
 assert.equal(rankHosts(ids,reports)[0],"9");
});
test("stable route wins against a similar-ping lossier candidate", () => {
 const r=fixture();
 for(const observer of people)for(const candidate of people){if(observer===candidate)continue;r[observer][candidate].rtts=Array(50).fill(candidate==="f"?10:20);}
 r.a.f.rtts=Array(48).fill(10);
 assert.notEqual(rankHosts(people,r)[0],"f");
});
test("worst peer latency is bounded", () => {
  const r = fixture();
  r.a.f.rtts = Array(50).fill(300);
  assert(!rankHosts(people, r).includes("f"));
});
test("majority scales to playlist capacity", () => {
  assert.equal(
    majority([2, 2, 1, 1], [1, 2], 4, () => 0),
    1,
  );
  assert.equal(majority([2, 2, 2, 1], [1, 2], 4), 2);
});
test("all five playlist capacities are server-owned", () =>
  assert.deepEqual(
    Object.values(PLAYLISTS).map((p) => p.size),
    [2, 4, 6, 8, 10],
  ));
test("team assignment balances official server ratings", () => {
  const team = balancedTeams(["a", "b", "c", "d"], {
    a: 1000,
    b: 1000,
    c: 0,
    d: 0,
  });
  assert.equal(team.size, 2);
  assert.equal([...team].filter((p) => ["a", "b"].includes(p)).length, 1);
});

test("native ICE list retains UDP TURN and filters unsupported TCP/TLS transports", async () => {
  const { supportedIceServers } = await import("../dist/core.js");
  assert.deepEqual(
    supportedIceServers([
      { urls: ["stun:stun.cloudflare.com:3478"] },
      {
        urls: [
          "turn:turn.cloudflare.com:3478?transport=udp",
          "turns:turn.cloudflare.com:443?transport=tcp",
          "turn:turn.cloudflare.com:3478?transport=tcp",
        ],
        username: "temporary",
        credential: "test-only",
      },
    ]).map((s) => s.urls),
    [
      ["stun:stun.cloudflare.com:3478"],
      ["turn:turn.cloudflare.com:3478?transport=udp"],
    ],
  );
});

import { partyMatch } from "../dist/core.js";
test("party selection skips incompatible totals and keeps party identities intact",()=>{
 const g=[["a","b"],["c","d"],["e","f"]];assert.equal(partyMatch(g,{},6),undefined);
 const m=partyMatch([...g,["x"],["y"]],{},6);assert(m);assert.equal(m.people.length,6);
 for(const p of g)if(p.some(id=>m.people.includes(id)))assert.equal(new Set(p.map(id=>m.team.has(id))).size,1);
 assert.equal(partyMatch([["a","b"]],{},2),undefined);
});

test("plurality wins and a zero-vote option cannot win",()=>{
 const ballots=[0,0,0,0,1,1,1,2,2,2];assert.equal(majority(ballots,[0,1,2,3,4],10,()=>.99),0);
 for(const rng of [0,.49,.99])assert([0,1].includes(majority([0,0,1,1],[0,1,2],4,()=>rng)));
});

test('low upload candidate loses eligibility even with slightly better ping',()=>{
 const r={a:{b:{rtts:Array(50).fill(21),bytes:100000,seconds:.1}},b:{a:{rtts:Array(50).fill(20),bytes:40000,seconds:1}}};assert.deepEqual(rankHosts(['a','b'],r),['b']);
});
test('overloaded host is excluded without changing peer connectivity requirements',()=>{
 const r=fixture();assert(!rankHosts(people,r,{f:{cpu_p95_ms:25,logical_cpus:4,samples:60}}).includes('f'));
});
test('unwilling players remain players but cannot be elected host',()=>{
 const r=fixture();
 assert(!rankHosts(people,r,{a:{cpu_p95_ms:1,logical_cpus:8,samples:180,allow_host:false}}).includes('a'));
 assert.deepEqual(rankHosts(people,r,Object.fromEntries(people.map(p=>[p,{cpu_p95_ms:1,logical_cpus:8,samples:180,allow_host:false}]))),[]);
});
