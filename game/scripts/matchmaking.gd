class_name NestMatchmaking
extends Node
## One persistent, authoritative six-human room per dedicated server process.
## Connection-bound tickets are private; public rosters never contain secrets.
const SIZE=6
const MODES=[2,1,3,0,4]
const MODE_LABELS=["Team Deathmatch","Iso Deathmatch","Capture the Flag","Extraction","Bomb Defusal"]
const MAPS=[0,1,2,3,4,5]
const VOTE_SECONDS=25.0
const LOAD_SECONDS=45.0
const SETTINGS_PATH="user://matchmaking.cfg"
var game
var dedicated=false
var active=false
var phase="idle"
var status=""
var epoch=0
var until=0.0
var local_slot=0
var ticket=""
const PLAYLIST_IDS=["duel_1v1","doubles_2v2","tactical_3v3","arena_4v4","bomb_defuse_5v5"]
const PLAYLIST_NAMES=["1 v 1 Loners","2 v 2 Couples","3 v 3 Trios","4 v 4 Quads","5 v 5 Squads"]
var playlist="tactical_3v3"
var party: Dictionary={}
var party_mode=false
var resume_reserved_match=true
var browser_mode=false
var browser_lobbies: Array=[]
var browser_loaded=false
var browser_refresh_at=0.0
var browser_pending=""
var browser_deadline=0.0
var browser_generation=0
var browser_manual_at=-100.0
var browser_failures=0
var browser_was_visible=false
var queue_cancelled=false
func browser_window_visible() -> bool:
 # Headless fixtures have logical screens but no native window to minimize.
 if DisplayServer.get_name()=="headless":return true
 return game.get_window().visible and game.get_window().mode!=Window.MODE_MINIMIZED
func browser_visible() -> bool:
 return browser_mode and not game.running and game.current_screen=="server_browser" and phase=="party" and game.screen.is_visible_in_tree() and browser_window_visible()
func invalidate_browser_view() -> void:
 browser_pending="";browser_generation+=1;browser_was_visible=false;browser_refresh_at=0
func update_browser_visibility() -> bool:
 var visible=browser_visible()
 if visible!=browser_was_visible:
  browser_was_visible=visible;browser_pending="";browser_generation+=1
  if visible:browser_refresh_at=0
 return visible
func custom_match() -> bool:return party.has("custom") or hybrid.current_event.get("config",{}).get("custom",false)
func refresh_browser(manual: bool=true) -> void:
 if not update_browser_visibility():return
 if not browser_pending.is_empty():return
 if manual and clock()-browser_manual_at<2:return
 if not hybrid.master_connected() or not party.get("server_browser_supported",false):return
 if manual:browser_manual_at=clock()
 browser_generation+=1;browser_pending=str(epoch)+":"+str(browser_generation)
 browser_deadline=clock()+float(NestControlPolicy.settings().request_timeout_seconds)
 browser_refresh_at=clock()+float(NestControlPolicy.settings().browser_refresh_seconds)
 party_action("browse",{"request_id":browser_pending})
var lobby_effects: bool=true
var queue_started_at: float=0
var queue_previous_phase: String=""
var search_countdown_until: float=0
var search_countdown_context: String=""
func search_context() -> String:
 return str([playlist,party.get("code",""),party.get("leader",""),party.get("members",[])])
func can_start_search() -> bool:
 return phase=="party" and hybrid.master_connected() and party_leader() and not party.get("members",[]).is_empty() and party.get("members",[]).size()<=mini(5,team_size())
func begin_search_countdown() -> bool:
 if not can_start_search() or search_countdown_until>0:return false
 search_countdown_context=search_context();search_countdown_until=clock()+3.0;return true
func cancel_search_countdown() -> void:
 search_countdown_until=0;search_countdown_context=""
