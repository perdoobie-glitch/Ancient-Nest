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
    scriptPath: new URL("../dist/worker.js", import.meta.url).pathname,
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
  const publicPem = pem(await webcrypto.subtle.exportKey("spki", key.publicKey));
  if (typeof accountAssertion === "function") accountAssertion = await accountAssertion(publicPem);
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
      public_key: publicPem,
      name: "Test",
      account_assertion: accountAssertion,
    }),
  );
  const hello = await wait("hello");
  return { ws, events, wait, user: hello.player };
}
test("Cloudflare health states player-hosted service only", async () => {
  const mf = await setup();
  try {
    const res = await mf.dispatchFetch("http://localhost/health");
    assert.equal((await res.json()).hosting, "player_hosted");
  } finally {
    await mf.dispose();
  }
});
for(const votedMap of [2,3,4,5])test("playlist separation, assigned teams and selected map " + votedMap, async () => {
  const mf = await setup(),
    clients = [];
  try {
    const a = await client(mf),
      b = await client(mf, "doubles_2v2");
    clients.push(a, b);
    await pause(100);
    assert(!a.events.some((e) => e.type === "collect_telemetry"));
    assert(!b.events.some((e) => e.type === "collect_telemetry"));
    const c = await client(mf);
    clients.push(c);
    const probe = await a.wait("collect_telemetry");
    assert.equal(Object.keys(probe.roster).length, 2);
    assert.equal(
      new Set(Object.values(probe.roster).map((m) => m.faction)).size,
      2,
    );
    assert(!b.events.some((e) => e.type === "collect_telemetry"));
    for (const who of [a, c]) {
      const peer = who === a ? c : a;
      who.ws.send(
        JSON.stringify({
          type: "telemetry",
          epoch: probe.epoch,
          round: probe.round,
          routes: {
            [peer.user]: {
              rtts: Array(50).fill(who === a ? 10 : 30),
              bytes: 120000,
              seconds: 1.5,
            },
          },
        }),
      );
    }
    const vote = await a.wait("voting");
    assert.equal(vote.capacity, 2);
    assert.equal(vote.host_name, "Test");
    assert(!a.events.some((e) => e.type === "host_offer"));
    assert(!b.events.some((e) => e.type === "voting"));
    for (const who of [a, c])
      who.ws.send(
        JSON.stringify({
          type: "vote",
          epoch: vote.epoch,
          stage: "setup",
          mode: 0,
          map: votedMap,
        }),
      );
    const offers = await Promise.race([
      a.wait("host_offer"),
      c.wait("host_offer"),
    ]);
    assert.equal(offers.config.mode, 0);
    assert.equal(offers.config.map, votedMap);
    assert.equal(offers.config.matchup, 3);
    assert(!a.events.some((e) => e.type === "connect"));
    assert(!c.events.some((e) => e.type === "connect"));
  } finally {
    for (const c of clients) c.ws.close();
    await mf.dispose();
  }
});
test("unrecognized playlist rejected before entering any queue", async () => {
  const mf = await setup();
  try {
    const res = await mf.dispatchFetch("http://localhost/v1/matchmaking", {
      headers: { Upgrade: "websocket" },
    });
    const ws = res.webSocket;
    ws.accept();
    const got = new Promise((resolve) =>
      ws.addEventListener("message", (e) => resolve(JSON.parse(e.data))),
    );
    ws.send(
      JSON.stringify({ type: "hello", version: VERSION, playlist: "toString" }),
    );
    assert.equal((await got).type, "failed");
    ws.close();
  } finally {
    await mf.dispose();
  }
});

test("old client protocol rejected before any new-map allocation", async () => {
  const mf = await setup();
  try {
    const res = await mf.dispatchFetch("http://localhost/v1/matchmaking", {
      headers: { Upgrade: "websocket" },
    });
    const ws = res.webSocket;
    ws.accept();
    const got = new Promise((resolve) =>
      ws.addEventListener("message", (e) => resolve(JSON.parse(e.data))),
    );
    ws.send(
      JSON.stringify({ type: "hello", version: "10.1-peerhost2", playlist: "duel_1v1" }),
    );
    assert.equal((await got).type, "failed");
    ws.close();
  } finally {
    await mf.dispose();
  }
});

