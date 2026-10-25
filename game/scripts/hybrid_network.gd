class_name NestHybridNetwork
extends Node
## WSS master control; native WebRTC gameplay, with the legacy ENet path retained.
var master_authenticated=false
var master_last_reply=-1.0
var cloud=false
var rtc=NestCloudPeer.new()
var result_report_at=0.0
var game
var mm
var enabled=false
var worker=false
var ws=WebSocketPeer.new()
var session=NestHybridSession.new()
var identity: CryptoKey
var certificate: X509Certificate
var player_id=""
var worker_token=""
var hub_url=""
var udp=PacketPeerUDP.new()
var udp_port=0
var udp_host=""
var reflector_port=8081
var cookie=""
var probe_key=""
var probe_endpoints={}
var probe_started=0.0
var probe_sent=false
var probe_reported=false
var probe_round=-1
var probe_records={}
var probe_epoch=0
var probe_seen={}
var reflector_ip=""
var resolve_request=-1
var legacy_refresh_at=0.0
var probe_nonces={}
var observed={}
var heartbeat_at=0.0
var hello_sent=false
var control_deadline=0.0
var server_offset=0.0
var current_event={}
var roster={}
var authenticated={}
var challenges={}
var consumed={}
var admission_until={}
var game_grant=""
var staged=false
var rejoining=false
var checkpoint_at=0.0
var checkpoint_tick=0
var checkpoint_data=PackedByteArray()
var checkpoint_digest=""
var cert_key: CryptoKey
var listen_port=0
var authority=false
var failure_reason=""
var completion_sent=false
var account_preflight=false
var cpu_samples: Array[float]=[]
var scheduler
var continuity
var queue_fallback
var pending_results
var control_metrics={"messages_received":0,"messages_sent":0,"handler_us_sum":0,"handler_us_max":0,"text_bytes_sent":0}
var film_transport_until=0.0
var film_drain_at=0.0
func _ready() -> void:
 name="HybridNetwork";add_child(session);rtc.bridge=self;add_child(rtc)
 session.freeze_simulation.connect(freeze_game)
 session.start_authority.connect(start_host)
 session.handoff_requested.connect(handoff)
 session.resume_simulation.connect(resume_game)
 session.return_to_queue.connect(fail)
 session.report_unhealthy.connect(func(_epoch):send({"type":"unhealthy","epoch":session.epoch}))
 scheduler=load("res://scripts/master_scheduler.gd").new();scheduler.hub=self;add_child(scheduler)
 continuity=load("res://scripts/authority_continuity.gd").new();continuity.hub=self;continuity.name="AuthorityContinuity";add_child(continuity)
 queue_fallback=load("res://scripts/queue_fallback.gd").new();queue_fallback.hub=self;add_child(queue_fallback)
 pending_results=load("res://scripts/pending_results.gd").new();pending_results.hub=self;add_child(pending_results)
func clock() -> float:return Time.get_ticks_msec()/1000.0
func server_time() -> float:return clock()+server_offset
func sha(bytes: PackedByteArray) -> PackedByteArray:
 var h=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish()
func send(message: Dictionary) -> void:
 if message.get("type","") not in ["hello","proof","ping","result_report"] and not str(message.get("type","")).begins_with("party_") and not session.match_id.is_empty():message["match"]=session.match_id
 if message.get("type","")=="hello" and scheduler.reconnecting and game.running and not session.match_id.is_empty():message["control_resume"]={"match":session.match_id,"epoch":session.epoch}
 if ws.get_ready_state()==WebSocketPeer.STATE_OPEN:
  var text=JSON.stringify(message);control_metrics.messages_sent+=1;control_metrics.text_bytes_sent+=text.to_utf8_buffer().size();ws.send_text(text)
func load_identity() -> void:
 identity=CryptoKey.new()
 if not FileAccess.file_exists("user://hybrid_identity.key") or identity.load("user://hybrid_identity.key")!=OK:
  identity=Crypto.new().generate_rsa(2048);identity.save("user://hybrid_identity.key")
static func valid_hub_url(url: String) -> bool:
 if url.begins_with("wss://"):return true
 if not url.begins_with("ws://"):return false
 var netloc=url.trim_prefix("ws://").get_slice("/",0).get_slice("?",0).get_slice("#",0)
 if netloc.contains("@"):return false
 return netloc.get_slice(":",0) in ["localhost","127.0.0.1"]
func master_connected() -> bool:
 return enabled and master_authenticated and ws.get_ready_state()==WebSocketPeer.STATE_OPEN and clock()-master_last_reply<float(NestControlPolicy.settings().socket_keepalive_seconds)+float(NestControlPolicy.settings().request_timeout_seconds)
func master_status() -> String:
 if not enabled or not failure_reason.is_empty():return "MASTER SERVER · DISCONNECTED"
 if not master_authenticated:return "MASTER SERVER · CONNECTING"
 if not master_connected():return "MASTER SERVER · CONNECTION INTERRUPTED"
 return "MASTER SERVER · CONNECTED"