func advance_search_countdown(at: float=-1) -> void:
 if search_countdown_until<=0:return
 if not can_start_search() or search_context()!=search_countdown_context:
  cancel_search_countdown();return
 if (clock() if at<0 else at)>=search_countdown_until:
  cancel_search_countdown();party_action("search")

func team_size() -> int:return maxi(1,PLAYLIST_IDS.find(playlist)+1)
func party_leader() -> bool:return party.is_empty() or str(party.get("leader",""))==hybrid.player_id
func party_action(action: String,extra: Dictionary={}) -> void:
 if not hybrid.enabled or not hybrid.cloud:return
 if action in ["search","custom_start"]:queue_cancelled=false
 if action in ["search","custom_start"] and hybrid.master_connected():hybrid.release_film_transport("A new search started before every perspective was available")
 if action=="cancel":
  queue_cancelled=true;phase="party";party["searching"]=false
  if not hybrid.master_connected():hybrid.queue_fallback.cancel_queue();changed();return
 if not hybrid.master_connected():status="Master server connection unavailable. Reconnect before searching.";changed();return
 var message=extra.duplicate();message["type"]="party_"+action;hybrid.send(message)
func open_party() -> void:
 party_mode=true;party.clear();search(endpoint,port)
func capacity() -> int:
 return int(public_state.get("capacity",2*(maxi(0,PLAYLIST_IDS.find(playlist))+1))) if hybrid.enabled or endpoint.begins_with("ws") else SIZE
var endpoint=""
var port=7780
var slots: Dictionary={}
var peers: Dictionary={}
var loaded: Dictionary={}
var votes: Dictionary={}
var selected_mode=2
var selected_map=0
var selected_matchup=1
var vote_stage="setup"
var result_text=""
var public_state: Dictionary={}
var last_request: Dictionary={}
var anonymous: Dictionary={}
var rejoin_deadlines: Dictionary={}
var retry_at=0.0
var connect_until=0.0
var post_until=0.0
var hybrid: NestHybridNetwork
var rng=RandomNumberGenerator.new()
func _ready() -> void:
 hybrid=NestHybridNetwork.new();hybrid.game=game;hybrid.mm=self;add_child(hybrid)
 rng.randomize()
 var cfg=ConfigFile.new()
 if cfg.load(SETTINGS_PATH)==OK:
  playlist=str(cfg.get_value("server","playlist","tactical_3v3"));playlist=playlist if playlist in PLAYLIST_IDS else "tactical_3v3"
  endpoint=str(cfg.get_value("server","address",""));port=int(cfg.get_value("server","port",7780))
  ticket=str(cfg.get_value("session","ticket",""))
  if cfg.get_value("server","revision","")!="9.0":endpoint="";ticket=""
 if endpoint.is_empty():
  var packaged=ConfigFile.new()
  if packaged.load("res://data/matchmaking.cfg")==OK:
   endpoint=str(packaged.get_value("server","address",""));port=int(packaged.get_value("server","port",7780))
func clock() -> float:return Time.get_ticks_msec()/1000.0
func save_connection() -> void:
 var cfg=ConfigFile.new();cfg.set_value("server","address",endpoint);cfg.set_value("server","playlist",playlist);cfg.set_value("server","revision","9.0");cfg.set_value("server","port",port);cfg.set_value("session","ticket",ticket);cfg.save(SETTINGS_PATH)
func start_server(listen_port: int=7780,bind_address: String="*") -> Error:
 if listen_port<1 or listen_port>65535:return ERR_INVALID_PARAMETER
 if game.running:game.stop_game()
 game.close_connection()
 dedicated=false;active=false
 slots.clear();peers.clear();loaded.clear();votes.clear();anonymous.clear();rejoin_deadlines.clear();last_request.clear();public_state.clear()
 epoch+=1;until=0;retry_at=0;connect_until=0;post_until=0;local_slot=0;result_text=""
 var transport=ENetMultiplayerPeer.new();transport.set_bind_ip(bind_address)
 var error=transport.create_server(listen_port,16)
 if error!=OK:return error
 dedicated=true;active=true;phase="queue";port=listen_port;game.lobby_kind="matchmaking"
 game.multiplayer.server_relay=false # Clients talk only to the authoritative server.
 game.multiplayer.multiplayer_peer=transport;game.network_active=true;game.connection_port=port;game.lobby_members.clear()
 configure_rules(2,0);publish()
 print("Ancient Nest Server 10.2 - God and Vote listening UDP ",port," · six human clients / 3v3; no server player")
 return OK
