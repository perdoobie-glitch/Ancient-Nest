// src/core.ts
var VERSION = "10.2-peerhost2";
var PLAYLISTS = {
  duel_1v1: { size: 2, mode: 1, name: "1v1 Duel" },
  doubles_2v2: { size: 4, mode: 2, name: "2v2 Doubles" },
  tactical_3v3: { size: 6, mode: 4, name: "3v3 Tactical" },
  arena_4v4: { size: 8, mode: 2, name: "4v4 Arena" },
  bomb_defuse_5v5: { size: 10, mode: 4, name: "5v5 Bomb Defuse" }
};
function modesForPlaylist(playlist) {
  return playlist === "duel_1v1" ? [2, 1, 3, 0, 4] : [2, 3, 0, 4];
}
function majority(ballots, options, size, random = Math.random) {
  if (!options.length) throw Error("No voting options");
  const counts = options.map((option) => ballots.filter((v) => v === option).length);
  const highest = Math.max(...counts);
  const leaders = options.filter((_v, i) => counts[i] === highest);
  return leaders[Math.max(0, Math.min(leaders.length - 1, Math.floor(random() * leaders.length)))];
}
function percentile(a, q) {
  const s = [...a].sort((a2, b) => a2 - b), x = (s.length - 1) * q;
  return s.length ? s[Math.floor(x)] + (s[Math.ceil(x)] - s[Math.floor(x)]) * (x % 1) : 0;
}
var MIN_PEER_UPLOAD_MBPS = 0.55;
function rankHosts(people, reports, capacity = {}) {
  const candidates = [];
  for (const id of people) {
    const pings = [], jitter = [], upload = [], losses = [];
    const hardware = capacity[id];
    if (hardware && (!Number.isFinite(hardware.cpu_p95_ms) || hardware.cpu_p95_ms > 12 || hardware.cpu_p95_ms < 0 || hardware.logical_cpus < 2 || hardware.samples < 15)) continue;
    let valid = true;
    for (const peer of people.filter((p) => p !== id)) {
      const r = reports[peer]?.[id], reverse = reports[id]?.[peer];
      const usable = (r2) => !!r2 && Array.isArray(r2.rtts) && r2.rtts.length >= 45 && r2.rtts.length <= 50 && r2.rtts.every((v) => Number.isFinite(v) && v >= 0 && v <= 250) && Number.isInteger(r2.bytes) && r2.bytes > 0 && r2.bytes <= 5e5 && Number.isFinite(r2.seconds) && r2.seconds >= 0.1 && r2.seconds <= 5;
      if (!usable(r) || !usable(reverse)) {
        valid = false;
        break;
      }
      const throughput = r.bytes * 8 / r.seconds / 1e6;
      if (throughput < MIN_PEER_UPLOAD_MBPS || reverse.bytes * 8 / reverse.seconds / 1e6 < 0.05) {
        valid = false;
        break;
      }
      const mean = r.rtts.reduce((a, b) => a + b, 0) / r.rtts.length;
      pings.push(mean);
      upload.push(throughput);
      losses.push(100 * (1 - Math.min(r.rtts.length, reverse.rtts.length) / 50));
      jitter.push(...r.rtts.slice(1).map((v, i) => Math.abs(v - r.rtts[i])));
    }
    if (!valid || !pings.length || percentile(jitter, 0.95) > 40) continue;
    candidates.push({
      id,
      quality: pings.reduce((a, b) => a + b, 0) / pings.length + 0.25 * Math.max(...pings) + 2 * percentile(jitter, 0.95) + 8 * Math.max(...losses) + 8 / percentile(upload, 0.1) + (hardware ? hardware.cpu_p95_ms * 0.5 : 0),
      upload: percentile(upload, 0.1)
    });
  }
  return candidates.sort(
    (a, b) => a.quality - b.quality || b.upload - a.upload || a.id.localeCompare(b.id)
  ).map((p) => p.id);
}
var b64 = (bytes) => {
  const a = new Uint8Array(bytes);
  let result = "";
  for (let i = 0; i < a.length; i += 8192)
    result += String.fromCharCode(...a.subarray(i, i + 8192));
  return btoa(result);
};
var unb64 = (text) => Uint8Array.from(atob(text), (ch) => ch.charCodeAt(0));
async function hash(text) {
  const a = typeof text === "string" ? new TextEncoder().encode(text) : text;
  return Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", a))).map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function publicKey(pem) {
  if (typeof pem !== "string" || pem.length > 8192) throw Error("Invalid key");
  return crypto.subtle.importKey(
    "spki",
    unb64(pem.replace(/-----[^-]+-----|\s/g, "")),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"]
  );
}
function supportedIceServers(servers) {
  return servers.map((server) => ({
    ...server,
    urls: (Array.isArray(server.urls) ? server.urls : [server.urls]).filter(
      (url) => typeof url === "string" && (url.startsWith("stun:") || url.startsWith("turn:") && !/[?&]transport=(?:tcp|tls)(?:&|$)/i.test(url))
    )
  })).filter((server) => server.urls.length > 0);
}
function partyMatch(groups, ratings, size) {
  const half = size / 2;
  const candidates = groups.slice(0, 32).filter((g) => g.length > 0 && g.length <= half);
  for (let anchor = 0; anchor < candidates.length; anchor++) {
    let best;
    let visits = 0;
    const visit = (i, a, b, picked) => {
      if (++visits > 2e4) return;
      if (a.length === half && b.length === half) {
        const sum = (v) => v.reduce((s, p) => s + (ratings[p] || 0), 0);
        const delta = Math.abs(sum(a) - sum(b));
        if (!best || delta < best.delta) best = { people: picked, team: new Set(a), delta };
        return;
      }
      if (i >= candidates.length) return;
      const g = candidates[i];
      if (a.length + g.length <= half) visit(i + 1, [...a, ...g], b, [...picked, ...g]);
      if (b.length + g.length <= half) visit(i + 1, a, [...b, ...g], [...picked, ...g]);
      visit(i + 1, a, b, picked);
    };
    visit(anchor + 1, [...candidates[anchor]], [], [...candidates[anchor]]);
    if (best) return best;
  }
  return void 0;
}

// src/monitor.ts
function snapshot(rooms, users, parties, history, totals, time, capabilities) {
  const online = new Set(users.filter((a) => a.build === VERSION && time - a.seen < 15).map((a) => a.user));
  const liveParties = parties.filter((p) => p.members.some((u) => online.has(u)));
  const active = rooms.filter((r) => !["complete", "failed"].includes(r.phase));
  const matches = rooms.map((r) => {
    const players = Object.entries(r.roster).map(([id, m]) => ({ name: m.name, team: m.faction, online: online.has(id), host: id === r.authority }));
    return { id: r.id, playlist: r.playlist, mode: r.config.mode, map: r.config.map, phase: r.phase, epoch: r.epoch, capacity: players.length, online: players.filter((p) => p.online).length, disconnected: players.filter((p) => !p.online).length, host: r.roster[r.authority]?.name || "Selecting host", age_seconds: Math.max(0, Math.floor(time - r.born)), players, live: r.live || null };
  });
  const playlists = Object.entries(PLAYLISTS).map(([id, p]) => ({ id, name: p.name, team_size: p.size / 2, max_players: p.size, searching: users.filter((a) => a.playlist === id && a.queued && online.has(a.user)).length, parties: liveParties.filter((q) => q.playlist === id).length, playing: active.filter((r) => r.playlist === id && r.phase === "running").length, forming: active.filter((r) => r.playlist === id && r.phase !== "running").length }));
  const activeRows = matches.filter((r) => !["complete", "failed"].includes(r.phase));
  const modeNames = { 0: "Extraction", 1: "Iso Deathmatch", 2: "Team Deathmatch", 3: "Capture the Flag", 4: "Bomb Defusal" };
  return {
    release: "10.2",
    protocol: VERSION,
    generated_at: time,
    scope: "master-coordinated matches only",
    offline_practice: "not tracked",
    capabilities,
    summary: { online_players: online.size, queued_players: users.filter((a) => a.queued && online.has(a.user)).length, parties: liveParties.length, playing_matches: active.filter((r) => r.phase === "running").length, forming_matches: active.filter((r) => !["running", "results"].includes(r.phase)).length, results_matches: active.filter((r) => r.phase === "results").length, disconnected_slots: activeRows.reduce((n, r) => n + r.disconnected, 0), ...totals },
    playlists,
    game_types: Object.entries(modeNames).map(([id, name]) => ({ id: Number(id), name, playing: active.filter((r) => r.phase === "running" && r.config.mode === Number(id)).length })),
    matches,
    recent: history.slice(-100).reverse()
  };
}
async function monitorAuthorized(request, token) {
  if (!token || token.length < 32) return false;
  const provided = request.headers.get("Authorization") || "";
  if (!provided.startsWith("Bearer ") || provided.length > 256) return false;
  const hash2 = (s) => crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  const [a, b] = await Promise.all([hash2(provided.slice(7)), hash2(token)]);
  const aa = new Uint8Array(a), bb = new Uint8Array(b);
  let difference = 0;
  for (let i = 0; i < aa.length; i++) difference |= aa[i] ^ bb[i];
  return difference === 0;
}