func connect_hub(url: String,as_worker: bool=false,token: String="",port: int=0) -> Error:
 if not valid_hub_url(url):
  mm.status="Use a secure wss:// hub URL (plain WS is permitted only on loopback).";mm.phase="error";return ERR_INVALID_PARAMETER
 if enabled:leave()
 current_event={}
 session.epoch=0;session.lease_until=0;session.pending_resume=false;session.authority="";session.match_id="";authenticated.clear();consumed.clear();roster.clear();checkpoint_data=PackedByteArray();checkpoint_digest="";checkpoint_tick=0
 cloud=false;rtc.stop();load_identity();worker=as_worker;worker_token=token;listen_port=port;enabled=true;mm.active=true;mm.dedicated=worker;mm.phase="connecting";hub_url=url;game.lobby_kind="matchmaking"
 master_authenticated=false;master_last_reply=-1.0
 hello_sent=false;account_preflight=false;control_deadline=clock()+float(NestControlPolicy.settings().request_timeout_seconds);failure_reason="";staged=false;session.frozen=true;scheduler.reset()
 if worker:
  authority=true
  var error=open_listener(listen_port)
  if error!=OK:fail("Unable to open worker UDP listener");return error
 ws=WebSocketPeer.new();ws.inbound_buffer_size=2097152;ws.outbound_buffer_size=2097152;ws.max_queued_packets=512
 var error=ws.connect_to_url(url)
 if error!=OK:fail("Unable to open matchmaking control connection");return error
 mm.status="Connecting to hybrid matchmaking hub…";mm.changed();return error
func leave(abandon: bool=false) -> void:
 if resolve_request>=0:IP.erase_resolve_item(resolve_request);resolve_request=-1
 scheduler.reset();scheduler.retry_at=0
 if abandon and master_connected():send({"type":"leave_match"});ws.poll()
 master_authenticated=false;master_last_reply=-1.0
 close_game_transport() # A departing player-host must not broadcast end_network_match.
 rtc.stop();enabled=false;ws.close();udp.close();session.frozen=true;authority=false;game.multiplayer.auth_callback=Callable();game.multiplayer.auth_timeout=3
func _process(_delta: float) -> void:
 cpu_samples.append(1000.0*(Performance.get_monitor(Performance.TIME_PROCESS)+Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)))
 if cpu_samples.size()>180:cpu_samples.pop_front()
 if not enabled:return
 if game.film_retaining_transport:
  if game.film_recorder.transfer.pending_work():film_drain_at=0
  elif film_drain_at<=0:film_drain_at=clock()+2
  if clock()>=film_transport_until or (film_drain_at>0 and clock()>=film_drain_at):release_film_transport("Perspective collection finished or timed out")
 if control_deadline>0 and clock()>control_deadline:
  control_deadline=0;scheduler.lost();ws.close(4000,"Control request timeout");return
 ws.poll()
 if resolve_request>=0 and IP.get_resolve_item_status(resolve_request) in [IP.RESOLVER_STATUS_DONE,IP.RESOLVER_STATUS_ERROR]:
  if IP.get_resolve_item_status(resolve_request)==IP.RESOLVER_STATUS_DONE:reflector_ip=IP.get_resolve_item_address(resolve_request)
  IP.erase_resolve_item(resolve_request);resolve_request=-1
 if not cloud and not authority and not cookie.is_empty() and not reflector_ip.is_empty() and clock()>=legacy_refresh_at:
  legacy_refresh_at=clock()+float(NestControlPolicy.settings().socket_keepalive_seconds)
  for index in range(2):
   var nonce=Crypto.new().generate_random_bytes(12).hex_encode()
   var signature=Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256,sha((cookie+nonce+str(index)).to_utf8_buffer()),identity))
   udp_send(reflector_ip,reflector_port+index,{"type":"hello","cookie":cookie,"nonce":nonce,"signature":signature})
 if ws.get_ready_state()==WebSocketPeer.STATE_OPEN:
  if not worker and not hello_sent and game.get("accounts")!=null and game.accounts.linked() and not account_preflight:
   account_preflight=true
   account_handshake()
   return
  if not worker and not hello_sent and game.get("accounts")!=null and game.accounts.linked() and account_preflight:return
  if not hello_sent:
   hello_sent=true
   if worker:send({"type":"worker","token":worker_token,"public_key":identity.save_to_string(true),"certificate":"" if cloud else certificate.save_to_string()})
   else:send({"type":"hello","lobby_only":mm.party_mode,"resume":mm.resume_reserved_match,"playlist":mm.playlist,"name":game.current_username(),"version":game.NETWORK_VERSION,"public_key":identity.save_to_string(true),"rating":game.ranked.profile.summary(),"local_ips":IP.get_local_addresses(),"account_assertion":game.accounts.account_assertion if game.get("accounts")!=null else ""})
  var parsed=0
  while ws.get_available_packet_count()>0 and parsed<8:
   parsed+=1
   var packet=ws.get_packet()
   if packet.size()>1500000:continue
   var raw=packet.get_string_from_utf8()
   if raw=="nest-pong":master_last_reply=clock();continue
   var value=JSON.parse_string(raw)
   if value is Dictionary:control(value)
 elif ws.get_ready_state()==WebSocketPeer.STATE_CLOSED and hello_sent:
  while ws.get_available_packet_count()>0:
   var pending=JSON.parse_string(ws.get_packet().get_string_from_utf8())
   if pending is Dictionary:control(pending)
  if failure_reason.is_empty():scheduler.lost(ws.get_close_code() in [1008,4001,4003])
 if authority:
  for peer in admission_until.keys():
   if clock()>admission_until[peer]:
    admission_until.erase(peer)
    if game.network_active and peer in game.multiplayer.get_peers():game.multiplayer.multiplayer_peer.disconnect_peer(peer)
 if not cloud and not authority:poll_probes()
 if cloud and game.running and game.finished and clock()>=result_report_at:
  result_report_at=clock()+1;send_result_report()
 if authority and master_connected() and not session.frozen and game.running and game.finished and not completion_sent:
  completion_sent=true;send({"type":"complete","epoch":session.epoch})
 if authority and not session.frozen and game.running and clock()>=checkpoint_at:
  checkpoint_at=clock()+2;checkpoint_tick+=1
  checkpoint_data=NestMigrationState.pack(game)
  if checkpoint_data.size()<=1048576:send({"type":"checkpoint","epoch":session.epoch,"tick":checkpoint_tick,"state":Marshalls.raw_to_base64(checkpoint_data)})