func configure_rules(mode: int,map_id: int,life: int=1) -> void:
 game.god_mode=false
 game.game_type=NestMatchPresets.create(mode,map_id,life,true)
 game.fair_playing_field=false;game.selected_character=-1
 game.forge_session.clear();game.sync_game_type_to_legacy();game.ensure_selected_map()
func search(address: String,server_port: int=7780) -> Error:
 if game.running:return ERR_BUSY
 if address.begins_with("ws://") or address.begins_with("wss://"):
  endpoint=address;save_connection();return hybrid.connect_hub(address)
 address=address.strip_edges()
 if address.is_empty() or server_port<1 or server_port>65535:status="Enter the matchmaking server address and UDP port.";return ERR_INVALID_PARAMETER
 if endpoint!=address or port!=server_port:ticket=""
 endpoint=address;port=server_port;public_state.clear();retry_at=0;active=true;phase="connecting";status="Connecting to matchmaking server…";local_slot=0
 game.lobby_kind="matchmaking";game.lobby_network.cancel_pending_join()
 var error=game.join_direct(endpoint,port,game.current_username(),0)
 game.lobby_kind="matchmaking";connect_until=clock()+12;save_connection()
 if error!=OK:phase="error";status="Unable to open connection.";connect_until=0
 return error
func connected() -> void:
 if hybrid.enabled:hybrid.game_connected();return
 connect_until=clock()+12;phase="connecting";status="Connected · registering human slot…"
 join_queue.rpc_id(1,game.current_username(),game.NETWORK_VERSION,game.ranked.profile.summary(),ticket)
func connection_lost(reason: String) -> void:
 if hybrid.enabled:hybrid.lost();return
 if game.running:game.stop_game()
 game.close_connection();active=true;game.lobby_kind="matchmaking";phase="reconnecting";status=reason+" · Reconnecting…";retry_at=clock()+2;connect_until=0
 changed()
func leave(abandon: bool=true) -> void:
 resume_reserved_match=not abandon
 cancel_search_countdown()
 if hybrid.enabled:hybrid.leave(abandon)
 party.clear();party_mode=false;browser_mode=false;browser_lobbies.clear();browser_loaded=false
 invalidate_browser_view()
 active=false;retry_at=0;connect_until=0
 if game.running:game.stop_game()
 game.close_connection();phase="idle";game.lobby_kind="custom"
func blocks_simulation() -> bool:
 if hybrid!=null and hybrid.enabled:return hybrid.session.frozen
 return active and not dedicated and phase not in ["playing","results"]