test("agreed account results commit once; slow account writes do not block heartbeats", async () => {
  const calls = [];
  let slowLoginStarted=false;
  const voiceCalls=[]; let voiceAttempts=0;
  const secret =
    "test-only-coordinator-key-not-production-01234567890123456789";
  const mf = await setup({
    bindings: {
      ALLOW_GUESTS: "false",
      LOCAL_TEST: "true",
      VOTE_SECONDS: "1",
      ACCOUNT_API: "https://accounts.local",
      TEAM_VOICE: "true",
      COORDINATOR_API_KEY: secret,
    },
    outboundService: async (req) => {
      const path = new URL(req.url).pathname;
      if(path.startsWith('/internal/voice/')) {
        assert.equal(req.headers.get('X-Coordinator-Key'),secret);
        const data=req.method==='DELETE'?null:await req.json();
        voiceCalls.push({method:req.method,path,data});
        if(req.method==='POST' && ++voiceAttempts===1)return Response.json({}, {status:503});
        return Response.json({ok:true});
      }
      const data = await req.json();
      if (path === "/api/game/verify") {
        if(data.assertion.startsWith("cccc")){slowLoginStarted=true;await pause(1800);}
        return Response.json({
          valid: true,
          key_hash: data.key_hash,
          account_id: data.assertion,
          username: "Account" + data.assertion.slice(0, 3),
        });
      }
      if (path === "/api/game/profile") return Response.json({ rp: 100 });
      assert.equal(req.headers.get("Authorization"), "Bearer " + secret);
      calls.push({ path, data });
      if(path.endsWith("/register"))await pause(1600);
      return Response.json({ registered: true, committed: true, epoch: 1 });
    },
  });
  const clients = [];
  let heartbeatTimer;
  try {
    const a = await client(
        mf,
        "duel_1v1",
        "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      ),
      b = await client(mf, "duel_1v1", "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb");
    clients.push(a, b);
    const probe = await a.wait("collect_telemetry");
    for (const who of clients) {
      const peer = who === a ? b : a;
      who.ws.send(
        JSON.stringify({
          type: "telemetry",
          epoch: probe.epoch,
          round: probe.round,
          routes: {
            [peer.user]: {
              rtts: Array(50).fill(20),
              bytes: 120000,
              seconds: 1.5,
            },
          },
        }),
      );
    }
    const vote = await a.wait("voting");
    for (const c of clients)
      c.ws.send(
        JSON.stringify({
          type: "vote",
          epoch: vote.epoch,
          stage: "setup",
          mode: 0,
          map: 0,
        }),
      );
    await Promise.race(clients.map((c) => c.wait("host_offer")));
    const host = clients.find((c) =>
        c.events.some((e) => e.type === "host_offer"),
      ),
      offer = host.events.findLast((e) => e.type === "host_offer");
    host.ws.send(JSON.stringify({ type: "host_ready", epoch: offer.epoch }));
    for (const c of clients) {
      await c.wait("connect");
      c.ws.send(JSON.stringify({ type: "loaded", epoch: offer.epoch }));
    }
    await a.wait("resume");
    heartbeatTimer=setInterval(()=>host.ws.send(JSON.stringify({type:"heartbeat",epoch:offer.epoch})),800);
    const registrationDeadline=Date.now()+5000;
    while(!calls.some(c=>c.path.endsWith("/register"))&&Date.now()<registrationDeadline)await pause(10);
    assert(calls.some(c=>c.path.endsWith("/register")),"Delayed account write started");
    const pingAt=Date.now();a.ws.send(JSON.stringify({type:"ping"}));await a.wait("pong");
    assert(Date.now()-pingAt<800,"Upstream account latency blocked the control loop");
    const newcomer=client(mf,"duel_1v1","cccccccc-cccc-4ccc-8ccc-cccccccccccc");
    const loginDeadline=Date.now()+5000;
    while(!slowLoginStarted&&Date.now()<loginDeadline)await pause(10);
    assert(slowLoginStarted,"Slow sign-in preflight started");
    const pongs=a.events.filter(e=>e.type==="pong").length,readAt=Date.now();
    a.ws.send(JSON.stringify({type:"ping"}));
    while(a.events.filter(e=>e.type==="pong").length===pongs && Date.now()-readAt<2500)await pause(10);
    assert(a.events.filter(e=>e.type==="pong").length>pongs && Date.now()-readAt<800,"Another player's slow login blocked an existing match heartbeat");
    clients.push(await newcomer);
    const players = Object.keys(probe.roster).map((player) => ({
        player,
        kills: 1,
        deaths: 1,
        assists: 0,
        flags_captured: 0,
        flags_stopped: 0,
      })),
      report = {
        type: "result_report",
        epoch: offer.epoch,
        winner_team: 0,
        players,
      };
    for (const c of clients) c.ws.send(JSON.stringify(report));
    await pause(1200);
    assert(
      !calls.some((c) => c.path.endsWith("/result")),
      "No early rank submission",
    );
    host.ws.send(JSON.stringify({ type: "complete", epoch: offer.epoch }));
    a.ws.send(JSON.stringify(report));
    await pause(400);
    assert(
      !calls.some((c) => c.path.endsWith("/result")),
      "One client cannot award ranks",
    );
    b.ws.send(JSON.stringify(report));
    const until = Date.now() + 6000;
    while (Date.now() < until && !calls.some((c) => c.path.endsWith("/result")))
      await pause(50);
    const sent = calls.filter((c) => c.path.endsWith("/result"));
    assert.equal(sent.length, 1);
    assert.equal(sent[0].data.players.length, 2);
    assert.equal(calls.find(c=>c.path.endsWith("/register")).data.playlist_id,"duel_1v1");
    assert.equal(sent[0].data.authority_id, host.user);
    assert.equal(sent[0].data.epoch, 1);
    const voiceDeadline=Date.now()+6000;
    while(!voiceCalls.some(v=>v.method==='DELETE')&&Date.now()<voiceDeadline)await pause(50);
    assert(voiceCalls.filter(v=>v.method==='POST').length>=2, 'Voice create retries after provider failure');
    assert(voiceCalls.some(v=>v.method==='DELETE'), 'Voice room cleanup requested on match completion');
    const voiceRoster=voiceCalls.find(v=>v.method==='POST').data.teams.flatMap(t=>t.player_ids).sort();
    assert.deepEqual(voiceRoster,['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb']);
    for (const c of clients) c.ws.send(JSON.stringify(report));
    await pause(1100);
    assert.equal(calls.filter((c) => c.path.endsWith("/result")).length, 1);
  } finally {
    clearInterval(heartbeatTimer);
    for (const c of clients) c.ws.close();
    await mf.dispose();
  }
});

test('real accounts Worker issues key-bound assertions accepted by the matchmaking Worker', async () => {
  const { build } = await import('esbuild');
  const { readFile, readdir } = await import('node:fs/promises');
  const accountRoot = new URL('../../ancient-nest-accounts/', import.meta.url);
  const bundle = await build({ entryPoints: [new URL('src/index.js', accountRoot).pathname], bundle: true, write: false, format: 'esm', platform: 'browser' });
  const accounts = new Miniflare({ modules: true, script: bundle.outputFiles[0].text, compatibilityDate: '2026-08-01', d1Databases: ['DB'],
    bindings: { JWT_SECRET: 'test-cross-worker-jwt-secret-at-least-32', COORDINATOR_API_KEY: 'test-cross-worker-coordinator-secret-at-least-32', DISCORD_CLIENT_ID: '1562796619722793010', DISCORD_CLIENT_SECRET: 'test-cross-worker-discord-secret' },
    serviceBindings: { DISCORD_HTTP: async request => {
      if (new URL(request.url).pathname.endsWith('/oauth2/token')) {
        const form = new URLSearchParams(await request.text());
        return Response.json({ access_token: form.get('code'), refresh_token: 'mock-refresh', token_type: 'Bearer', expires_in: 3600, scope: 'identify sdk.social_layer' });
      }
      const id = request.headers.get('Authorization').slice(7);
      return Response.json({ id, username: 'Player' + id.slice(-3) });
    } },
  });
  let master; const clients = [];
  try {
    const db = await accounts.getD1Database('DB');
    const migrationRoot = new URL('migrations/', accountRoot);
    for (const name of (await readdir(migrationRoot)).filter(n => n.endsWith('.sql')).sort()) {
      const sql = (await readFile(new URL(name, migrationRoot), 'utf8')).replace(/--[^\n]*/g, '');
      for (const statement of sql.split(/;(?=\s*(?:CREATE|ALTER|INSERT|UPDATE|DELETE|DROP|PRAGMA|$))/i).filter(x => x.trim())) await db.prepare(statement).run();
    }
    master = await setup({ bindings: { ALLOW_GUESTS: 'false', LOCAL_TEST: 'true', VOTE_SECONDS: '1', ACCOUNT_API: 'https://accounts.local', COORDINATOR_API_KEY: 'test-cross-worker-coordinator-secret-at-least-32' },
      outboundService: async request => accounts.dispatchFetch(request.url, { method: request.method, headers: request.headers, body: ['GET','HEAD'].includes(request.method) ? undefined : await request.arrayBuffer() }),
    });
    for (const id of ['123456789012345678','223456789012345678']) {
      const response = await accounts.dispatchFetch('https://accounts.local/auth/discord/exchange', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({ code:id,code_verifier:'A'.repeat(43),redirect_uri:'http://127.0.0.1:4567/callback' }) });
      assert.equal(response.status,200);
      const login = await response.json();
      clients.push(await client(master, 'duel_1v1', async public_key => {
        const result = await accounts.dispatchFetch('https://accounts.local/api/game/assertion', { method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+login.token},body:JSON.stringify({public_key}) });
        assert.equal(result.status,200);return (await result.json()).assertion;
      }));
    }
    const probe = await clients[0].wait('collect_telemetry');
    assert.equal(Object.keys(probe.roster).length,2);
    assert(clients.every(c=>c.user.startsWith('account:')));
    assert.notEqual(clients[0].user,clients[1].user);
    for(const c of clients){const peer=clients.find(p=>p!==c);c.ws.send(JSON.stringify({type:'telemetry',epoch:probe.epoch,round:probe.round,routes:{[peer.user]:{rtts:Array(50).fill(20),bytes:120000,seconds:1.5}}}));}
    const vote=await clients[0].wait('voting');
    for(const c of clients)c.ws.send(JSON.stringify({type:'vote',epoch:vote.epoch,stage:'setup',mode:4,map:5}));
    await Promise.race(clients.map(c=>c.wait('host_offer')));
    const host=clients.find(c=>c.events.some(e=>e.type==='host_offer'));
    const offer=host.events.findLast(e=>e.type==='host_offer');
    host.ws.send(JSON.stringify({type:'host_ready',epoch:offer.epoch}));
    for(const c of clients){const connect=await c.wait('connect');assert(connect);c.ws.send(JSON.stringify({type:'loaded',epoch:offer.epoch}));}
    await clients[0].wait('resume');await clients[1].wait('resume');
    const deadline=Date.now()+5000;let stored;
    while(Date.now()<deadline){stored=await db.prepare('SELECT * FROM matches').first();if(stored)break;await pause(40);}
    assert(stored,'Actual account database registered the match');
    assert.equal(stored.playlist_id,'duel_1v1');
    assert.equal(stored.map_id,'temple');
    assert.equal((await db.prepare('SELECT COUNT(*) AS n FROM match_roster').first()).n,2);
  } finally {for(const c of clients)c.ws.close();await master?.dispose();await accounts.dispose();}
});