func control(e: Dictionary) -> void:
 var started=Time.get_ticks_usec();handle_control(e)
 var elapsed=Time.get_ticks_usec()-started
 control_metrics.messages_received+=1;control_metrics.handler_us_sum+=elapsed;control_metrics.handler_us_max=maxi(int(control_metrics.handler_us_max),elapsed)
func handle_control(e: Dictionary) -> void:
 var kind=str(e.get("type",""))
 if game.film_retaining_transport and kind in ["collect_telemetry","voting","host_offer","connect"]:release_film_transport("A new match started before every perspective was available")
 master_last_reply=clock()
 if kind=="failed" and not e.has("epoch"):
  scheduler.lost(true);ws.close();return
 if e.has("server_time"):server_offset=float(e.server_time)-clock()
 match kind:
  "challenge":send({"type":"proof","signature":Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256,sha(str(e.nonce).to_utf8_buffer()),identity))})
  "hello":
   mm.resume_reserved_match=true
   master_authenticated=true;master_last_reply=clock()
   control_deadline=0
   cloud=e.get("transport","")=="webrtc"
   if e.get("playlist","") in NestMatchmaking.PLAYLIST_IDS:mm.playlist=str(e.playlist)
   player_id=e.player;cookie=e.cookie;udp_host=e.udp_host;reflector_ip="";reflector_port=int(e.udp_port)
   if not cloud:resolve_request=IP.resolve_hostname_queue_item(udp_host,IP.TYPE_IPV4)
   if not cloud:
    udp_port=randi_range(22000,55000)
    if udp.bind(udp_port,"*")!=OK:fail("Unable to bind a P2P UDP probe port. Retry matchmaking.");return
    if DisplayServer.get_name()!="headless":game.lobby_network._start_upnp(udp_port)
   if session.configure(session.match_id if scheduler.reconnecting and game.running else "",player_id,str(e.public_key),server_time)!=OK:fail("Master server returned an invalid signing key.");return
   scheduler.restored()
   if game.running and not session.match_id.is_empty():return
   mm.status="Opening party lobby…" if mm.party_mode else "Connected to matchmaking hub · waiting for this playlist to fill";mm.phase="connecting" if mm.party_mode and cloud else "queue";mm.changed()
  "party":
   if mm.queue_cancelled:e["searching"]=false
   mm.party=e
   if e.has("custom"):mm.browser_mode=true
   mm.playlist=str(e.playlist);mm.save_connection()
   if mm.phase not in ["probing","voting","loading","rejoining","playing","results","migrating"]:
    mm.phase="queue" if e.get("searching",false) else "party"
    mm.public_state={"capacity":mm.team_size()*2,"connected":0,"members":{}}
    mm.status="Finding an opposing team…" if e.get("searching",false) else "Invite friends or search solo. Your party stays on the same team."
    if e.has("custom"):mm.status="Preparing custom game…" if e.get("searching",false) else "Custom lobby · Unranked · The lobby owner starts the game."
    elif mm.browser_mode:mm.status="Browse public custom games or create a lobby."
   mm.changed()
  "server_list":
   if game.running or game.current_screen!="server_browser" or str(e.get("request_id",""))!=mm.browser_pending:return
   mm.browser_pending="";mm.browser_failures=0
   mm.browser_lobbies=e.get("lobbies",[]);mm.browser_loaded=true;mm.changed()
  "party_error":
   mm.status=str(e.get("reason","Unable to update party"));mm.changed()
  "allocated":
   control_deadline=0
   player_id=e.authority;roster=e.roster;session.configure(e.match,player_id,e.public_key,server_time);session.epoch=int(e.epoch);session.authority=player_id
   current_event=e;session.frozen=true;mm.phase="loading";game.match_session=session_number();configure_auth()
  "pong":master_last_reply=clock()
  "heartbeat_ack":scheduler.acknowledge(int(e.get("revision",-1)))
  "host_status_grant":
   if scheduler.host_grant.is_empty():scheduler.status_due=clock()+.05
   scheduler.host_grant=str(e.get("grant",""))
  "control_restored":
   current_event=e;roster=e.roster;mm.status="Master connection restored";scheduler.restored()
   if game.running:mm.phase="results" if game.finished else "playing"
   if game.finished:completion_sent=false
  "result_receipt":pending_results.acknowledge(str(e.get("match_id","")),str(e.get("receipt","")))
  "queue":
   if mm.queue_cancelled:return
   queue_fallback.accept_ticket(str(e.get("queue_token",queue_fallback.ticket)))
   mm.status=str(e.get("status","Finding players for your playlist…"))
   mm.phase="queue";mm.public_state={"capacity":int(e.get("capacity",6)),"connected":int(e.connected),"members":integer_members(e.members),"votes":{},"seconds":0};mm.changed()
  "voting":
   if mm.queue_cancelled and not game.running:send({"type":"leave_match"});return
   current_event=e;roster=e.roster;session.match_id=e.match;mm.local_slot=int(roster[player_id].slot)
   var ballots={}
   for id in e.votes:ballots[int(roster[id].slot)]=e.votes[id]
   mm.status="Player-host: "+str(e.get("host_name","selected after voting"))+" · teams assigned · vote now"
   mm.phase="voting";mm.until=clock()+float(e.seconds);mm.public_state={"capacity":roster.size(),"connected":roster.size(),"members":make_members(),"votes":ballots,"seconds":e.seconds,"vote_stage":e.get("stage","setup"),"mode":e.get("config",{}).get("mode",2),"map":e.get("config",{}).get("map",0)};mm.changed()
  "rtc_signal":rtc.receive(e)
  "collect_telemetry":
   if cloud:
    roster=e.roster;current_event=e;session.match_id=e.match;session.epoch=int(e.epoch);mm.local_slot=int(roster[player_id].slot);rtc.begin_probes(e);mm.phase="probing";mm.public_state={"capacity":roster.size(),"connected":roster.size(),"members":make_members()};mm.status="Playlist filled · teams assigned · measuring player-host routes";mm.changed();return
   roster=e.roster;probe_key=e.probe_key;probe_epoch=int(e.epoch);probe_seen.clear();probe_endpoints.clear();probe_sent=false;probe_reported=false;probe_round=-1;probe_records.clear();probe_nonces.clear();probe_started=clock();mm.phase="probing";mm.status="Measuring peer connection quality · selecting the best reachable player-host…";mm.changed()
  "probe_peers":
   if not probe_sent:probe_endpoints=e.endpoints;probe_started=clock();probe_sent=true
  "host_offer","connect":
   current_event=e;roster=e.roster;rejoining=bool(e.get("rejoin",false));staged=false
   checkpoint_data=Marshalls.base64_to_raw(str(e.get("state","")));checkpoint_digest=str(e.get("checkpoint",e.get("restore","")))
   if not checkpoint_data.is_empty() and checkpoint_digest!="" and checkpoint_digest!="<null>" and sha(checkpoint_data).hex_encode()!=checkpoint_digest:fail("Checkpoint digest mismatch");return
   if player_id in roster:mm.local_slot=int(roster[player_id].slot)
   session.match_id=e.match;session.on_control(e)
  "checkpoint_offer":
   var bytes=Marshalls.base64_to_raw(str(e.state))
   if bytes.size()<=1048576 and sha(bytes).hex_encode()==str(e.digest) and NestMigrationState.valid(bytes_to_var(bytes),game.NETWORK_VERSION):
    send({"type":"checkpoint_ack","epoch":int(e.epoch),"tick":int(e.tick),"digest":e.digest})
  "checkpoint_committed":checkpoint_digest=str(e.digest);checkpoint_tick=maxi(checkpoint_tick,int(e.tick))
  "freeze":
   authority=false;session.on_control(e);close_game_transport();
   if not cloud and not worker and not udp.is_bound():udp.bind(udp_port,"*")
   mm.phase="migrating";mm.status="Host lost · electing replacement and restoring the match…";mm.changed()
  "result_status":
   mm.status=str(e.get("message",""));game.messages.append(mm.status);mm.changed()
  "return_queue":
   var keep_film=game.film_recorder.ended and not game.film_recorder.track_owner.is_empty() and game.network_active
   var active_transport=game.network_active;game.network_active=false
   if game.running:game.stop_game()
   game.network_active=active_transport
   if keep_film:
    game.film_retaining_transport=true;film_transport_until=clock()+1800;film_drain_at=0
   else:close_game_transport()
   if worker:get_tree().quit();return
   authority=false;staged=false;completion_sent=false;checkpoint_data=PackedByteArray();checkpoint_digest="";checkpoint_tick=0;roster.clear();authenticated.clear();admission_until.clear();current_event={}
   session.epoch=0;session.lease_until=0;session.pending_resume=false;session.frozen=true;session.authority="";session.match_id="";mm.local_slot=0
   if not cloud and not udp.is_bound():udp.bind(udp_port,"*")
   mm.phase="party" if mm.party_mode else "queue";mm.status="Match complete · ready for your next search";mm.changed()
  "authority_lease","resume","failed":session.on_control(e)