func is_authority() -> bool:return dedicated or (hybrid!=null and hybrid.enabled and hybrid.authority)
func _process(_delta: float) -> void:
 advance_search_countdown()
 var visible=update_browser_visibility()
 if visible and not browser_pending.is_empty() and clock()>=browser_deadline:
  browser_pending="";browser_failures+=1;status="Directory offline / showing the previous server list"
  browser_refresh_at=clock()+maxf(float(NestControlPolicy.settings().browser_refresh_seconds),NestControlPolicy.retry_delay(browser_failures,randf()));changed()
 if visible and not game.get_meta("server_create_form",false) and clock()>=browser_refresh_at:refresh_browser(false)
 if phase=="queue" and queue_previous_phase!="queue":queue_started_at=clock()
 queue_previous_phase=phase
 if not active:return
 if hybrid.enabled:return
 if dedicated:
  for peer in rejoin_deadlines.keys():
   if clock()>=float(rejoin_deadlines[peer]):
    disconnected(peer)
    if can_send(peer):game.multiplayer.multiplayer_peer.disconnect_peer(peer)
  for peer in anonymous.keys():
   if clock()>anonymous[peer]:
    anonymous.erase(peer)
    if game.multiplayer.get_peers().has(peer):game.multiplayer.multiplayer_peer.disconnect_peer(peer)
  if phase in ["voting","loading"] and clock()>=until:
   if phase=="voting":resolve_vote()
   else:
    var missing=[]
    for id in slots:
     if not loaded.has(id):missing.append(int(slots[id].peer))
    for peer in missing:
     disconnected(peer);game.multiplayer.multiplayer_peer.disconnect_peer(peer)
  if game.running and game.finished and phase=="playing":
   # ranked.complete updates lobby summaries; retain them in the owning queue.
   for id in slots:
    slots[id].rating=NestRatingProfile.clean_summary(game.lobby_members.get(id,{}).get("rating",slots[id].rating))
   phase="results";post_until=clock()+15;publish()
  if phase=="results" and clock()>=post_until:reset_queue()
  return
 if connect_until>0 and clock()>connect_until:
  game.close_connection();connect_until=0;phase="error";status="Server did not respond. Check its address, UDP port and firewall.";changed()
 if retry_at>0 and clock()>=retry_at:
  retry_at=0;search(endpoint,port);changed()
func throttle(peer: int) -> bool:
 var old=float(last_request.get(peer,-100))
 if clock()-old<.15:return false
 last_request[peer]=clock();return true
@rpc("any_peer","call_remote","reliable")
func join_queue(alias: String,version: String,rating: Dictionary,resume: String="") -> void:
 if not dedicated or not game.multiplayer.is_server():return
 var peer=game.multiplayer.get_remote_sender_id()
 if not throttle(peer):return
 if peers.has(peer):return
 if version!=game.NETWORK_VERSION:deny.rpc_id(peer,"Use a compatible Ancient Nest 10.5-dev client.");return
 # A bearer secret can reclaim only its original slot on this server instance.
 var reclaim=0
 if not resume.is_empty():
  for id in slots:
   if slots[id].secret==resume:reclaim=id;break
 if reclaim!=0:
  if int(slots[reclaim].peer)!=0:deny.rpc_id(peer,"That player is already connected.");return
  slots[reclaim].peer=peer;peers[peer]=reclaim;anonymous.erase(peer)
  welcome.rpc_id(peer,reclaim,slots[reclaim].secret,epoch)
  refresh_members()
  if game.running:
   rejoin_deadlines[peer]=clock()+LOAD_SECONDS
   prepare.rpc_id(peer,game.active_config(),game.lobby_members,epoch,true)
  else:maybe_vote()
  publish();return
 if phase!="queue" or slots.size()>=SIZE:deny.rpc_id(peer,"Match is full or already in progress. Only its disconnected players may rejoin.");return
 var secret=Crypto.new().generate_random_bytes(32).hex_encode()
 var slot=available_slot(peer)
 slots[slot]={"peer":peer,"secret":secret,"name":game.unique_alias(alias),"faction":0,"rating":NestRatingProfile.clean_summary(rating),"bot":false}
 peers[peer]=slot;anonymous.erase(peer);welcome.rpc_id(peer,slot,secret,epoch)
 refresh_members();maybe_vote();publish()
func available_slot(preferred: int) -> int:
 # Stable identities survive reconnects; an old stable ID may match a new
 # ENet transport ID. Never overwrite the original player's reservation.
 var id=maxi(2,preferred)
 while slots.has(id):id+=1
 return id
