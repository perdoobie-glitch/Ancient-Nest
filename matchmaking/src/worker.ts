import {snapshot,monitorAuthorized} from "./monitor";
import {
  PLAYLISTS,
  VERSION,
  majority,
  modesForPlaylist,
  rankHosts,
  partyMatch,
  b64,
  unb64,
  hash,
  publicKey,
  supportedIceServers,
  type Playlist,
  type Reports,
} from "./core";
interface Env {
  TEAM_VOICE?: string;
  LOCAL_TEST?: string;
  LOCAL_ICE_JSON?: string;
  RELAY_ONLY?: string;
  MATCHMAKER: DurableObjectNamespace;
  ACCOUNT_API?: string;
  ALLOW_GUESTS?: string;
  VOTE_SECONDS?: string;
  TURN_KEY_ID?: string;
  TURN_KEY_API_TOKEN?: string;
  COORDINATOR_API_KEY?: string;
  MONITOR_TOKEN?: string;
}
type Json = Record<string, any>;
type Member = {
  slot: number;
  name: string;
  faction: number;
  rating: { human: number; practice: number };
  public_key: string;
  account?: string;
};
type Pending = {
  tick: number;
  digest: string;
  acks: string[];
  at: number;
  blob: string;
};
type Room = {
  id: string;
  playlist: Playlist;
  roster: Record<string, Member>;
  targets: string[];
  phase: string;
  epoch: number;
  authority: string;
  deadline: number;
  seen: Record<string, number>;
  host_seen: number;
  reports: Reports;
  tried: string[];
  votes: Record<string, Json>;
  config: Json;
  ready: string[];
  migration: boolean;
  checkpoint?: Pending;
  pending: Pending[];
  born: number;
  iceServers: Json[];
  rtcRound: string;
  voice?: { expires: number; active: boolean; ended: boolean; next: number; attempts: number };
  registered?: boolean;
  apiEpoch?: number;
  results?: Record<string, Json>;
  live?: Json;
  monitorStarted?: boolean;
  monitorRecorded?: boolean;
  jobs?: { path: string; body: Json; attempts: number; next?: number }[];
};
type Party = { id: string; leader: string; members: string[]; playlist: Playlist; searching: boolean };
type Attachment = {
  build?: string;
  party?: string;
  lobbyOnly?: boolean;
  nonce: string;
  user?: string;
  public_key?: string;
  name?: string;
  playlist?: Playlist;
  rating?: number;
  ratings?: Record<string,number>;
  account?: string;
  room?: string;
  seen: number;
  messages?: number;
  window?: number;
};
const now = () => Date.now() / 1000;
const origin = (s: string) => {
  const u = new URL(s);
  if (
    u.protocol !== "https:" &&
    !["localhost", "127.0.0.1"].includes(u.hostname)
  )
    throw Error("HTTPS account service required");
  if (u.pathname !== "/" || u.username || u.password || u.search || u.hash)
    throw Error("Invalid account origin");
  return u.origin;
};
export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if(url.pathname==="/api/monitor") {
      if(req.method!=="GET")return new Response("Method not allowed",{status:405,headers:{Allow:"GET"}});
      if(!env.MONITOR_TOKEN||env.MONITOR_TOKEN.length<32)return Response.json({error:"Monitor access not configured"},{status:503,headers:{"Cache-Control":"no-store"}});
      if(!await monitorAuthorized(req,env.MONITOR_TOKEN))return Response.json({error:"Unauthorized"},{status:401,headers:{"Cache-Control":"no-store"}});
      return env.MATCHMAKER.get(env.MATCHMAKER.idFromName("global-v1")).fetch(req);
    }
    if (url.pathname === "/ready") {
      if(req.method!=="GET")return new Response("Method not allowed",{status:405,headers:{Allow:"GET"}});
      try{return await env.MATCHMAKER.get(env.MATCHMAKER.idFromName("global-v1")).fetch(req);}
      catch{return Response.json({service:"ancient-nest-matchmaking",release:"10.5-dev",ready:false,error:"Matchmaker initialization failed"},{status:503,headers:{"Cache-Control":"no-store"}});}
    }
    if (url.pathname === "/health")
      return Response.json({
        service: "ancient-nest-matchmaking",
        release: "10.5-dev",
        version: VERSION,
        hosting: "player_hosted",
      });
    if (
      url.pathname !== "/v1/matchmaking" ||
      req.headers.get("Upgrade")?.toLowerCase() !== "websocket"
    )
      return new Response("Use WebSocket /v1/matchmaking", { status: 404 });
    return env.MATCHMAKER.get(env.MATCHMAKER.idFromName("global-v1")).fetch(
      req,
    );
  },
};
export class Matchmaker {
  private rooms: Record<string, Room> = {};
  private queue: string[] = [];
  private parties: Record<string, Party> = {};
  private key!: CryptoKey;
  private pem = "";
  private serial: Promise<unknown> = Promise.resolve();
  private dirty = new Set<string>();
  private jobsInFlight = new Set<string>();
  private voiceInFlight = new Set<string>();
  private telemetry:Json={started:0,finished:0,failed:0,history:[]};
  private telemetrySaved="";
  private reviewCache:{at:number;data:Json}={at:0,data:{available:false}};
  private reviewLoading:Promise<void>|null=null;
  private queueSaved = "";
  private partySaved = "";
  constructor(
    private ctx: DurableObjectState,
    private env: Env,
  ) {
    ctx.blockConcurrencyWhile(async () => {
      let stored = await ctx.storage.get<Json>("identity");
      if (!stored) {
        const keys = (await crypto.subtle.generateKey(
          {
            name: "RSASSA-PKCS1-v1_5",
            modulusLength: 2048,
            publicExponent: new Uint8Array([1, 0, 1]),
            hash: "SHA-256",
          },
          true,
          ["sign", "verify"],
        )) as CryptoKeyPair;
        stored = {
          private: b64(
            (await crypto.subtle.exportKey(
              "pkcs8",
              keys.privateKey,
            )) as ArrayBuffer,
          ),
          public: b64(
            (await crypto.subtle.exportKey(
              "spki",
              keys.publicKey,
            )) as ArrayBuffer,
          ),
        };
        await ctx.storage.put("identity", stored);
      }
      this.key = await crypto.subtle.importKey(
        "pkcs8",
        unb64(stored.private),
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"],
      );
      this.pem =
        "-----BEGIN PUBLIC KEY-----\n" +
        stored.public.match(/.{1,64}/g).join("\n") +
        "\n-----END PUBLIC KEY-----\n";
      this.rooms = Object.fromEntries(
        [...(await ctx.storage.list<Room>({ prefix: "room:" }))].map(
          ([k, v]) => [k.slice(5), v],
        ),
      );
      this.queue = (await ctx.storage.get<string[]>("queue")) || [];
      this.queueSaved = JSON.stringify(this.queue);
      this.parties = (await ctx.storage.get<Record<string, Party>>("parties")) || {};
      this.partySaved=JSON.stringify(this.parties);
      this.telemetry=(await ctx.storage.get<Json>("monitor-telemetry"))||this.telemetry;
      this.telemetrySaved=JSON.stringify(this.telemetry);
    });
  }
  private run(job: () => Promise<void>): Promise<void> {
    const task = this.serial.then(job);
    this.serial = task.catch(() => {});
    return task;
  }
  async fetch(_req: Request): Promise<Response> {
    if(new URL(_req.url).pathname==="/ready") {
      const initialized=!!(await this.ctx.storage.get("identity"))&&!!this.key;
      return Response.json({service:"ancient-nest-matchmaking",release:"10.5-dev",version:VERSION,ready:initialized,checks:{coordinator:initialized,auth_mode:this.env.ALLOW_GUESTS==="true"?"guest":"accounts",account_bridge_configured:!!this.env.ACCOUNT_API&&!!this.env.COORDINATOR_API_KEY,turn_configured:!!this.env.TURN_KEY_ID&&!!this.env.TURN_KEY_API_TOKEN,monitor_configured:!!this.env.MONITOR_TOKEN&&this.env.MONITOR_TOKEN.length>=32}},{status:initialized?200:503,headers:{"Cache-Control":"no-store","X-Content-Type-Options":"nosniff"}});
    }
    if(new URL(_req.url).pathname==="/api/monitor") {
      if(!await monitorAuthorized(_req,this.env.MONITOR_TOKEN))return new Response("Unauthorized",{status:401});
      let result:Json={};await this.run(async()=>{
        const users=[...this.sockets().values()].map(ws=>ws.deserializeAttachment() as Attachment).filter(a=>!!a.user).map(a=>({...a,queued:this.queue.includes(a.user!)}));
        result=snapshot(Object.values(this.rooms),users,Object.values(this.parties),this.telemetry.history,{started:this.telemetry.started,finished:this.telemetry.finished,failed:this.telemetry.failed},now(),{turn_configured:!!this.env.TURN_KEY_ID&&!!this.env.TURN_KEY_API_TOKEN,accounts_configured:!!this.env.ACCOUNT_API&&!!this.env.COORDINATOR_API_KEY,guest_mode:this.env.ALLOW_GUESTS==="true",max_control_sockets:512,max_active_rooms:64});
      });
      await this.refreshReviewSummary();result.ranking_review=this.reviewCache.data;
      return Response.json(result,{headers:{"Cache-Control":"no-store","X-Content-Type-Options":"nosniff"}});
    }
    if (this.ctx.getWebSockets().length >= 512)
      return new Response("Matchmaking capacity reached", { status: 503 });
    const pair = new WebSocketPair(),
      client = pair[0],
      server = pair[1];
    this.ctx.acceptWebSocket(server);
    if ((await this.ctx.storage.getAlarm()) === null)
      await this.ctx.storage.setAlarm(Date.now() + 15000);
    server.serializeAttachment({
      nonce: crypto.randomUUID(),
      seen: now(),
    } satisfies Attachment);
    return new Response(null, { status: 101, webSocket: client });
  }
  webSocketMessage(
    ws: WebSocket,
    message: string | ArrayBuffer,
  ): Promise<void> {
    // Authenticated keep-alives are deliberately independent of slow login,
    // rating-read and TURN requests. They never change queue/party membership.
    if(typeof message==="string" && message.length<=1500000){
      try{
        const packet=JSON.parse(message),attachment:Attachment=ws.deserializeAttachment();
        if((packet?.type==="ping"||packet?.type==="heartbeat") && attachment?.user && attachment.build===VERSION)
          return this.keepAlive(ws,attachment,packet,message.length);
      }catch{/* The serialized validator below returns the normal rejection. */}
    }
    return this.run(async () => {
      try {
        if (typeof message !== "string" || message.length > 1500000)
          throw Error("Message too large");
        const a: Attachment = ws.deserializeAttachment(),
          time = now();
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
        const updated: Attachment = ws.deserializeAttachment();
        if (
          updated.room &&
          !["ping", "heartbeat", "rtc_signal"].includes(p.type)
        )
          this.dirty.add(updated.room);
        await this.persist();
      } catch (error) {
        if(this.env.LOCAL_TEST==="true")console.log("QA_REQUEST_REJECT",error instanceof Error?error.message:"Invalid request");
        this.send(ws, {
          type: "failed",
          reason: error instanceof Error ? error.message : "Invalid request",
        });
        ws.close(1008, "Request rejected");
      }
    });
  }
  private async keepAlive(ws:WebSocket,a:Attachment,p:Json,size:number):Promise<void>{
    try{
      if(size>8192)throw Error("Keep-alive too large");
      const time=now();
      if(!a.window || time-a.window>5){a.window=time;a.messages=0;}
      if((a.messages=(a.messages||0)+1)>400)throw Error("Rate limit");
      a.seen=time;ws.serializeAttachment(a);
      // The message handler still checks the authenticated identity, protocol,
      // authority, room and epoch. Room state persists on the normal alarm.
      await this.message(ws,a,p);
    }catch(error){this.send(ws,{type:"failed",reason:error instanceof Error?error.message:"Invalid keep-alive"});ws.close(1008,"Request rejected");}
  }
  webSocketClose(ws: WebSocket): Promise<void> {
    return this.run(async () => {
      const a: Attachment = ws.deserializeAttachment();
      if (a?.nonce) await this.ctx.storage.delete("login:" + a.nonce);
      if (a?.user) {
        if(!a.room)await this.removePartyMember(a.user);
        this.queue = this.queue.filter((p) => p !== a.user);
        await this.queueState();
      }
      await this.persist();
    });
  }
  webSocketError(ws: WebSocket): Promise<void> {
    return this.webSocketClose(ws);
  }
  private sockets(): Map<string, WebSocket> {
    const values = new Map<string, WebSocket>();
    for (const ws of this.ctx.getWebSockets()) {
      const a: Attachment = ws.deserializeAttachment();
      if (a?.user) values.set(a.user, ws);
    }
    return values;
  }
  private info(user: string): Attachment | undefined {
    return this.sockets().get(user)?.deserializeAttachment();
  }
  private send(ws: WebSocket | undefined, value: Json): void {
    try {
      ws?.send(JSON.stringify({ ...value, server_time: now() }));
    } catch {}
  }
  private async emit(r: Room, value: Json, user?: string): Promise<void> {
    const sockets = this.sockets(),
      event = {
        match: r.id,
        epoch: r.epoch,
        roster: r.roster,
        config: r.config,
        targets: r.targets,
        transport: "webrtc",
        ice_policy: this.env.RELAY_ONLY === "true" ? "relay" : "all",
        ...value,
      };
    for (const who of user ? [user] : Object.keys(r.roster))
      this.send(sockets.get(who), event);
  }
  private async persist(): Promise<void> {
    const reservedUsers=new Set(Object.values(this.rooms).filter(r=>!["complete","failed"].includes(r.phase)).flatMap(r=>Object.keys(r.roster)));
    for(const party of Object.values(this.parties)){
      party.members=party.members.filter(u=>this.info(u)?.party===party.id || reservedUsers.has(u));
      if(!party.members.length){delete this.parties[party.id];continue;}
      if(!party.members.includes(party.leader))party.leader=party.members[0];
    }

    for(const r of Object.values(this.rooms)) {
      if(!r.monitorStarted && ["running","results","complete"].includes(r.phase)){r.monitorStarted=true;this.telemetry.started++;this.dirty.add(r.id);}
      if(!r.monitorRecorded && ["complete","failed"].includes(r.phase)){
        r.monitorRecorded=true;this.telemetry[r.phase==="complete"?"finished":"failed"]++;this.dirty.add(r.id);
        this.telemetry.history.push({id:r.id,playlist:r.playlist,mode:r.config.mode,map:r.config.map,result:r.phase,ended_at:now(),duration_seconds:Math.max(0,Math.floor(now()-r.born)),players:Object.keys(r.roster).length});
        this.telemetry.history=this.telemetry.history.slice(-100);
      }
    }
    const telemetry=JSON.stringify(this.telemetry);
    if(telemetry!==this.telemetrySaved){await this.ctx.storage.put("monitor-telemetry",this.telemetry);this.telemetrySaved=telemetry;}

    const parties=JSON.stringify(this.parties);
    if(parties!==this.partySaved){await this.ctx.storage.put("parties",this.parties);this.partySaved=parties;}
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
    if (
      this.queue.length ||
      Object.keys(this.rooms).length ||
      this.ctx.getWebSockets().length
    ) {
      const due = Date.now() + 1000,
        alarm = await this.ctx.storage.getAlarm();
      if (alarm === null || alarm > due) await this.ctx.storage.setAlarm(due);
    }
  }
  private async saveBlob(key: string, text: string): Promise<void> {
    for (let i = 0; i < text.length; i += 60000)
      await this.ctx.storage.put(
        `${key}:${i / 60000}`,
        text.slice(i, i + 60000),
      );
    await this.ctx.storage.put(key + ":length", text.length);
  }
  private async blob(key: string): Promise<string> {
    const length = (await this.ctx.storage.get<number>(key + ":length")) || 0;
    let text = "";
    for (let i = 0; i < length; i += 60000)
      text += (await this.ctx.storage.get<string>(`${key}:${i / 60000}`)) || "";
    return text;
  }
  private async deleteBlob(key: string): Promise<void> {
    const keys = [
      ...(await this.ctx.storage.list({ prefix: key + ":" })).keys(),
    ];
    if (keys.length) await this.ctx.storage.delete(keys);
  }
  private async ticket(
    r: Room,
    kind: string,
    subject: string,
    ttl: number,
    extra: Json = {},
  ): Promise<string> {
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
        extra,
      }),
    );
    return (
      b64(raw) +
      "." +
      b64(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", this.key, raw))
    );
  }
  private async hello(ws: WebSocket, a: Attachment, p: Json): Promise<void> {
    if (
      a.user ||
      p.version !== VERSION ||
      typeof p.playlist !== "string" ||
      !Object.hasOwn(PLAYLISTS, p.playlist)
    )
      throw Error("Use matching game version and a valid playlist");
    const key = await publicKey(p.public_key);
    if (
      Number((key.algorithm as { modulusLength?: number }).modulusLength) < 2048
    )
      throw Error("RSA key is too small");
    a.build=VERSION;
    a.public_key = p.public_key;
    a.lobbyOnly = p.lobby_only === true;
    a.name =
      String(p.name || "Player")
        .replace(/[^A-Za-z0-9_ -]/g, "")
        .slice(0, 20) || "Player";
    a.playlist = p.playlist as Playlist;
    // Challenge binds the authenticated WebSocket session to the game's private key.
    a.nonce = crypto.randomUUID();
    if (
      (typeof p.account_assertion !== "string" &&
        p.account_assertion !== undefined) ||
      String(p.account_assertion || "").length > 8192
    )
      throw Error("Invalid account assertion");
    await this.ctx.storage.put("login:" + a.nonce, {
      account_assertion: p.account_assertion || "",
    });
    ws.serializeAttachment(a);
    this.send(ws, { type: "challenge", nonce: a.nonce });
  }
  private async proof(ws: WebSocket, a: Attachment, p: Json): Promise<void> {
    const pending = await this.ctx.storage.get<Json>("login:" + a.nonce);
    if (!pending || !a.public_key || a.user) throw Error("No pending sign-in");
    const valid = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      await publicKey(a.public_key),
      unb64(p.signature),
      new TextEncoder().encode(a.nonce),
    );
    if (!valid) throw Error("Game identity proof rejected");
    const key_hash = await hash(a.public_key);
    a.user = key_hash.slice(0, 32);
    a.rating = 1;
    if (pending.account_assertion && this.env.ACCOUNT_API) {
      const base = origin(this.env.ACCOUNT_API),
        body = JSON.stringify({
          assertion: pending.account_assertion,
          key_hash,
        });
      const res = await fetch(base + "/api/game/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
        redirect: "manual",
        signal: AbortSignal.timeout(5000),
      });
      const account = (await res.json()) as Json;
      if (
        !res.ok ||
        account.valid !== true ||
        account.key_hash !== key_hash ||
        typeof account.account_id !== "string" ||
        !/^[a-f0-9-]{36}$/.test(account.account_id)
      )
        throw Error("Account verification failed");
      a.account = account.account_id;
      a.user = "account:" + a.account;
      a.name = account.username;
      const profile = await fetch(base + "/api/game/profile", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
        redirect: "manual",
        signal: AbortSignal.timeout(5000),
      });
      if (profile.ok) {
        const stats = (await profile.json()) as Json;
        a.ratings = Object.fromEntries(Object.keys(PLAYLISTS).map(key => [key, Math.max(1, Number(stats.playlists?.[key]?.elo) || 1)]));
        a.rating = a.ratings.duel_1v1;
      }
    } else if (this.env.ALLOW_GUESTS !== "true")
      throw Error("Link your Ancient Nest account before matchmaking");
    if (this.sockets().has(a.user)) throw Error("Identity already connected");
    await this.ctx.storage.delete("login:" + a.nonce);
    const reserved = Object.values(this.rooms).find(
      (r) => r.config.build===VERSION && r.roster[a.user!] && !["complete", "failed"].includes(r.phase),
    );
    if (reserved) {
      a.party=Object.values(this.parties).find(p=>p.members.includes(a.user!))?.id;
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
      transport: "webrtc",
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
  private async queueState(): Promise<void> {
    for (const [id, list] of Object.entries(PLAYLISTS)) {
      const people = this.queue.filter(
        (user) => this.info(user)?.playlist === id,
      );
      const members = Object.fromEntries(
        people.slice(0, list.size).map((user, i) => [
          i + 2,
          {
            name: this.info(user)?.name,
            faction: 0,
            rating: { human: this.info(user)?.rating || 0, practice: 0 },
          },
        ]),
      );
      for (const who of people)
        this.send(this.sockets().get(who), {
          type: "queue",
          playlist: id,
          capacity: list.size,
          members,
          connected: Math.min(people.length, list.size),
          status: people.length>=list.size ? "Waiting for compatible team sizes. Parties stay together." : "Finding players for your playlist…",
        });
    }
  }
  private async createParty(ws:WebSocket,a:Attachment):Promise<void> {
    let id:string;do{id=crypto.randomUUID().replaceAll("-","").slice(0,10).toUpperCase();}while(this.parties[id]);
    const party:Party={id,leader:a.user!,members:[a.user!],playlist:a.playlist!,searching:false};
    this.parties[id]=party;a.party=id;ws.serializeAttachment(a);await this.publishParty(party);
  }
  private async publishParty(party:Party):Promise<void>{
    const sockets=this.sockets();
    const members=party.members.map(user=>({user,name:this.info(user)?.name||"Player",leader:user===party.leader,rating:this.info(user)?.rating||0}));
    for(const user of party.members)this.send(sockets.get(user),{type:"party",code:party.id,leader:party.leader,members,playlist:party.playlist,searching:party.searching,team_size:PLAYLISTS[party.playlist].size/2});
  }
  private async cancelParty(party:Party):Promise<void>{
    party.searching=false;this.queue=this.queue.filter(p=>!party.members.includes(p));
    await this.publishParty(party);await this.queueState();
  }
  private async removePartyMember(user:string):Promise<void>{
    const party=Object.values(this.parties).find(p=>p.members.includes(user));if(!party)return;
    party.searching=false;this.queue=this.queue.filter(p=>!party.members.includes(p));party.members=party.members.filter(p=>p!==user);
    if(!party.members.length){delete this.parties[party.id];await this.queueState();return;}
    if(party.leader===user)party.leader=party.members[0];await this.publishParty(party);await this.queueState();
  }
  private async partyMessage(ws:WebSocket,a:Attachment,p:Json):Promise<void>{
    if(a.room)throw Error("Party changes are unavailable during a match");
    let party=this.parties[a.party||""];
    if(!party){await this.createParty(ws,a);party=this.parties[a.party!];}
    if(p.type==="party_sync"){await this.publishParty(party);return;}
    if(p.type==="party_join"){
      const code=String(p.code||"").trim().toUpperCase();const target=this.parties[code];
      if(!target)throw Error("Invite code not found. Ask your friend for a new code.");
      if(target===party)return;
      if(party.searching||target.searching)throw Error("Cancel search before changing parties");
      if(target.members.some(u=>!!this.info(u)?.room))throw Error("This party is already in a match");
      if(target.members.length>=PLAYLISTS[target.playlist].size/2)throw Error("Party is full for this playlist");
      await this.removePartyMember(a.user!);target.members.push(a.user!);a.party=code;a.playlist=target.playlist;ws.serializeAttachment(a);await this.publishParty(target);return;
    }
    if(p.type==="party_leave"){
      await this.removePartyMember(a.user!);delete a.party;ws.serializeAttachment(a);await this.createParty(ws,a);return;
    }
    if(party.leader!==a.user)throw Error("Only the party leader can choose a playlist or search");
    if(p.type==="party_playlist"){
      if(party.searching)throw Error("Cancel search before changing playlist");
      if(typeof p.playlist!=="string"||!Object.hasOwn(PLAYLISTS,p.playlist))throw Error("Invalid playlist");
      const playlist=p.playlist as Playlist;
      if(party.members.length>PLAYLISTS[playlist].size/2)throw Error("Choose a playlist with enough team slots for your party");
      party.playlist=playlist;
      for(const u of party.members){const sock=this.sockets().get(u);if(sock){const info:Attachment=sock.deserializeAttachment();info.playlist=playlist;sock.serializeAttachment(info);}}
      await this.publishParty(party);return;
    }
    if(p.type==="party_cancel"){await this.cancelParty(party);return;}
    if(p.type==="party_search"){
      if(party.searching)return;
      if(party.members.length>PLAYLISTS[party.playlist].size/2)throw Error("Party exceeds this playlist's team size");
      if(!party.members.every(u=>!!this.info(u)&&!this.info(u)?.room))throw Error("Wait for every party member to connect");
      const membersBefore=JSON.stringify(party.members),playlistBefore=party.playlist;
      await this.refreshRatings([...party.members]);
      if(this.parties[party.id]!==party||JSON.stringify(party.members)!==membersBefore||party.playlist!==playlistBefore||party.searching||!party.members.every(u=>!!this.info(u)&&!this.info(u)?.room))throw Error("Party changed while refreshing ratings. Search again.");
      party.searching=true;
      for(const u of party.members)if(!this.queue.includes(u))this.queue.push(u);
      await this.publishParty(party);await this.form();await this.queueState();return;
    }
    throw Error("Unknown party action");
  }
  private ratingFor(user:string,playlist:Playlist):number {
    return this.info(user)?.ratings?.[playlist] ?? 1;
  }
  private async refreshReviewSummary():Promise<void>{
    if(!this.env.ACCOUNT_API||!this.env.COORDINATOR_API_KEY){this.reviewCache={at:now(),data:{available:false,reason:'accounts_not_configured'}};return;}
    if(now()-this.reviewCache.at<30)return;
    if(this.reviewLoading)return this.reviewLoading;
    this.reviewLoading=(async()=>{
      try{
        const response=await fetch(origin(this.env.ACCOUNT_API!)+"/api/internal/reviews",{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+this.env.COORDINATOR_API_KEY},body:'{}',redirect:'manual',signal:AbortSignal.timeout(1500)});
        const value=await response.json() as Json;
        this.reviewCache={at:now(),data:response.ok&&Array.isArray(value.reviews)?{available:true,...value}:{available:false,reason:'review_service_unavailable'}};
      }catch{this.reviewCache={at:now(),data:{available:false,reason:'review_service_unavailable'}};}
    })();
    try{await this.reviewLoading;}finally{this.reviewLoading=null;}
  }
  private async refreshRatings(users:string[]):Promise<void> {
    const accounts=users.map(user=>this.info(user)?.account).filter((id):id is string=>!!id);
    if(!accounts.length)return; // Local development guests have no competitive record.
    if(!this.env.ACCOUNT_API||!this.env.COORDINATOR_API_KEY)throw Error("Playlist rating service is not configured");
    const response=await fetch(origin(this.env.ACCOUNT_API)+"/api/internal/players/ratings",{
      method:"POST",headers:{"Content-Type":"application/json",Authorization:"Bearer "+this.env.COORDINATOR_API_KEY},
      body:JSON.stringify({account_ids:accounts}),redirect:"manual",signal:AbortSignal.timeout(5000)
    });
    if(!response.ok)throw Error("Cannot refresh playlist ratings. Please retry search.");
    const data=await response.json() as Json;
    for(const user of users){
      const socket=this.sockets().get(user);if(!socket)throw Error("Party member disconnected");
      const a:Attachment=socket.deserializeAttachment();if(!a.account)continue;
      const values=data.ratings?.[a.account];
      if(!values||Object.keys(PLAYLISTS).some(key=>!Number.isSafeInteger(values[key])||values[key]<1))throw Error("Invalid playlist rating response");
      a.ratings=values;socket.serializeAttachment(a);
    }
  }
  private async ice(): Promise<Json[]> {
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
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ ttl: 14400 }),
        redirect: "manual",
        signal: AbortSignal.timeout(5000),
      },
    );
    if (!res.ok) throw Error("TURN credential service unavailable");
    const value = (await res.json()) as Json;
    if (!Array.isArray(value.iceServers)) throw Error("Invalid TURN response");
    return supportedIceServers(value.iceServers);
  }
  private async form(): Promise<void> {
    this.queue = this.queue.filter((p) => this.info(p)?.build===VERSION);
    for (const first of [...this.queue]) {
      const list = this.info(first)?.playlist;
      if (!list) continue;
      const spec = PLAYLISTS[list];
      const eligible=this.queue.filter(p=>this.info(p)?.playlist===list);
      const grouped=new Set<string>();const groups:string[][]=[];
      for(const p of eligible){
        if(grouped.has(p))continue;
        const party=this.parties[this.info(p)?.party||""];
        const group=party?party.members:[p];
        if(party && (!party.searching || !group.every(id=>eligible.includes(id))))continue;
        group.forEach(id=>grouped.add(id));groups.push(group);
      }
      const ratings=Object.fromEntries(eligible.map(p=>[p,this.ratingFor(p,list)]));
      const selection=partyMatch(groups,ratings,spec.size);
      if(!selection)continue;
      const {people,team}=selection;
      if (
        Object.keys(this.rooms).length >= 256 ||
        Object.values(this.rooms).filter(
          (r) => !["complete", "failed"].includes(r.phase),
        ).length >= 64
      )
        break;
      this.queue = this.queue.filter((p) => !people.includes(p));
      people.sort();
      const roster: Record<string, Member> = {};
      for (const [i, who] of people.entries()) {
        const a = this.info(who)!;
        roster[who] = {
          slot: i + 2,
          name: a.name!,
          faction: team.has(who) ? 0 : 1,
          rating: { human: this.ratingFor(who,list), practice: 0 },
          public_key: a.public_key!,
          account: a.account,
        };
      }
      const id = crypto.randomUUID(),
        r: Room = {
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
            capacity: spec.size,
          },
          ready: [],
          migration: false,
          pending: [],
          born: now(),
          iceServers: await this.ice(),
          rtcRound: crypto.randomUUID(),
        };
      this.rooms[id] = r;
      this.dirty.add(id);
      for (const who of people) {
        const ws = this.sockets().get(who)!,
          a: Attachment = ws.deserializeAttachment();
        a.room = id;
        ws.serializeAttachment(a);
      }
      await this.probe(r);
    }
  }
  private async probe(r: Room): Promise<void> {
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
      reason: r.migration ? "host_migration" : "peer_host_selection",
    });
  }
  private async elect(r: Room, finished = false): Promise<void> {
    if (!finished && !r.targets.every((p) => r.reports[p])) return;
    if (r.migration) {
      r.targets = r.targets.filter((who) => now() - r.seen[who] < 6);
      if (r.targets.length <= Object.keys(r.roster).length / 2) {
        await this.fail(r, "Not enough connected original players to migrate");
        return;
      }
    }
    const ranked = rankHosts(r.targets, r.reports,r.config.host_capacity||{}).filter(
      (p) => !r.tried.includes(p) && now() - r.seen[p] < 6,
    );
    if (!ranked.length) {
      if (this.env.LOCAL_TEST === "true")
        console.log("QA_ELECTION_REJECT", JSON.stringify({reports:r.reports,capacity:r.config.host_capacity}));
      await this.fail(
        r,
        rankHosts(r.targets,r.reports).length
          ? "No available player has enough observed CPU headroom to host. Close background programs or choose a stronger host."
          : "No player has a stable route with enough upload to every opponent. Check TURN relay credentials or try another network.",
      );
      return;
    }
    r.config.host_order=ranked;
    r.authority = ranked[0];
    r.reports = {};
    if (!r.migration && !r.config.voted) {
      r.phase = "voting";
      r.config.vote_stage = "setup";
      r.deadline = now() + this.voteSeconds();
      await this.publishVote(r);
    } else await this.offer(r);
  }
  private voteSeconds(): number {
    return Math.max(1, Math.min(60, Number(this.env.VOTE_SECONDS) || 25));
  }
  private async publishVote(r: Room): Promise<void> {
    await this.emit(r, {
      type: "voting",
      stage: r.config.vote_stage,
      capacity: Object.keys(r.roster).length,
      playlist: r.playlist,
      votes: r.votes,
      seconds: Math.max(0, r.deadline - now()),
      host_name: r.roster[r.authority]?.name,
      allowed_modes: modesForPlaylist(r.playlist),
    });
  }
  private async finishVote(r: Room): Promise<void> {
    const values = Object.values(r.votes),
      size = Object.keys(r.roster).length;
    if (r.config.vote_stage === "setup") {
      r.config.mode = majority(
        values.map((v) => v.mode),
        modesForPlaylist(r.playlist),
        size,
      );
      r.config.map = majority(
        values.map((v) => v.map),
        [0, 1, 2, 3, 4, 5],
        size,
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
        size,
      );
    delete r.config.vote_stage;
    r.config.voted = true;
    await this.offer(r);
  }
  private async offer(r: Room): Promise<void> {
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
        round: r.rtcRound,
      },
      r.authority,
    );
  }
  private async connect(r: Room, user: string, rejoin = false): Promise<void> {
    const endpoint = { host: "webrtc", port: 1, relay: false },
      checkpoint = r.checkpoint?.digest || null;
    await this.emit(
      r,
      {
        type: "connect",
        authority: r.authority,
        mode: "peer",
        grant: await this.ticket(r, "join", user, 45, {
          endpoint,
          checkpoint,
          client_public_key: r.roster[user].public_key,
        }),
        checkpoint,
        state: r.checkpoint ? await this.blob(r.checkpoint.blob) : "",
        rejoin,
        ice_servers: r.iceServers,
        round: r.rtcRound,
      },
      user,
    );
  }
  private async resume(r: Room): Promise<void> {
    r.phase = "running";
    r.host_seen = now();
    await this.emit(r, {
      type: "authority_lease",
      grant: await this.ticket(r, "authority", r.authority, 4),
    });
    await this.emit(r, {
      type: "resume",
      members: r.targets,
      bots: Object.keys(r.roster).filter((p) => !r.targets.includes(p)),
    });
  }
  private async migrate(r: Room): Promise<void> {
    const old = r.authority;
    r.epoch++;
    r.phase = "probing";
    r.migration = true;
    r.ready = [];
    r.tried = [old];
    r.targets = Object.keys(r.roster).filter(
      (p) => p !== old && now() - r.seen[p] < 6,
    );
    await this.emit(r, {
      type: "freeze",
      reason: "host_migration",
      checkpoint: r.checkpoint?.digest,
    });
    if (
      !r.checkpoint ||
      now() - r.checkpoint.at > 20 ||
      r.targets.length <= Object.keys(r.roster).length / 2
    ) {
      await this.fail(
        r,
        "Cannot safely migrate without a fresh checkpoint and majority of original players",
      );
      return;
    }
    const backup=(r.config.host_order||[]).find((who:string)=>r.targets.includes(who)&&!r.tried.includes(who)&&(!r.config.host_capacity?.[who]||r.config.host_capacity[who].cpu_p95_ms<=12));
    if(backup){r.authority=backup;await this.offer(r);}
    else await this.probe(r);
  }
  private async fail(r: Room, reason: string): Promise<void> {
    r.phase = "failed";
    r.deadline = now() + 30;
    await this.emit(r, { type: "failed", reason });
    if(r.registered&&r.monitorStarted)await this.apiJob(r,"review",{match_id:r.id,reason:"abandoned_or_interrupted",absent:Object.keys(r.roster).filter(who=>!this.info(who)).map(who=>r.roster[who].account),reports:Object.entries(r.results||{}).map(([who,v])=>({account:r.roster[who]?.account,digest:v.digest,winner_team:v.report.winner_team})),sample_report:Object.values(r.results||{})[0]?.report});
    await this.apiJob(r, "void", { match_id: r.id });
    for(const who of Object.keys(r.roster)) {
      const ws=this.sockets().get(who);if(!ws)continue;
      const a:Attachment=ws.deserializeAttachment();delete a.room;ws.serializeAttachment(a);
      const party=this.parties[a.party||""];if(party)party.searching=false;
    }
  }
  private async apiJob(r: Room, action: string, body: Json): Promise<void> {
    if (
      !this.env.COORDINATOR_API_KEY ||
      !this.env.ACCOUNT_API ||
      (["void","review"].includes(action) && !r.registered)
    )
      return;
    r.jobs ??= [];
    r.jobs.push({ path: "/api/internal/matches/" + action, body, attempts: 0 });
  }
  private async flushJobs(r: Room): Promise<void> {
    const job=r.jobs?.[0];
    if(!job || (job.next||0)>now() || this.jobsInFlight.has(r.id) || !this.env.COORDINATOR_API_KEY || !this.env.ACCOUNT_API)return;
    // Upstream account latency must never hold the serialized heartbeat/lease loop.
    // One outstanding request per room preserves register -> migrate -> result ordering.
    this.jobsInFlight.add(r.id);
    this.ctx.waitUntil(this.deliverJob(r.id,job));
  }
  private async deliverJob(roomId:string,job:NonNullable<Room["jobs"]>[number]):Promise<void>{
    let delivered=false;
    try{
      const res=await fetch(origin(this.env.ACCOUNT_API!)+job.path,{
        method:"POST",headers:{"Content-Type":"application/json",Authorization:"Bearer "+this.env.COORDINATOR_API_KEY},
        body:JSON.stringify(job.body),redirect:"manual",signal:AbortSignal.timeout(4000)
      });
      delivered=res.ok;
    }catch{/* Persist a bounded retry below; no rank award is inferred from a timeout. */}
    await this.run(async()=>{
      try{
        const current=this.rooms[roomId];
        if(!current || current.jobs?.[0]!==job)return;
        if(delivered){
          current.jobs.shift();
          if(job.path.endsWith('/result'))await this.emit(current,{type:'result_status',status:'recorded',message:'Match result recorded by the account server.'});
        }else{job.attempts++;job.next=now()+Math.min(300,2**Math.min(9,job.attempts));}
        this.dirty.add(roomId);await this.persist();
      }finally{this.jobsInFlight.delete(roomId);}
    });
  }
  private syncVoice(r: Room): void {
    if(this.env.TEAM_VOICE!=="true" || !this.env.ACCOUNT_API || !this.env.COORDINATOR_API_KEY || this.voiceInFlight.has(r.id))return;
    if(!r.voice && r.phase==="running" && r.config.mode!==1 && Object.values(r.roster).every(m=>!!m.account))
      r.voice={expires:Math.floor(r.born+10800),active:false,ended:false,next:0,attempts:0};
    const voice=r.voice;
    if(!voice || voice.ended || voice.next>now())return;
    const ending=["results","complete","failed"].includes(r.phase) || voice.expires<=now();
    if(voice.active && !ending)return;
    this.voiceInFlight.add(r.id);
    this.ctx.waitUntil(this.deliverVoice(r.id,ending));
  }
  private async deliverVoice(roomId:string,ending:boolean):Promise<void>{
    const room=this.rooms[roomId];
    if(!room?.voice){this.voiceInFlight.delete(roomId);return;}
    let delivered=false;
    try{
      const response=await fetch(origin(this.env.ACCOUNT_API!)+"/internal/voice/matches"+(ending?"/"+roomId:""),{
        method:ending?"DELETE":"POST",redirect:"manual",signal:AbortSignal.timeout(4000),
        headers:{"Content-Type":"application/json","X-Coordinator-Key":this.env.COORDINATOR_API_KEY!},
        ...(ending?{}:{body:JSON.stringify({match_id:roomId,expires_at:room.voice.expires,
          teams:[0,1].map(team=>({team_id:String(team),player_ids:Object.values(room.roster).filter(m=>m.faction===team).map(m=>m.account)}))})})
      });
      delivered=response.ok;
    }catch{/* Retried independently of simulation, heartbeat and ranking jobs. */}
    await this.run(async()=>{
      try{
        const current=this.rooms[roomId];if(!current?.voice)return;
        if(delivered){current.voice.active=!ending;current.voice.ended=ending;current.voice.attempts=0;current.voice.next=0;}
        else{current.voice.attempts++;current.voice.next=now()+Math.min(300,2**Math.min(8,current.voice.attempts));}
        this.dirty.add(roomId);await this.persist();
      }finally{this.voiceInFlight.delete(roomId);}
    });
  }
  private async registerResultMatch(r: Room): Promise<void> {
    if (
      r.registered ||
      !this.env.COORDINATOR_API_KEY ||
      !this.env.ACCOUNT_API ||
      Object.values(r.roster).some((p) => !p.account)
    )
      return;
    const modes = [
      "extraction",
      "free_for_all",
      "team_deathmatch",
      "capture_the_flag",
      "bomb_defuse",
    ];
    const sorted = Object.values(r.roster).sort((a, b) =>
      a.account!.localeCompare(b.account!),
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
        team: r.config.mode === 1 ? i : m.faction,
      })),
    });
    r.registered = true;
    r.apiEpoch = 1;
  }
  private async message(ws: WebSocket, a: Attachment, p: Json): Promise<void> {
    if (p.type === "hello") {
      await this.hello(ws, a, p);
      return;
    }
    if (p.type === "proof") {
      await this.proof(ws, a, p);
      return;
    }
    if (!a.user) throw Error("Authenticate first");
    if(a.build!==VERSION)throw Error("Update and restart Ancient Nest to use this matchmaking version");
    if (p.type === "ping") {
      this.send(ws, { type: "pong" });
      return;
    }
    if(p.type.startsWith("party_")) {
      try { await this.partyMessage(ws,a,p); }
      catch(error) { this.send(ws,{type:"party_error",reason:error instanceof Error?error.message:"Party action failed"}); }
      return;
    }
    const r = this.rooms[a.room || ""];
    if (!r || !r.roster[a.user]) return;
    r.seen[a.user] = now();
    if (p.type === "heartbeat") {
      const capacity=p.host_capacity;
      if(capacity&&Number.isFinite(capacity.cpu_p95_ms)&&capacity.cpu_p95_ms>=0&&capacity.cpu_p95_ms<=1000&&Number.isInteger(capacity.logical_cpus)&&capacity.logical_cpus>=1&&capacity.logical_cpus<=1024&&Number.isInteger(capacity.samples)&&capacity.samples>=15&&capacity.samples<=180){r.config.host_capacity??={};r.config.host_capacity[a.user]=capacity;}

      if (
        p.epoch === r.epoch &&
        a.user === r.authority &&
        ["running", "results"].includes(r.phase)
      ) {
        r.host_seen = now();
        if(p.live && Array.isArray(p.live.scores) && p.live.scores.length===2 && p.live.scores.every((n:any)=>Number.isFinite(n)&&n>=0&&n<=1000000) && Number.isFinite(p.live.elapsed)&&p.live.elapsed>=0&&p.live.elapsed<=10800)r.live={scores:p.live.scores,elapsed:p.live.elapsed,updated_at:now()};
        await this.emit(r, {
          type: "authority_lease",
          grant: await this.ticket(r, "authority", r.authority, 4),
        });
      }
      return;
    }
    if (p.type === "rtc_signal") {
      if (
        p.epoch !== r.epoch ||
        !r.roster[p.target] ||
        p.target === a.user ||
        p.round !== r.rtcRound
      )
        return;
      if (
        !["probe", "game"].includes(p.purpose) ||
        !["sdp", "ice"].includes(p.kind) ||
        typeof p.data !== "object" ||
        JSON.stringify(p.data).length > 20000
      )
        return;
      if (p.purpose === "probe" && !["probing", "voting"].includes(r.phase))
        return;
      if (
        p.purpose === "game" &&
        !(a.user === r.authority || p.target === r.authority)
      )
        return;
      await this.emit(
        r,
        {
          type: "rtc_signal",
          sender: a.user,
          round: r.rtcRound,
          purpose: p.purpose,
          kind: p.kind,
          data: p.data,
        },
        p.target,
      );
      return;
    }
    if (
      p.type === "telemetry" &&
      r.phase === "probing" &&
      p.epoch === r.epoch &&
      p.round === r.rtcRound &&
      r.targets.includes(a.user) &&
      !r.reports[a.user]
    ) {
      if (
        !p.routes ||
        typeof p.routes !== "object" ||
        Object.keys(p.routes).length > 10
      )
        return;
      const clean: Record<string, any> = {};
      for (const [who, raw] of Object.entries(p.routes)) {
        const value = raw as Json;
        if (
          !r.roster[who] ||
          who === a.user ||
          !value ||
          typeof value !== "object" ||
          !Array.isArray(value.rtts) ||
          value.rtts.length > 50 ||
          value.rtts.some(
            (v: unknown) =>
              typeof v !== "number" || !Number.isFinite(v) || v < 0 || v > 5000,
          ) ||
          !Number.isInteger(value.bytes) ||
          value.bytes < 0 ||
          value.bytes > 500000 ||
          typeof value.seconds !== "number" ||
          !Number.isFinite(value.seconds) ||
          value.seconds < 0.1 ||
          value.seconds > 5
        )
          return;
        clean[who] = {
          rtts: value.rtts,
          bytes: value.bytes,
          seconds: value.seconds,
        };
      }
      const hw=p.host_capacity;
      if(hw&&Number.isFinite(hw.cpu_p95_ms)&&Number.isInteger(hw.logical_cpus)&&Number.isInteger(hw.samples)){
        r.config.host_capacity??={};r.config.host_capacity[a.user]={cpu_p95_ms:hw.cpu_p95_ms,logical_cpus:hw.logical_cpus,samples:hw.samples};
      }else if(this.env.LOCAL_TEST!=="true"){await this.fail(r,"Client hosting-capacity measurement missing. Update the game.");return;}
      r.reports[a.user] = clean;
      await this.elect(r);
      return;
    }
    if (
      p.type === "vote" &&
      r.phase === "voting" &&
      p.stage === r.config.vote_stage
    ) {
      const valid =
        r.config.vote_stage === "life"
          ? [1, 2].includes(p.life)
          : modesForPlaylist(r.playlist).includes(p.mode) && [0, 1, 2, 3, 4, 5].includes(p.map);
      if (valid) {
        r.votes[a.user] = { mode: p.mode, map: p.map, life: p.life };
        await this.publishVote(r);
      }
      return;
    }
    if (p.epoch !== r.epoch) return;
    if (
      p.type === "host_ready" &&
      r.phase === "offered" &&
      a.user === r.authority
    ) {
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
            grant: await this.ticket(r, "authority", r.authority, 4),
          },
          a.user,
        );
        await this.emit(r, {
          type: "resume",
          members: r.targets,
          bots: Object.keys(r.roster).filter((who) => !r.targets.includes(who)),
        });
        return;
      }
      if (
        r.phase !== "connecting" ||
        !r.targets.includes(a.user) ||
        (r.migration && p.digest !== r.checkpoint?.digest)
      )
        return;
      if (!r.ready.includes(a.user)) r.ready.push(a.user);
      if (r.targets.every((who) => r.ready.includes(who))) {
        await this.registerResultMatch(r);
        if (r.registered && r.apiEpoch !== r.epoch) {
          await this.apiJob(r, "migrate", {
            match_id: r.id,
            previous_epoch: r.apiEpoch,
            authority_id: r.authority,
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
      if (
        Object.keys(r.roster).filter(
          (who) => now() - (r.seen["unhealthy:" + who] || 0) < 6,
        ).length >
        Object.keys(r.roster).length / 2
      )
        await this.migrate(r);
      return;
    }
    if (
      p.type === "checkpoint" &&
      r.phase === "running" &&
      a.user === r.authority
    ) {
      if (
        !Number.isInteger(p.tick) ||
        p.tick < 0 ||
        p.tick <= (r.checkpoint?.tick ?? -1) ||
        typeof p.state !== "string" ||
        p.state.length > 1400000 ||
        r.pending.length >= 3
      )
        return;
      const bytes = unb64(p.state),
        digest = await hash(bytes);
      if (bytes.length > 1048576) return;
      const blob = `blob:${r.id}:${r.epoch}:${p.tick}:${digest}`;
      if (r.pending.some((v) => v.digest === digest)) return;
      await this.saveBlob(blob, p.state);
      r.pending.push({ tick: p.tick, digest, acks: [a.user], at: now(), blob });
      await this.emit(r, {
        type: "checkpoint_offer",
        tick: p.tick,
        digest,
        state: p.state,
      });
      return;
    }
    if (p.type === "checkpoint_ack" && r.phase === "running") {
      const pending = r.pending.find(
        (v) => v.tick === p.tick && v.digest === p.digest && now() - v.at <= 20,
      );
      if (!pending || !r.targets.includes(a.user)) return;
      if (!pending.acks.includes(a.user)) pending.acks.push(a.user);
      if (pending.acks.length > Object.keys(r.roster).length / 2) {
        if (r.checkpoint && r.checkpoint.blob !== pending.blob)
          await this.deleteBlob(r.checkpoint.blob);
        r.checkpoint = pending;
        r.checkpoint.at = now();
        for (const stale of r.pending.filter(
          (v) => v.tick <= pending.tick && v.blob !== pending.blob,
        ))
          await this.deleteBlob(stale.blob);
        r.pending = r.pending.filter((v) => v.tick > pending.tick);
        await this.emit(r, {
          type: "checkpoint_committed",
          tick: pending.tick,
          digest: pending.digest,
        });
      }
      return;
    }
    if (
      p.type === "complete" &&
      a.user === r.authority &&
      r.phase === "running"
    ) {
      r.phase = "results";
      r.deadline = now() + 45;
      return;
    }
    if (p.type === "result_report" && r.phase === "results") {
      if (
        !Array.isArray(p.players) ||
        p.players.length !== Object.keys(r.roster).length
      )
        return;
      const rows: Json[] = [];
      for (const row of p.players) {
        const m = r.roster[row.player];
        if (
          !m ||
          !m.account ||
          [
            "kills",
            "deaths",
            "assists",
            "flags_captured",
            "flags_stopped",
          ].some(
            (k) => !Number.isInteger(row[k]) || row[k] < 0 || row[k] > 10000,
          )
        )
          return;
        rows.push({
          account_id: m.account,
          kills: row.kills,
          deaths: row.deaths,
          assists: row.assists,
          flags_captured: row.flags_captured,
          flags_stopped: row.flags_stopped,
        });
      }
      rows.sort((a, b) => a.account_id.localeCompare(b.account_id));
      if (
        new Set(rows.map((v) => v.account_id)).size !== rows.length ||
        ![null, 0, 1].includes(p.winner_team)
      )
        return;
      const report = { winner_team: p.winner_team, players: rows },
        digest = await hash(JSON.stringify(report));
      r.results ??= {};
      r.results[a.user] = { digest, report };
      const agreed = Object.keys(r.results).filter(
          (who) => r.results![who].digest === digest,
        ),
        teams = new Set(agreed.map((who) => r.roster[who].faction));
      if (
        r.results[r.authority]?.digest === digest &&
        agreed.length > Object.keys(r.roster).length / 2 &&
        (r.config.mode === 1 || teams.size === 2) &&
        r.registered &&
        !r.config.resultQueued
      ) {
        await this.apiJob(r, "result", {
          match_id: r.id,
          epoch: r.apiEpoch,
          authority_id: r.authority,
          ...report,
        });
        r.config.resultQueued = true;
      }
      return;
    }
  }
  alarm(): Promise<void> {
    return this.run(async () => {
      for (const ws of this.ctx.getWebSockets()) {
        const a: Attachment = ws.deserializeAttachment();
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
        } else if (
          ["offered", "connecting"].includes(r.phase) &&
          now() > r.deadline
        ) {
          if (
            r.migration &&
            r.ready.length > Object.keys(r.roster).length / 2
          ) {
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
          if (!r.config.resultQueued){
            await this.apiJob(r,"review",{match_id:r.id,reason:"missing_or_conflicting_reports",reports:Object.entries(r.results||{}).map(([who,v])=>({account:r.roster[who]?.account,digest:v.digest,winner_team:v.report.winner_team})),sample_report:Object.values(r.results||{})[0]?.report,absent:Object.keys(r.roster).filter(who=>!this.info(who)).map(who=>r.roster[who].account)});
            await this.emit(r,{type:"result_status",status:"pending_review",message:"Result needs review. No unverified rank points were awarded."});
            await this.apiJob(r, "void", { match_id: r.id });
          }
          await this.emit(r, { type: "return_queue" });
          for (const who of Object.keys(r.roster)) {
            const ws = this.sockets().get(who);
            if (ws) {
              const a: Attachment = ws.deserializeAttachment();
              delete a.room;
              ws.serializeAttachment(a);
              if (!a.lobbyOnly && !this.queue.includes(who)) this.queue.push(who);
            }
          }
          for(const party of Object.values(this.parties)) {
            if(party.members.some(who=>!!r.roster[who])) {
              party.searching=false;party.members=party.members.filter(who=>!!this.info(who));
              if(!party.members.length){delete this.parties[party.id];continue;}
              if(!party.members.includes(party.leader))party.leader=party.members[0];
              await this.publishParty(party);
            }
          }
          await this.form();
          await this.queueState();
        }
        if (now() - r.born > 10800 && !["complete", "failed"].includes(r.phase))
          await this.fail(r, "Match session expired");
        await this.flushJobs(r);
        this.syncVoice(r);
        if (
          ["complete", "failed"].includes(r.phase) &&
          now() > r.deadline &&
          !r.jobs?.length && (!r.voice || r.voice.ended)
        ) {
          for (const pending of [
            ...r.pending,
            ...(r.checkpoint ? [r.checkpoint] : []),
          ])
            await this.deleteBlob(pending.blob);
          delete this.rooms[r.id];
          await this.ctx.storage.delete("room:" + r.id);
        }
      }
      await this.persist();
    });
  }
}