func integer_members(data: Dictionary) -> Dictionary:
 var result={}
 for key in data:result[int(key)]=data[key]
 return result
func make_members() -> Dictionary:
 var result={}
 for who in roster:
  var info=roster[who];var peer=1 if who==session.authority and authority else int(authenticated.get(who,0))
  result[int(info.slot)]={"name":info.name,"faction":int(info.faction),"character":-1,"ready":peer>0,"peer":peer,"substitute":(peer==0 if authority else who not in current_event.get("targets",roster.keys())),"rating":info.rating,"account":info.get("account","")}
 return result
func udp_send(address: String,port: int,value: Dictionary) -> void:
 udp.set_dest_address(address,port);udp.put_packet(JSON.stringify(value).to_utf8_buffer())
func probe_mac(value: Dictionary) -> String:
 var data=value.duplicate();data.erase("mac")
 return Crypto.new().hmac_digest(HashingContext.HASH_SHA256,probe_key.to_utf8_buffer(),JSON.stringify(data).to_utf8_buffer()).hex_encode()
func poll_probes() -> void:
 while udp.get_available_packet_count()>0:
  var packet=udp.get_packet();var host=udp.get_packet_ip();var port=udp.get_packet_port()
  if packet.size()>1400 or packet.is_empty() or packet[0]!=123:continue
  var p=JSON.parse_string(packet.get_string_from_utf8())
  if not p is Dictionary:continue
  if p.get("type")=="observed":
   var index=int(p.get("index",-1))
   if index in [0,1] and host==reflector_ip and port==reflector_port+index:observed[index]={"host":p.host,"port":p.port}
   continue
  if probe_key.is_empty() or p.get("mac","")!=probe_mac(p) or p.get("sender","") not in roster:continue
  var who=str(p.sender)
  var route=str(p.get("target","")) if p.get("type")=="echo" else who
  var ep=probe_endpoints.get(route,{})
  if p.get("epoch",-1)!=probe_epoch or ep.is_empty() or host!=str(ep.host) or port!=int(ep.port):continue
  if p.get("type")=="ping" and p.get("target","")==player_id:
   p.type="echo";p.mac=probe_mac(p);udp_send(host,port,p)
  elif p.get("type")=="echo" and who==player_id:
   var target=str(p.get("target",""))
   if probe_nonces.get(str(p.nonce),"")!=target:continue
   probe_nonces.erase(str(p.nonce))
   if not probe_records.has(target):probe_records[target]={"rtts":[],"bytes":0,"first":clock(),"last":clock()}
   var values: Array=probe_records[target].rtts
   if values.size()<50:values.append((Time.get_ticks_usec()-int(p.nonce))/1000.0)
  elif p.get("type")=="data" and p.get("target","")==player_id:
   var seq=int(p.get("sequence",-1));var key=who+":"+str(seq)
   if seq<0 or seq>=100 or probe_seen.has(key):continue
   probe_seen[key]=true
   if not probe_records.has(who):probe_records[who]={"rtts":[],"bytes":0,"first":clock(),"last":clock()}
   var entry=probe_records[who];entry.bytes=mini(500000,int(entry.bytes)+packet.size());entry.last=clock()
 if not probe_sent or probe_reported:return
 var age=clock()-probe_started
 var round_index=mini(49,int(age/.03))
 if round_index>probe_round and age<2.2:
  probe_round=round_index
  for who in probe_endpoints:
   if who==player_id:continue
   var ep=probe_endpoints[who]
   var ping={"type":"ping","epoch":probe_epoch,"sender":player_id,"target":who,"nonce":str(Time.get_ticks_usec())};probe_nonces[str(ping.nonce)]=who;ping.mac=probe_mac(ping);udp_send(ep.host,int(ep.port),ping)
   # Two bounded datagrams every 30ms; receiver observes actual bytes and duration.
   for i in range(2):
    var data={"type":"data","epoch":probe_epoch,"sender":player_id,"target":who,"sequence":round_index*2+i,"nonce":str(Time.get_ticks_usec()),"pad":"x".repeat(1000)};data.mac=probe_mac(data);udp_send(ep.host,int(ep.port),data)
 if age>2.8:
  probe_reported=true
  var routes={}
  for who in probe_records:
   var entry=probe_records[who];routes[who]={"rtts":entry.rtts,"bytes":entry.bytes,"seconds":maxf(.1,float(entry.last)-float(entry.first))}
  send({"type":"telemetry","epoch":probe_epoch,"routes":routes,"host_capacity":host_capacity()})