func refresh_members() -> void:
 game.lobby_members.clear()
 for id in slots:
  var s=slots[id]
  game.lobby_members[id]={"name":s.name,"faction":s.faction,"character":-1,"ready":int(s.peer)>0,"peer":s.peer,"substitute":s.bot,"rating":s.rating}
func can_send(peer: int) -> bool:
 if not game.network_active or not game.multiplayer.get_peers().has(peer):return false
 var transport=game.multiplayer.multiplayer_peer
 if transport is WebRTCMultiplayerPeer:
  if not transport.has_peer(peer):return false
  var remote: Dictionary=transport.get_peer(peer)
  if not remote.get("connected",false):return false
  var connection=remote.get("connection")
  if connection==null or connection.get_connection_state()!=WebRTCPeerConnection.STATE_CONNECTED:return false
  for channel in remote.get("channels",[]):
   if channel.get_ready_state()!=WebRTCDataChannel.STATE_OPEN:return false
  return true
 if not transport is ENetMultiplayerPeer:return false
 var connection=transport.get_peer(peer)
 return connection!=null and connection.get_state()==ENetPacketPeer.STATE_CONNECTED
func connected_count() -> int:
 var count=0
 for s in slots.values():
  if int(s.peer)>0 and can_send(int(s.peer)):count+=1
 return count
static func balanced_teams(entries: Dictionary) -> Dictionary:
 # Exhaustively choose the closest 3v3 split (only 20 candidates), stable on ties.
 var ids=entries.keys();ids.sort();var answer={};var best=INF
 if ids.size()!=6:return answer
 for a in range(4):
  for b in range(a+1,5):
   for c in range(b+1,6):
    var chosen=[ids[a],ids[b],ids[c]];var totals=[0,0]
    for id in ids:totals[0 if id in chosen else 1]+=int(entries[id].rating.human)
    var error=abs(totals[0]-totals[1])
    if error<best:
     best=error;answer.clear()
     for id in ids:answer[id]=0 if id in chosen else 1
 return answer
func maybe_vote() -> void:
 if phase!="queue" or slots.size()!=SIZE or connected_count()!=SIZE:return
 epoch+=1;phase="voting";vote_stage="setup";until=clock()+VOTE_SECONDS;votes.clear();loaded.clear();result_text=""
 var teams=balanced_teams(slots)
 for id in slots:slots[id].faction=teams[id]
 refresh_members()
@rpc("authority","call_remote","reliable")
func welcome(slot: int,secret: String,revision: int) -> void:
 if not active:return
 local_slot=slot;ticket=secret;epoch=revision;connect_until=0;save_connection()
@rpc("authority","call_remote","reliable")
func deny(reason: String) -> void:
 if not active:return
 game.close_connection();phase="error";status=reason;connect_until=0;retry_at=0;changed()
func vote(mode: int,map_id: int,life: int=1) -> void:
 if hybrid.enabled:hybrid.send({"type":"vote","mode":mode,"map":map_id,"life":life,"stage":public_state.get("vote_stage","setup")});return
 if active and not dedicated and phase=="voting":cast_vote.rpc_id(1,epoch,mode,map_id,life)
@rpc("any_peer","call_remote","reliable")
func cast_vote(revision: int,mode: int,map_id: int,life: int=1) -> void:
 if not dedicated or phase!="voting" or revision!=epoch:return
 var peer=game.multiplayer.get_remote_sender_id()
 if not peers.has(peer) or not throttle(peer):return
 if vote_stage=="setup" and (mode not in MODES or map_id not in MAPS):return
 if vote_stage=="life" and life not in [1,2]:return
 votes[peers[peer]]={"mode":mode,"map":map_id,"life":life};publish()
static func winner(ballots: Array,options: Array,random: RandomNumberGenerator) -> int:
 return NestLobbyVote.winner(ballots,options,SIZE,random)