// src/worker.ts
var now = () => Date.now() / 1e3;
var origin = (s) => {
  const u = new URL(s);
  if (u.protocol !== "https:" && !["localhost", "127.0.0.1"].includes(u.hostname))
    throw Error("HTTPS account service required");
  if (u.pathname !== "/" || u.username || u.password || u.search || u.hash)
    throw Error("Invalid account origin");
  return u.origin;
};
var worker_default = {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname === "/api/monitor") {
      if (req.method !== "GET") return new Response("Method not allowed", { status: 405, headers: { Allow: "GET" } });
      if (!env.MONITOR_TOKEN || env.MONITOR_TOKEN.length < 32) return Response.json({ error: "Monitor access not configured" }, { status: 503, headers: { "Cache-Control": "no-store" } });
      if (!await monitorAuthorized(req, env.MONITOR_TOKEN)) return Response.json({ error: "Unauthorized" }, { status: 401, headers: { "Cache-Control": "no-store" } });
      return env.MATCHMAKER.get(env.MATCHMAKER.idFromName("global-v1")).fetch(req);
    }
    if (url.pathname === "/ready") {
      if (req.method !== "GET") return new Response("Method not allowed", { status: 405, headers: { Allow: "GET" } });
      try {
        return await env.MATCHMAKER.get(env.MATCHMAKER.idFromName("global-v1")).fetch(req);
      } catch {
        return Response.json({ service: "ancient-nest-matchmaking", release: "10.2", ready: false, error: "Matchmaker initialization failed" }, { status: 503, headers: { "Cache-Control": "no-store" } });
      }
    }
    if (url.pathname === "/health")
      return Response.json({
        service: "ancient-nest-matchmaking",
        release: "10.2",
        version: VERSION,
        hosting: "player_hosted"
      });
    if (url.pathname !== "/v1/matchmaking" || req.headers.get("Upgrade")?.toLowerCase() !== "websocket")
      return new Response("Use WebSocket /v1/matchmaking", { status: 404 });
    return env.MATCHMAKER.get(env.MATCHMAKER.idFromName("global-v1")).fetch(
      req
    );
  }
};
var Matchmaker = class {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
    ctx.blockConcurrencyWhile(async () => {
      let stored = await ctx.storage.get("identity");
      if (!stored) {
        const keys = await crypto.subtle.generateKey(
          {
            name: "RSASSA-PKCS1-v1_5",
            modulusLength: 2048,
            publicExponent: new Uint8Array([1, 0, 1]),
            hash: "SHA-256"
          },
          true,
          ["sign", "verify"]
        );
        stored = {
          private: b64(
            await crypto.subtle.exportKey(
              "pkcs8",
              keys.privateKey
            )
          ),
          public: b64(
            await crypto.subtle.exportKey(
              "spki",
              keys.publicKey
            )
          )
        };
        await ctx.storage.put("identity", stored);
      }
      this.key = await crypto.subtle.importKey(
        "pkcs8",
        unb64(stored.private),
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"]
      );
      this.pem = "-----BEGIN PUBLIC KEY-----\n" + stored.public.match(/.{1,64}/g).join("\n") + "\n-----END PUBLIC KEY-----\n";
      this.rooms = Object.fromEntries(
        [...await ctx.storage.list({ prefix: "room:" })].map(
          ([k, v]) => [k.slice(5), v]
        )
      );
      this.queue = await ctx.storage.get("queue") || [];
      this.queueSaved = JSON.stringify(this.queue);
      this.parties = await ctx.storage.get("parties") || {};
      this.partySaved = JSON.stringify(this.parties);
      this.telemetry = await ctx.storage.get("monitor-telemetry") || this.telemetry;
      this.telemetrySaved = JSON.stringify(this.telemetry);
    });
  }
  ctx;
  env;
  rooms = {};
  queue = [];
  parties = {};
  key;
  pem = "";
  serial = Promise.resolve();
  dirty = /* @__PURE__ */ new Set();
  jobsInFlight = /* @__PURE__ */ new Set();
  telemetry = { started: 0, finished: 0, failed: 0, history: [] };
  telemetrySaved = "";
  reviewCache = { at: 0, data: { available: false } };
  reviewLoading = null;
  queueSaved = "";
  partySaved = "";
  run(job) {
    const task = this.serial.then(job);
    this.serial = task.catch(() => {
    });
    return task;
  }
  async fetch(_req) {
    if (new URL(_req.url).pathname === "/ready") {
      const initialized = !!await this.ctx.storage.get("identity") && !!this.key;
      return Response.json({ service: "ancient-nest-matchmaking", release: "10.2", version: VERSION, ready: initialized, checks: { coordinator: initialized, auth_mode: this.env.ALLOW_GUESTS === "true" ? "guest" : "accounts", account_bridge_configured: !!this.env.ACCOUNT_API && !!this.env.COORDINATOR_API_KEY, turn_configured: !!this.env.TURN_KEY_ID && !!this.env.TURN_KEY_API_TOKEN, monitor_configured: !!this.env.MONITOR_TOKEN && this.env.MONITOR_TOKEN.length >= 32 } }, { status: initialized ? 200 : 503, headers: { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" } });
    }
    if (new URL(_req.url).pathname === "/api/monitor") {
      if (!await monitorAuthorized(_req, this.env.MONITOR_TOKEN)) return new Response("Unauthorized", { status: 401 });
      let result = {};
      await this.run(async () => {
        const users = [...this.sockets().values()].map((ws) => ws.deserializeAttachment()).filter((a) => !!a.user).map((a) => ({ ...a, queued: this.queue.includes(a.user) }));
        result = snapshot(Object.values(this.rooms), users, Object.values(this.parties), this.telemetry.history, { started: this.telemetry.started, finished: this.telemetry.finished, failed: this.telemetry.failed }, now(), { turn_configured: !!this.env.TURN_KEY_ID && !!this.env.TURN_KEY_API_TOKEN, accounts_configured: !!this.env.ACCOUNT_API && !!this.env.COORDINATOR_API_KEY, guest_mode: this.env.ALLOW_GUESTS === "true", max_control_sockets: 512, max_active_rooms: 64 });
      });
      await this.refreshReviewSummary();
      result.ranking_review = this.reviewCache.data;
      return Response.json(result, { headers: { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" } });
    }
    if (this.ctx.getWebSockets().length >= 512)
      return new Response("Matchmaking capacity reached", { status: 503 });
    const pair = new WebSocketPair(), client = pair[0], server = pair[1];
    this.ctx.acceptWebSocket(server);
    if (await this.ctx.storage.getAlarm() === null)
      await this.ctx.storage.setAlarm(Date.now() + 15e3);
    server.serializeAttachment({
      nonce: crypto.randomUUID(),
      seen: now()
    });
    return new Response(null, { status: 101, webSocket: client });
  }
  webSocketMessage(ws, message) {
    if (typeof message === "string" && message.length <= 15e5) {
      try {
        const packet = JSON.parse(message), attachment = ws.deserializeAttachment();
        if ((packet?.type === "ping" || packet?.type === "heartbeat") && attachment?.user && attachment.build === VERSION)
          return this.keepAlive(ws, attachment, packet, message.length);
      } catch {
      }
    }
    return this.run(async () => {
      try {
        if (typeof message !== "string" || message.length > 15e5)
          throw Error("Message too large");
        const a = ws.deserializeAttachment(), time = now();
        if (!a.window || time - a.window > 5) {
          a.window = time;
          a.messages = 0;
        }
        if ((a.messages = (a.messages || 0) + 1) > 400)
          throw Error("Rate limit");
        a.seen = time;
        ws.serializeAttachment(a);
        const p = JSON.parse(message);
        if (!p || typeof p !== "object" || Array.isArray(p))
          throw Error("Invalid message");
        await this.message(ws, a, p);
        const updated = ws.deserializeAttachment();
        if (updated.room && !["ping", "heartbeat", "rtc_signal"].includes(p.type))
          this.dirty.add(updated.room);
        await this.persist();
      } catch (error) {
        if (this.env.LOCAL_TEST === "true") console.log("QA_REQUEST_REJECT", error instanceof Error ? error.message : "Invalid request");
        this.send(ws, {
          type: "failed",
          reason: error instanceof Error ? error.message : "Invalid request"
        });
        ws.close(1008, "Request rejected");
      }
    });
  }
  async keepAlive(ws, a, p, size) {
    try {
      if (size > 8192) throw Error("Keep-alive too large");
      const time = now();
      if (!a.window || time - a.window > 5) {
        a.window = time;
        a.messages = 0;
      }
      if ((a.messages = (a.messages || 0) + 1) > 400) throw Error("Rate limit");
      a.seen = time;
      ws.serializeAttachment(a);
      await this.message(ws, a, p);
    } catch (error) {
      this.send(ws, { type: "failed", reason: error instanceof Error ? error.message : "Invalid keep-alive" });
      ws.close(1008, "Request rejected");
    }
  }
  webSocketClose(ws) {
    return this.run(async () => {
      const a = ws.deserializeAttachment();
      if (a?.nonce) await this.ctx.storage.delete("login:" + a.nonce);
      if (a?.user) {
        if (!a.room) await this.removePartyMember(a.user);
        this.queue = this.queue.filter((p) => p !== a.user);
        await this.queueState();
      }
      await this.persist();
    });
  }
  webSocketError(ws) {
    return this.webSocketClose(ws);
  }
  sockets() {
    const values = /* @__PURE__ */ new Map();
    for (const ws of this.ctx.getWebSockets()) {
      const a = ws.deserializeAttachment();
      if (a?.user) values.set(a.user, ws);
    }
    return values;
  }
  info(user) {
    return this.sockets().get(user)?.deserializeAttachment();
  }
  send(ws, value) {
    try {
      ws?.send(JSON.stringify({ ...value, server_time: now() }));
    } catch {
    }
  }
  async emit(r, value, user) {
    const sockets = this.sockets(), event = {
      match: r.id,
      epoch: r.epoch,
      roster: r.roster,
      config: r.config,
      targets: r.targets,
      transport: "webrtc",
      ice_policy: this.env.RELAY_ONLY === "true" ? "relay" : "all",
      ...value
    };
    for (const who of user ? [user] : Object.keys(r.roster))
      this.send(sockets.get(who), event);
  }
  async persist() {
    const reservedUsers = new Set(Object.values(this.rooms).filter((r) => !["complete", "failed"].includes(r.phase)).flatMap((r) => Object.keys(r.roster)));
    for (const party of Object.values(this.parties)) {
      party.members = party.members.filter((u) => this.info(u)?.party === party.id || reservedUsers.has(u));
      if (!party.members.length) {
        delete this.parties[party.id];
        continue;
      }
      if (!party.members.includes(party.leader)) party.leader = party.members[0];
    }
    for (const r of Object.values(this.rooms)) {
      if (!r.monitorStarted && ["running", "results", "complete"].includes(r.phase)) {
        r.monitorStarted = true;
        this.telemetry.started++;
        this.dirty.add(r.id);
      }
      if (!r.monitorRecorded && ["complete", "failed"].includes(r.phase)) {
        r.monitorRecorded = true;
        this.telemetry[r.phase === "complete" ? "finished" : "failed"]++;
        this.dirty.add(r.id);
        this.telemetry.history.push({ id: r.id, playlist: r.playlist, mode: r.config.mode, map: r.config.map, result: r.phase, ended_at: now(), duration_seconds: Math.max(0, Math.floor(now() - r.born)), players: Object.keys(r.roster).length });
        this.telemetry.history = this.telemetry.history.slice(-100);
      }
    }
    const telemetry = JSON.stringify(this.telemetry);
    if (telemetry !== this.telemetrySaved) {
      await this.ctx.storage.put("monitor-telemetry", this.telemetry);
      this.telemetrySaved = telemetry;
    }
    const parties = JSON.stringify(this.parties);
    if (parties !== this.partySaved) {
      await this.ctx.storage.put("parties", this.parties);
      this.partySaved = parties;
    }
    const queue = JSON.stringify(this.queue);
    if (queue !== this.queueSaved) {
      await this.ctx.storage.put("queue", this.queue);
      this.queueSaved = queue;
    }
    for (const id of this.dirty) {
      if (this.rooms[id])
        await this.ctx.storage.put("room:" + id, this.rooms[id]);
    }
    this.dirty.clear();
    if (this.queue.length || Object.keys(this.rooms).length || this.ctx.getWebSockets().length) {
      const due = Date.now() + 1e3, alarm = await this.ctx.storage.getAlarm();
      if (alarm === null || alarm > due) await this.ctx.storage.setAlarm(due);
    }
  }
  async saveBlob(key, text) {
    for (let i = 0; i < text.length; i += 6e4)
      await this.ctx.storage.put(
        `${key}:${i / 6e4}`,
        text.slice(i, i + 6e4)
      );
    await this.ctx.storage.put(key + ":length", text.length);
  }
  async blob(key) {
    const length = await this.ctx.storage.get(key + ":length") || 0;
    let text = "";
    for (let i = 0; i < length; i += 6e4)
      text += await this.ctx.storage.get(`${key}:${i / 6e4}`) || "";
    return text;
  }
  async deleteBlob(key) {
    const keys = [
      ...(await this.ctx.storage.list({ prefix: key + ":" })).keys()
    ];
    if (keys.length) await this.ctx.storage.delete(keys);
  }
  async ticket(r, kind, subject, ttl, extra = {}) {
    const raw = new TextEncoder().encode(
      JSON.stringify({
        v: 1,
        kind,
        match: r.id,
        epoch: r.epoch,
        subject,
        authority: r.authority,
        issued: now(),
        expires: now() + ttl,
        nonce: crypto.randomUUID().replaceAll("-", ""),
        extra
      })
    );
    return b64(raw) + "." + b64(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", this.key, raw));
  }
  async hello(ws, a, p) {
    if (a.user || p.version !== VERSION || typeof p.playlist !== "string" || !Object.hasOwn(PLAYLISTS, p.playlist))
      throw Error("Use matching game version and a valid playlist");
    const key = await publicKey(p.public_key);
    if (Number(key.algorithm.modulusLength) < 2048)
      throw Error("RSA key is too small");
    a.build = VERSION;
    a.public_key = p.public_key;
    a.lobbyOnly = p.lobby_only === true;
    a.name = String(p.name || "Player").replace(/[^A-Za-z0-9_ -]/g, "").slice(0, 20) || "Player";
    a.playlist = p.playlist;
    a.nonce = crypto.randomUUID();
    if (typeof p.account_assertion !== "string" && p.account_assertion !== void 0 || String(p.account_assertion || "").length > 8192)
      throw Error("Invalid account assertion");
    await this.ctx.storage.put("login:" + a.nonce, {
      account_assertion: p.account_assertion || ""
    });
    ws.serializeAttachment(a);
    this.send(ws, { type: "challenge", nonce: a.nonce });
  }
  async proof(ws, a, p) {
    const pending = await this.ctx.storage.get("login:" + a.nonce);
    if (!pending || !a.public_key || a.user) throw Error("No pending sign-in");
    const valid = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      await publicKey(a.public_key),
      unb64(p.signature),
      new TextEncoder().encode(a.nonce)
    );
    if (!valid) throw Error("Game identity proof rejected");
    const key_hash = await hash(a.public_key);
    a.user = key_hash.slice(0, 32);
    a.rating = 1;
    if (pending.account_assertion && this.env.ACCOUNT_API) {
      const base = origin(this.env.ACCOUNT_API), body = JSON.stringify({
        assertion: pending.account_assertion,
        key_hash
      });
      const res = await fetch(base + "/api/game/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
        redirect: "manual",
        signal: AbortSignal.timeout(5e3)
      });
      const account = await res.json();
      if (!res.ok || account.valid !== true || account.key_hash !== key_hash || typeof account.account_id !== "string" || !/^[a-f0-9-]{36}$/.test(account.account_id))
        throw Error("Account verification failed");
      a.account = account.account_id;
      a.user = "account:" + a.account;
      a.name = account.username;
      const profile = await fetch(base + "/api/game/profile", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
        redirect: "manual",
        signal: AbortSignal.timeout(5e3)
      });
      if (profile.ok) {
        const stats = await profile.json();
        a.ratings = Object.fromEntries(Object.keys(PLAYLISTS).map((key) => [key, Math.max(1, Number(stats.playlists?.[key]?.elo) || 1)]));
        a.rating = a.ratings.duel_1v1;
      }
    } else if (this.env.ALLOW_GUESTS !== "true")
      throw Error("Link your Ancient Nest account before matchmaking");
    if (this.sockets().has(a.user)) throw Error("Identity already connected");
    await this.ctx.storage.delete("login:" + a.nonce);
    const reserved = Object.values(this.rooms).find(
      (r) => r.config.build === VERSION && r.roster[a.user] && !["complete", "failed"].includes(r.phase)
    );
    if (reserved) {
      a.party = Object.values(this.parties).find((p2) => p2.members.includes(a.user))?.id;
      a.room = reserved.id;
      a.playlist = reserved.playlist;
    }
    ws.serializeAttachment(a);
    this.send(ws, {
      type: "hello",
      player: a.user,
      playlist: a.playlist,
      public_key: this.pem,
      cookie: "",
      udp_host: "",
      udp_port: 0,
      transport: "webrtc"
    });
    if (reserved) {
      if (reserved.phase === "running")
        await this.connect(reserved, a.user, true);
      else if (reserved.phase === "voting") await this.publishVote(reserved);
      else throw Error("Reserved match is recovering; reconnect shortly");
    } else if (a.lobbyOnly) {
      await this.createParty(ws, a);
    } else {
      this.queue.push(a.user);
      await this.form();
      await this.queueState();
    }
  }
  async queueState() {
    for (const [id, list] of Object.entries(PLAYLISTS)) {
      const people = this.queue.filter(
        (user) => this.info(user)?.playlist === id
      );
      const members = Object.fromEntries(
        people.slice(0, list.size).map((user, i) => [
          i + 2,
          {
            name: this.info(user)?.name,
            faction: 0,
            rating: { human: this.info(user)?.rating || 0, practice: 0 }
          }
        ])
      );
      for (const who of people)
        this.send(this.sockets().get(who), {
          type: "queue",
          playlist: id,
          capacity: list.size,
          members,
          connected: Math.min(people.length, list.size),
          status: people.length >= list.size ? "Waiting for compatible team sizes. Parties stay together." : "Finding players for your playlist\u2026"
        });
    }
  }
  async createParty(ws, a) {
    let id;
    do {
      id = crypto.randomUUID().replaceAll("-", "").slice(0, 10).toUpperCase();
    } while (this.parties[id]);
    const party = { id, leader: a.user, members: [a.user], playlist: a.playlist, searching: false };
    this.parties[id] = party;
    a.party = id;
    ws.serializeAttachment(a);
    await this.publishParty(party);
  }
  async publishParty(party) {
    const sockets = this.sockets();
    const members = party.members.map((user) => ({ user, name: this.info(user)?.name || "Player", leader: user === party.leader, rating: this.info(user)?.rating || 0 }));
    for (const user of party.members) this.send(sockets.get(user), { type: "party", code: party.id, leader: party.leader, members, playlist: party.playlist, searching: party.searching, team_size: PLAYLISTS[party.playlist].size / 2 });
  }
  async cancelParty(party) {
    party.searching = false;
    this.queue = this.queue.filter((p) => !party.members.includes(p));
    await this.publishParty(party);
    await this.queueState();
  }
  async removePartyMember(user) {
    const party = Object.values(this.parties).find((p) => p.members.includes(user));
    if (!party) return;
    party.searching = false;
    this.queue = this.queue.filter((p) => !party.members.includes(p));
    party.members = party.members.filter((p) => p !== user);
    if (!party.members.length) {
      delete this.parties[party.id];
      await this.queueState();
      return;
    }
    if (party.leader === user) party.leader = party.members[0];
    await this.publishParty(party);
    await this.queueState();
  }
  async partyMessage(ws, a, p) {
    if (a.room) throw Error("Party changes are unavailable during a match");
    let party = this.parties[a.party || ""];
    if (!party) {
      await this.createParty(ws, a);
      party = this.parties[a.party];
    }
    if (p.type === "party_sync") {
      await this.publishParty(party);
      return;
    }
    if (p.type === "party_join") {
      const code = String(p.code || "").trim().toUpperCase();
      const target = this.parties[code];
      if (!target) throw Error("Invite code not found. Ask your friend for a new code.");
      if (target === party) return;
      if (party.searching || target.searching) throw Error("Cancel search before changing parties");
      if (target.members.some((u) => !!this.info(u)?.room)) throw Error("This party is already in a match");
      if (target.members.length >= PLAYLISTS[target.playlist].size / 2) throw Error("Party is full for this playlist");
      await this.removePartyMember(a.user);
      target.members.push(a.user);
      a.party = code;
      a.playlist = target.playlist;
      ws.serializeAttachment(a);
      await this.publishParty(target);
      return;
    }
    if (p.type === "party_leave") {
      await this.removePartyMember(a.user);
      delete a.party;
      ws.serializeAttachment(a);
      await this.createParty(ws, a);
      return;
    }
    if (party.leader !== a.user) throw Error("Only the party leader can choose a playlist or search");
    if (p.type === "party_playlist") {
      if (party.searching) throw Error("Cancel search before changing playlist");
      if (typeof p.playlist !== "string" || !Object.hasOwn(PLAYLISTS, p.playlist)) throw Error("Invalid playlist");
      const playlist = p.playlist;
      if (party.members.length > PLAYLISTS[playlist].size / 2) throw Error("Choose a playlist with enough team slots for your party");
      party.playlist = playlist;
      for (const u of party.members) {
        const sock = this.sockets().get(u);
        if (sock) {
          const info = sock.deserializeAttachment();
          info.playlist = playlist;
          sock.serializeAttachment(info);
        }
      }
      await this.publishParty(party);
      return;
    }
    if (p.type === "party_cancel") {
      await this.cancelParty(party);
      return;
    }
    if (p.type === "party_search") {
      if (party.searching) return;
      if (party.members.length > PLAYLISTS[party.playlist].size / 2) throw Error("Party exceeds this playlist's team size");
      if (!party.members.every((u) => !!this.info(u) && !this.info(u)?.room)) throw Error("Wait for every party member to connect");
      const membersBefore = JSON.stringify(party.members), playlistBefore = party.playlist;
      await this.refreshRatings([...party.members]);
      if (this.parties[party.id] !== party || JSON.stringify(party.members) !== membersBefore || party.playlist !== playlistBefore || party.searching || !party.members.every((u) => !!this.info(u) && !this.info(u)?.room)) throw Error("Party changed while refreshing ratings. Search again.");
      party.searching = true;
      for (const u of party.members) if (!this.queue.includes(u)) this.queue.push(u);
      await this.publishParty(party);
      await this.form();
      await this.queueState();
      return;
    }
    throw Error("Unknown party action");
  }
  ratingFor(user, playlist) {
    return this.info(user)?.ratings?.[playlist] ?? 1;
  }
  async refreshReviewSummary() {
    if (!this.env.ACCOUNT_API || !this.env.COORDINATOR_API_KEY) {
      this.reviewCache = { at: now(), data: { available: false, reason: "accounts_not_configured" } };
      return;
    }
    if (now() - this.reviewCache.at < 30) return;
    if (this.reviewLoading) return this.reviewLoading;
    this.reviewLoading = (async () => {
      try {
        const response = await fetch(origin(this.env.ACCOUNT_API) + "/api/internal/reviews", { method: "POST", headers: { "Content-Type": "application/json", Authorization: "Bearer " + this.env.COORDINATOR_API_KEY }, body: "{}", redirect: "manual", signal: AbortSignal.timeout(1500) });
        const value = await response.json();
        this.reviewCache = { at: now(), data: response.ok && Array.isArray(value.reviews) ? { available: true, ...value } : { available: false, reason: "review_service_unavailable" } };
      } catch {
        this.reviewCache = { at: now(), data: { available: false, reason: "review_service_unavailable" } };
      }
    })();
    try {
      await this.reviewLoading;
    } finally {
      this.reviewLoading = null;
    }
  }
  async refreshRatings(users) {
    const accounts = users.map((user) => this.info(user)?.account).filter((id) => !!id);
    if (!accounts.length) return;
    if (!this.env.ACCOUNT_API || !this.env.COORDINATOR_API_KEY) throw Error("Playlist rating service is not configured");
    const response = await fetch(origin(this.env.ACCOUNT_API) + "/api/internal/players/ratings", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: "Bearer " + this.env.COORDINATOR_API_KEY },
      body: JSON.stringify({ account_ids: accounts }),
      redirect: "manual",
      signal: AbortSignal.timeout(5e3)
    });
    if (!response.ok) throw Error("Cannot refresh playlist ratings. Please retry search.");
    const data = await response.json();
    for (const user of users) {
      const socket = this.sockets().get(user);
      if (!socket) throw Error("Party member disconnected");
      const a = socket.deserializeAttachment();
      if (!a.account) continue;
      const values = data.ratings?.[a.account];
      if (!values || Object.keys(PLAYLISTS).some((key) => !Number.isSafeInteger(values[key]) || values[key] < 1)) throw Error("Invalid playlist rating response");
      a.ratings = values;
      socket.serializeAttachment(a);
    }
  }
  async ice() {
    if (this.env.LOCAL_TEST === "true" && this.env.ALLOW_GUESTS === "true")
      return JSON.parse(this.env.LOCAL_ICE_JSON || "[]");
    if (!this.env.TURN_KEY_ID || !this.env.TURN_KEY_API_TOKEN)
      return [{ urls: ["stun:stun.cloudflare.com:3478"] }];
    const res = await fetch(
      `https://rtc.live.cloudflare.com/v1/turn/keys/${encodeURIComponent(this.env.TURN_KEY_ID)}/credentials/generate-ice-servers`,
      {
        method: "POST",
        headers: {
          Authorization: "Bearer " + this.env.TURN_KEY_API_TOKEN,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ ttl: 14400 }),
        redirect: "manual",
        signal: AbortSignal.timeout(5e3)
      }
    );
    if (!res.ok) throw Error("TURN credential service unavailable");
    const value = await res.json();
    if (!Array.isArray(value.iceServers)) throw Error("Invalid TURN response");
    return supportedIceServers(value.iceServers);
  }
  async form() {
    this.queue = this.queue.filter((p) => this.info(p)?.build === VERSION);
    for (const first of [...this.queue]) {
      const list = this.info(first)?.playlist;
      if (!list) continue;
      const spec = PLAYLISTS[list];
      const eligible = this.queue.filter((p) => this.info(p)?.playlist === list);
      const grouped = /* @__PURE__ */ new Set();
      const groups = [];
      for (const p of eligible) {
        if (grouped.has(p)) continue;
        const party = this.parties[this.info(p)?.party || ""];
        const group = party ? party.members : [p];
        if (party && (!party.searching || !group.every((id2) => eligible.includes(id2)))) continue;
        group.forEach((id2) => grouped.add(id2));
        groups.push(group);
      }
      const ratings = Object.fromEntries(eligible.map((p) => [p, this.ratingFor(p, list)]));
      const selection = partyMatch(groups, ratings, spec.size);
      if (!selection) continue;
      const { people, team } = selection;
      if (Object.keys(this.rooms).length >= 256 || Object.values(this.rooms).filter(
        (r2) => !["complete", "failed"].includes(r2.phase)
      ).length >= 64)
        break;
      this.queue = this.queue.filter((p) => !people.includes(p));
      people.sort();
      const roster = {};
      for (const [i, who] of people.entries()) {
        const a = this.info(who);
        roster[who] = {
          slot: i + 2,
          name: a.name,
          faction: team.has(who) ? 0 : 1,
          rating: { human: this.ratingFor(who, list), practice: 0 },
          public_key: a.public_key,
          account: a.account
        };
      }
      const id = crypto.randomUUID(), r = {
        id,
        playlist: list,
        roster,
        targets: people,
        phase: "probing",
        epoch: 0,
        authority: "",
        deadline: now() + 25,
        seen: Object.fromEntries(people.map((p) => [p, now()])),
        host_seen: now(),
        reports: {},
        tried: [],
        votes: {},
        config: {
          build: VERSION,
          mode: spec.mode,
          map: 0,
          matchup: 1,
          playlist: list,
          capacity: spec.size
        },
        ready: [],
        migration: false,
        pending: [],
        born: now(),
        iceServers: await this.ice(),
        rtcRound: crypto.randomUUID()
      };
      this.rooms[id] = r;
      this.dirty.add(id);
      for (const who of people) {
        const ws = this.sockets().get(who), a = ws.deserializeAttachment();
        a.room = id;
        ws.serializeAttachment(a);
      }
      await this.probe(r);
    }
  }
  async probe(r) {
    r.reports = {};
    r.rtcRound = crypto.randomUUID();
    r.deadline = now() + 25;
    r.iceServers = await this.ice();
    await this.emit(r, {
      type: "collect_telemetry",
      members: r.targets,
      probe_key: "",
      udp_host: "",
      udp_port: 0,
      ice_servers: r.iceServers,
      round: r.rtcRound,
      reason: r.migration ? "host_migration" : "peer_host_selection"
    });
  }
  async elect(r, finished = false) {
    if (!finished && !r.targets.every((p) => r.reports[p])) return;
    if (r.migration) {
      r.targets = r.targets.filter((who) => now() - r.seen[who] < 6);
      if (r.targets.length <= Object.keys(r.roster).length / 2) {
        await this.fail(r, "Not enough connected original players to migrate");
        return;
      }
    }
    const ranked = rankHosts(r.targets, r.reports, r.config.host_capacity || {}).filter(
      (p) => !r.tried.includes(p) && now() - r.seen[p] < 6
    );
    if (!ranked.length) {
      if (this.env.LOCAL_TEST === "true")
        console.log("QA_ELECTION_REJECT", JSON.stringify({ reports: r.reports, capacity: r.config.host_capacity }));
      await this.fail(
        r,
        rankHosts(r.targets, r.reports).length ? "No available player has enough observed CPU headroom to host. Close background programs or choose a stronger host." : "No player has a stable route with enough upload to every opponent. Check TURN relay credentials or try another network."
      );
      return;
    }
    r.config.host_order = ranked;
    r.authority = ranked[0];
    r.reports = {};
    if (!r.migration && !r.config.voted) {
      r.phase = "voting";
      r.config.vote_stage = "setup";
      r.deadline = now() + this.voteSeconds();
      await this.publishVote(r);
    } else await this.offer(r);
  }
  voteSeconds() {
    return Math.max(1, Math.min(60, Number(this.env.VOTE_SECONDS) || 25));
  }
  async publishVote(r) {
    await this.emit(r, {
      type: "voting",
      stage: r.config.vote_stage,
      capacity: Object.keys(r.roster).length,
      playlist: r.playlist,
      votes: r.votes,
      seconds: Math.max(0, r.deadline - now()),
      host_name: r.roster[r.authority]?.name,
      allowed_modes: modesForPlaylist(r.playlist)
    });
  }
  async finishVote(r) {
    const values = Object.values(r.votes), size = Object.keys(r.roster).length;
    if (r.config.vote_stage === "setup") {
      r.config.mode = majority(
        values.map((v) => v.mode),
        modesForPlaylist(r.playlist),
        size
      );
      r.config.map = majority(
        values.map((v) => v.map),
        [0, 1, 2, 3, 4, 5],
        size
      );
      if (r.config.mode !== 0) {
        r.config.vote_stage = "life";
        r.votes = {};
        r.deadline = now() + this.voteSeconds();
        await this.publishVote(r);
        return;
      }
      r.config.matchup = 3;
    } else
      r.config.matchup = majority(
        values.map((v) => v.life),
        [1, 2],
        size
      );
    delete r.config.vote_stage;
    r.config.voted = true;
    await this.offer(r);
  }
  async offer(r) {
    if (!this.info(r.authority)) {
      r.phase = "probing";
      r.tried.push(r.authority);
      await this.probe(r);
      return;
    }
    r.epoch++;
    r.tried.push(r.authority);
    r.phase = "offered";
    r.deadline = now() + 12;
    r.ready = [];
    await this.emit(
      r,
      {
        type: "host_offer",
        grant: await this.ticket(r, "host_offer", r.authority, 12),
        restore: r.checkpoint?.digest,
        state: r.checkpoint ? await this.blob(r.checkpoint.blob) : "",
        ice_servers: r.iceServers,
        round: r.rtcRound
      },
      r.authority
    );
  }
  async connect(r, user, rejoin = false) {
    const endpoint = { host: "webrtc", port: 1, relay: false }, checkpoint = r.checkpoint?.digest || null;
    await this.emit(
      r,
      {
        type: "connect",
        authority: r.authority,
        mode: "peer",
        grant: await this.ticket(r, "join", user, 45, {
          endpoint,
          checkpoint,
          client_public_key: r.roster[user].public_key
        }),
        checkpoint,
        state: r.checkpoint ? await this.blob(r.checkpoint.blob) : "",
        rejoin,
        ice_servers: r.iceServers,
        round: r.rtcRound
      },
      user
    );
  }
  async resume(r) {
    r.phase = "running";
    r.host_seen = now();
    await this.emit(r, {
      type: "authority_lease",
      grant: await this.ticket(r, "authority", r.authority, 4)
    });
    await this.emit(r, {
      type: "resume",
      members: r.targets,
      bots: Object.keys(r.roster).filter((p) => !r.targets.includes(p))
    });
  }
  async migrate(r) {
    const old = r.authority;
    r.epoch++;
    r.phase = "probing";
    r.migration = true;
    r.ready = [];
    r.tried = [old];
    r.targets = Object.keys(r.roster).filter(
      (p) => p !== old && now() - r.seen[p] < 6
    );
    await this.emit(r, {
      type: "freeze",
      reason: "host_migration",
      checkpoint: r.checkpoint?.digest
    });
    if (!r.checkpoint || now() - r.checkpoint.at > 20 || r.targets.length <= Object.keys(r.roster).length / 2) {
      await this.fail(
        r,
        "Cannot safely migrate without a fresh checkpoint and majority of original players"
      );
      return;
    }
    const backup = (r.config.host_order || []).find((who) => r.targets.includes(who) && !r.tried.includes(who) && (!r.config.host_capacity?.[who] || r.config.host_capacity[who].cpu_p95_ms <= 12));
    if (backup) {
      r.authority = backup;
      await this.offer(r);
    } else await this.probe(r);
  }
  async fail(r, reason) {
    r.phase = "failed";
    r.deadline = now() + 30;
    await this.emit(r, { type: "failed", reason });
    if (r.registered && r.monitorStarted) await this.apiJob(r, "review", { match_id: r.id, reason: "abandoned_or_interrupted", absent: Object.keys(r.roster).filter((who) => !this.info(who)).map((who) => r.roster[who].account), reports: Object.entries(r.results || {}).map(([who, v]) => ({ account: r.roster[who]?.account, digest: v.digest, winner_team: v.report.winner_team })), sample_report: Object.values(r.results || {})[0]?.report });
    await this.apiJob(r, "void", { match_id: r.id });
    for (const who of Object.keys(r.roster)) {
      const ws = this.sockets().get(who);
      if (!ws) continue;
      const a = ws.deserializeAttachment();
      delete a.room;
      ws.serializeAttachment(a);
      const party = this.parties[a.party || ""];
      if (party) party.searching = false;
    }
  }
  async apiJob(r, action, body) {
    if (!this.env.COORDINATOR_API_KEY || !this.env.ACCOUNT_API || ["void", "review"].includes(action) && !r.registered)
      return;
    r.jobs ??= [];
    r.jobs.push({ path: "/api/internal/matches/" + action, body, attempts: 0 });
  }
  async flushJobs(r) {
    const job = r.jobs?.[0];
    if (!job || (job.next || 0) > now() || this.jobsInFlight.has(r.id) || !this.env.COORDINATOR_API_KEY || !this.env.ACCOUNT_API) return;
    this.jobsInFlight.add(r.id);
    this.ctx.waitUntil(this.deliverJob(r.id, job));
  }
  async deliverJob(roomId, job) {
    let delivered = false;
    try {
      const res = await fetch(origin(this.env.ACCOUNT_API) + job.path, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: "Bearer " + this.env.COORDINATOR_API_KEY },
        body: JSON.stringify(job.body),
        redirect: "manual",
        signal: AbortSignal.timeout(4e3)
      });
      delivered = res.ok;
    } catch {
    }
    await this.run(async () => {
      try {
        const current = this.rooms[roomId];
        if (!current || current.jobs?.[0] !== job) return;
        if (delivered) {
          current.jobs.shift();
          if (job.path.endsWith("/result")) await this.emit(current, { type: "result_status", status: "recorded", message: "Match result recorded by the account server." });
        } else {
          job.attempts++;
          job.next = now() + Math.min(300, 2 ** Math.min(9, job.attempts));
        }
        this.dirty.add(roomId);
        await this.persist();
      } finally {
        this.jobsInFlight.delete(roomId);
      }
    });
  }
  async registerResultMatch(r) {
    if (r.registered || !this.env.COORDINATOR_API_KEY || !this.env.ACCOUNT_API || Object.values(r.roster).some((p) => !p.account))
      return;
    const modes = [
      "extraction",
      "free_for_all",
      "team_deathmatch",
      "capture_the_flag",
      "bomb_defuse"
    ];
    const sorted = Object.values(r.roster).sort(
      (a, b) => a.account.localeCompare(b.account)
    );
    await this.apiJob(r, "register", {
      match_id: r.id,
      scope: "matchmaking",
      playlist_id: r.playlist,
      game_type: modes[r.config.mode],
      hosting: "player_hosted",
      map_id: ["sanctuary", "crossroads", "savannah", "connectuct", "qaytal", "temple"][r.config.map],
      authority_id: r.authority,
      roster: sorted.map((m, i) => ({
        account_id: m.account,
        team: r.config.mode === 1 ? i : m.faction
      }))
    });
    r.registered = true;
    r.apiEpoch = 1;
  }
  async message(ws, a, p) {
    if (p.type === "hello") {
      await this.hello(ws, a, p);
      return;
    }
    if (p.type === "proof") {
      await this.proof(ws, a, p);
      return;
    }
    if (!a.user) throw Error("Authenticate first");
    if (a.build !== VERSION) throw Error("Update and restart Ancient Nest to use this matchmaking version");
    if (p.type === "ping") {
      this.send(ws, { type: "pong" });
      return;
    }
    if (p.type.startsWith("party_")) {
      try {
        await this.partyMessage(ws, a, p);
      } catch (error) {
        this.send(ws, { type: "party_error", reason: error instanceof Error ? error.message : "Party action failed" });
      }
      return;
    }
    const r = this.rooms[a.room || ""];
    if (!r || !r.roster[a.user]) return;
    r.seen[a.user] = now();
    if (p.type === "heartbeat") {
      const capacity = p.host_capacity;
      if (capacity && Number.isFinite(capacity.cpu_p95_ms) && capacity.cpu_p95_ms >= 0 && capacity.cpu_p95_ms <= 1e3 && Number.isInteger(capacity.logical_cpus) && capacity.logical_cpus >= 1 && capacity.logical_cpus <= 1024 && Number.isInteger(capacity.samples) && capacity.samples >= 15 && capacity.samples <= 180) {
        r.config.host_capacity ??= {};
        r.config.host_capacity[a.user] = capacity;
      }
      if (p.epoch === r.epoch && a.user === r.authority && ["running", "results"].includes(r.phase)) {
        r.host_seen = now();
        if (p.live && Array.isArray(p.live.scores) && p.live.scores.length === 2 && p.live.scores.every((n) => Number.isFinite(n) && n >= 0 && n <= 1e6) && Number.isFinite(p.live.elapsed) && p.live.elapsed >= 0 && p.live.elapsed <= 10800) r.live = { scores: p.live.scores, elapsed: p.live.elapsed, updated_at: now() };
        await this.emit(r, {
          type: "authority_lease",
          grant: await this.ticket(r, "authority", r.authority, 4)
        });
      }
      return;
    }
    if (p.type === "rtc_signal") {
      if (p.epoch !== r.epoch || !r.roster[p.target] || p.target === a.user || p.round !== r.rtcRound)
        return;
      if (!["probe", "game"].includes(p.purpose) || !["sdp", "ice"].includes(p.kind) || typeof p.data !== "object" || JSON.stringify(p.data).length > 2e4)
        return;
      if (p.purpose === "probe" && !["probing", "voting"].includes(r.phase))
        return;
      if (p.purpose === "game" && !(a.user === r.authority || p.target === r.authority))
        return;
      await this.emit(
        r,
        {
          type: "rtc_signal",
          sender: a.user,
          round: r.rtcRound,
          purpose: p.purpose,
          kind: p.kind,
          data: p.data
        },
        p.target
      );
      return;
    }
    if (p.type === "telemetry" && r.phase === "probing" && p.epoch === r.epoch && p.round === r.rtcRound && r.targets.includes(a.user) && !r.reports[a.user]) {
      if (!p.routes || typeof p.routes !== "object" || Object.keys(p.routes).length > 10)
        return;
      const clean = {};
      for (const [who, raw] of Object.entries(p.routes)) {
        const value = raw;
        if (!r.roster[who] || who === a.user || !value || typeof value !== "object" || !Array.isArray(value.rtts) || value.rtts.length > 50 || value.rtts.some(
          (v) => typeof v !== "number" || !Number.isFinite(v) || v < 0 || v > 5e3
        ) || !Number.isInteger(value.bytes) || value.bytes < 0 || value.bytes > 5e5 || typeof value.seconds !== "number" || !Number.isFinite(value.seconds) || value.seconds < 0.1 || value.seconds > 5)
          return;
        clean[who] = {
          rtts: value.rtts,
          bytes: value.bytes,
          seconds: value.seconds
        };
      }
      const hw = p.host_capacity;
      if (hw && Number.isFinite(hw.cpu_p95_ms) && Number.isInteger(hw.logical_cpus) && Number.isInteger(hw.samples)) {
        r.config.host_capacity ??= {};
        r.config.host_capacity[a.user] = { cpu_p95_ms: hw.cpu_p95_ms, logical_cpus: hw.logical_cpus, samples: hw.samples };
      } else if (this.env.LOCAL_TEST !== "true") {
        await this.fail(r, "Client hosting-capacity measurement missing. Update the game.");
        return;
      }
      r.reports[a.user] = clean;
      await this.elect(r);
      return;
    }
    if (p.type === "vote" && r.phase === "voting" && p.stage === r.config.vote_stage) {
      const valid = r.config.vote_stage === "life" ? [1, 2].includes(p.life) : modesForPlaylist(r.playlist).includes(p.mode) && [0, 1, 2, 3, 4, 5].includes(p.map);
      if (valid) {
        r.votes[a.user] = { mode: p.mode, map: p.map, life: p.life };
        await this.publishVote(r);
      }
      return;
    }
    if (p.epoch !== r.epoch) return;
    if (p.type === "host_ready" && r.phase === "offered" && a.user === r.authority) {
      r.phase = "connecting";
      r.deadline = now() + 45;
      for (const who of r.targets) await this.connect(r, who);
      return;
    }
    if (p.type === "host_failed" && a.user === r.authority) {
      r.phase = "probing";
      await this.probe(r);
      return;
    }
    if (p.type === "loaded") {
      if (p.rejoin && r.phase === "running") {
        if (!r.targets.includes(a.user)) r.targets.push(a.user);
        await this.emit(
          r,
          {
            type: "authority_lease",
            grant: await this.ticket(r, "authority", r.authority, 4)
          },
          a.user
        );
        await this.emit(r, {
          type: "resume",
          members: r.targets,
          bots: Object.keys(r.roster).filter((who) => !r.targets.includes(who))
        });
        return;
      }
      if (r.phase !== "connecting" || !r.targets.includes(a.user) || r.migration && p.digest !== r.checkpoint?.digest)
        return;
      if (!r.ready.includes(a.user)) r.ready.push(a.user);
      if (r.targets.every((who) => r.ready.includes(who))) {
        await this.registerResultMatch(r);
        if (r.registered && r.apiEpoch !== r.epoch) {
          await this.apiJob(r, "migrate", {
            match_id: r.id,
            previous_epoch: r.apiEpoch,
            authority_id: r.authority
          });
          r.apiEpoch = (r.apiEpoch || 1) + 1;
        }
        await this.resume(r);
      }
      return;
    }
    if (p.type === "unhealthy" && r.phase === "running") {
      const key = "unhealthy:" + a.user;
      r.seen[key] = now();
      if (Object.keys(r.roster).filter(
        (who) => now() - (r.seen["unhealthy:" + who] || 0) < 6
      ).length > Object.keys(r.roster).length / 2)
        await this.migrate(r);
      return;
    }
    if (p.type === "checkpoint" && r.phase === "running" && a.user === r.authority) {
      if (!Number.isInteger(p.tick) || p.tick < 0 || p.tick <= (r.checkpoint?.tick ?? -1) || typeof p.state !== "string" || p.state.length > 14e5 || r.pending.length >= 3)
        return;
      const bytes = unb64(p.state), digest = await hash(bytes);
      if (bytes.length > 1048576) return;
      const blob = `blob:${r.id}:${r.epoch}:${p.tick}:${digest}`;
      if (r.pending.some((v) => v.digest === digest)) return;
      await this.saveBlob(blob, p.state);
      r.pending.push({ tick: p.tick, digest, acks: [a.user], at: now(), blob });
      await this.emit(r, {
        type: "checkpoint_offer",
        tick: p.tick,
        digest,
        state: p.state
      });
      return;
    }
    if (p.type === "checkpoint_ack" && r.phase === "running") {
      const pending = r.pending.find(
        (v) => v.tick === p.tick && v.digest === p.digest && now() - v.at <= 20
      );
      if (!pending || !r.targets.includes(a.user)) return;
      if (!pending.acks.includes(a.user)) pending.acks.push(a.user);
      if (pending.acks.length > Object.keys(r.roster).length / 2) {
        if (r.checkpoint && r.checkpoint.blob !== pending.blob)
          await this.deleteBlob(r.checkpoint.blob);
        r.checkpoint = pending;
        r.checkpoint.at = now();
        for (const stale of r.pending.filter(
          (v) => v.tick <= pending.tick && v.blob !== pending.blob
        ))
          await this.deleteBlob(stale.blob);
        r.pending = r.pending.filter((v) => v.tick > pending.tick);
        await this.emit(r, {
          type: "checkpoint_committed",
          tick: pending.tick,
          digest: pending.digest
        });
      }
      return;
    }
    if (p.type === "complete" && a.user === r.authority && r.phase === "running") {
      r.phase = "results";
      r.deadline = now() + 45;
      return;
    }
    if (p.type === "result_report" && r.phase === "results") {
      if (!Array.isArray(p.players) || p.players.length !== Object.keys(r.roster).length)
        return;
      const rows = [];
      for (const row of p.players) {
        const m = r.roster[row.player];
        if (!m || !m.account || [
          "kills",
          "deaths",
          "assists",
          "flags_captured",
          "flags_stopped"
        ].some(
          (k) => !Number.isInteger(row[k]) || row[k] < 0 || row[k] > 1e4
        ))
          return;
        rows.push({
          account_id: m.account,
          kills: row.kills,
          deaths: row.deaths,
          assists: row.assists,
          flags_captured: row.flags_captured,
          flags_stopped: row.flags_stopped
        });
      }
      rows.sort((a2, b) => a2.account_id.localeCompare(b.account_id));
      if (new Set(rows.map((v) => v.account_id)).size !== rows.length || ![null, 0, 1].includes(p.winner_team))
        return;
      const report = { winner_team: p.winner_team, players: rows }, digest = await hash(JSON.stringify(report));
      r.results ??= {};
      r.results[a.user] = { digest, report };
      const agreed = Object.keys(r.results).filter(
        (who) => r.results[who].digest === digest
      ), teams = new Set(agreed.map((who) => r.roster[who].faction));
      if (r.results[r.authority]?.digest === digest && agreed.length > Object.keys(r.roster).length / 2 && (r.config.mode === 1 || teams.size === 2) && r.registered && !r.config.resultQueued) {
        await this.apiJob(r, "result", {
          match_id: r.id,
          epoch: r.apiEpoch,
          authority_id: r.authority,
          ...report
        });
        r.config.resultQueued = true;
      }
      return;
    }
  }
  alarm() {
    return this.run(async () => {
      for (const ws of this.ctx.getWebSockets()) {
        const a = ws.deserializeAttachment();
        if (now() - a.seen > (a.user ? 30 : 15))
          ws.close(1001, "Heartbeat timeout");
      }
      for (const r of Object.values(this.rooms)) {
        this.dirty.add(r.id);
        for (const old of r.pending.filter((p) => now() - p.at > 20))
          await this.deleteBlob(old.blob);
        r.pending = r.pending.filter((p) => now() - p.at <= 20);
        if (r.phase === "probing" && now() > r.deadline)
          await this.elect(r, true);
        else if (r.phase === "voting" && now() > r.deadline) {
          if (Object.keys(r.roster).some((who) => !this.info(who)))
            await this.fail(r, "A player left before voting completed");
          else await this.finishVote(r);
        } else if (["offered", "connecting"].includes(r.phase) && now() > r.deadline) {
          if (r.migration && r.ready.length > Object.keys(r.roster).length / 2) {
            r.targets = [...r.ready];
            await this.resume(r);
            continue;
          }
          r.epoch++;
          await this.emit(r, { type: "freeze", reason: "connection_timeout" });
          r.phase = "probing";
          await this.probe(r);
        } else if (r.phase === "running" && now() - r.host_seen > 3.5)
          await this.migrate(r);
        else if (r.phase === "results" && now() > r.deadline) {
          r.phase = "complete";
          r.deadline = now() + 60;
          if (!r.config.resultQueued) {
            await this.apiJob(r, "review", { match_id: r.id, reason: "missing_or_conflicting_reports", reports: Object.entries(r.results || {}).map(([who, v]) => ({ account: r.roster[who]?.account, digest: v.digest, winner_team: v.report.winner_team })), sample_report: Object.values(r.results || {})[0]?.report, absent: Object.keys(r.roster).filter((who) => !this.info(who)).map((who) => r.roster[who].account) });
            await this.emit(r, { type: "result_status", status: "pending_review", message: "Result needs review. No unverified rank points were awarded." });
            await this.apiJob(r, "void", { match_id: r.id });
          }
          await this.emit(r, { type: "return_queue" });
          for (const who of Object.keys(r.roster)) {
            const ws = this.sockets().get(who);
            if (ws) {
              const a = ws.deserializeAttachment();
              delete a.room;
              ws.serializeAttachment(a);
              if (!a.lobbyOnly && !this.queue.includes(who)) this.queue.push(who);
            }
          }
          for (const party of Object.values(this.parties)) {
            if (party.members.some((who) => !!r.roster[who])) {
              party.searching = false;
              party.members = party.members.filter((who) => !!this.info(who));
              if (!party.members.length) {
                delete this.parties[party.id];
                continue;
              }
              if (!party.members.includes(party.leader)) party.leader = party.members[0];
              await this.publishParty(party);
            }
          }
          await this.form();
          await this.queueState();
        }
        if (now() - r.born > 10800 && !["complete", "failed"].includes(r.phase))
          await this.fail(r, "Match session expired");
        await this.flushJobs(r);
        if (["complete", "failed"].includes(r.phase) && now() > r.deadline && !r.jobs?.length) {
          for (const pending of [
            ...r.pending,
            ...r.checkpoint ? [r.checkpoint] : []
          ])
            await this.deleteBlob(pending.blob);
          delete this.rooms[r.id];
          await this.ctx.storage.delete("room:" + r.id);
        }
      }
      await this.persist();
    });
  }
};
export {
  Matchmaker,
  worker_default as default
};