func configure_auth() -> void:
 var mp=game.multiplayer
 mp.auth_callback=authenticate;mp.auth_timeout=8
 if not mp.peer_authenticating.is_connected(authenticating):mp.peer_authenticating.connect(authenticating)
 if not mp.peer_authentication_failed.is_connected(auth_failed):mp.peer_authentication_failed.connect(auth_failed)
func authenticating(peer: int) -> void:
 if not authority:return
 var nonce=Crypto.new().generate_random_bytes(32).hex_encode();challenges[peer]=nonce
 game.multiplayer.send_auth(peer,var_to_bytes({"challenge":nonce,"epoch":session.epoch}))
func authenticate(peer: int,bytes: PackedByteArray) -> void:
 if bytes.size()>16000:return
 var value=bytes_to_var(bytes)
 if not value is Dictionary:return
 if authority:
  if not challenges.has(peer):return
  var proof_parts=str(value.get("grant","")).split(".")
  if proof_parts.size()!=2:return
  var claims=JSON.parse_string(Marshalls.base64_to_raw(proof_parts[0]).get_string_from_utf8())
  if not claims is Dictionary:return
  var who=str(claims.get("subject",""));var verified=session.verify_grant(str(value.grant),"join",session.epoch,who,session.authority)
  if verified.is_empty() or who not in roster or authenticated.has(who) or consumed.has(str(verified.nonce)):return
  var key=CryptoKey.new()
  if key.load_from_string(str(verified.extra.get("client_public_key","")),true)!=OK:return
  var digest=sha((str(challenges[peer])+str(value.grant)).to_utf8_buffer())
  if not Crypto.new().verify(HashingContext.HASH_SHA256,digest,Marshalls.base64_to_raw(str(value.get("signature",""))),key):return
  consumed[str(verified.nonce)]=true;challenges.erase(peer);authenticated[who]=peer;admission_until[peer]=clock()+15
  game.multiplayer.send_auth(peer,var_to_bytes({"accepted":true}));game.multiplayer.complete_auth(peer)
 else:
  if value.has("challenge"):
   var digest=sha((str(value.challenge)+game_grant).to_utf8_buffer())
   game.multiplayer.send_auth(peer,var_to_bytes({"grant":game_grant,"signature":Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256,digest,identity))}))
  elif value.get("accepted",false):game.multiplayer.complete_auth(peer)