func resolve_vote() -> void:
 if not dedicated or phase!="voting":return
 if connected_count()!=SIZE:abort_staging();return
 if vote_stage=="setup":
  var modes=[];var maps=[]
  for ballot in votes.values():modes.append(ballot.mode);maps.append(ballot.map)
  selected_mode=winner(modes,MODES,rng);selected_map=winner(maps,MAPS,rng)
  if selected_mode!=0:
   vote_stage="life";epoch+=1;votes.clear();last_request.clear();until=clock()+VOTE_SECONDS;publish();return
  selected_matchup=3
 else:
  var lives=[]
  for ballot in votes.values():lives.append(ballot.get("life",1))
  selected_matchup=winner(lives,[1,2],rng)
 result_text="%s / %s / %s"%[NestArena.MAP_NAMES[selected_map],game.MODE_NAMES[selected_mode],"Annu vs Naki" if selected_mode==0 else "Naki vs Naki" if selected_matchup==1 else "Annu vs Annu"]
 configure_rules(selected_mode,selected_map,selected_matchup);phase="loading";until=clock()+LOAD_SECONDS;loaded.clear();refresh_members();publish()
 if game.network_active:prepare.rpc(game.active_config(),game.lobby_members,epoch,false)
@rpc("authority","call_remote","reliable")
func prepare(config: Dictionary,members: Dictionary,revision: int,rejoining: bool) -> void:
 if not active or local_slot==0:return
 epoch=revision;phase="rejoining" if rejoining else "loading";public_state.members=members
 game.begin_network_match(config,members)
 game.clear_held_input();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 loaded_world.rpc_id(1,epoch)
 changed()
@rpc("any_peer","call_remote","reliable")
func loaded_world(revision: int) -> void:
 if not dedicated or revision!=epoch:return
 var peer=game.multiplayer.get_remote_sender_id()
 if not peers.has(peer):return
 var id=peers[peer]
 if game.running:
  var actor=game.actor_by_id(id)
  if actor==null or not slots[id].bot:return
  rejoin_deadlines.erase(peer)
  reset_owner_commands(actor);actor.remote_peer=peer;slots[id].bot=false;refresh_members()
  # Initialize from authoritative current state before enabling local control.
  var payload=game.snapshot_state()
  restore_world.rpc_id(peer,epoch,payload[0],payload[1],restoration_config());publish();return
 if phase!="loading" or loaded.has(id):return
 loaded[id]=true;publish()
 if loaded.size()!=SIZE or connected_count()!=SIZE:return
 # All six have instantiated the selected map and actors. No AI filled any seat.
 game.start_game();phase="playing"
 var payload=game.snapshot_state()
 restore_world.rpc(epoch,payload[0],payload[1],restoration_config());publish()
@rpc("authority","call_remote","reliable")
func activate(revision: int) -> void:
 if not active or revision!=epoch or not game.running:return
 phase="results" if game.finished else "playing";game.context=phase;game.clear_held_input()
 if game.has_method("network_match_started"):game.call("network_match_started")
 # The UI startup hook initializes a playing HUD; restore result context after it.
 game.context=phase
 if game.finished:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 else:game.capture_mouse()
@rpc("authority","call_remote","reliable")
func restore_world(revision: int,match_state: Dictionary,actors: Array,config: Dictionary) -> void:
 if not active or revision!=epoch or not game.running:return
 game.accept_config(config);game.ranked.begin()
 if config.get("rating_roster") is Dictionary:
  game.ranked.roster=config.rating_roster.duplicate(true)
  game.ranked.channel=str(config.get("rating_channel","human"))
  game.ranked.eligible=false # Ranked eligibility cannot be granted by a player-host config.
 game.receive_snapshot(match_state,actors)
 if is_instance_valid(game.player):
  # Clients may have randomly chosen a different provisional spawn while loading.
  # Seed the visible view from the restored authority before accepting a click.
  game.player.view_correction=Vector3.ZERO
  game.player.reset_physics_interpolation();game.player.reset_aim()
 activate(revision)
func restoration_config() -> Dictionary:
 var config=game.active_config()
 # Roster ratings may already show the finished match. Result validation must
 # retain the original before-match ratings even when joining results late.
 config["rating_roster"]=game.ranked.roster.duplicate(true)
 config["rating_channel"]=game.ranked.channel
 config["rating_eligible"]=game.ranked.eligible
 return config
func reset_owner_commands(actor: NestActor) -> void:
 actor.cmd_queue.clear();actor.cmd_deferred.clear();actor.cmd_template.clear();actor.cmd_last_seq=-1;actor.cmd_credit=0;actor.cmd_starved=0
 actor.remote_shot_id=-1;actor.remote_melee_id=-1;actor.burst_left=0;actor.server_jump_buffer=0
 actor.clear_local_input()
func disconnected(peer: int) -> bool:
 if hybrid.enabled:hybrid.disconnected(peer);return true
 if not dedicated:return false
 anonymous.erase(peer);last_request.erase(peer);rejoin_deadlines.erase(peer)
 if not peers.has(peer):return true
 var id=peers[peer];peers.erase(peer);slots[id].peer=0
 game.command_received.erase(peer);game.remote_shot_clocks.erase(peer);game.remote_interactions.erase(peer);game.remote_throws.erase(peer)
 for key in game.shot_authorizations.keys():
  if str(key).begins_with(str(peer)+":"):game.shot_authorizations.erase(key)
 if game.running:
  var actor=game.actor_by_id(id)
  if actor!=null:
   reset_owner_commands(actor);actor.remote_peer=0;slots[id].bot=true
   if game.nu.birds.has(id):game.nu.birds[id].destroy("owner disconnected")
 else:
  slots.erase(id);abort_staging()
 refresh_members();publish();return true
func abort_staging() -> void:
 epoch+=1;phase="queue";votes.clear();loaded.clear();until=0;result_text="Player disconnected · waiting for six humans again."
 for peer in peers:
  if can_send(peer):cancel_staging.rpc_id(peer,epoch)
@rpc("authority","call_remote","reliable")
func cancel_staging(revision: int) -> void:
 if not active:return
 if game.running:game.stop_game()
 epoch=revision;phase="queue";changed()
func reset_queue() -> void:
 # A connected loading player returns to the queue with everyone else. Old
 # rejoin timers must never disconnect them during the next vote or match.
 rejoin_deadlines.clear()
 game.stop_game()
 for id in slots.keys():
  if int(slots[id].peer)==0:slots.erase(id)
  else:slots[id].bot=false
 abort_staging();refresh_members();maybe_vote();publish()
func publish() -> void:
 if not dedicated:return
 refresh_members()
 public_state={"phase":phase,"epoch":epoch,"connected":connected_count(),"members":game.lobby_members.duplicate(true),"votes":votes.duplicate(true),"seconds":maxf(0,until-clock()),"mode":selected_mode,"map":selected_map,"matchup":selected_matchup,"vote_stage":vote_stage,"result":result_text,"loaded":loaded.size()}
 # Private tickets exist only in slots, never in this broadcast.
 for peer in peers:
  if can_send(peer):state.rpc_id(peer,public_state)
@rpc("authority","call_remote","reliable")
func state(value: Dictionary) -> void:
 if not active:return
 public_state=value;epoch=int(value.epoch);until=clock()+float(value.seconds)
 # During world creation, state broadcasts cannot prematurely release input.
 if phase!="rejoining":phase=str(value.phase)
 game.lobby_members=value.members;game.lobby_kind="matchmaking"
 status=str(value.result)
 game.network_status="Matchmaking · %s:%d · %s · %d/6 humans"%[endpoint,port,phase,int(value.connected)]
 changed()
func changed() -> void:
 if not dedicated and game.has_method("matchmaking_ui_changed"):game.call_deferred("matchmaking_ui_changed")