func auth_failed(peer: int) -> void:
 challenges.erase(peer)
 for who in authenticated.keys():
  if int(authenticated[who])==peer:authenticated.erase(who)
func open_listener(port: int) -> Error:
 if cloud:return rtc.start_host(current_event)
 close_game_transport();udp.close();listen_port=port
 cert_key=Crypto.new().generate_rsa(2048);certificate=Crypto.new().generate_self_signed_certificate(cert_key,"CN=ancient-nest-host,O=AncientNest,C=US")
 var transport=ENetMultiplayerPeer.new();var error=transport.create_server(port,10)
 if error!=OK:return error
 error=transport.host.dtls_server_setup(TLSOptions.server(cert_key,certificate))
 if error!=OK:transport.close();return error
 configure_auth();game.multiplayer.server_relay=false;game.multiplayer.multiplayer_peer=transport;game.network_active=true
 return OK
func start_host(_epoch: int,_offer: String,_checkpoint: String) -> void:
 if not bool(game.prefs.values.get("allow_host",true)):send({"type":"host_failed","epoch":session.epoch});return
 authority=true;mm.phase="loading";mm.status="Creating the elected host’s lobby…";authenticated.clear();consumed.clear()
 var error=open_listener(udp_port)
 if error!=OK:send({"type":"host_failed","epoch":session.epoch});return
 authenticated[player_id]=1
 send({"type":"host_ready","epoch":session.epoch,"certificate":"" if cloud else certificate.save_to_string()})
func handoff(endpoint: Dictionary,grant: String,as_host: bool,_checkpoint: String) -> void:
 game_grant=grant;mm.phase="loading";mm.status="Automatically joining the selected player-host…";mm.changed()
 if as_host:
  authority=true;try_stage();return
 authority=false;close_game_transport();configure_auth()
 if cloud:
  if rtc.start_client(current_event)!=OK:fail("Unable to create native WebRTC gameplay transport")
  return
 var cert=X509Certificate.new()
 if cert.load_from_string(str(current_event.get("certificate","")))!=OK:fail("Missing authority certificate");return
 var transport=ENetMultiplayerPeer.new();var error=transport.create_client(str(endpoint.host),int(endpoint.port))
 if error!=OK:fail("Unable to create gameplay connection");return
 error=transport.host.dtls_client_setup("ancient-nest-host",TLSOptions.client(cert))
 if error!=OK:transport.close();fail("DTLS setup failed");return
 game.multiplayer.multiplayer_peer=transport;game.network_active=true
func session_number() -> int:
 return int(session.match_id.substr(0,7).hex_to_int())+session.epoch
func close_game_transport() -> void:
 if cloud:rtc.close_game()
 if game.network_active:
  NestNetworkCleanup.retire_rpc_cache([game,mm,game.nu,self]);game.multiplayer.multiplayer_peer.close()
  game.multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
 game.network_active=false;game.clear_held_input()
 game.film_retaining_transport=false
func release_film_transport(reason: String="Perspective source disconnected"):
 if not game.film_retaining_transport:return
 game.film_recorder.metadata["perspective_status"]=reason
 game.film_recorder.queue.append({"id":game.film_recorder.id,"payload":{"metadata":game.film_recorder.metadata.duplicate(true)}})
 close_game_transport()
func peer_connected(_peer: int) -> void:
 if authority:call_deferred("try_stage")
func game_connected() -> void:
 mm.status="Authenticated gameplay transport · loading arena…";mm.changed()
func try_stage() -> void:
 if not authority:return
 if session.authority==player_id and not worker:authenticated[player_id]=1
 var required=current_event.get("targets",roster.keys()).size() if not checkpoint_data.is_empty() else roster.size()
 if authenticated.size()<required:return
 if staged and not game.running:return
 for who in authenticated:
  var peer=int(authenticated[who])
  if peer>1 and (peer not in game.multiplayer.get_peers() or not mm.can_send(peer)):return
 var members=make_members();mm.peers.clear();mm.slots.clear()
 for who in roster:
  var id=int(roster[who].slot);var peer=int(authenticated.get(who,0));mm.slots[id]={"peer":peer,"bot":peer==0}
  if peer>1:mm.peers[peer]=id
 var state=checkpoint_data
 if staged:
  state=NestMigrationState.pack(game)
 else:
  game.match_session=session_number()
  if state.is_empty():
   mm.configure_rules(int(current_event.config.mode),int(current_event.config.map),int(current_event.config.get("matchup",1)))
   game.snapshot_interval_ticks=clampi(int(current_event.config.get("snapshot_ticks",2)),1,3)
   if current_event.config.get("custom",false):game.game_type.matchup=int(current_event.config.matchup)
   game.game_type.max_players=roster.size();game.game_type.max_players_per_team=ceili(roster.size()/2.0);game.game_type.validate();game.sync_game_type_to_legacy();game.match_session=session_number();game.begin_network_match(game.active_config(),members)
  elif not NestMigrationState.restore(game,state,members,session_number()):fail("Unable to restore complete checkpoint");return
  game.snapshot_interval_ticks=clampi(int(current_event.config.get("snapshot_ticks",2)),1,3)
  staged=true
 game.lobby_members=members
 for actor in game.actors:
  actor.remote_peer=int(members[actor.net_id].peer)
 for who in authenticated:
  var peer=int(authenticated[who])
  if peer<=1:continue
  if rejoining or admission_until.has(peer):
   stage.rpc_id(peer,session.epoch,game.active_config(),members,state,session_number(),not session.frozen)
 if session.frozen:send({"type":"loaded","epoch":session.epoch,"digest":checkpoint_digest if not checkpoint_data.is_empty() else null})
 mm.public_state={"connected":authenticated.size(),"members":members,"mode":game.mode,"map":game.game_type.map_selection,"loaded":authenticated.size()};mm.changed()
@rpc("authority","call_remote","reliable")
func stage(epoch: int,config: Dictionary,members: Dictionary,state: PackedByteArray,number: int,is_rejoin: bool) -> void:
 if game.film_retaining_transport:return
 if not enabled or authority or epoch!=session.epoch or state.size()>1048576:return
 if game.running and state.is_empty():return
 if state.is_empty():game.begin_network_match(config,members);game.match_session=number
 elif not NestMigrationState.restore(game,state,members,number):fail("Checkpoint restoration failed");return
 game.snapshot_interval_ticks=clampi(int(config.get("snapshot_ticks",3)),1,3)
 game.match_session=number;game.player=game.actor_by_id(mm.local_slot);game.lobby_members=members;staged=true
 mm.public_state={"connected":members.values().filter(func(m):return int(m.peer)>0).size(),"members":members,"mode":game.mode,"map":game.game_type.map_selection,"loaded":members.size()}
 if is_instance_valid(game.player):game.player.local_player=true;game.player.camera.current=true
 send({"type":"loaded","epoch":session.epoch,"digest":checkpoint_digest if not checkpoint_data.is_empty() else null,"rejoin":is_rejoin or rejoining})
 ready_on_host.rpc_id(1,session.epoch)
@rpc("any_peer","call_remote","reliable")
func ready_on_host(epoch: int) -> void:
 if game.film_retaining_transport:return
 if not authority or epoch!=session.epoch:return
 admission_until.erase(game.multiplayer.get_remote_sender_id())
func freeze_game(reason: String) -> void:
 if not enabled:return
 game.clear_held_input();mm.status=reason
 if game.running:
  game.context="migration";mm.phase="migrating";mm.changed()
 for child in game.effects.get_children():
  if child is RigidBody3D:child.set_meta("migration_frozen",child.freeze);child.freeze=true
func resume_game(_epoch: int) -> void:
 if not staged:return
 mm.phase="results" if game.finished else "playing";game.context=mm.phase;game.clear_held_input()
 for child in game.effects.get_children():
  if child is RigidBody3D and child.has_meta("migration_frozen"):child.freeze=child.get_meta("migration_frozen");child.remove_meta("migration_frozen")
 if not worker and game.has_method("network_match_started"):game.call("network_match_started");game.capture_mouse()
 checkpoint_at=clock()+.2;mm.status="%s · epoch %d"%["Hosting the match" if authority else "Connected to player-host" if cloud else "Connected to match authority",session.epoch]
 print("HYBRID RUNNING epoch=",session.epoch," local=",mm.local_slot," authority=",authority," actors=",game.actors.size())
func disconnected(peer: int) -> void:
 if not authority:return
 for who in authenticated.keys():
  if authenticated[who]!=peer:continue
  authenticated.erase(who);admission_until.erase(peer);mm.peers.erase(peer)
  var actor=game.actor_by_id(int(roster[who].slot))
  if actor!=null:mm.reset_owner_commands(actor);actor.remote_peer=0
func lost() -> void:
 if not enabled:return
 if game.film_retaining_transport:release_film_transport();return
 session.freeze("Authority connection lost · waiting for migration");mm.phase="migrating";send({"type":"unhealthy","epoch":session.epoch});mm.changed()
func fail(reason: String) -> void:
 master_authenticated=false
 control_deadline=0
 if not cloud and (reason.contains("No reachable") or reason.contains("eligible player")):
  reason+=" · Open/forward P2P UDP port %d or add dedicated capacity. No relay is configured."%udp_port
 failure_reason=reason;session.freeze(reason);close_game_transport();mm.phase="error";mm.status=reason;mm.changed();print("HYBRID FAILED: ",reason)

func account_handshake() -> void:
 if not await game.accounts.refresh_session():
  if game.running and scheduler.reconnecting:scheduler.lost(true)
  else:fail("Account sign-in expired or unavailable. Open Account in the main menu.")
  return
 if not enabled or ws.get_ready_state()!=WebSocketPeer.STATE_OPEN:return
 hello_sent=true;control_deadline=clock()+float(NestControlPolicy.settings().request_timeout_seconds)
 send({"type":"hello","lobby_only":mm.party_mode,"resume":mm.resume_reserved_match,"playlist":mm.playlist,"name":game.current_username(),"version":game.NETWORK_VERSION,"public_key":identity.save_to_string(true),"rating":game.ranked.profile.summary(),"local_ips":IP.get_local_addresses(),"account_assertion":game.accounts.account_assertion})

func send_result_report() -> void:
 if mm.custom_match():return
 var players=[]
 for who in roster:
  var actor=game.actor_by_id(int(roster[who].slot))
  if actor==null:return
  players.append({"player":who,"kills":actor.kills,"deaths":actor.deaths,"assists":actor.assists,"flags_captured":actor.captures,"flags_stopped":actor.flag_returns})
 var winner=null if game.mode==1 or game.scores[0]==game.scores[1] else (0 if game.scores[0]>game.scores[1] else 1)
 pending_results.enqueue({"type":"result_report","epoch":session.epoch,"winner_team":winner,"players":players})

func host_capacity() -> Dictionary:
 var measured=(game.physics_samples if game.running and game.physics_samples.size()>=15 else cpu_samples).duplicate();measured.sort()
 return {"allow_host":bool(game.prefs.values.get("allow_host",true)),"cpu_p95_ms":float(measured[mini(measured.size()-1,int(measured.size()*.95))]) if not measured.is_empty() else 1000.,"logical_cpus":OS.get_processor_count(),"samples":measured.size()}
