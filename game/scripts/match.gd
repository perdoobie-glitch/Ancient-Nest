class_name NestMatch
extends Node3D
var tuning: NestTuning = preload("res://resources/default_tuning.tres")
var prefs = NestPreferences.new()
var arena: NestArena
var actors: Array[NestActor] = []
var replay_active: bool = false
var film_retaining_transport: bool = false
var replay_state: Dictionary = {}
var film_recorder
var film_viewer
var campaign
var nu_sightings: Array[Dictionary]=[{},{}]
var nu: NestNuFlight
var player: NestActor
var running: bool = false
var context: String = "menu"
var sandbox_mode: bool=false
var ranked: NestRankedMatch
var input_window_focused: bool = true
var mode: int = 0 # Extraction, Slayer, TDM
var now: float = 0
var round_number: int = 1
var round_started: float = 0
var deadline: float = 180
var attacking_faction: int = 0
var scores: Array[int] = [0,0]
var finished: bool = false
var break_until: float = 0
var round_reason: String = ""
var event_sequence: int = 0
var damage_events: Dictionary = {}
var site_states: Array[Dictionary] = []
var interaction_progress: float = 0
var interaction_key: String = ""
var interaction_text: String = ""
var interaction_duration: float = 0
var bot_progress: Dictionary = {}
var bot_difficulty: String = "normal"
var bot_difficulty_rules: Dictionary = {}
var bags: Dictionary = {}
var delivered_bags: int = 0
var loaded_bags: int = 0
var bomb_site: int = -1
var bomb_planter: NestActor
var pad_stock: Array[int] = [0,0,0,0,0,0]
var pad_duration: Array[float] = [60,60,60,60,60,45]
var pad_next: float = 150
var power_pad_next: float = 30
var hit_until: float = 0
var hurt_until: float = 0
var forge_session: NestForgeSession
var lobby_kind="custom"
var matchmaking: NestMatchmaking
var flag_bases: Array[Vector3]=[Vector3(-27.2,7.65,-.4),Vector3(27.2,7.65,-.4)]
var kill_feed: Array[Dictionary] = []
var local_kill_notice: String=""
var local_kill_notice_until: float=-100
var seen_kill_notices: Dictionary={}

var messages: Array[String] = []
var last_message: float = -100
var effects: Node3D
var corpses: Node3D
var death_body_keys: Dictionary = {}
var audio: NestAudioManager
var audio_config: Dictionary
var damage_rules: Dictionary
var game_type: GameTypeSettings = GameTypeSettings.new()
var pending_game_type: GameTypeSettings
var applying_round_restart: bool=false
var announcer: NestAnnouncer
var starting_primary: String = "default"
var starting_secondary: String = "default"
var fair_playing_field: bool = false
var fair_health_type: String = "naki"
var match_session: int = 0
var last_cache_cleanup_count: int=0
var network_active: bool = false
var network_status: String = "Offline"
const NETWORK_VERSION: String = "10.5-discord2"
var god_mode: bool=false
var lobby_network: NestLobbyNetwork
var connection_port: int = 7777
var connection_address: String = ""
var lobby_members: Dictionary = {}
var command_sequence: int = 0
var command_last_sent: float = 0
var snapshot_last_sent: float = 0
var snapshot_sequence: int = 0
var snapshot_received: int = -1
var snapshot_fragments: Dictionary = {}
var network_clock: float = 0
var command_received: Dictionary = {}
var shot_authorizations: Dictionary = {}
var remote_interactions: Dictionary = {}
var remote_shot_clocks: Dictionary = {}
var remote_throws: Dictionary = {}
var bot_fill: bool = true
var team_size: int = 2
var selected_character: int = -1
var lobby_ready: bool = false
var selected_faction: int = 0
var bot_play_objectives: bool = true
# Matchup: which character each team uses. 0 Naki vs Annu, 1 Naki vs Naki, 2 Annu vs Annu.
const MATCHUPS=[[0,1],[0,0],[1,1],[1,0]]
var matchup: int = 0
var team_characters: Array[int] = [0,1]
# ---- Network timing, prediction and lag compensation ----
const NET_TICK: float = 1.0/60
const SNAPSHOT_TICKS: int = 2 # 30 Hz initial target; coordinator selects 20/30 before play.
var snapshot_interval_ticks: int = SNAPSHOT_TICKS
const COMMAND_REDUNDANCY: int = 8 # each packet repeats the last 8 commands
const LAG_COMP_MAX_REWIND: float = .150 # bounded rewind window (seconds)
const LAG_COMP_HISTORY: float = .5
const DEFER_TIMEOUT: float = .35
const COMMAND_STALL: float = .25 # host has not simulated this client for this long
var lag_compensation_enabled: bool = true
@export_range(0,150,1) var maximum_hitscan_rewind_ms: float = 150
var command_send_paused: bool = false
var command_drop_packets: int = 0 # test hook: drop the next N outgoing command packets
var last_command_packet: PackedByteArray = PackedByteArray()
var snapshot_tick: int = 0
var clock_ready: bool = false
var clock_offset: float = 0
var clock_spread: float = 0
var host_oneway: float = 0
var interp_delay: float = .1
var remote_view_time: float = 0
var prediction_offset: float = 0
var prediction_ready: bool = false
var lift_offset: float = 0
var lift_sync_ready: bool = false
var hitbox_history: Dictionary = {}
var blocker_history: Array = []
var rewind_blockers: Array = []
var rewind_active: bool = false
var rewind_boxes: Array = []
var rewind_poses: Dictionary = {}
var net_stats: Dictionary = {}
var network_policy = preload("res://scripts/network_policy.gd").new()
var probe_at: float = 0
var physics_started: int = 0
var physics_samples: Array = []
var transport_sample_at: float = 0
class LatePhysics extends Node:
	var game
	func _physics_process(_delta: float) -> void:
		game.late_physics()
		game.finish_physics_measurement()
func _ready() -> void:
	var waterfall=load("res://scripts/waterfall_ambience.gd").new()
	waterfall.game=self;add_child(waterfall)
	prefs.load_saved()
	if "--light-mode" in OS.get_cmdline_user_args():prefs.light_preset()
	ranked=NestRankedMatch.new(self)
	lobby_network=NestLobbyNetwork.new(); lobby_network.name="LobbyNetwork"; lobby_network.game=self; add_child(lobby_network)
	bot_difficulty_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/bot_difficulty.json"))
	damage_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/damage_rules.json"))
	audio_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_audio.json"))
	tuning=tuning.duplicate()
	game_type=game_type.duplicate_settings()
	tuning.health_capacity=float(damage_rules.body_health_max); tuning.shield_capacity=float(damage_rules.shield_max); tuning.armor_capacity=float(damage_rules.armor_max)
	tuning.shield_delay=float(damage_rules.shield_recharge_delay); tuning.shield_rate=float(damage_rules.shield_recharge_rate)
	load_custom_preset()
	sync_game_type_to_legacy() # Keep roster capacity, team size and visible rules in agreement.
	audio=NestAudioManager.new(); audio.playback_enabled=DisplayServer.get_name()!="headless"; add_child(audio)
	for item in NestWeaponCatalog.data().weapons:
		if item.get("slot","") in ["primary","secondary"]:audio.prepare_weapon(NestWeaponCatalog.profile(item.id))
	announcer=NestAnnouncer.new(); announcer.manager=audio; announcer.rules=audio_config; add_child(announcer)
	arena=NestArena.new();arena.map_selection=game_type.map_selection
	add_child(arena)
	flag_bases.assign(arena.flag_positions)
	NestGraphicsQuality.apply_arena(arena,prefs.values)
	forge_session=NestForgeSession.new(self)
	effects=Node3D.new()
	add_child(effects)
	corpses=Node3D.new();corpses.name="DeathBodies";add_child(corpses)
	nu=NestNuFlight.new();nu.name="NuFlight";nu.game=self;add_child(nu)
	var late=LatePhysics.new(); late.name="LatePhysics"; late.game=self; late.process_physics_priority=1000; add_child(late)
	var bomb_audio=load("res://scripts/bomb_audio.gd").new();bomb_audio.game=self;add_child(bomb_audio)
	multiplayer.connected_to_server.connect(network_connected)
	multiplayer.connection_failed.connect(network_failed)
	multiplayer.server_disconnected.connect(network_lost)
	multiplayer.peer_connected.connect(network_peer_connected)
	multiplayer.peer_disconnected.connect(network_peer_left)
	matchmaking=NestMatchmaking.new();matchmaking.name="Matchmaking";matchmaking.game=self;add_child(matchmaking)
	film_recorder=load("res://scripts/film_recorder.gd").new();film_recorder.name="FilmRecorder";film_recorder.game=self;add_child(film_recorder)
	campaign=load("res://scripts/campaign.gd").new();campaign.name="Campaign";campaign.game=self;add_child(campaign)
func next_event() -> int:
	event_sequence+=1
	return event_sequence
func trace(start: Vector3, finish: Vector3, mask: int=1, excludes: Array[RID]=[]) -> Dictionary:
	if start.distance_squared_to(finish)<0.000001: return {}
	if rewind_active and mask&4: return rewound_trace(start,finish,mask,excludes)
	var query=PhysicsRayQueryParameters3D.create(start,finish,mask,excludes)
	query.collide_with_areas=true
	query.hit_from_inside=true
	var result=get_world_3d().direct_space_state.intersect_ray(query)
	return result
func start_game() -> void:
	network_policy=NestNetworkPolicy.new();probe_at=0
	if matchmaking.active and (not matchmaking.dedicated or matchmaking.phase!="loading" or matchmaking.loaded.size()!=6 or matchmaking.connected_count()!=6):return
	if running: return
	ensure_selected_map();
	if not matchmaking.active:save_custom_preset()
	announcer.reset()
	now=0; round_number=1; scores=[0,0]; attacking_faction=0; finished=false
	match_session=randi_range(1,2147483647); prepare_match_input()
	forge_session.prepare_mode(mode)
	NestPlacementSafety.prepare(self)
	running=true; context="playing";get_viewport().disable_3d=false
	team_characters.assign(MATCHUPS[clampi(matchup,0,3)])
	if network_active:
		create_network_actors()
	else:create_offline_actors()
	reset_round()
	arena.validate_navigation(arena.navigation_revision)
	ranked.begin()
	if network_active and multiplayer.is_server():
		begin_network_match.rpc(active_config(),lobby_members)
	capture_mouse()
	announce("match_start")
func stop_game() -> void:
	if film_recorder!=null and not replay_active:film_recorder.finish()
	var ballot=get_node_or_null("LobbyVote")
	if ballot!=null and not is_client():ballot.reset()
	var waterfall=get_node_or_null("WaterfallAmbience")
	if waterfall!=null:waterfall.stop_immediately()
	if ranked!=null:ranked.clear()
	if network_active and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED and multiplayer.is_server() and running:
		if matchmaking.dedicated:
			for peer in matchmaking.peers:
				if matchmaking.can_send(peer):end_network_match.rpc_id(peer)
		else:end_network_match.rpc()
	running=false; context="menu"
	announcer.reset(); audio.stop_all()
	for i in range(arena.deposits.size()): arena.set_site_visual(i,"sealed",now)
	for actor in actors: actor.queue_free()
	actors.clear(); player=null
	for i in range(arena.deposits.size()): arena.set_site_visual(i,"sealed",now)
	clear_effects()
	update_flag_visuals()
	bags.clear(); finished=false
	if pending_game_type!=null:
		game_type=pending_game_type;pending_game_type=null;sync_game_type_to_legacy();ensure_selected_map();save_custom_preset()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func reset_round() -> void:
	nu_sightings=[{},{}]
	if pending_game_type!=null and not applying_round_restart and not is_client():
		restart_round_in_match();return
	local_kill_notice="";local_kill_notice_until=-100;seen_kill_notices.clear()
	forge_session.prepare_mode(mode)
	if not NestPlacementSafety.prepare(self):round_reason="No clear placement available. Edit the map and restart the round."
	round_started=now; deadline=now+minf(120.0,tuning.round_seconds) if mode==MODE_CS else now+tuning.round_seconds if tuning.round_seconds>0 else INF; break_until=0
	bomb_site=-1; delivered_bags=0; loaded_bags=0; bags.clear(); bot_progress.clear(); damage_events.clear(); shot_authorizations.clear(); remote_shot_clocks.clear(); remote_interactions.clear()
	interaction_progress=0; interaction_key=""
	clear_effects()
	site_states.clear()
	for i in range(2): site_states.append({"stage":"sealed","bomb_at":0.0,"start_at":0.0,"work":0.0})
	pad_stock.clear();pad_duration.clear()
	for kind in arena.pad_kinds:
		pad_stock.append(0 if kind in ["cloak","overshield"] or not game_type.map_weapons else 1);pad_duration.append(tuning.overshield_duration if kind=="overshield" else 60)
	pad_next=now+150*game_type.weapon_respawn_percent/100.0;power_pad_next=now+tuning.pickup_delay
	arena.set_sides(attacking_faction,[team_name(0),team_name(1)])
	arena.set_meta("bomb_only",mode==MODE_CS)
	for i in range(2):
		arena.deposit_labels[i].text=("A" if i==0 else "B")+(" · BOMB SITE" if mode==MODE_CS else " · SEALED")
	for i in range(2): arena.deposits[i].visible=mode in [0,MODE_CS]; arena.deposit_labels[i].visible=mode in [0,MODE_CS];arena.set_site_visual(i,"sealed",now)
	for actor in actors: actor.respawn()
	reset_cs_bomb()
	reset_flags()
	if round_number>1: announce("round_start")
func choose_spawn(actor: NestActor) -> Vector3:
	if campaign!=null and campaign.active:return campaign.choose_spawn(actor)
	var side=0 if actor.is_attacker() else 1
	if mode not in [0,MODE_CS]: side=actor.faction
	return NestPlacementSafety.spawn(self,actor,arena.spawns[side])
func _physics_process(delta: float) -> void:
	if replay_active:return
	physics_started=Time.get_ticks_usec()
	if campaign!=null and campaign.paused():return
	if not running or matchmaking.blocks_simulation(): return
	if bool(arena.get_meta("placement_blocked",false)):return
	now+=delta
	announcer.tick(self)
	if not is_client():process_pending_grenade_releases()
	network_clock+=delta
	if network_active:
		if is_client():
			# Track host time smoothly: slew the clock instead of jumping it to
			# each snapshot, so jitter cannot move timers backwards.
			if clock_ready:
				var error=local_clock()+clock_offset-now
				if absf(error)>.25: now+=error
				else: now+=clampf(error,-delta*.05,delta*.05)
				update_remote_view_time(delta)
			interaction_text=interaction_for(player).get("text","") if context=="playing" and is_instance_valid(player) else ""
			return
		for actor in actors:
			if actor.remote_peer>1: update_remote_interaction(actor,delta)
	if finished: return
	if campaign!=null and campaign.active:campaign.tick(delta);return
	if break_until>0:
		if now>=break_until:
			round_number+=1
			if mode==0 and (round_number-1)%tuning.role_switch_rounds==0: switch_sides()
			if mode==MODE_CS and round_number==11:
				attacking_faction=1-attacking_faction;announce("halftime")
			reset_round()
		return
	# Expiry has priority over completions on the same tick.
	if mode==MODE_CS:
		update_cs_round()
		if break_until>now or finished:return
	elif now>=deadline:
		if mode==0: end_round("Time expired")
		else: finish_match()
		return
	if mode==0: update_objectives(delta)
	elif mode==MODE_CTF: update_ctf()
	if now>=pad_next:
		for i in range(arena.pads.size()):
			if game_type.map_weapons and arena.pad_kinds[i] not in ["cloak","overshield"] and pad_stock[i]==0:pad_stock[i]=1
		pad_next+=150*game_type.weapon_respawn_percent/100.0
	if now>=power_pad_next:
		for i in [4,5]:
			if pad_stock[i]==0:pad_stock[i]=1
			else:pad_duration[i]=minf(tuning.pickup_stack_cap,pad_duration[i]+tuning.pickup_time_topup)
		power_pad_next+=tuning.pickup_interval
	for i in range(arena.pads.size()):
		arena.pad_meshes[i].visible=pad_stock[i]>0
		if pad_stock[i]>0:
			arena.pad_meshes[i].rotation.y=now
			for actor in actors:
				if arena.pad_kinds[i] in ["cloak","overshield"] and actor.alive and actor.global_position.distance_to(arena.pads[i])<1.25: take_pickup(actor,i); break
	if is_instance_valid(player) and player.alive and context=="playing":
		update_player_interaction(delta)
	else: interaction_progress=0; interaction_key=""; interaction_text=""
	if mode==MODE_CS and interaction_text.is_empty() and is_instance_valid(player):interaction_text=cs_summary(player)
	elif mode!=0 and interaction_text.is_empty():
		interaction_text="Slayer · Every elimination counts" if mode==1 else "Team Deathmatch · Eliminate the opposing team" if mode==2 else "Capture the Flag · Bring the enemy flag to your base"
func update_objectives(delta: float) -> void:
	for i in range(2):
		var s=site_states[i]
		if s.stage=="planted" and now>=s.bomb_at:
			s.stage="off"; scores[attacking_faction]+=1
			if is_instance_valid(bomb_planter): bomb_planter.detonations+=1
			bomb_impact(arena.sites[i]+Vector3(0,1,0))
			if network_active and multiplayer.is_server(): objective_blast.rpc(i,match_session,round_number)
			sound("blast",arena.sites[i],false)
			if scores[attacking_faction]>=tuning.score_limit: finish_match(); return
		if s.stage=="starting" and now>=s.start_at: s.stage="drilling"; announce("drill_commencing")
		if s.stage=="drilling":
			s.work=minf(tuning.drill_seconds,s.work+delta)
			if s.work>=tuning.drill_seconds: s.stage="complete"; sound("objective",arena.sites[i],false); announce("drill_complete")
		arena.set_site_visual(i,s.stage,now)
		arena.deposit_labels[i].text=("A" if i==0 else "B")+" · "+s.stage.to_upper()
		if s.stage=="drilling": arena.deposit_labels[i].text+="\n%d / %d s"%[s.work,tuning.drill_seconds]
		if s.stage=="starting": arena.deposit_labels[i].text+="\nStarting %.1f"%maxf(0,s.start_at-now)
func pickup_choice(actor: NestActor) -> Dictionary:
	if not game_type.weapon_pickups:return {}
	var nearest=-1;var distance=1.5
	for i in range(arena.pads.size()):
		if i>=pad_stock.size() or pad_stock[i]<=0 or arena.pad_kinds[i] in ["cloak","overshield"]:continue
		var d=actor.global_position.distance_to(arena.pads[i])
		if d<distance:distance=d;nearest=i
	if nearest<0:return {}
	return {"key":"pickup:"+str(nearest),"pad":nearest,"seconds":0.0,"site":-1,"text":"Press %s · Pick up %s"%[prefs.key_label("interact"),NestWeaponCatalog.profile(arena.pad_kinds[nearest]).title]}
func interaction_for(actor: NestActor) -> Dictionary:
	if campaign!=null and campaign.active:return campaign.interaction(actor)
	if not actor.alive or (nu!=null and nu.blocked(actor)): return {}
	var pickup=pickup_choice(actor)
	if not pickup.is_empty():return pickup
	if mode==MODE_CS:return cs_interaction(actor)
	if mode!=0:return {}
	if actor.carrying and actor.is_attacker() and actor.global_position.distance_to(arena.ship_position)<3:
		return {"key":"deliver","text":"Press %s · Deliver bag to base ship"%prefs.key_label("interact"),"seconds":0.0,"site":-1}
	if actor.is_attacker() and not actor.carrying:
		for id in bags:
			if actor.global_position.distance_to(bags[id].position)<1.6: return {"key":"recover:%d"%id,"text":"Press %s · Recover dropped bag"%prefs.key_label("interact"),"seconds":0.0,"site":-1,"bag":id}
	for i in range(2):
		if actor.global_position.distance_to(arena.sites[i])>3.4: continue
		var s=site_states[i]
		var action=""
		var duration=0.0
		var description=""
		if actor.is_attacker():
			if s.stage=="sealed" and bomb_site<0: action="plant"; duration=tuning.plant_seconds; description="Plant bomb"
			elif s.stage=="off": action="activate"; duration=tuning.switch_seconds; description="Activate drill"
			elif s.stage=="complete" and not actor.carrying and loaded_bags<tuning.bag_stock: action="load"; duration=tuning.load_seconds; description="Load gold bag"
		else:
			if s.stage=="planted": action="defuse"; duration=tuning.defuse_seconds; description="Defuse bomb"
			elif s.stage in ["starting","drilling"]: action="shutdown"; duration=tuning.switch_seconds; description="Switch drill off"
		if action!="": return {"key":action+":%d"%i,"text":"Hold %s · %s"%[prefs.key_label("interact"),description],"seconds":duration,"site":i}
	return {}
func update_player_interaction(delta: float) -> void:
	var chosen=interaction_for(player)
	if chosen.is_empty(): interaction_progress=0; interaction_key=""; interaction_text=""; interaction_duration=0; return
	interaction_text=chosen.text; interaction_duration=chosen.seconds
	if chosen.key!=interaction_key: interaction_progress=0; interaction_key=chosen.key
	if chosen.seconds==0:
		if Input.is_action_just_pressed("interact") and not player.suppressed_actions.has("interact"): complete_interaction(player,chosen)
	elif player.gameplay_held("interact"):
		if interaction_progress==0 and chosen.key.begins_with("defuse:"):global_objective_sound("bomb_defuse_start")
		player.burst_left=0
		if player.action_state in ["reloading","switching","throwing"]: player.action_state="ready"; player.action_until=now
		interaction_progress+=delta
		if interaction_progress>=chosen.seconds: complete_interaction(player,chosen); interaction_progress=0; interaction_key=""
	else: interaction_progress=0
func complete_interaction(actor: NestActor, choice: Dictionary) -> bool:
	if campaign!=null and campaign.active:return campaign.interact(actor,choice)
	if not actor.alive or finished or break_until>now or (now>=deadline and not (mode==MODE_CS and cs_planted())): return false
	var current=interaction_for(actor)
	if current.is_empty() or current.key!=choice.key: return false
	var action: String=choice.key.split(":")[0]
	if action=="pickup":
		take_pickup(actor,int(choice.pad));return true
	if mode==MODE_CS:return complete_cs_interaction(actor,choice)
	if action=="deliver":
		if not actor.carrying: return false
		actor.carrying=false; actor.bag_id=-1; actor.delivered+=1; delivered_bags+=1; scores[attacking_faction]+=1
		if scores[attacking_faction]>=tuning.score_limit: finish_match()
		elif delivered_bags>=tuning.bag_stock: end_round("All gold extracted")
	elif action=="recover":
		var id: int=choice.bag
		if not bags.has(id): return false
		bags[id].node.queue_free(); bags.erase(id); actor.carrying=true; actor.bag_id=id
	else:
		var site: int=choice.site
		var state=site_states[site]
		match action:
			"plant": state.stage="planted"; state.bomb_at=now+tuning.bomb_fuse; bomb_site=site; bomb_planter=actor; announce("bomb_planted");global_objective_sound("bomb_planted_alert")
			"defuse": announce("bomb_defused"); end_round("Bomb defused")
			"activate": state.stage="starting"; state.start_at=now+tuning.startup_seconds
			"shutdown": state.stage="off"; state.start_at=0; state.work=state.work if tuning.retain_drill_work else 0
			"load":
				if loaded_bags>=tuning.bag_stock or actor.carrying: return false
				loaded_bags+=1; actor.carrying=true; actor.bag_id=next_event()
	sound("objective",actor.global_position,actor.local_player)
	return true
func drop_bag(actor: NestActor) -> void:
	var pos=actor.global_position
	var support=trace(pos+Vector3(0,0.3,0),pos-Vector3(0,30,0),1)
	if support.is_empty(): pos=arena.sites[maxi(0,bomb_site)]+Vector3(-2,0.2,0)
	else: pos=support.position+Vector3(0,0.1,0)
	var safe=NestPlacementSafety.dropped(self,pos,.3,.6,arena.sites[maxi(0,bomb_site)]+Vector3(-2,0,0))
	if not safe.is_finite():actor.carrying=false;actor.bag_id=-1;return
	pos=safe
	var node=Node3D.new()
	effects.add_child(node)
	node.position=pos+Vector3(0,0.15,0)
	arena.kit.box(node,Vector3(0,0.2,0),Vector3(0.5,0.4,0.4),arena.kit.gold)
	arena.kit.label(node,Vector3(0,1,0),"GOLD BAG",Color("eac982"),24)
	bags[actor.bag_id]={"position":pos,"node":node}
	actor.carrying=false; actor.bag_id=-1
func bomb_impact(position: Vector3) -> void:
	var effect=NestBlastFX.new()
	effect.visual_multiplier=10.0
	effects.add_child(effect)
	effect.global_position=position
func nearest_objective_actor(actor: NestActor, position: Vector3) -> bool:
	for other in actors:
		if other==actor or not other.alive or other.faction!=actor.faction:continue
		var a=actor.global_position.distance_squared_to(position)
		var b=other.global_position.distance_squared_to(position)
		if b<a-.1 or (absf(a-b)<=.1 and other.net_id<actor.net_id):return false
	return true
func bot_goal(actor: NestActor) -> Vector3:
	if campaign!=null and campaign.active:return campaign.enemy_goal(actor)
	if mode==MODE_CS and bot_play_objectives:return cs_bot_goal(actor)
	if mode==MODE_CTF and bot_play_objectives and flags.size()==2: return arena.nav_points[arena.nearest_nav(ctf_bot_goal(actor))]
	if mode==0 and bot_play_objectives:
		if actor.carrying: return arena.ship_position
		var site=maxi(0,bomb_site)
		if bomb_site<0 and arena.map_selection>=3:
			site=0 if actor.global_position.distance_squared_to(arena.sites[0])<actor.global_position.distance_squared_to(arena.sites[1]) else 1
		elif bomb_site<0 and actor.global_position.y<3: site=1
		var position=arena.sites[site]
		if not nearest_objective_actor(actor,position):
			var angle=float(actor.net_id%6)*TAU/6.0
			return position+Vector3(cos(angle)*4.5,0,sin(angle)*4.5)
		return position+Vector3(-2.5,0,0)
	if is_instance_valid(actor.target): return arena.nav_points[arena.nearest_nav(actor.target.global_position)]
	if not actor.bot_route.is_empty() and actor.global_position.distance_to(actor.bot_destination)>1.2: return actor.bot_destination
	return arena.nav_points[randi()%arena.nav_points.size()]
func bot_interact(actor: NestActor, delta: float) -> void:
	if mode==MODE_CS and cs_carrier==actor.net_id and actor.is_attacker() and actor.action_state=="ready":
		for position in arena.sites:
			if actor.global_position.distance_to(position)<3.4:actor.bomb_equipped=true
	var pickup=pickup_choice(actor)
	if not pickup.is_empty():complete_interaction(actor,pickup)
	if not bot_play_objectives or mode not in [0,MODE_CS]: return
	var chosen=interaction_for(actor)
	var id=actor.get_instance_id()
	if chosen.is_empty(): bot_progress.erase(id); return
	if not bot_progress.has(id) or bot_progress[id].key!=chosen.key:
		bot_progress[id]={"key":chosen.key,"time":0.0}
		if chosen.key.begins_with("defuse:"):global_objective_sound("bomb_defuse_start")
	actor.burst_left=0
	bot_progress[id].time+=delta
	if bot_progress[id].time>=chosen.seconds: complete_interaction(actor,chosen); bot_progress.erase(id)
func end_round(reason: String) -> void:
	if finished or break_until>now: return
	round_reason=reason; break_until=now+tuning.round_break; interaction_progress=0
	for actor in actors: actor.burst_left=0
	clear_effects()
	announce("round_end")
	bags.clear()
func finish_match() -> void:
	if campaign!=null and campaign.active:return
	if finished:return
	finished=true; interaction_progress=0; context="results"; Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for actor in actors: actor.burst_left=0
	announce("match_end")
	ranked.complete()
	for actor in actors:
		if not actor.local_player and actor.remote_peer<=1: continue
		var result="draw" if scores[0]==scores[1] else "you_win" if scores[actor.faction]>scores[1-actor.faction] else "you_lose"
		announce(result,actor)
func register_kill(attacker: NestActor, victim: NestActor, reason: String) -> void:
	announcer.record_kill(self,attacker,victim,reason)
	if attacker.local_player:receive_kill_notice(victim.username,victim.net_id,victim.life_id,match_session,round_number)
	elif network_active and multiplayer.is_server() and attacker.remote_peer>1:
		receive_kill_notice.rpc_id(attacker.remote_peer,victim.username,victim.net_id,victim.life_id,match_session,round_number)
	kill_feed.push_front({"text":attacker.username+"  →  "+victim.username+"  ·  "+reason,"until":now+5})
	if kill_feed.size()>4: kill_feed.pop_back()
	if mode==2: scores[attacker.faction]+=1
	elif mode==1: scores[attacker.faction]=maxi(scores[attacker.faction],attacker.kills)
	if mode!=0 and (scores[0]>=tuning.score_limit or scores[1]>=tuning.score_limit): finish_match()
@rpc("authority","call_remote","reliable")
func receive_kill_notice(victim_name: String, victim_id: int, life: int, session: int, round_id: int) -> void:
	if film_retaining_transport:return
	if not running or session!=match_session or round_id!=round_number:return
	var key="%d:%d:%d:%d"%[session,round_id,victim_id,life]
	if seen_kill_notices.has(key):return
	seen_kill_notices[key]=true
	if seen_kill_notices.size()>128:seen_kill_notices.erase(seen_kill_notices.keys()[0])
	local_kill_notice=victim_name.strip_edges().replace("\n"," ").replace("\r"," ").substr(0,32)
	local_kill_notice_until=now+3.5
@rpc("authority","call_remote","reliable")
func objective_blast(index: int, session: int, round_id: int) -> void:
	if film_retaining_transport:return
	if not running or session!=match_session or round_id!=round_number or index not in [0,1]: return
	bomb_impact(arena.sites[index]+Vector3(0,1,0)); sound("blast",arena.sites[index],false)
func launch_bullet(actor: NestActor, weapon: NestWeapon, pos: Vector3, direction: Vector3, _pellet: int, cosmetic: bool=false, supplied_id: int=0, first_in_burst: bool=true) -> void:
	actor.tracer_sequence+=1
	var draw_tracer=actor.tracer_sequence%maxi(1,weapon.tracer_every_n_shots)==0
	var bullet=Node3D.new()
	bullet.set_script(load("res://scripts/bullet.gd"))
	bullet.game=self; bullet.owner_actor=actor; bullet.profile=weapon; bullet.direction=direction; bullet.event_id=supplied_id if supplied_id>0 else next_event()*16; bullet.cosmetic=cosmetic; bullet.round_id=round_number
	# Penetrating bullets add victims to this list. Keep that per bullet so a
	# sniper hit cannot make later shots ignore that opponent permanently.
	bullet.excludes=actor.ray_exclusions().duplicate()
	if network_active and multiplayer.is_server() and not cosmetic: cosmetic_bullet.rpc(actor.net_id,weapon.kind,pos,direction,match_session,round_number,_pellet==0,first_in_burst)
	bullet.draw_tracer=draw_tracer
	bullet.position=pos
	effects.add_child(bullet)
	# Hitscan and projectiles share the camera-ray origin; muzzle flashes stay cosmetic.
	if weapon.speed==0:
		bullet.resolve_hit(pos,pos+direction*weapon.max_range)
		if draw_tracer:
			var tracer=NestTracer.new();tracer.game=self;tracer.streak_width=NestTracer.WIDTH*(1.0 if actor.local_player else 1.7);effects.add_child(tracer)
			tracer.setup(pos,bullet.hit_position if bullet.hit_position.is_finite() else pos+direction*weapon.max_range,weapon.tracer_opacity*(1.0 if actor.local_player else 1.6),weapon.kind=="sniper")
		bullet.queue_free()
func launch_grenade(actor: NestActor, kind: int, cosmetic: bool=false, supplied_id: int=0, origin: Vector3=Vector3.INF, direction: Vector3=Vector3.INF, inherited_velocity: Vector3=Vector3.INF) -> void:
	var grenade=RigidBody3D.new()
	grenade.set_script(load("res://scripts/grenade.gd"))
	grenade.game=self; grenade.owner_actor=actor; grenade.sticky=kind==1; grenade.event_id=supplied_id if supplied_id>0 else next_event()*16; grenade.cosmetic=cosmetic; grenade.round_id=round_number
	if origin==Vector3.INF: origin=actor.grenade_release_origin()
	if direction==Vector3.INF: direction=actor.aim_direction()
	if inherited_velocity==Vector3.INF: inherited_velocity=actor.velocity
	var hand_blocked=trace(actor.eye.global_position,origin,1,actor.ray_exclusions())
	if not hand_blocked.is_empty():origin=hand_blocked.position+hand_blocked.normal*.09
	var pos=origin+direction*0.55
	var blocked=trace(origin,pos,1,actor.ray_exclusions())
	if not blocked.is_empty(): pos=blocked.position+blocked.normal*0.09
	grenade.launch_velocity=direction*14+Vector3.UP*3+inherited_velocity*0.75
	grenade.position=pos
	effects.add_child(grenade)
	if network_active and multiplayer.is_server() and not cosmetic: cosmetic_grenade.rpc(actor.net_id,kind,origin,direction,inherited_velocity,match_session,round_number)
func explode(pos: Vector3, attacker: NestActor, event_id: int, damage: float, cosmetic: bool=false, weapon_kind: String="") -> void:
	var definition=NestWeaponCatalog.for_kind(weapon_kind)
	var radius=float(definition.get("splash_radius_m",damage_rules.legacy_explosion_radius))
	var audio_id="rocket_launcher_explosion" if weapon_kind=="rocket" else weapon_kind+"_explosion" if not weapon_kind.is_empty() else "frag_grenade_explosion"
	if cosmetic:
		impact(pos,Vector3.UP,true); audio.play_sound(audio_id,pos); return
	for bird in nu.birds.values().duplicate():
		if is_instance_valid(bird) and bird.global_position.distance_to(pos)<=radius and trace(pos,bird.global_position,1).is_empty():bird.destroy("explosion")
	for victim in actors:
		if not victim.alive: continue
		var offset=victim.global_position+Vector3(0,NestActor.STAND_CENTER,0)-pos
		var distance=offset.length()
		if distance>radius: continue
		var exposed=0.0
		for h in damage_rules.explosion_probe_heights_m:
			if trace(pos,victim.global_position+Vector3(0,float(h)*NestActor.SIZE,0),1).is_empty(): exposed+=1.0/damage_rules.explosion_probe_heights_m.size()
		var factor=clampf(1-distance/radius,0,1)*exposed
		if factor<=0: continue
		if is_client() and is_instance_valid(attacker) and attacker.local_player:
			report_blast.rpc_id(1,event_id,victim.net_id,victim.life_id,factor,offset.normalized() if distance>0.01 else Vector3.UP,match_session)
		elif victim.take_damage(damage*factor,"torso","explosion",false,attacker,event_id,pos,weapon_kind,distance):
			var direction=offset.normalized() if distance>0.01 else Vector3.UP
			var knockback=game_type.explosion_knockback_percent/100.0
			victim.external=(victim.external+direction*float(damage_rules.blast_impulse)*factor*knockback+Vector3.UP*float(damage_rules.blast_up_impulse)*factor*knockback).limit_length(float(damage_rules.max_blast_impulse))
			if victim.alive and victim==attacker and weapon_kind in ["frag_grenade","plasma_grenade"]:
				var feet=victim.global_position-pos
				var horizontal=Vector2(feet.x,feet.z).length()
				# A close detonation underneath a rising player adds to jump velocity.
				# No bonus for airborne downward motion or grenades above the player.
				if feet.y>=-.12 and feet.y<=2.0 and horizontal<2.0 and victim.controlled.y>0.0:
					var strength=(1.0-horizontal/2.0)*clampf(1.0-maxf(0,feet.y)/3.0,0,1)*exposed*knockback
					victim.external.y=minf(12.0,maxf(victim.external.y,7.5*strength))
	impact(pos,Vector3.UP,true); audio.play_sound(audio_id,pos)
func impact(pos: Vector3, normal: Vector3, big: bool=false) -> void:
	if big:
		var blast=NestBlastFX.new(); effects.add_child(blast); blast.position=pos
		return
	var mesh=arena.kit.sphere(effects,pos+(normal*0.02),0.5 if big else 0.035,arena.kit.lamp)
	var tween=create_tween()
	tween.tween_property(mesh,"scale",Vector3.ONE*(4 if big else 0.1),0.22 if big else 0.08)
	tween.tween_callback(mesh.queue_free)
func take_pickup(actor: NestActor, index: int) -> void:
	if pad_stock[index]<=0 or (arena.pad_kinds[index] not in ["cloak","overshield"] and not game_type.weapon_pickups): return
	var kind=arena.pad_kinds[index]
	if kind not in ["cloak","overshield"]:
		var path=kind
		var weapon: NestWeapon=NestWeaponCatalog.profile(path)
		var found=-1
		for i in range(actor.weapons.size()):
			if actor.weapons[i].kind==weapon.kind: found=i
		if found<0:
			actor.weapons.append(weapon); actor.ammo.append(weapon.magazine); actor.reserve.append(weapon.reserve+(pad_stock[index]-1)*tuning.pickup_ammo_topup)
			actor.slot=actor.weapons.size()-1
		else: actor.reserve[found]+=weapon.magazine+pad_stock[index]*tuning.pickup_ammo_topup
	elif kind=="cloak": actor.cloak_deadline=now+pad_duration[index]
	else: actor.overshield=tuning.overshield_capacity; actor.over_deadline=now+pad_duration[index]
	pad_stock[index]=0
	sound("weapon_pickup" if kind not in ["cloak","overshield"] else "objective",actor.global_position,actor.local_player)
func sound(name: String, pos: Vector3, local: bool) -> void:
	var id=str(audio.manifest.get("aliases",{}).get(name,name))
	audio.play_sound(id,pos,{"spatial":not local})
func active_damage_model() -> String:
	return fair_health_type if mode in [1,2,3] and fair_playing_field else "faction"
func surface_tag(collider: Object) -> String:
	if is_instance_valid(collider) and collider.has_meta("surface_material"): return str(collider.get_meta("surface_material"))
	return str(audio_config.default_material)
func weapon_falloff(weapon: Dictionary, distance: float) -> float:
	if distance>float(weapon.max_effective_range_m): return 0
	if distance<=float(weapon.falloff_start_m): return 1
	if distance>=float(weapon.falloff_end_m): return float(weapon.falloff_min_percent)
	return lerpf(1,float(weapon.falloff_min_percent),inverse_lerp(float(weapon.falloff_start_m),float(weapon.falloff_end_m),distance))
func sync_game_type_to_legacy() -> void:
	game_type.validate()
	apply_player_traits()
	tuning.round_seconds=minf(120.0,game_type.time_limit_seconds) if game_type.mode==MODE_CS else game_type.time_limit_seconds
	tuning.score_limit=game_type.score_to_win
	tuning.respawn_seconds=game_type.respawn_seconds
	tuning.radar_range=game_type.radar_range
	tuning.plant_seconds=game_type.plant_seconds
	tuning.defuse_seconds=game_type.defuse_seconds
	tuning.bomb_fuse=game_type.bomb_timer_seconds
	tuning.drill_seconds=game_type.drill_seconds
	tuning.load_seconds=game_type.bag_load_seconds
	tuning.bag_stock=game_type.bag_stock
	tuning.friendly_fire=game_type.friendly_fire_mode!=0
	mode=game_type.mode
	matchup=game_type.matchup
	team_size=game_type.max_players_per_team
	bot_fill=game_type.bots_fill_empty_slots
	bot_play_objectives=game_type.bots_play_objectives
	starting_primary=game_type.starting_primary
	starting_secondary=game_type.starting_secondary
	bot_difficulty=["easy","normal","hard","insane"][clampi(game_type.bot_difficulty,0,3)]

func apply_player_traits() -> void:
	# Always derive capacities from base rules: repeated Apply never compounds them.
	tuning.health_capacity=float(damage_rules.body_health_max)*game_type.max_health_percent/100.0
	tuning.shield_capacity=float(damage_rules.shield_max)*game_type.shield_strength_percent/100.0 if game_type.shields_enabled else 0.0
	tuning.shield_delay=game_type.shield_recharge_delay
	tuning.shield_rate=float(damage_rules.shield_recharge_rate)*game_type.shield_recharge_rate_percent/100.0 if game_type.shields_enabled else 0.0
func apply_game_type_settings(settings: GameTypeSettings) -> bool:
	if matchmaking!=null and matchmaking.active:return false
	if is_client():return false
	var next=settings.duplicate_settings()
	if running:
		next.validate();pending_game_type=next
		if not sandbox_mode:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://gametypes"))
			ResourceSaver.save(next,"user://gametypes/custom_game.tres")
		if network_active:receive_pending_rules.rpc(next.to_network_dict(),match_session)
		return true
	game_type=next;sync_game_type_to_legacy();ensure_selected_map()
	for member in lobby_members.values():member["ready"]=false
	lobby_ready=false
	save_custom_preset()
	if has_method("broadcast_lobby"):call("broadcast_lobby")
	return true
func ensure_selected_map() -> void:
	if not is_instance_valid(arena) or arena.map_selection==game_type.map_selection:return
	if forge_session!=null and forge_session.model!=null:
		# Keep a copy before switching base maps. Explicit map choice replaces the live layout.
		if forge_session.dirty:forge_session.save()
		forge_session.model.destroy();forge_session.model=null
		forge_session.active=false;forge_session.testing=false;forge_session.dirty=false
		forge_session.history.clear();forge_session.revision+=1
	var previous=arena;remove_child(previous);previous.queue_free()
	arena=NestArena.new();arena.map_selection=game_type.map_selection;add_child(arena)
	NestGraphicsQuality.apply_arena(arena,prefs.values);flag_bases.assign(arena.flag_positions)
	for item in flag_nodes:
		item.base.queue_free();item.flag.queue_free()
	flag_nodes.clear();flag_labels.clear();flags.clear()
	if has_method("map_changed_ui"):call("map_changed_ui")
func refresh_live_traits() -> void:
	for actor in actors:
		actor.refresh_traits()
		# A bigger capacity is not a free heal. Lower capacities clamp safely.
		actor.armor=minf(actor.armor,actor.tuning.armor_capacity)
		actor.helmet_hp=minf(actor.helmet_hp,float(actor.traits.settings.annu_head_armor)*actor.traits.helmet_strength_percent/100.0)
		actor.health=minf(actor.health,actor.tuning.health_capacity)
		actor.shield=minf(actor.shield,actor.tuning.shield_capacity if actor.damage_model()=="naki" else 0.0)
		if actor.shield<=0:actor.body_phase=true
	# Adjust the existing round's duration without restarting objectives/scores.
	if not is_client():deadline=round_started+minf(120.0,maxf(1,game_type.time_limit_seconds)) if mode==MODE_CS else round_started+game_type.time_limit_seconds if game_type.time_limit_seconds>0 else INF
	if has_method("set_hud_preferences"):call("set_hud_preferences")
@rpc("authority","call_remote","reliable")
func receive_live_rules(data: Dictionary, session: int, _round_id: int) -> void:
	if film_retaining_transport:return
	if not running or session!=match_session:return
	game_type.apply_network_dict(data);sync_game_type_to_legacy();refresh_live_traits()
	if has_method("live_rules_changed"):call("live_rules_changed")
func sync_legacy_to_game_type() -> void:
	game_type.mode=mode
	game_type.matchup=matchup
	game_type.max_players_per_team=team_size
	game_type.max_players=clampi(game_type.max_players,2,16)
	game_type.bots_fill_empty_slots=bot_fill
	game_type.bots_play_objectives=bot_play_objectives
	game_type.time_limit_seconds=tuning.round_seconds
	game_type.round_time_limit_seconds=tuning.round_seconds
	game_type.score_to_win=tuning.score_limit
	game_type.bag_stock=tuning.bag_stock
	game_type.starting_primary=starting_primary
	game_type.starting_secondary=starting_secondary
	game_type.bot_difficulty=maxi(0,["easy","normal","hard","insane"].find(bot_difficulty))

func save_custom_preset() -> void:
	sync_legacy_to_game_type()
	game_type.validate();apply_player_traits()
	if sandbox_mode:return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://gametypes"))
	ResourceSaver.save(pending_game_type if pending_game_type!=null else game_type,"user://gametypes/custom_game.tres")
	var config=ConfigFile.new() # legacy compatibility with older v0.12 builds
	for key in active_config():
		if key!="session": config.set_value("custom",key,active_config()[key])
	config.save("user://custom_game.cfg")

func load_custom_preset() -> void:
	if ResourceLoader.exists("user://gametypes/custom_game.tres"):
		var loaded=ResourceLoader.load("user://gametypes/custom_game.tres","",ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is GameTypeSettings:
			game_type=loaded.duplicate_settings(); sync_game_type_to_legacy()
			# These established faction options live in the legacy lobby config.
			var extras=ConfigFile.new()
			if extras.load("user://custom_game.cfg")==OK:
				fair_playing_field=bool(extras.get_value("custom","fair_playing_field",false))
				fair_health_type=String(extras.get_value("custom","fair_health_type","naki"))
				if fair_health_type not in ["naki","annu"]:fair_health_type="naki"
				matchup=game_type.matchup # Resource settings take precedence over old lobby config.
			game_type.matchup=matchup
			return
	var config=ConfigFile.new()
	if config.load("user://custom_game.cfg")!=OK: return
	var current=active_config()
	for key in current:
		if key!="session": current[key]=config.get_value("custom",key,current[key])
	accept_config(current)
	sync_legacy_to_game_type()

var objective_audio_sequence: int=0
var received_objective_audio: int=0
var last_defuse_cue: float=-INF
func global_objective_sound(id: String) -> void:
	if is_client() or id not in ["bomb_planted_alert","bomb_defuse_start"]:return
	if id=="bomb_defuse_start":
		if now-last_defuse_cue<.35:return
		last_defuse_cue=now
	objective_audio_sequence+=1
	audio.play_sound(id,Vector3.ZERO,{"spatial":false})
	if network_active:receive_objective_sound.rpc(id,objective_audio_sequence,match_session,round_number)
@rpc("authority","call_remote","reliable")
func receive_objective_sound(id: String, sequence: int, session: int, round_id: int) -> void:
	if film_retaining_transport:return
	if not running or session!=match_session or round_id!=round_number or sequence<=received_objective_audio or id not in ["bomb_planted_alert","bomb_defuse_start"]:return
	received_objective_audio=sequence;audio.play_sound(id,Vector3.ZERO,{"spatial":false})
func announce(id: String, target: NestActor=null) -> void:
	if target==null or target.local_player: announcer.say(id)
	if network_active and multiplayer.is_server():
		if target==null: receive_announcement.rpc(id,match_session,round_number)
		elif target.remote_peer>1: receive_announcement.rpc_id(target.remote_peer,id,match_session,round_number)
@rpc("authority","call_remote","reliable")
func receive_announcement(id: String, session: int, round_id: int) -> void:
	if film_retaining_transport:return
	if running and session==match_session and round_id==round_number: announcer.say(id)
@rpc("authority","call_remote","reliable")
func damage_audio_event(id: int, before: Dictionary, region: String, category: String, sequence: int, life: int, session: int, round_id: int, new_health: float, new_shield: float, new_armor: float, new_over: float, new_helmet: float) -> void:
	if film_retaining_transport:return
	if not running or session!=match_session or round_id!=round_number: return
	var actor=actor_by_id(id)
	if actor==null or actor.life_id!=life: return
	# Reliable audio carries its own hit state so coalesced snapshots lose no cues.
	var saved=[actor.health,actor.shield,actor.armor,actor.overshield,actor.helmet_hp]
	actor.health=new_health; actor.shield=new_shield; actor.armor=new_armor; actor.overshield=new_over; actor.helmet_hp=new_helmet
	actor.combat_audio.on_damage(before,region,category,sequence)
	actor.health=saved[0]; actor.shield=saved[1]; actor.armor=saved[2]; actor.overshield=saved[3]; actor.helmet_hp=saved[4]
func display_death_recap(actor: NestActor) -> void:
	if not actor.local_player or actor.death_recap.is_empty() or actor.recap_announced_life==actor.life_id: return
	actor.recap_announced_life=actor.life_id
	messages.append(actor.death_recap_text().replace("\n"," · "))
	if messages.size()>4: messages.pop_front()
@rpc("authority","call_remote","reliable")
func receive_death_recap(id: int, life: int, session: int, round_id: int, recap: Dictionary) -> void:
	if film_retaining_transport:return
	if not running or session!=match_session or round_id!=round_number: return
	var actor=actor_by_id(id)
	if actor==null or not actor.local_player or actor.life_id!=life: return
	actor.death_recap=recap.duplicate(true); display_death_recap(actor)
func send_chat(message: String) -> bool:
	message=message.strip_edges().substr(0,200)
	if handle_god_command(message):return true
	if message.is_empty() or not prefs.values.chat or now-last_message<1: return false
	last_message=now
	if network_active:
		if is_client(): relay_chat.rpc_id(1,message,match_session)
		else: receive_chat.rpc(lobby_members.get(1,{"name":"Host"}).name+": "+message); receive_chat(lobby_members.get(1,{"name":"Host"}).name+": "+message)
		return true
	messages.append(current_username()+" (local): "+message)
	if messages.size()>4: messages.pop_front()
	return true
func close_chat() -> void:
	context="playing"
	capture_mouse()
func capture_mouse() -> void:
	if matchmaking!=null and (matchmaking.dedicated or matchmaking.blocks_simulation()):return
	if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:clear_held_input()
	var focused=get_viewport().gui_get_focus_owner()
	if focused!=null: focused.release_focus()
	if input_window_focused:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func is_client() -> bool:
	if not network_active:return false
	var transport=multiplayer.multiplayer_peer
	return transport!=null and transport.get_connection_status()!=MultiplayerPeer.CONNECTION_DISCONNECTED and not multiplayer.is_server()
func lobby_capacity() -> int:
	return mini(16,game_type.max_players) if lobby_kind=="forge" else mini(game_type.max_players,team_size*2)
func host_direct(port: int, name: String, faction: int) -> Error:
	close_connection()
	var peer=ENetMultiplayerPeer.new()
	var err=peer.create_server(port,16) # Lobby membership enforces the editable player limit.
	if err!=OK: network_status="Unable to open UDP port %d"%port; return err
	multiplayer.multiplayer_peer=peer; network_active=true; connection_port=port
	lobby_members={1:{"name":clean_alias(name),"faction":faction,"character":selected_character,"ready":false,"rating":ranked.profile.summary()}}
	network_status="Hosting on UDP port %d"%port
	return OK
func join_direct(address: String, port: int, name: String, faction: int) -> Error:
	close_connection()
	var peer=ENetMultiplayerPeer.new()
	var err=peer.create_client(address,port)
	if err!=OK: network_status="Unable to connect"; return err
	multiplayer.multiplayer_peer=peer; network_active=true; connection_port=port; connection_address=address
	selected_faction=faction
	lobby_members={0:{"name":clean_alias(name),"faction":faction}}
	network_status="Connecting to %s:%d…"%[address,port]
	return OK
func close_connection() -> void:
	film_retaining_transport=false
	god_mode=false
	var ballot=get_node_or_null("LobbyVote")
	if ballot!=null:ballot.reset()
	if has_method("clear_join_notifications"):call("clear_join_notifications")
	if network_active:
		last_cache_cleanup_count=NestNetworkCleanup.retire_rpc_cache([self,matchmaking,nu,get_node_or_null("LobbyVote")])
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
		multiplayer.server_relay=true # Restore normal Custom / Forge behavior.
	network_active=false; network_status="Offline"; lobby_members.clear(); command_received.clear(); shot_authorizations.clear(); remote_shot_clocks.clear(); snapshot_fragments.clear(); snapshot_received=-1; remote_throws.clear(); match_session=0
	reset_network_timing()
func current_username() -> String:
	if not AncientNestAuth.current_user.is_empty():
		return str(AncientNestAuth.current_user.get("username", "Player"))
	return clean_alias(String(prefs.values.username))
func clean_alias(alias: String) -> String:
	var cleaned=NestPreferences.normalize_username(alias)
	return cleaned if not cleaned.is_empty() else "Player"
func unique_alias(proposed: String, except_peer: int=0) -> String:
	var base=clean_alias(proposed);var candidate=base;var suffix=2
	while true:
		var taken=false
		for id in lobby_members:
			if id!=except_peer and String(lobby_members[id].name).nocasecmp_to(candidate)==0:taken=true;break
		if not taken:return candidate
		var tail="_"+str(suffix);candidate=base.substr(0,24-tail.length())+tail;suffix+=1
	return base
func save_username(proposed: String) -> Error:
	var name=NestPreferences.normalize_username(proposed)
	if name.is_empty():return ERR_INVALID_PARAMETER
	if running:return ERR_BUSY
	var previous=prefs.values.username;prefs.values.username=name
	var result=prefs.save()
	if result!=OK:prefs.values.username=previous;return result
	if is_client():request_username.rpc_id(1,name)
	elif network_active:apply_username(1,name)
	return OK
func apply_username(peer: int, proposed: String) -> bool:
	if running or is_client() or not lobby_members.has(peer):return false
	var name=NestPreferences.normalize_username(proposed)
	if name.is_empty():return false
	lobby_members[peer]["name"]=unique_alias(name,peer)
	if network_active:update_lobby.rpc(lobby_members,active_config())
	if has_method("network_ui_changed"):call("network_ui_changed")
	return true
@rpc("any_peer","call_remote","reliable")
func request_username(proposed: String) -> void:
	if film_retaining_transport:return
	if not network_active or not multiplayer.is_server() or running:return
	# A rename contains no target slot: only the authenticated sender can change.
	var sender=multiplayer.get_remote_sender_id()
	if sender<=1 or not apply_username(sender,proposed):push_warning("Ignored invalid username request from peer %d"%sender)
func disable_unreliable_throttle(peer_id: int) -> void:
	# ENet randomly discards unreliable packets when its RTT estimate rises
	# (it starts at 500 ms and fluctuates early on). Movement commands are
	# already redundant and snapshots are small, so keep every packet.
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		var peer=(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(peer_id)
		if peer!=null: peer.throttle_configure(ENetPacketPeer.PACKET_THROTTLE_SCALE,ENetPacketPeer.PACKET_THROTTLE_SCALE,0)
func network_connected() -> void:
	if campaign!=null and campaign.active:campaign.connected();return
	disable_unreliable_throttle(1)
	if matchmaking.active:matchmaking.connected();return
	var local=lobby_members.get(0,{"name":current_username(),"faction":selected_faction})
	register_member.rpc_id(1,local.name,local.faction,NETWORK_VERSION,ranked.profile.summary())
	network_status="Connected · Waiting for host"
	if lobby_network!=null: lobby_network.on_join_succeeded()
func network_failed() -> void:
	if campaign!=null and campaign.active:campaign.connection_failed();return
	if matchmaking.active:matchmaking.connection_lost("Matchmaking connection failed");return
	var reason="Connection failed. Check address, UDP port and host firewall."
	if lobby_network!=null: lobby_network.on_join_failed(reason)
	else:
		close_connection(); network_status=reason
		if has_method("network_ui_changed"): call("network_ui_changed")
func network_lost() -> void:
	if campaign!=null and campaign.active:campaign.host_lost();return
	if matchmaking.active:matchmaking.connection_lost("Matchmaking server disconnected");return
	if forge_session!=null:
		forge_session.active=false;forge_session.testing=false
		if is_instance_valid(get("forge_editor")):call("leave_forge_editor_ui",false)
	if running: stop_game()
	if lobby_network!=null: lobby_network.on_server_disconnected("Host disconnected — returning to your lobby.")
	else:
		close_connection(); network_status="Host disconnected. Return to lobby to reconnect."
		if has_method("network_ui_changed"): call("network_ui_changed")
func network_peer_connected(peer: int) -> void:
	if matchmaking.hybrid.enabled:matchmaking.hybrid.peer_connected(peer);return
	if multiplayer.is_server():
		disable_unreliable_throttle(peer)
		if matchmaking.dedicated:matchmaking.anonymous[peer]=matchmaking.clock()+10
func network_peer_left(peer: int) -> void:
	if campaign!=null and campaign.active:campaign.disconnected(peer);return
	if not network_active or not multiplayer.is_server(): return
	if matchmaking.disconnected(peer):return
	announcer.forget_player(peer)
	lobby_members.erase(peer)
	for actor in actors.duplicate():
		if actor.remote_peer==peer:
			ranked.remember(actor)
			if actor.carrying: drop_bag(actor)
			if actor.flag_carry>=0: drop_flag(actor)
			drop_cs_bomb(actor)
			actors.erase(actor); actor.queue_free()
	if forge_session!=null:forge_session.processed.erase(peer);forge_session.rate.erase(peer)
	call_deferred("refresh_remaining_lobby")
	if has_method("network_ui_changed"): call("network_ui_changed")
func refresh_remaining_lobby() -> void:
	await get_tree().create_timer(.1).timeout
	if not network_active or not multiplayer.is_server() or not multiplayer.multiplayer_peer is ENetMultiplayerPeer:return
	var config=active_config()
	for id in multiplayer.get_peers():
		var peer=(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(id)
		if peer!=null and peer.get_state()==ENetPacketPeer.STATE_CONNECTED:update_lobby.rpc_id(id,lobby_members,config)
@rpc("any_peer","call_remote","reliable")
func register_member(alias: String, faction: int, version: String="",rating: Dictionary={}) -> void:
	if campaign!=null and campaign.active:return # Campaign owns its separate enrolled-seat handshake.
	if film_retaining_transport:return
	if matchmaking.is_authority():return # Queue registration is the only matchmaking admission path.
	if not network_active or not multiplayer.is_server(): return
	var sender=multiplayer.get_remote_sender_id()
	if version!=NETWORK_VERSION: reject_join.rpc_id(sender,"Version mismatch — both players must use Ancient Nest %s."%NETWORK_VERSION); return
	if running: reject_join.rpc_id(sender,"Match already started. Join in progress is not available in this build." if game_type.join_in_progress else "Match already started — Join in progress is disabled for this game type."); return
	if lobby_members.has(sender):return # Already accepted; do not announce twice.
	if lobby_members.size()>=lobby_capacity(): reject_join.rpc_id(sender,"Lobby is full."); return
	faction=clampi(faction,0,1)
	var counts=[0,0]
	for member in lobby_members.values(): counts[member.faction]+=1
	if lobby_kind!="forge" and counts[faction]>=team_size: faction=1-faction
	if lobby_kind!="forge" and counts[faction]>=team_size: reject_join.rpc_id(sender,"Both teams are full."); return
	alias=unique_alias(alias,sender)
	lobby_members[sender]={"name":alias,"faction":faction,"character":-1,"ready":false,"rating":NestRatingProfile.clean_summary(rating)}
	update_lobby.rpc(lobby_members,active_config())
	player_joined_notice.rpc(sender,alias)
	if forge_session.active:forge_session.sync_to(sender)
	if has_method("network_ui_changed"): call("network_ui_changed")
@rpc("authority","call_local","reliable")
func player_joined_notice(peer: int, alias: String) -> void:
	if film_retaining_transport:return
	# Only accepted, named players are announced. Initial rosters and bots are not.
	if not network_active or peer==multiplayer.get_unique_id():return
	if has_method("show_join_notification"):call("show_join_notification",clean_alias(alias))
@rpc("authority","call_remote","reliable")
func reject_join(reason: String) -> void:
	if film_retaining_transport:return
	close_connection(); network_status=reason
	if lobby_network!=null: lobby_network.call_deferred("on_join_failed",reason)
	elif has_method("network_ui_changed"): call("network_ui_changed")
@rpc("authority","call_remote","reliable")
func host_departing() -> void:
	if film_retaining_transport:return
	network_status="Host left — returning to menu"
	if has_method("network_ui_changed"): call("network_ui_changed")
func active_config() -> Dictionary:
	sync_legacy_to_game_type()
	return {"snapshot_ticks":snapshot_interval_ticks,"lobby_kind":lobby_kind,"lobby_vote":get_node("LobbyVote").snapshot() if has_node("LobbyVote") else {},"forge_layout":forge_session.layout(),"forge_playtest":forge_session.testing,"rating_token":ranked.token,"mode":mode,"team_size":team_size,"bot_fill":bot_fill,"round_seconds":tuning.round_seconds,"score_limit":tuning.score_limit,"bag_stock":tuning.bag_stock,"bot_objectives":bot_play_objectives,"bot_difficulty":bot_difficulty,"session":match_session,"starting_primary":starting_primary,"starting_secondary":starting_secondary,"fair_playing_field":fair_playing_field,"fair_health_type":fair_health_type,"matchup":matchup,"game_type":game_type.to_network_dict()}
func accept_config(config: Dictionary) -> void:
	snapshot_interval_ticks=clampi(int(config.get("snapshot_ticks",3)),1,3) # Older hosts send 20 Hz.
	if has_node("LobbyVote") and config.get("lobby_vote") is Dictionary:get_node("LobbyVote").accept(config.lobby_vote)
	lobby_kind=String(config.get("lobby_kind","custom"))
	if lobby_kind not in ["forge","matchmaking"]:lobby_kind="custom"
	ranked.token=String(config.get("rating_token",ranked.token)).substr(0,96)
	if config.has("game_type") and config.game_type is Dictionary:
		game_type.apply_network_dict(config.game_type); sync_game_type_to_legacy();ensure_selected_map()
	else:
		mode=config.mode; team_size=config.team_size; bot_fill=config.bot_fill; tuning.round_seconds=config.round_seconds; tuning.score_limit=config.score_limit; tuning.bag_stock=config.bag_stock; bot_play_objectives=config.bot_objectives
	match_session=config.get("session",0)
	bot_difficulty=str(config.get("bot_difficulty",bot_difficulty))
	if bot_difficulty not in ["easy","normal","hard","insane"]: bot_difficulty="normal"
	starting_primary=config.get("starting_primary",starting_primary); starting_secondary=config.get("starting_secondary",starting_secondary); fair_playing_field=config.get("fair_playing_field",false); fair_health_type=config.get("fair_health_type","naki")
	matchup=clampi(int(config.get("matchup",game_type.matchup)),0,3)
	forge_session.testing=bool(config.get("forge_playtest",false));sandbox_mode=forge_session.testing
	if forge_session.testing:forge_session.active=false
	if config.get("forge_layout") is Dictionary and not config.forge_layout.is_empty():forge_session.accept_layout(config.forge_layout)
	elif config.has("forge_layout") and forge_session.model!=null:forge_session.clear()
	sync_legacy_to_game_type()
@rpc("authority","call_remote","reliable")
func update_lobby(members: Dictionary, config: Dictionary) -> void:
	if film_retaining_transport:return
	lobby_members=members; accept_config(config)
	var own_id=matchmaking.local_slot if matchmaking.active else multiplayer.get_unique_id()
	if members.has(own_id):
		var member=members[own_id];selected_faction=member.faction;selected_character=int(member.get("character",-1));lobby_ready=bool(member.get("ready",false))
	network_status="Connected · %d players · Waiting for host"%members.size()
	if has_method("network_ui_changed"): call("network_ui_changed")
func create_network_actors() -> void:
	var counts=[0,0]
	var ids=lobby_members.keys(); ids.sort()
	for id in ids:
		var member=lobby_members[id]
		var actor=NestActor.new(); actor.game=self; actor.character_choice=int(member.get("character",-1)); actor.faction=member.faction; actor.username=member.name; actor.remote_peer=int(member.get("peer",id)); actor.net_id=id; actor.local_player=not matchmaking.dedicated and (id==matchmaking.local_slot if matchmaking.active else id==multiplayer.get_unique_id())
		add_child(actor); actors.append(actor); counts[actor.faction]+=1
		if actor.local_player: player=actor
	if bot_fill and not matchmaking.active:
		for f in [0,1]:
			for i in range(round_bot_count(f,counts[f])):
				var bot=NestActor.new(); bot.game=self; bot.faction=f; bot.username=bot_name(f,i); bot.net_id=-(1+f*16+i)
				add_child(bot); actors.append(bot)
@rpc("authority","call_remote","reliable")
func begin_network_match(config: Dictionary, members: Dictionary) -> void:
	if film_retaining_transport:return
	if running: return
	announcer.reset()
	accept_config(config); lobby_members=members; now=0; round_number=1; scores=[0,0]; attacking_faction=0; finished=false; running=true; context="playing";get_viewport().disable_3d=false
	team_characters.assign(MATCHUPS[matchup])
	prepare_match_input(); create_network_actors(); reset_round()
	ranked.begin()
	if has_method("network_match_started"): call("network_match_started")
	capture_mouse()
@rpc("authority","call_remote","reliable")
func end_network_match() -> void:
	if film_retaining_transport:return
	stop_game()
	if has_method("network_ui_changed"): call("network_ui_changed")
func actor_for_peer(peer: int) -> NestActor:
	for actor in actors:
		if actor.remote_peer==peer and peer>0:return actor
	return null
func actor_by_id(id: int) -> NestActor:
	for actor in actors:
		if actor.net_id==id: return actor
	return null
# ---- Command transport ----
# Packet: session(i32) first_seq(i32) count(u8), then per command
# move.x move.y yaw pitch (f32) and flags (u8: jump, interact, crouch 2 bits).
func encode_command_packet(commands: Array, session: int=-1) -> PackedByteArray:
	var buffer=StreamPeerBuffer.new()
	buffer.put_32(match_session if session<0 else session); buffer.put_32(int(commands[0].seq)); buffer.put_u8(commands.size())
	for c in commands:
		buffer.put_float(c.move.x); buffer.put_float(c.move.y); buffer.put_float(c.yaw); buffer.put_float(c.pitch)
		buffer.put_u8((1 if c.jump else 0)|(2 if c.interact else 0)|((int(c.crouch)+1)<<2))
	return buffer.data_array
func decode_command_packet(packet: PackedByteArray) -> Dictionary:
	if packet.size()<9 or packet.size()>9+17*32: return {}
	var buffer=StreamPeerBuffer.new(); buffer.data_array=packet
	var session=buffer.get_32(); var first=buffer.get_32(); var count=buffer.get_u8()
	if count<1 or count>32 or packet.size()!=9+17*count or first<1: return {}
	var commands=[]
	for i in range(count):
		var move=Vector2(buffer.get_float(),buffer.get_float()); var yaw=buffer.get_float(); var pitch=buffer.get_float(); var flags=buffer.get_u8()
		if not move.is_finite() or not is_finite(yaw) or not is_finite(pitch) or (flags>>2)>2: return {}
		commands.append({"seq":first+i,"move":move.limit_length(1),"yaw":wrapf(yaw,-PI,PI),"pitch":clampf(pitch,-1.55,1.55),"jump":(flags&1)!=0,"interact":(flags&2)!=0,"crouch":(flags>>2)-1})
	return {"session":session,"commands":commands}
func send_commands() -> void:
	if not is_client() or command_send_paused or not is_instance_valid(player): return
	var stride=maxi(1,ceili(60.0/clampf(float(NestControlPolicy.settings().input_hz),1,60)))
	if command_sequence%stride!=0:return
	if matchmaking.hybrid.enabled and not matchmaking.can_send(1):return
	var history: Array=player.cmd_history
	if history.is_empty(): return
	var count=mini(history.size(),COMMAND_REDUNDANCY)
	last_command_packet=encode_command_packet(history.slice(history.size()-count))
	if command_drop_packets>0:
		command_drop_packets-=1; net_stat("command_packets_dropped_by_test"); return
	net_stat("input_payload_bytes_sent",last_command_packet.size());net_stat("input_packets_sent")
	receive_commands.rpc_id(1,last_command_packet)
@rpc("any_peer","call_remote","unreliable_ordered",1)
func receive_commands(packet: PackedByteArray) -> void:
	if film_retaining_transport:return
	if matchmaking.blocks_simulation():return
	if not network_active or not multiplayer.is_server() or not running: return
	var decoded=decode_command_packet(packet)
	if decoded.is_empty() or decoded.session!=match_session: return
	var actor=actor_for_peer(multiplayer.get_remote_sender_id())
	if actor==null or actor.remote_peer<=1: return
	if not network_policy.admit(actor.remote_peer,"input",local_clock(),75,20):net_stat("input_rate_rejected");return
	net_stat("input_payload_bytes_received",packet.size())
	if int(decoded.commands[-1].seq)>actor.cmd_last_seq+NestNetworkPolicy.MAX_COMMAND_LEAD: return
	actor.queue_commands(decoded.commands)
	net_stat("command_packets_received")
func snapshot_state() -> Array:
	var states=[]
	for actor in actors:
		var kinds=[]
		for weapon in actor.weapons: kinds.append(weapon.kind)
		states.append({"bomb_equipped":actor.bomb_equipped,"bomb_drop_at":actor.bomb_drop_at,"nu_used":actor.nu_used,"nu_until":actor.nu_launch_until,"melee_ack":actor.remote_melee_id,"sword_draw":actor.sword_draw,"traits_pending":actor.traits.settings==pending_game_type,"id":actor.net_id,"peer":actor.remote_peer,"char":actor.character,"pos":actor.global_position,"yaw":actor.rotation.y,"pitch":actor.eye.rotation.x,"velocity":actor.velocity,"health":actor.health,"shield":actor.shield,"armor":actor.armor,"over":actor.overshield,"over_until":actor.over_deadline,"alive":actor.alive,"life":actor.life_id,"respawn":actor.respawn_at,"carrying":actor.carrying,"bag":actor.bag_id,"ammo":actor.ammo,"reserve":actor.reserve,"weapons":kinds,"slot":actor.slot,"action":actor.action_state,"action_until":actor.action_until,"throw_started":actor.throw_started,"throw_kind":actor.throw_kind,"grenades":actor.grenades,"cloak":actor.cloak_deadline,"kills":actor.kills,"deaths":actor.deaths,"assists":actor.assists,"captures":actor.captures,"flag_returns":actor.flag_returns,"delivered":actor.delivered,"bombs":actor.detonations,"crouch":actor.crouched,"grounded":actor.is_on_floor(),"air_duck":actor.air_duck,"interaction":remote_interactions.get(actor.remote_peer,{"time":0.0}).time})
		states[-1].merge({"rank_h":actor.rank_human,"rank_p":actor.rank_practice,"fx_seq":actor.damage_fx_seq,"fx_shield":Vector3(actor.shield_flash_at,actor.shield_flash_strength,1 if actor.shield_flash_over else 0),"fx_health":Vector2(actor.health_flash_at,actor.health_flash_strength),"fx_break":actor.shield_break_at,"fx_directions":actor.directional_hits,"last_damage":actor.last_damage,"flash":actor.flash_until,"shot_kind":actor.last_shot_kind,"body_phase":actor.body_phase,"helmet":actor.helmet_hp,"stun":actor.hit_stun_until,"reload_duration":actor.reload_duration,"reload_empty":actor.reload_was_empty,"fx_region":actor.last_damage_region,"recap":actor.death_recap if not actor.alive else {},"shot_ack":actor.remote_shot_id,"shot_count":actor.accepted_shots,"ak_spray":actor.ak_spray_count,"flag":actor.flag_carry,"caps":actor.captures,"rets":actor.flag_returns})
		if actor.remote_peer>1:
			# Movement acknowledgement: the last processed command and the exact
			# state it produced, which the owner replays its later commands from.
			states[-1].merge({"ack":actor.cmd_last_seq,"ctrl":actor.controlled,"ext":actor.external,"takeoff":actor.cannon_takeoff,"jbuf":actor.server_jump_buffer,"lunge_t":actor.lunge_ticks,"lunge_v":actor.lunge_velocity})
	var drops=[]
	for id in bags: drops.append({"id":id,"position":bags[id].position})
	var match_state={"nu_sightings":nu_sightings,"nu":nu.snapshot(),"rating_result":ranked.last_packet if finished else {},"cs_carrier":cs_carrier,"cs_drop":cs_drop_position,"session":match_session,"chars":team_characters,"flags":flags,"now":now,"lift":current_lift_clock(),"deadline":deadline,"round":round_number,"attacker":attacking_faction,"scores":scores,"sites":site_states,"bomb_site":bomb_site,"delivered":delivered_bags,"loaded":loaded_bags,"break":break_until,"reason":round_reason,"finished":finished,"pads":pad_stock,"drops":drops,"feed":kill_feed}
	return [match_state,states]
func send_snapshot() -> void:
	var encode_started=Time.get_ticks_usec()
	var bytes=var_to_bytes(snapshot_state()).compress(FileAccess.COMPRESSION_DEFLATE)
	net_stat("snapshot_encode_us",Time.get_ticks_usec()-encode_started);net_stat("snapshot_payload_bytes",bytes.size());net_stat("snapshots_sent")
	snapshot_sequence+=1
	var total=ceili(float(bytes.size())/850)
	if total>24:net_stat("oversized_snapshots_rejected");return
	for index in range(total):
		var chunk=bytes.slice(index*850,mini(bytes.size(),(index+1)*850))
		if matchmaking.is_authority():
			# A timed-out transport may linger until ENet polls its disconnect.
			# Send only to registered, ready, currently connected players.
			for peer in matchmaking.peers:
				if matchmaking.can_send(peer) and not matchmaking.rejoin_deadlines.has(peer):snapshot_packet.rpc_id(peer,snapshot_sequence,index,total,chunk,match_session)
		elif campaign!=null and campaign.active:
			for slot in campaign.connected_slots():
				var peer=int(campaign.members[slot].peer)
				if peer>1:snapshot_packet.rpc_id(peer,snapshot_sequence,index,total,chunk,match_session)
		else:snapshot_packet.rpc(snapshot_sequence,index,total,chunk,match_session)
@rpc("authority","call_remote","unreliable_ordered",2)
func receive_snapshot(match_state: Dictionary, states: Array) -> void:
	if film_retaining_transport:return
	if not running or match_state.get("session",-1)!=match_session: return
	if film_recorder!=null:film_recorder.authoritative_snapshot(match_state,states)
	observe_server_clock(match_state)
	cs_carrier=int(match_state.get("cs_carrier",0));cs_drop_position=match_state.get("cs_drop",Vector3.INF)
	deadline=match_state.deadline; round_number=match_state.round; attacking_faction=match_state.attacker; scores.assign(match_state.scores); site_states.assign(match_state.sites); bomb_site=match_state.bomb_site; delivered_bags=match_state.delivered; loaded_bags=match_state.loaded; break_until=match_state["break"]; round_reason=match_state.reason; finished=match_state.finished; pad_stock.assign(match_state.pads); kill_feed.assign(match_state.feed)
	if finished and match_state.get("rating_result",{}) is Dictionary and not match_state.get("rating_result",{}).is_empty():ranked.accept(match_state.rating_result)
	team_characters.assign(match_state.get("chars",team_characters))
	if match_state.has("flags"): flags=match_state.flags.duplicate(true)
	arena.set_sides(attacking_faction,[team_name(0),team_name(1)])
	var received_ids=[]
	for state in states:
		received_ids.append(state.id)
		var actor=actor_by_id(state.id)
		if actor==null: continue
		actor.nu_used=bool(state.get("nu_used",false));actor.nu_launch_until=float(state.get("nu_until",0));actor.sword_draw=float(state.get("sword_draw",0))
		if not actor.local_player:actor.remote_peer=int(state.get("peer",actor.remote_peer))
		var old_life=actor.life_id
		if old_life!=state.life or (state.get("traits_pending",false) and pending_game_type!=null and actor.traits.settings!=pending_game_type):actor.refresh_traits()
		var was_alive=actor.alive
		var old_action=actor.action_state
		var old_health=actor.health
		var old_shield=actor.shield
		var old_over=actor.overshield
		actor.set_character(int(state.get("char",actor.character)))
		actor.net_target_pos=state.pos; actor.net_target_yaw=state.yaw
		if actor.local_player:
			if state.has("ack"): observe_prediction_ack(actor,int(state.ack),float(match_state.now))
			if old_life!=state.life:
				actor.global_position=state.pos; actor.controlled=state.get("ctrl",state.velocity); actor.external=state.get("ext",Vector3.ZERO); actor.net_position_error=Vector3.ZERO
				actor.cmd_history.clear(); actor.pending_reconcile={}; actor.view_correction=Vector3.ZERO
				actor.reset_physics_interpolation()
			elif state.has("ack"): actor.queue_reconcile(state,float(match_state.now))
		else:
			actor.net_grounded=state.grounded
			if old_life!=state.life:
				actor.snap_buffer.clear()
				actor.global_position=state.pos; actor.rotation.y=state.yaw; actor.eye.rotation.x=state.pitch; actor.reset_physics_interpolation()
			actor.push_net_sample(float(match_state.now),state)
		actor.alive=state.alive; actor.life_id=state.life; actor.respawn_at=state.respawn; actor.health=state.health; actor.shield=state.shield; actor.armor=state.armor; actor.overshield=state.over; actor.over_deadline=state.over_until; actor.carrying=state.carrying; actor.bag_id=state.bag; actor.cloak_deadline=state.cloak
		if not actor.local_player: actor.velocity=state.velocity
		actor.capsule.disabled=not actor.alive
		for hitbox in actor.hitboxes: hitbox.collision_layer=4 if actor.alive else 0
		actor.refresh_model_visibility()
		var existing_kinds=[]
		for weapon in actor.weapons: existing_kinds.append(weapon.kind)
		if existing_kinds!=state.weapons:
			actor.weapons.clear()
			for kind in state.weapons: actor.weapons.append(NestWeaponCatalog.profile(kind))
		actor.ammo.assign(state.ammo)
		if actor.local_player:
			if old_life!=state.life:actor.pending_shots.clear()
			actor.pending_shots=actor.pending_shots.filter(func(shot):return shot.id>state.get("shot_ack",-1))
			actor.accepted_shots=int(state.get("shot_count",0))+actor.pending_shots.size()
			actor.ak_spray_count=int(state.get("ak_spray",actor.ak_spray_count))
			for pending in actor.pending_shots:
				if pending.kind=="ak47":actor.ak_spray_count=1 if pending.get("spray_reset",false) else actor.ak_spray_count+1
			for shot in actor.pending_shots:
				if actor.traits.infinite_ammo!=2 and shot.slot<actor.weapons.size() and actor.weapons[shot.slot].kind==shot.kind:actor.ammo[shot.slot]=maxi(0,actor.ammo[shot.slot]-1)
		actor.reserve.assign(state.reserve);actor.slot=state.slot;actor.grenades.assign(state.grenades)
		var keep_predicted_throw=actor.local_player and actor.action_state=="throwing" and actor.throw_life==int(state.life) and now<actor.action_until and state.alive and state.action in ["ready","throwing"]
		var keep_predicted_melee=actor.local_player and actor.action_state=="melee" and now<actor.action_until and state.alive and state.action=="ready" and int(state.get("melee_ack",-1))<actor.melee_event_id
		if not keep_predicted_throw and not keep_predicted_melee:
			actor.bomb_equipped=bool(state.get("bomb_equipped",false));actor.bomb_drop_at=float(state.get("bomb_drop_at",0));actor.action_state=state.action;actor.action_until=state.action_until;actor.throw_started=float(state.get("throw_started",actor.throw_started));actor.throw_kind=int(state.get("throw_kind",actor.throw_kind))
		actor.rank_human=clampi(int(state.get("rank_h",actor.rank_human)),0,3200);actor.rank_practice=clampi(int(state.get("rank_p",actor.rank_practice)),0,3200)
		actor.kills=state.kills; actor.deaths=state.deaths; actor.assists=state.assists;actor.captures=int(state.get("captures",0));actor.flag_returns=int(state.get("flag_returns",0)); actor.delivered=state.delivered; actor.detonations=state.bombs
		actor.flag_carry=int(state.get("flag",-1)); actor.captures=int(state.get("caps",0)); actor.flag_returns=int(state.get("rets",0))
		if old_life!=actor.life_id:
			actor.reset_damage_visual(); actor.death_recap.clear()
			if actor.local_player: actor.reset_crouch()
		if not actor.alive and not state.get("recap",{}).is_empty():
			actor.death_recap=state.recap.duplicate(true); display_death_recap(actor)
		if state.has("fx_seq"):
			if state.fx_seq>actor.damage_fx_seq:
				actor.damage_fx_seq=state.fx_seq
				actor.shield_flash_at=state.fx_shield.x; actor.shield_flash_strength=state.fx_shield.y; actor.shield_flash_over=state.fx_shield.z>0
				actor.health_flash_at=state.fx_health.x; actor.health_flash_strength=state.fx_health.y; actor.shield_break_at=state.fx_break
				actor.directional_hits.assign(state.get("fx_directions",[]))
			actor.last_damage=state.get("last_damage",actor.last_damage)
		elif old_life==actor.life_id and (old_health>state.health or old_shield>state.shield or old_over>state.over): actor.record_damage_visual(old_shield,old_over,old_health); actor.last_damage=now
		actor.last_damage_region=state.get("fx_region","torso")
		if not actor.local_player:
			actor.flash_until=maxf(actor.flash_until,state.get("flash",actor.flash_until));actor.last_shot_kind=state.get("shot_kind",actor.last_shot_kind)
		actor.body_phase=state.get("body_phase",actor.shield<=0 and actor.damage_model()=="naki")
		actor.helmet_hp=state.get("helmet",actor.helmet_hp); actor.hit_stun_until=state.get("stun",actor.hit_stun_until)
		actor.reload_duration=state.get("reload_duration",actor.weapons[actor.slot].reload_seconds); actor.reload_was_empty=state.get("reload_empty",false)
		if was_alive and not actor.alive and old_life==actor.life_id: actor.combat_audio.on_death()
		if actor.local_player:
			if not actor.alive and context=="chat": close_chat()
			if old_life!=actor.life_id: actor.reset_aim(); clear_held_input()
			interaction_progress=state.interaction
			interaction_duration=interaction_for(actor).get("seconds",0.0)
		if actor.local_player and old_life==actor.life_id and (old_health>state.health or old_shield>state.shield or old_over>state.over): hurt_until=now+0.15
	for actor in actors.duplicate():
		if actor.net_id not in received_ids: actors.erase(actor); actor.queue_free()
	for id in bags.keys():
		var present=false
		for drop in match_state.drops:
			if drop.id==id: present=true
		if not present: bags[id].node.queue_free(); bags.erase(id)
	for drop in match_state.drops:
		if not bags.has(drop.id):
			var node=Node3D.new(); effects.add_child(node); node.position=drop.position
			arena.kit.box(node,Vector3(0,0.3,0),Vector3(0.5,0.4,0.4),arena.kit.gold); arena.kit.label(node,Vector3(0,1,0),"GOLD BAG",Color("eac982"),24)
			bags[drop.id]={"node":node,"position":drop.position}
	for i in range(2):
		arena.set_site_visual(i,site_states[i].stage,now)
		arena.deposit_labels[i].text=("A" if i==0 else "B")+" · "+site_states[i].stage.to_upper()
	for i in range(arena.pads.size()): arena.pad_meshes[i].visible=pad_stock[i]>0
	var recon=match_state.get("nu_sightings",[{},{}])
	if recon is Array and recon.size()==2:
		nu_sightings.assign(recon)
	nu.receive(match_state.get("nu",{}))

func update_remote_interaction(actor: NestActor, delta: float) -> void:
	var id=actor.remote_peer
	var chosen=interaction_for(actor)
	if chosen.is_empty() or not actor.net_interact or now-actor.net_last_command>0.35: remote_interactions.erase(id); return
	if not remote_interactions.has(id) or remote_interactions[id].key!=chosen.key:
		remote_interactions[id]={"key":chosen.key,"time":0.0}
		if chosen.key.begins_with("defuse:"):global_objective_sound("bomb_defuse_start")
	actor.burst_left=0
	if actor.action_state in ["reloading","switching","throwing"]: actor.action_state="ready"; actor.action_until=now
	remote_interactions[id].time+=delta
	if remote_interactions[id].time>=chosen.seconds: complete_interaction(actor,chosen); remote_interactions.erase(id)
func request_remote_action(action: String, parameter: int=0) -> void:
	request_action.rpc_id(1,action,parameter,player.life_id,round_number,match_session,command_sequence)
@rpc("any_peer","call_remote","reliable")
func request_action(action: String, parameter: int, life: int, round_id: int, session: int, cmd_seq: int=-1) -> void:
	if film_retaining_transport:return
	if matchmaking.blocks_simulation():return
	if not multiplayer.is_server() or not running or finished or round_id!=round_number or session!=match_session: return
	if action not in ["nu","sword","pickup","reload","switch","select_weapon","bomb","cancel_uncommitted","throw_begin"]:return
	var actor=actor_for_peer(multiplayer.get_remote_sender_id())
	if actor==null: return
	if actor.life_id!=life or cmd_seq>actor.cmd_last_seq+NestNetworkPolicy.MAX_COMMAND_LEAD or (cmd_seq>0 and cmd_seq<actor.cmd_last_seq-30):return
	if not network_policy.admit(actor.remote_peer,"action",local_clock(),30,12):net_stat("action_rate_rejected");return
	if not network_policy.accept_action(actor.remote_peer,action,cmd_seq,str(match_session)+":"+str(round_id)+":"+str(life)):return
	if action=="cancel_uncommitted" and (parameter<0 or parameter>actor.cmd_last_seq+NestNetworkPolicy.MAX_COMMAND_LEAD):return
	# Cancellation is a barrier for in-flight input, so it applies on receipt.
	if action=="cancel_uncommitted" or cmd_seq<=0: apply_action(actor,action,parameter,life,round_id,session)
	else: defer_for_command(actor,cmd_seq,apply_action.bind(actor,action,parameter,life,round_id,session))
func apply_action(actor: NestActor, action: String, parameter: int, life: int, round_id: int, session: int) -> void:
	if not is_instance_valid(actor) or not running or finished or round_id!=round_number or session!=match_session: return
	if not actor.alive or actor.life_id!=life: return
	if nu.blocked(actor) and action not in ["nu","cancel_uncommitted"]:return
	match action:
		"nu": nu.toggle(actor)
		"sword": actor.wield_sword()
		"pickup":
			var pickup=pickup_choice(actor)
			if not pickup.is_empty() and int(pickup.pad)==parameter:complete_interaction(actor,pickup)
		"reload": actor.reload_weapon()
		"switch": actor.switch_weapon()
		"select_weapon": actor.select_weapon_slot(parameter)
		"bomb": bomb_control(actor,parameter)
		"cancel_uncommitted":
			# In-flight commands up to the barrier are still consumed in order (to
			# keep sequences aligned) but their movement, jump and use are dropped.
			var previous=command_received.get(actor.remote_peer,{"sequence":actor.cmd_last_seq,"at":-1.0})
			previous.barrier=maxi(int(previous.get("barrier",-1)),parameter);previous.at=now;command_received[actor.remote_peer]=previous
			actor.burst_left=0;actor.net_move=Vector2.ZERO;actor.net_jump=false;actor.net_jump_until=-INF;actor.net_crouch=false;actor.net_interact=false
			actor.server_jump_buffer=0;actor.cmd_template={}
			if actor.action_state in ["melee","throwing"]: actor.action_state="ready"; actor.action_until=now; remote_throws.erase(actor.remote_peer)
		"throw_begin":
			if actor.action_state=="ready" and not is_interacting(actor) and parameter in [0,1] and actor.grenades[parameter]>0:
				actor.action_state="throwing"; actor.action_until=now+0.75;actor.throw_started=now;actor.throw_kind=parameter
				remote_throws[actor.remote_peer]={"kind":parameter,"earliest":now+0.18,"used":false}
@rpc("any_peer","call_remote","reliable")
func authorize_shot(client_event: int, life: int, round_id: int, kind: String, pos: Vector3, direction: Vector3, session: int, zoom_level: int=0, cmd_seq: int=-1, view_time: float=-1.0) -> void:
	if film_retaining_transport:return
	if matchmaking.blocks_simulation():return
	if session!=match_session or not network_active or not multiplayer.is_server() or not running:return
	if client_event<=0 or client_event%16!=0 or not pos.is_finite() or not direction.is_finite() or absf(direction.length()-1)>.01 or not is_finite(view_time):return
	var sender=multiplayer.get_remote_sender_id();var actor=actor_for_peer(sender)
	if actor==null:return
	if not network_policy.admit(sender,"shot",local_clock(),40,12):net_stat("shot_rate_rejected");return
	if cmd_seq<=0:return # This protocol requires a shot's numbered input.
	var shot=apply_shot.bind(sender,actor,client_event,life,round_id,kind,pos,direction,session,zoom_level,cmd_seq,view_time,local_clock())
	# A sequenced shot executes right after the host simulates the movement
	# command it was fired on, so origin, cadence and rewind use that moment
	# rather than whenever the packet happened to arrive.
	if cmd_seq<=0: shot.call()
	else: defer_for_command(actor,cmd_seq,shot)
func apply_shot(sender: int, actor: NestActor, client_event: int, life: int, round_id: int, kind: String, pos: Vector3, direction: Vector3, session: int, zoom_level: int, cmd_seq: int, view_time: float, received_at: float=-1.0) -> void:
	if not is_instance_valid(actor) or session!=match_session or not network_active or not running or finished or break_until>now:return
	if not actor.alive or actor.life_id!=life or round_id!=round_number or client_event<=actor.remote_shot_id:return
	actor.remote_shot_id=client_event
	actor.advance_combat_recovery();actor.advance_weapon_timers()
	# Sequenced only when its command was really simulated; otherwise (stalled
	# stream or timeout) fall back to arrival-time validation without rewind.
	var sequenced=cmd_seq>0 and cmd_seq<=actor.cmd_last_seq
	if actor.bomb_equipped or nu.blocked(actor) or actor.action_state!="ready" or now+.000001<actor.hit_stun_until or is_interacting(actor):net_stat("shots_rejected_state");return
	if not sequenced and actor.last_shot_frame==Engine.get_process_frames():return
	var weapon=actor.weapons[actor.slot];var config=NestWeaponCatalog.for_kind(kind)
	if weapon.kind!=kind or kind=="plasma_sword" or actor.ammo[actor.slot]<=0:net_stat("shots_rejected_weapon");return
	if pos.distance_to(actor.eye.global_position)>1.25:net_stat("shots_rejected_origin");return
	# Allow recoil/spread and sub-tick mouse motion, but reject unrelated aim.
	var command_aim: Vector3=actor.command_aims.get(cmd_seq,-actor.eye.global_basis.z)
	if direction.dot(command_aim)<cos(deg_to_rad(35)):net_stat("shots_rejected_aim");return
	var levels=maxi(config.get("scope_fov",[]).size(),config.get("zoom_factors",[]).size())
	if zoom_level<0 or zoom_level>levels:return
	# Cadence: sequenced shots are timed on the shooter's command timeline (one
	# command per 1/60 s), so packets that arrive together are not misjudged.
	# One tick of tolerance absorbs sub-tick firing; deadlines advance from the
	# schedule, so the tolerance cannot accumulate into a higher fire rate.
	var shot_time=float(cmd_seq)*NET_TICK if sequenced else now
	var tolerance=NET_TICK+.002 if sequenced else .000001
	var clock=remote_shot_clocks.get(sender,{})
	if clock.is_empty() or bool(clock.get("sequenced",false))!=sequenced:
		clock={"next":(-INF if sequenced else actor.cooldown),"burst":0,"sequenced":sequenced}
		if sequenced and actor.cooldown>now: clock.next=shot_time+actor.cooldown-now
	if shot_time+tolerance<float(clock.next):net_stat("shots_rejected_cadence");return
	# Sequence gaps must not create fire-rate credit. Bound catch-up on the
	# host's real simulation clock as well as the ordered command timeline.
	if now+.1<float(clock.get("wall_next",now)):net_stat("shots_rejected_wall_cadence");return
	# pos is the bounded client view origin, not the weapon model's muzzle.
	# A clear crosshair must not be clipped by the offset gun. Retain the eye-to-
	# origin cover check so a client cannot place its ray on the far side of a wall.
	var blocked=trace(actor.eye.global_position,pos,1,actor.ray_exclusions())
	if not blocked.is_empty():pos=blocked.position+blocked.normal*.002
	actor.scope_level=zoom_level;actor.consume_round();actor.last_shot_frame=Engine.get_process_frames()
	var first=int(clock.burst)==0
	var interval=weapon.interval
	if int(config.get("burst_count",1))>1:
		clock.burst=(int(clock.burst)+1)%int(config.burst_count)
		interval=float(config.burst_interval) if int(clock.burst)>0 else float(config.burst_delay)
	if sequenced: clock.next=(float(clock.next) if shot_time-float(clock.next)<=tolerance else shot_time)+actor.fire_interval(interval)
	else: clock.next=actor.next_deadline(float(clock.next),actor.fire_interval(interval))
	clock.wall_next=maxf(now-.1,float(clock.get("wall_next",now)))+actor.fire_interval(interval)
	remote_shot_clocks[sender]=clock;actor.cooldown=now+float(clock.next)-shot_time if sequenced else float(clock.next)
	var key=str(sender)+":"+str(client_event)
	shot_authorizations[key]={"origin":pos,"weapon":weapon,"category":"explosion" if weapon.explosive else "bullet","damage":weapon.damage,"precision":weapon.precision,"pellets":weapon.pellets,"id":next_event()*16,"expires":now+maxf(7.0,weapon.max_range/maxf(weapon.speed,1.0)+1.0),"round":round_number,"hits":{},"actor":actor,"authoritative":true}
	actor.accepted_shots+=1
	net_stat("shots_accepted")
	var age: float=network_policy.rewind_age(sender)
	if age>0 and received_at>=0:age=minf(network_policy.maximum_rewind,age+clampf(local_clock()-received_at,0,.05))
	if absf(view_time-(now-age))>.05:net_stat("shot_time_hints_ignored")
	var rewind=sequenced and lag_compensation_enabled and weapon.speed<=0 and not weapon.explosive and age>0
	# Client view_time is diagnostic only. Host probes determine the budget.
	if rewind: begin_rewind(actor,now-age)
	actor.prepare_ak_shot(client_event,shot_time,sequenced)
	var directions=actor.shot_directions(direction.normalized(),pos,client_event,pos)
	for i in range(directions.size()):launch_bullet(actor,weapon,pos,directions[i],i,false,int(shot_authorizations[key].id)+i,first)
	if rewind: end_rewind()
	actor.shot_fired.emit(client_event,now,pos,directions)
	actor.last_shot_kind=weapon.kind;actor.flash_until=now+.15;actor.combat_audio.on_fire(first);actor.add_shot_recoil();actor.queue_auto_reload()
func report_local_hit(victim: NestActor, region: String, category: String, amount: float, event_id: int, distance: float=-1) -> void:
	if category in ["bullet","melee"]: report_hit.rpc_id(1,event_id,victim.net_id,victim.life_id,region,1.0,match_session,distance,remote_view_time)
	elif category=="explosion": report_blast.rpc_id(1,event_id,victim.net_id,victim.life_id,clampf(amount/160.0,0,1),Vector3.UP,match_session)
@rpc("any_peer","call_remote","reliable")
func report_hit(client_event: int, target_id: int, target_life: int, region: String, falloff: float, session: int, reported_distance: float=-1, view_time: float=-1.0) -> void:
	if film_retaining_transport:return
	# Retain the RPC signature for diagnostics; every actual hit is queried by the host.
	# Neither predicted bullets nor melee client contact claims can cause damage.
	if network_active and multiplayer.is_server() and session==match_session:net_stat("client_hit_claims_ignored")
@rpc("any_peer","call_remote","reliable")
func report_blast(client_event: int, target_id: int, target_life: int, factor: float, direction: Vector3, session: int) -> void:
	if film_retaining_transport:return
	if matchmaking.blocks_simulation():return
	if session!=match_session or not direction.is_finite(): return
	if not multiplayer.is_server() or not is_finite(factor): return
	var sender=multiplayer.get_remote_sender_id()
	var key=str(sender)+":"+str(client_event)
	if not shot_authorizations.has(key): return
	var auth=shot_authorizations[key]
	if auth.get("authoritative",false) or auth.expires<now or auth.round!=round_number or auth.hits.has(target_id): return
	var victim=actor_by_id(target_id)
	if victim==null or victim.life_id!=target_life or not victim.alive: return
	if auth.category!="explosion": return
	auth.hits[target_id]=true
	if victim.take_damage(auth.damage*clampf(factor,0,1),"torso","explosion",false,auth.actor,auth.id,Vector3.INF,auth.weapon.kind if auth.get("weapon")!=null else ""):
		var outward=direction.normalized() if direction.length()>0.01 else Vector3.UP
		victim.external=(victim.external+(outward*8+Vector3.UP*2)*clampf(factor,0,1)).limit_length(15)
		confirm_hit.rpc_id(sender)
@rpc("any_peer","call_remote","reliable")
func report_direct_hit(client_event: int, target_id: int, target_life: int, session: int) -> void:
	if film_retaining_transport:return
	if matchmaking.blocks_simulation():return
	if not network_active or not multiplayer.is_server() or session!=match_session: return
	var sender=multiplayer.get_remote_sender_id(); var key=str(sender)+":"+str(client_event)
	if not shot_authorizations.has(key): return
	var auth=shot_authorizations[key]; var victim=actor_by_id(target_id)
	if auth.get("authoritative",false) or auth.weapon==null or not auth.weapon.explosive or auth.expires<now or auth.round!=round_number or auth.hits.has(target_id) or victim==null or not victim.alive or victim.life_id!=target_life: return
	var definition=NestWeaponCatalog.for_kind(auth.weapon.kind)
	auth.hits[target_id]=true
	if victim.take_damage(float(definition.damage_direct),"torso","heavy",false,auth.actor,auth.id,auth.get("origin",auth.actor.eye.global_position),auth.weapon.kind): confirm_hit.rpc_id(sender,"torso",not victim.alive,victim.global_position,match_session)
@rpc("authority","call_remote","reliable")
func confirm_hit(region: String="torso", killed: bool=false, position: Vector3=Vector3.INF, session: int=0) -> void:
	if film_retaining_transport:return
	if not running or (session!=0 and session!=match_session): return
	if film_recorder!=null:film_recorder.event("confirmed_hit",{"region":region,"killed":killed})
	if not position.is_finite(): position=player.eye.global_position
	hit_until=now+0.13
	audio.play_sound("headshot_kill" if killed and region=="head" else "kill_confirm" if killed else "hit_head" if region=="head" else "hit_body",position)
@rpc("any_peer","call_remote","reliable")
func relay_chat(text: String, session: int) -> void:
	if film_retaining_transport:return
	if not multiplayer.is_server() or not running or finished or session!=match_session: return
	var sender=multiplayer.get_remote_sender_id()
	if not lobby_members.has(matchmaking.peers.get(sender,sender)): return
	text=clean_message(text)
	if text.is_empty(): return
	var key="chat:"+str(sender)
	if now-command_received.get(key,-100.0)<1: return
	command_received[key]=now
	var line=lobby_members[matchmaking.peers.get(sender,sender)].name+": "+text
	receive_chat.rpc(line); receive_chat(line)
func clean_message(text: String) -> String:
	return text.strip_edges().replace("\n"," ").replace("\r"," ").substr(0,200)
@rpc("authority","call_remote","reliable")
func receive_chat(text: String) -> void:
	if film_retaining_transport:return
	if not prefs.values.chat: return
	messages.append(text)
	if messages.size()>4: messages.pop_front()
@rpc("authority","call_remote","unreliable",2)
func snapshot_packet(sequence: int, index: int, total: int, data: PackedByteArray, session: int) -> void:
	if film_retaining_transport:return
	if matchmaking.hybrid.enabled:matchmaking.hybrid.session.observed_host_packet(matchmaking.hybrid.session.match_id,matchmaking.hybrid.session.epoch,matchmaking.hybrid.session.authority)
	if session!=match_session: return
	if sequence<=snapshot_received or total<1 or total>24 or index<0 or index>=total or data.size()>850: return
	if not snapshot_fragments.has(sequence): snapshot_fragments[sequence]={"total":total,"chunks":{}}
	var buffer=snapshot_fragments[sequence]
	if buffer.total!=total: return
	buffer.chunks[index]=data
	if buffer.chunks.size()==total:
		var combined=PackedByteArray()
		for i in range(total): combined.append_array(buffer.chunks[i])
		var raw=combined.decompress_dynamic(400000,FileAccess.COMPRESSION_DEFLATE)
		var payload=bytes_to_var(raw)
		if payload is Array and payload.size()==2: receive_snapshot(payload[0],payload[1]); snapshot_received=sequence; net_stat("snapshots_completed")
	for key in snapshot_fragments.keys():
		if key<=snapshot_received or key<sequence-4: snapshot_fragments.erase(key)
@rpc("authority","call_remote","unreliable",3)
func cosmetic_bullet(actor_id: int, kind: String, pos: Vector3, direction: Vector3, session: int, round_id: int, play_audio: bool=true, first_in_burst: bool=true) -> void:
	if film_retaining_transport:return
	if not running or session!=match_session or round_id!=round_number: return
	var actor=actor_by_id(actor_id)
	if actor==null or actor.local_player: return
	var profile: NestWeapon=NestWeaponCatalog.profile(kind)
	actor.flash_until=now+0.15
	launch_bullet(actor,profile,pos,direction,0,true)
	if play_audio: actor.combat_audio.on_fire(first_in_burst)
@rpc("authority","call_remote","reliable")
func cosmetic_grenade(actor_id: int, kind: int, origin: Vector3, direction: Vector3, inherited_velocity: Vector3, session: int, round_id: int) -> void:
	if film_retaining_transport:return
	if not running or session!=match_session or round_id!=round_number: return
	var actor=actor_by_id(actor_id)
	if actor==null or actor.local_player: return
	launch_grenade(actor,kind,true,0,origin,direction,inherited_velocity)
@rpc("any_peer","call_remote","reliable")
func authorize_melee(client_event: int, life: int, round_id: int, session: int, cmd_seq: int=-1, lunge: Vector3=Vector3.ZERO) -> void:
	if film_retaining_transport:return
	if matchmaking.blocks_simulation():return
	if session!=match_session or not multiplayer.is_server() or client_event<=0 or client_event%16!=0: return
	var sender=multiplayer.get_remote_sender_id()
	var actor=actor_for_peer(sender)
	if actor==null: return
	if not network_policy.admit(sender,"melee",local_clock(),8,4):return
	# Bound the prediction hint; the host derives the actual lunge on its command tick.
	if not lunge.is_finite() or absf(lunge.y)>.001 or lunge.length()>float(damage_rules.melee_max_lunge_m)+.01: lunge=Vector3.ZERO
	var melee=apply_melee.bind(sender,actor,client_event,life,round_id,session,lunge)
	if cmd_seq<=0: melee.call()
	else: defer_for_command(actor,cmd_seq,melee)
func apply_melee(sender: int, actor: NestActor, client_event: int, life: int, round_id: int, session: int, lunge: Vector3=Vector3.ZERO) -> void:
	if session!=match_session or not is_instance_valid(actor): return
	if not running or finished or break_until>now: return
	if nu.blocked(actor) or client_event<=actor.remote_melee_id or not actor.alive or actor.life_id!=life or round_id!=round_number or actor.action_state!="ready" or actor.cooldown>now or actor.melee_ready_at>now or actor.bomb_equipped: return
	var key=str(sender)+":"+str(client_event)
	if shot_authorizations.has(key): return
	actor.remote_melee_id=client_event
	actor.sword_draw=.6/actor.melee_speed() if actor.character==0 and actor.weapons[actor.slot].kind!="plasma_sword" else 0.0
	shot_authorizations[key]={"weapon":null,"category":"melee","damage":float(damage_rules.melee_damage),"precision":false,"pellets":1,"id":next_event()*16,"expires":now+1,"round":round_number,"hits":{},"actor":actor,"authoritative":true}
	# Recompute from shared movement/target rules; never trust a client-selected displacement or target.
	actor.begin_melee(int(shot_authorizations[key].id),actor.melee_lunge())
	sound("melee",actor.global_position,false)
	cosmetic_melee.rpc(actor.net_id,match_session,round_number,actor.sword_draw,actor.action_until)
@rpc("authority","call_remote","reliable")
func cosmetic_melee(actor_id: int, session: int, round_id: int, draw: float=-1, until: float=-1) -> void:
	if film_retaining_transport:return
	if not running or session!=match_session or round_id!=round_number:return
	var actor=actor_by_id(actor_id)
	if actor==null or actor.local_player:return
	actor.sword_draw=draw if draw>=0 else (.6/actor.melee_speed() if actor.character==0 and actor.weapons[actor.slot].kind!="plasma_sword" else 0.0)
	actor.action_state="melee";actor.action_until=until if until>=0 else now+(actor.sword_draw+.7/actor.melee_speed() if actor.character==0 else float(damage_rules.melee_cooldown_seconds))
	if actor.presentation!=null:actor.presentation.pose_upper_body()
	sound("melee",actor.global_position,false)
@rpc("any_peer","call_remote","reliable")
func authorize_grenade(client_event: int, life: int, round_id: int, kind: int, origin: Vector3, direction: Vector3, inherited_velocity: Vector3, session: int, cmd_seq: int=-1) -> void:
	if film_retaining_transport:return
	if matchmaking.blocks_simulation():return
	if session!=match_session or not multiplayer.is_server(): return
	if kind<0 or kind>1 or not origin.is_finite() or not direction.is_finite() or not inherited_velocity.is_finite() or origin.length()>1000: return
	var sender=multiplayer.get_remote_sender_id()
	var actor=actor_for_peer(sender)
	if actor==null: return
	if not network_policy.admit(sender,"grenade",local_clock(),8,4):return
	var grenade=apply_grenade.bind(sender,actor,client_event,life,round_id,kind,origin,direction,inherited_velocity,session)
	if cmd_seq<=0: grenade.call()
	else: defer_for_command(actor,cmd_seq,grenade)
func apply_grenade(sender: int, actor: NestActor, client_event: int, life: int, round_id: int, kind: int, origin: Vector3, direction: Vector3, _inherited_velocity: Vector3, session: int) -> void:
	if session!=match_session or not is_instance_valid(actor): return
	if not running or finished or break_until>now: return
	if not actor.alive or actor.life_id!=life or round_id!=round_number or actor.action_state!="throwing" or actor.grenades[kind]<=0: return
	var pending=remote_throws.get(sender,{"used":true,"kind":-1,"earliest":INF})
	if pending.used or pending.kind!=kind:return
	if now<pending.earliest:
		if not pending.has("release"):pending.release=apply_grenade.bind(sender,actor,client_event,life,round_id,kind,origin,direction,_inherited_velocity,session)
		return
	if origin.distance_to(actor.eye.global_position)>1.25 or absf(direction.length()-1)>.01:return
	pending.used=true
	var key=str(sender)+":"+str(client_event)
	if shot_authorizations.has(key): return
	actor.grenades[kind]-=1; actor.action_state="throwing"; actor.action_until=now+0.55
	shot_authorizations[key]={"weapon":null,"category":"explosion","damage":float(NestWeaponCatalog.definition("plasma_grenade" if kind==1 else "frag_grenade").splash_damage_max),"precision":false,"pellets":1,"id":next_event()*16,"expires":now+7,"round":round_number,"hits":{},"actor":actor,"authoritative":true}
	launch_grenade(actor,kind,false,int(shot_authorizations[key].id),actor.grenade_release_origin(),direction.normalized(),actor.velocity.limit_length(50))
func process_pending_grenade_releases() -> void:
	for peer in remote_throws:
		var pending: Dictionary=remote_throws[peer]
		if pending.has("release") and now>=float(pending.earliest):
			var release: Callable=pending.release;pending.erase("release");release.call()
func is_interacting(actor: NestActor) -> bool:
	if nu!=null and nu.blocked(actor):return false
	if mode not in [0,MODE_CS] or interaction_for(actor).is_empty(): return false
	if actor.local_player: return actor.input_active() and actor.gameplay_held("interact")
	return actor.net_interact if actor.remote_peer>1 else bot_progress.has(actor.get_instance_id())
func clear_effects() -> void:
	if nu!=null:nu.clear()
	death_body_keys.clear()
	for body in corpses.get_children():body.queue_free()
	for child in effects.get_children():
		effects.remove_child(child) # Cancel collision and callbacks immediately at the round boundary.
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D: child.stop(); child.stream=null
		child.queue_free()
func prepare_match_input() -> void:
	nu_sightings=[{},{}]
	clear_held_input()
	kill_feed.clear(); local_kill_notice="";local_kill_notice_until=-100;seen_kill_notices.clear(); messages.clear(); last_message=-100; hit_until=0; hurt_until=0
	objective_audio_sequence=0;received_objective_audio=0;last_defuse_cue=-INF
	command_received.clear(); command_sequence=0; snapshot_sequence=0; snapshot_received=-1; snapshot_fragments.clear(); remote_throws.clear()
	reset_network_timing()
func clear_held_input() -> void:
	if is_instance_valid(player):player.clear_local_input()
	for action in InputMap.get_actions(): Input.action_release(action)
# ---- Network timing ----
func local_clock() -> float:
	return Time.get_ticks_usec()/1000000.0
@rpc("authority","call_remote","unreliable",1)
func network_probe(nonce: int, session: int, one_way: float=0) -> void:
	if film_retaining_transport:return
	if is_client() and session==match_session:
		if is_finite(one_way):host_oneway=clampf(one_way,0,.25)
		network_probe_reply.rpc_id(1,nonce,session,interp_delay)
@rpc("any_peer","call_remote","unreliable",1)
func network_probe_reply(nonce: int, session: int, view_delay: float=.075) -> void:
	if film_retaining_transport:return
	if not network_active or not multiplayer.is_server() or session!=match_session:return
	var peer=multiplayer.get_remote_sender_id()
	if actor_for_peer(peer)!=null and network_policy.finish_probe(peer,nonce,local_clock(),view_delay):net_stat("latency_probes_accepted")
func net_stat(key: String, amount: float=1.0) -> void:
	net_stats[key]=float(net_stats.get(key,0.0))+amount
func net_stat_max(key: String, value: float) -> void:
	net_stats[key]=maxf(float(net_stats.get(key,0.0)),value)
func reset_network_timing() -> void:
	network_policy=NestNetworkPolicy.new();probe_at=0;physics_samples.clear();transport_sample_at=local_clock()
	network_policy.maximum_rewind=clampf(maximum_hitscan_rewind_ms/1000,0,NestNetworkPolicy.MAX_REWIND)
	clock_ready=false; clock_offset=0; clock_spread=0; host_oneway=0;interp_delay=.1; remote_view_time=0
	prediction_ready=false; prediction_offset=0; lift_sync_ready=false; lift_offset=0
	hitbox_history.clear(); rewind_active=false; rewind_boxes.clear(); rewind_poses.clear()
	blocker_history.clear();rewind_blockers.clear()
	command_drop_packets=0; command_send_paused=false; snapshot_tick=0; net_stats.clear()
	var lift=lift_node()
	if lift!=null: lift.clock_source=Callable()
func observe_server_clock(match_state: Dictionary) -> void:
	# Each snapshot is stamped with host simulation time. The estimate follows
	# the earliest arrivals (least delayed) and relaxes slowly, so it stays
	# stable under jitter; the observed spread sizes the interpolation buffer.
	var server_now=float(match_state.now)
	var sample=server_now+host_oneway-local_clock()
	if not clock_ready or absf(sample-clock_offset)>1.0:
		clock_offset=sample; clock_spread=0; clock_ready=true; now=server_now; remote_view_time=0
	else:
		clock_offset+=(sample-clock_offset)*(.3 if sample>clock_offset else .02)
		clock_spread=lerpf(clock_spread,absf(clock_offset-sample),.1)
	var minimum_delay=maxf(NestNetworkPolicy.INTERPOLATION_MIN,float(snapshot_interval_ticks)*NET_TICK*1.5)
	interp_delay=clampf(float(snapshot_interval_ticks)*NET_TICK+.02+2.5*clock_spread,minimum_delay,NestNetworkPolicy.INTERPOLATION_MAX)
	net_stats["interp_delay_ms"]=interp_delay*1000
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		var host=(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(1)
		if host!=null:
			net_stats["enet_rtt_ms"]=float(host.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
			net_stats["enet_throttle"]=float(host.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE))
			net_stats["enet_loss"]=float(host.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS))
	if match_state.has("lift"):
		lift_offset=float(match_state.lift)-server_now; lift_sync_ready=true; update_lift_source()
func update_remote_view_time(delta: float) -> void:
	var target=local_clock()+clock_offset-interp_delay
	if remote_view_time<=0 or absf(target-remote_view_time)>.25: remote_view_time=target
	else: remote_view_time+=delta+clampf(target-(remote_view_time+delta),-delta*.1,delta*.1)
func observe_prediction_ack(actor: NestActor, ack: int, server_now: float) -> void:
	# Host time at which a command was simulated minus the local time it was
	# issued: lets the client run time-driven world motion (the lift) on the
	# same timeline the host will simulate this client's commands against.
	for entry in actor.cmd_history:
		if entry.seq!=ack: continue
		var sample=server_now-float(entry.t)
		if not prediction_ready: prediction_offset=sample; prediction_ready=true; update_lift_source()
		else: prediction_offset+=(sample-prediction_offset)*(.3 if sample<prediction_offset else .02)
		return
func lift_node() -> Node:
	return arena.get_node_or_null("U2Lift") if is_instance_valid(arena) else null
func current_lift_clock() -> float:
	var lift=lift_node()
	return float(lift.clock) if lift!=null else 0.0
func predicted_lift_clock() -> float:
	return lift_offset+local_clock()+prediction_offset
func update_lift_source() -> void:
	var lift=lift_node()
	if lift!=null and is_client() and lift_sync_ready and prediction_ready and not lift.clock_source.is_valid(): lift.clock_source=predicted_lift_clock
func lift_physics_y() -> float:
	# Height the physics engine is using for the lift right now (it applies the
	# lift's scripted position at the next physics step).
	var lift=lift_node()
	if lift==null or not lift is PhysicsBody3D: return NAN
	return (PhysicsServer3D.body_get_state(lift.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM) as Transform3D).origin.y
func on_lift_column(pos: Vector3, lift_y: float) -> bool:
	var lift=lift_node()
	if lift==null or not lift is PhysicsBody3D: return false
	var shaft: Vector2=lift.shaft_position
	return absf(pos.x-shaft.x)<=2.9 and absf(pos.z-shaft.y)<=2.9 and pos.y-lift_y>=-.3 and pos.y-lift_y<=2.6
func finish_physics_measurement() -> void:
	if physics_started>0:
		var cost=Time.get_ticks_usec()-physics_started
		physics_samples.append(float(cost)/1000)
		if physics_samples.size()>180:physics_samples.pop_front()
		net_stat("physics_ticks");net_stat("physics_us_sum",cost);net_stat_max("physics_us_max",cost)
		if cost>16667:net_stat("physics_overruns")
		physics_started=0
func late_physics() -> void:
	if network_active and multiplayer.multiplayer_peer is ENetMultiplayerPeer and local_clock()-transport_sample_at>=1:
		var elapsed=local_clock()-transport_sample_at
		transport_sample_at=local_clock()
		var connection=(multiplayer.multiplayer_peer as ENetMultiplayerPeer).host
		for metric in [["transport_bytes_sent",ENetConnection.HOST_TOTAL_SENT_DATA],["transport_packets_sent",ENetConnection.HOST_TOTAL_SENT_PACKETS],["transport_bytes_received",ENetConnection.HOST_TOTAL_RECEIVED_DATA],["transport_packets_received",ENetConnection.HOST_TOTAL_RECEIVED_PACKETS]]:
			var amount=connection.pop_statistic(metric[1])
			net_stat(metric[0],amount);net_stats[str(metric[0])+"_per_second"]=amount/elapsed
	if running and network_active and multiplayer.is_server() and local_clock()>=probe_at:
		probe_at=local_clock()+1
		for peer in multiplayer.get_peers():
			if actor_for_peer(peer)!=null:
				var nonce: int=network_policy.start_probe(peer,local_clock())
				network_probe.rpc_id(peer,nonce,match_session,network_policy.one_way(peer))
	if matchmaking.blocks_simulation():return
	# Runs after every actor has simulated this tick.
	if not running or not network_active or not multiplayer.is_server(): return
	record_hitbox_history()
	for actor in actors:
		if not actor.cmd_deferred.is_empty(): run_deferred_commands(actor)
	snapshot_tick+=1
	if snapshot_tick>=snapshot_interval_ticks: snapshot_tick=0; send_snapshot()
# ---- Command-ordered client actions ----
func defer_for_command(actor: NestActor, seq: int, action: Callable) -> void:
	# If the host is not simulating this client's commands at all (stalled
	# stream), waiting would only add delay: apply on arrival instead.
	if seq>actor.cmd_last_seq+NestNetworkPolicy.MAX_COMMAND_LEAD or seq<actor.cmd_last_seq-30 or actor.cmd_deferred.size()>=NestNetworkPolicy.MAX_PENDING_ACTIONS: net_stat("deferred_rejected"); return
	if seq<=actor.cmd_last_seq or now-actor.net_last_command>COMMAND_STALL: action.call(); return
	actor.cmd_deferred.append({"seq":seq,"action":action,"at":now})
	net_stat("deferred_actions")
func run_deferred_commands(actor: NestActor) -> void:
	# In order: an action waits for its own command; after DEFER_TIMEOUT it runs
	# anyway so a lost command cannot hold later actions forever.
	while not actor.cmd_deferred.is_empty():
		var item: Dictionary=actor.cmd_deferred[0]
		var ready=int(item.seq)<=actor.cmd_last_seq
		if not ready and now-float(item.at)<=DEFER_TIMEOUT: break
		actor.cmd_deferred.pop_front()
		if not ready: net_stat("deferred_timeouts")
		item.action.call()
# ---- Bounded server-side lag compensation ----
func record_blocker_history() -> void:
	var bodies: Array=get_tree().get_nodes_in_group("network_rewind_blocker")
	for group in arena.sealed_bodies:
		for body in group:
			if body not in bodies:bodies.append(body)
	var boxes=[]
	for body in bodies:
		if not is_instance_valid(body) or not body is CollisionObject3D or (body.collision_layer&1)==0:continue
		for collision in body.find_children("*","CollisionShape3D",true,false):
			if collision.disabled or collision.shape==null:continue
			var shape: Shape3D=collision.shape
			var xf: Transform3D=collision.global_transform
			if shape is ConvexPolygonShape3D and not shape.has_meta("hull_planes"):
				# Changing ore cover uses a conservative cached hull bound. This
				# may deny an edge shot; it cannot expose a historical solid.
				if not shape.has_meta("rewind_bound"):
					var low=Vector3.INF;var high=-Vector3.INF
					for p in shape.points:low=low.min(p);high=high.max(p)
					var bound=BoxShape3D.new();bound.size=high-low
					shape.set_meta("rewind_bound",bound);shape.set_meta("rewind_center",(low+high)*.5)
				xf.origin=xf*Vector3(shape.get_meta("rewind_center"))
				shape=shape.get_meta("rewind_bound")
			boxes.append({"body":body,"rid":body.get_rid(),"shape":shape,"xf":xf})
	blocker_history.append({"t":now,"boxes":boxes})
	while blocker_history.size()>1 and now-float(blocker_history[0].t)>LAG_COMP_HISTORY:blocker_history.pop_front()
func record_hitbox_history() -> void:
	record_blocker_history()
	var live={}
	for actor in actors:
		var id=actor.get_instance_id(); live[id]=true
		var boxes=[]
		for hitbox in actor.hitboxes: boxes.append(hitbox.global_transform)
		var list: Array=hitbox_history.get(id,[])
		list.append({"t":now,"life":actor.life_id,"alive":actor.alive,"pos":actor.global_position,"crouched":actor.crouched,"air_duck":actor.air_duck,"waist":actor.waist_position(),"boxes":boxes})
		while list.size()>1 and now-float(list[0].t)>LAG_COMP_HISTORY: list.pop_front()
		hitbox_history[id]=list
	for id in hitbox_history.keys():
		if not live.has(id): hitbox_history.erase(id)
func current_pose(actor: NestActor) -> Dictionary:
	var boxes=[]
	for hitbox in actor.hitboxes: boxes.append(hitbox.global_transform)
	return {"pos":actor.global_position,"crouched":actor.crouched,"air_duck":actor.air_duck,"waist":actor.waist_position(),"boxes":boxes}
func historical_pose(actor: NestActor, t: float) -> Dictionary:
	var list: Array=hitbox_history.get(actor.get_instance_id(),[])
	if list.is_empty() or t>=float(list[-1].t): return current_pose(actor)
	var a: Dictionary=list[0]; var b: Dictionary=list[0]
	for k in range(list.size()-1):
		if float(list[k+1].t)>=t: a=list[k]; b=list[k+1]; break
	# A target that was dead or in a different life at that time cannot be hit.
	if int(a.life)!=actor.life_id or int(b.life)!=actor.life_id or not a.alive or not b.alive: return {}
	var f=clampf((t-float(a.t))/maxf(float(b.t)-float(a.t),.0001),0,1)
	if a.pos.distance_to(b.pos)>8: f=0.0 if f<.5 else 1.0
	var boxes=[]
	for i in range(a.boxes.size()): boxes.append(a.boxes[i].interpolate_with(b.boxes[i],f))
	var near=a if f<.5 else b
	return {"waist":a.get("waist",a.pos+Vector3.UP*.99*NestActor.SIZE).lerp(b.get("waist",b.pos+Vector3.UP*.99*NestActor.SIZE),f),"pos":a.pos.lerp(b.pos,f),"crouched":near.crouched,"air_duck":near.air_duck,"boxes":boxes}
func begin_rewind(shooter: NestActor, view_time: float) -> void:
	var target=clampf(view_time,now-LAG_COMP_MAX_REWIND,now)
	if view_time<now-LAG_COMP_MAX_REWIND: net_stat("rewinds_clamped")
	net_stat("rewinds"); net_stat("rewind_ms_sum",(now-target)*1000); net_stat_max("rewind_ms_max",(now-target)*1000)
	rewind_active=true; rewind_boxes.clear(); rewind_poses.clear()
	rewind_blockers.clear()
	# Keep current cover AND historical cover. Opening/removing a blocker must
	# not let an older shot pass through where that cover used to be.
	for frame in blocker_history:
		if float(frame.t)>target:break
		rewind_blockers=frame.boxes
	for actor in actors:
		if actor==shooter or not actor.alive: continue
		var pose=historical_pose(actor,target)
		if pose.is_empty(): continue
		rewind_poses[actor.get_instance_id()]=pose
		for i in range(actor.hitboxes.size()):
			rewind_boxes.append({"area":actor.hitboxes[i],"rid":actor.hitboxes[i].get_rid(),"xf":pose.boxes[i],"shape":actor.hitbox_shapes[i]})
func end_rewind() -> void:
	rewind_active=false; rewind_boxes.clear(); rewind_poses.clear();rewind_blockers=[]
func aim_pose_of(other: NestActor) -> Dictionary:
	if rewind_active: return rewind_poses.get(other.get_instance_id(),{})
	return {"pos":other.global_position,"crouched":other.crouched,"air_duck":other.air_duck}
func rewound_trace(start: Vector3, finish: Vector3, mask: int, excludes: Array[RID]) -> Dictionary:
	# World geometry still comes from the physics engine; actor hitboxes are
	# tested analytically at their recorded transforms. (The engine only moves
	# areas in its broadphase at the next physics step, so moving the real
	# hitboxes back and casting in the same frame would test stale positions.)
	var hit={}
	var best=INF
	var length=start.distance_to(finish)
	if mask&~4:
		var query=PhysicsRayQueryParameters3D.create(start,finish,mask&~4,excludes)
		query.collide_with_areas=true; query.hit_from_inside=true
		var world=get_world_3d().direct_space_state.intersect_ray(query)
		if not world.is_empty(): hit=world; best=start.distance_to(world.position)/length
	for box in rewind_blockers:
		if box.rid in excludes or not is_instance_valid(box.body):continue
		var f=ray_shape_fraction(start,finish,box.xf,box.shape)
		if f>=0 and f<best:best=f;hit={"position":start.lerp(finish,f),"normal":(start-finish)/length,"collider":box.body,"rid":box.rid,"shape":0}
	for box in rewind_boxes:
		if box.rid in excludes: continue
		var f=ray_shape_fraction(start,finish,box.xf,box.shape)
		if f>=0 and f<best: best=f; hit={"position":start.lerp(finish,f),"normal":(start-finish)/length,"collider":box.area,"rid":box.rid,"shape":0}
	return hit
static func ray_shape_fraction(start: Vector3, finish: Vector3, xf: Transform3D, shape: Shape3D) -> float:
	var inverse=xf.affine_inverse()
	var o=inverse*start; var d=inverse*finish-o
	if shape is ConvexPolygonShape3D:
		var low: Vector3=shape.get_meta("minimum");var high: Vector3=shape.get_meta("maximum")
		if ray_box(o-(low+high)*.5,d,(high-low)*.5)<0:return -1.0
		return ray_convex(o,d,shape.get_meta("hull_planes"))
	if shape is BoxShape3D: return ray_box(o,d,shape.size*.5)
	if shape is CapsuleShape3D: return ray_capsule(o,d,shape.radius,shape.height)
	return -1.0
static func ray_convex(origin: Vector3, direction: Vector3, planes: Array) -> float:
	var enter=0.0;var leave=1.0
	for plane in planes:
		var distance=plane.normal.dot(origin)-plane.d
		var rate=plane.normal.dot(direction)
		if absf(rate)<1e-9:
			if distance>1e-6:return -1.0
			continue
		var t=-distance/rate
		if rate<0:enter=maxf(enter,t)
		else:leave=minf(leave,t)
		if enter>leave:return -1.0
	return enter
static func ray_box(o: Vector3, d: Vector3, half: Vector3) -> float:
	var t_min=0.0; var t_max=1.0
	for axis in range(3):
		if absf(d[axis])<1e-9:
			if absf(o[axis])>half[axis]: return -1.0
			continue
		var t1=(-half[axis]-o[axis])/d[axis]; var t2=(half[axis]-o[axis])/d[axis]
		t_min=maxf(t_min,minf(t1,t2)); t_max=minf(t_max,maxf(t1,t2))
		if t_min>t_max: return -1.0
	return t_min
static func ray_capsule(o: Vector3, d: Vector3, radius: float, height: float) -> float:
	# Godot capsules: Y axis, total height includes both hemispherical caps.
	var half=maxf(height*.5-radius,0)
	var closest=Vector3(0,clampf(o.y,-half,half),0)
	if o.distance_to(closest)<=radius: return 0.0
	var best=INF
	var a=d.x*d.x+d.z*d.z
	if a>1e-12:
		var b=2*(o.x*d.x+o.z*d.z); var c=o.x*o.x+o.z*o.z-radius*radius
		var disc=b*b-4*a*c
		if disc>=0:
			var t=(-b-sqrt(disc))/(2*a)
			if t>=0 and t<=1 and absf(o.y+t*d.y)<=half: best=t
	for cy in [-half,half]:
		var oc=o-Vector3(0,cy,0)
		var qa=d.dot(d); var qb=2*d.dot(oc); var qc=oc.dot(oc)-radius*radius
		var qd=qb*qb-4*qa*qc
		if qa>1e-12 and qd>=0:
			var t=(-qb-sqrt(qd))/(2*qa)
			if t>=0 and t<=1: best=minf(best,t)
	return best if best<INF else -1.0
# ---- Teams and characters ----
func bot_name(team: int, index: int) -> String:
	var chars: Array=MATCHUPS[clampi(matchup,0,3)]
	var base="Naki" if chars[team]==0 else "Annu"
	return base+("_%02d"%(index+1) if chars[0]!=chars[1] else "_%s%d"%["A" if team==0 else "B",index+1])
func team_name(team: int) -> String:
	# Teams are named after their current character; mirror matchups add A/B.
	var name="NAKI" if team_characters[team]==0 else "ANNU"
	return ("RED " if team==0 else "GREEN ")+name if team_characters[0]==team_characters[1] else name
func switch_sides() -> void:
	# Every role_switch_rounds rounds the teams exchange characters and starting
	# sides. Scores stay with the teams (players), not with the characters.
	attacking_faction=1-attacking_faction
	team_characters.assign([team_characters[1],team_characters[0]])
	for actor in actors:
		if actor.character_choice<0:actor.set_character(team_characters[actor.faction])
	announce("halftime")
	messages.append("Sides switched · Teams exchange characters and starting sides")
	if messages.size()>4: messages.pop_front()
# ---- Capture the Flag (mode 3) ----
# Each team's flag stands at its base on the middle floor. Touch the enemy flag
# to take it; touch your own dropped flag to return it; reach your base with
# the enemy flag while your own flag is home to capture. Carriers drop the
# flag when they die; a dropped flag returns home after FLAG_RETURN_SECONDS.
const MODE_CS: int = 4
const MODE_CTF: int = 3
const MODE_NAMES=["EXTRACTION","ISO DEATHMATCH","TEAM DEATHMATCH","CAPTURE THE FLAG","BOMB DEFUSAL"]
const FLAG_BASES=[Vector3(-27.2,7.65,-0.4),Vector3(27.2,7.65,-0.4)]
const FLAG_TOUCH_M: float = 1.5
const FLAG_CAPTURE_M: float = 2.2
const FLAG_RETURN_SECONDS: float = 20.0
const FLAG_COLORS=[Color("5fb4e6"),Color("e0765c")]
var flags: Array = []
var flag_nodes: Array = []
var flag_labels: Array = []
func reset_flags() -> void:
	flags.clear()
	for team in [0,1]: flags.append({"state":"home","pos":flag_bases[team],"dropped_at":0.0})
	for actor in actors: actor.flag_carry=-1
	update_flag_visuals()
func flag_carrier(team: int) -> NestActor:
	for actor in actors:
		if actor.flag_carry==team: return actor
	return null
func update_ctf() -> void:
	if flags.size()!=2: reset_flags()
	for team in [0,1]:
		var flag: Dictionary=flags[team]
		if flag.state=="carried":
			var carrier=flag_carrier(team)
			if carrier==null or not carrier.alive: flag.state="home"; flag.pos=flag_bases[team]
			else: flag.pos=carrier.global_position
		elif flag.state=="dropped" and now-float(flag.dropped_at)>=FLAG_RETURN_SECONDS:
			flag.state="home"; flag.pos=flag_bases[team]; ctf_event("returned_timeout",team,null)
	for actor in actors:
		if not actor.alive: continue
		var own: int=actor.faction; var enemy: int=1-own
		var reach=FLAG_TOUCH_M*NestActor.SIZE
		if actor.flag_carry<0 and flags[enemy].state!="carried" and actor.global_position.distance_to(flags[enemy].pos)<=reach:
			flags[enemy].state="carried"; actor.flag_carry=enemy; flags[enemy].pos=actor.global_position; ctf_event("taken",enemy,actor)
		if flags[own].state=="dropped" and actor.global_position.distance_to(flags[own].pos)<=reach:
			flags[own].state="home"; flags[own].pos=flag_bases[own]; actor.flag_returns+=1; ctf_event("returned",own,actor)
		if actor.flag_carry==enemy and flags[own].state=="home" and actor.global_position.distance_to(flag_bases[own])<=FLAG_CAPTURE_M*NestActor.SIZE:
			actor.flag_carry=-1; flags[enemy].state="home"; flags[enemy].pos=flag_bases[enemy]
			actor.captures+=1; scores[own]+=1; ctf_event("captured",enemy,actor)
			if scores[own]>=tuning.score_limit: finish_match(); return
func drop_flag(actor: NestActor) -> void:
	var team=actor.flag_carry
	actor.flag_carry=-1
	if team<0 or flags.size()!=2: return
	var pos=actor.global_position
	var support=trace(pos+Vector3(0,.3,0),pos-Vector3(0,30,0),1)
	if support.is_empty() or pos.y<-15:
		flags[team].state="home"; flags[team].pos=flag_bases[team]; ctf_event("returned_timeout",team,null); return
	var safe=NestPlacementSafety.dropped(self,pos,.8,2.4,flag_bases[team])
	if not safe.is_finite():flags[team].state="home";flags[team].pos=flag_bases[team];return
	flags[team].state="dropped"; flags[team].pos=safe; flags[team].dropped_at=now
	ctf_event("dropped",team,actor)
func ctf_event(kind: String, team: int, actor: NestActor) -> void:
	var who=actor.username if is_instance_valid(actor) else ""
	var flag_name=team_name(team)+" FLAG"
	var text={"taken":"%s took the %s"%[who,flag_name],"dropped":"%s dropped the %s"%[who,flag_name],"returned":"%s returned the %s"%[who,flag_name],
		"returned_timeout":"The %s returned to base"%flag_name,"captured":"%s captured the %s"%[who,flag_name]}.get(kind,"")
	kill_feed.push_front({"text":text,"until":now+5})
	if kill_feed.size()>4: kill_feed.pop_back()
	var pos=flag_bases[team] if not is_instance_valid(actor) else actor.global_position
	sound("objective",pos,is_instance_valid(actor) and actor.local_player)
	if network_active and multiplayer.is_server(): ctf_sound.rpc(pos,match_session)
@rpc("authority","call_remote","reliable")
func ctf_sound(pos: Vector3, session: int) -> void:
	if film_retaining_transport:return
	if running and session==match_session: sound("objective",pos,false)
func build_flag_visuals() -> void:
	if not flag_nodes.is_empty(): return
	var kit=arena.kit
	for team in [0,1]:
		var root=Node3D.new(); root.name="CTFFlag%d"%team; add_child(root)
		var cloth_mat=kit.material(FLAG_COLORS[team])
		kit.cylinder(root,Vector3(0,1.1,0),.035,2.2,kit.dark)
		var cloth=kit.box(root,Vector3(.36,1.9,0),Vector3(.68,.42,.04),cloth_mat); cloth.name="Cloth"
		var label=Label3D.new(); label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test=true; label.fixed_size=true; label.pixel_size=.0009
		label.font_size=26; label.outline_size=6; label.modulate=Color(FLAG_COLORS[team],.75); label.position=Vector3(0,2.7,0); root.add_child(label)
		var base=Node3D.new(); base.name="CTFBase%d"%team; add_child(base); base.position=flag_bases[team]+Vector3(0,.03,0)
		kit.ring(base,Vector3.ZERO,FLAG_CAPTURE_M*NestActor.SIZE*.8,cloth_mat)
		flag_nodes.append({"flag":root,"base":base}); flag_labels.append(label)
func update_flag_visuals() -> void:
	if mode!=MODE_CTF or not running:
		for item in flag_nodes: item.flag.visible=false; item.base.visible=false
		return
	build_flag_visuals()
	if flags.size()!=2: return
	for team in [0,1]:
		var item: Dictionary=flag_nodes[team]; var flag: Dictionary=flags[team]
		item.flag.visible=true; item.base.visible=true
		var carrier=flag_carrier(team) if flag.state=="carried" else null
		if is_instance_valid(carrier):
			# Carried high on the carrier's back so everyone can see who has it.
			item.flag.global_position=carrier.global_position+carrier.global_transform.basis.z*.25*NestActor.SIZE+Vector3(0,.55*NestActor.SIZE,0)
			item.flag.rotation=Vector3(0,carrier.rotation.y,0)
		else:
			item.flag.global_position=flag.pos; item.flag.rotation=Vector3(0,now*.6 if flag.state=="dropped" else 0.0,0)
		var state_text="AT BASE" if flag.state=="home" else "TAKEN" if flag.state=="carried" else "DROPPED · %d s"%ceili(maxf(0,FLAG_RETURN_SECONDS-(now-float(flag.dropped_at))))
		flag_labels[team].text=team_name(team)+" FLAG\n"+state_text
func ctf_summary(viewer: NestActor) -> String:
	if flags.size()!=2: return ""
	var own=viewer.faction; var enemy=1-own
	var describe=func(team: int) -> String:
		var flag: Dictionary=flags[team]
		if flag.state=="home": return "at base"
		if flag.state=="dropped": return "dropped · returns in %d s"%ceili(maxf(0,FLAG_RETURN_SECONDS-(now-float(flag.dropped_at))))
		var carrier=flag_carrier(team)
		return "taken by "+(carrier.username if carrier!=null else "?")
	return "YOUR FLAG  %s   ·   ENEMY FLAG  %s"%[describe.call(own),describe.call(enemy)]
func ctf_bot_goal(actor: NestActor) -> Vector3:
	var own=actor.faction; var enemy=1-own
	if actor.flag_carry>=0: return flag_bases[own]
	if flags[own].state=="dropped": return flags[own].pos
	if flags[own].state=="carried":
		var thief=flag_carrier(own)
		if thief!=null: return thief.global_position
	if flags[enemy].state!="carried": return flags[enemy].pos
	var mate=flag_carrier(enemy)
	return mate.global_position if mate!=null else flag_bases[own]

func member_character(member: Dictionary) -> int:
	var choice=int(member.get("character",-1))
	return choice if NestCharacterCatalog.valid_index(choice) else int(MATCHUPS[matchup][clampi(int(member.faction),0,1)])
func set_personal_lobby(choice: int, ready: bool) -> void:
	if not god_mode:choice=-1
	if running or (choice!=-1 and not NestCharacterCatalog.valid_index(choice)):return
	if is_client():request_personal_lobby.rpc_id(1,choice,ready)
	elif network_active:
		apply_personal_lobby(1,choice,ready)
	else:
		selected_character=choice;lobby_ready=ready
		if has_method("network_ui_changed"):call("network_ui_changed")
func apply_personal_lobby(peer: int, choice: int, ready: bool) -> bool:
	if not god_mode or peer!=1:choice=-1
	if matchmaking.active:return false
	if running or is_client() or not lobby_members.has(peer) or (choice!=-1 and not NestCharacterCatalog.valid_index(choice)):return false
	lobby_members[peer]["character"]=choice;lobby_members[peer]["ready"]=ready
	if peer==1:selected_character=choice;lobby_ready=ready
	if network_active:update_lobby.rpc(lobby_members,active_config())
	if has_method("network_ui_changed"):call("network_ui_changed")
	return true
@rpc("any_peer","call_remote","reliable")
func request_personal_lobby(choice: int, ready: bool) -> void:
	if film_retaining_transport:return
	if not network_active or not multiplayer.is_server() or running:return
	# The packet cannot name another slot. Only its authenticated sender is edited.
	var sender=multiplayer.get_remote_sender_id()
	if sender<=1 or not apply_personal_lobby(sender,choice,ready):
		push_warning("Ignored invalid lobby character/ready request from peer %d"%sender)

# Death bodies are cosmetic physics. Living movement/damage rays never include
# layer 16; only the unblocked segment of an authoritative bullet can push one.
func spawn_death_body(actor: NestActor, reason: String) -> void:
	if is_client() or not running:return
	var key="%d:%d:%s"%[match_session,round_number,actor.combat_key()]
	if death_body_keys.has(key):return
	if campaign!=null and campaign.active:campaign.loot.release(actor)
	var spec=NestDeathBody.snapshot(actor,key,reason)
	add_death_body(spec)
	if network_active:receive_death_body.rpc(spec,match_session,round_number)

func add_death_body(spec: Dictionary) -> NestDeathBody:
	if death_body_keys.has(spec.key):return null
	death_body_keys[spec.key]=true
	var age=maxf(0,now-float(spec.born))
	if age>=NestDeathBody.LIFETIME:return null
	var body=NestDeathBody.new();body.spec=spec;body.transform=spec.root;body.age=age
	corpses.add_child(body)
	return body

@rpc("authority","call_remote","reliable")
func receive_death_body(spec: Dictionary, session: int, round_id: int) -> void:
	if film_retaining_transport:return
	if not running or session!=match_session or round_id!=round_number:return
	add_death_body(spec)

func push_death_bodies(start: Vector3, finish: Vector3, direction: Vector3, weapon: NestWeapon, shot_id: int, already_hit: Dictionary) -> void:
	if is_client() or corpses.get_child_count()==0:return
	var excluded: Array[RID]=[]
	# A ray can cross several bodies; exclude every hull of each body after its
	# first contact so a single bullet never adds 17 overlapping impulses.
	for _i in corpses.get_child_count():
		var hit=trace(start,finish,16,excluded)
		if hit.is_empty():break
		if not hit.collider.has_meta("corpse"):break
		var body:NestDeathBody=hit.collider.get_meta("corpse")
		for area in body.hitboxes:excluded.append(area.get_rid())
		if already_hit.has(body.body_key):continue
		already_hit[body.body_key]=true
		var impulse=direction*clampf(weapon.damage*.8,12,100)
		var key="shot:"+str(shot_id)
		body.apply_bullet_impulse(hit.position,impulse,key)
		if network_active:receive_body_impulse.rpc(body.body_key,hit.position,impulse,key,match_session,round_number)

@rpc("authority","call_remote","reliable")
func receive_body_impulse(key: String, point: Vector3, impulse: Vector3, shot_key: String, session: int, round_id: int) -> void:
	if film_retaining_transport:return
	if not running or session!=match_session or round_id!=round_number:return
	for body in corpses.get_children():
		if body.body_key==key:body.apply_bullet_impulse(point,impulse,shot_key);return

# ---- Bomb Defusal rounds (mode 4) ----
# One carried bomb, two sites; all objective state and wins are host-owned.
var cs_carrier: int=0
var cs_drop_position: Vector3=Vector3.INF
var cs_visual: Node3D
var cs_round_awarded: bool=false
func cs_planted() -> bool:
	return bomb_site>=0 and bomb_site<site_states.size() and site_states[bomb_site].stage=="planted"
func reset_cs_bomb() -> void:
	cs_carrier=0;cs_drop_position=Vector3.INF;cs_round_awarded=false
	if mode!=MODE_CS:return
	var candidates=[]
	for actor in actors:
		actor.bomb_equipped=false;actor.bomb_drop_at=0
		if actor.alive and actor.is_attacker():candidates.append(actor.net_id)
	if not candidates.is_empty():cs_carrier=candidates.pick_random()
	if not is_instance_valid(cs_visual):
		cs_visual=load("res://scripts/cs_bomb_visual.gd").new();cs_visual.game=self;add_child(cs_visual)
func drop_cs_bomb(actor: NestActor) -> void:
	if mode!=MODE_CS or cs_carrier!=actor.net_id or cs_planted():return
	var safe=NestPlacementSafety.dropped(self,actor.global_position,.3,.65,arena.spawns[0][0])
	if not safe.is_finite():return
	cs_carrier=0;actor.bomb_equipped=false;actor.bomb_drop_at=0;cs_drop_position=safe
func cs_interaction(actor: NestActor) -> Dictionary:
	if finished or break_until>now:return {}
	if not cs_planted():
		if cs_carrier==0 and cs_drop_position.is_finite() and actor.global_position.distance_to(cs_drop_position)<2:
			return {"key":"cs_recover","text":"Press %s · Pick up bomb"%prefs.key_label("interact"),"seconds":0.0,"site":-1}
		if cs_carrier!=actor.net_id:return {}
	for i in range(site_states.size()):
		if actor.global_position.distance_to(arena.sites[i])>3.4:continue
		var obstacle=trace(actor.eye.global_position,arena.sites[i]+Vector3.UP*1.2,1,actor.ray_exclusions())
		if not obstacle.is_empty() and not arena.sealed_bodies[i].has(obstacle.collider):continue
		var action=""
		var duration=0.0
		if actor.is_attacker() and actor.bomb_equipped and actor.action_state=="ready" and not cs_planted() and cs_carrier==actor.net_id and now<deadline:
			action="cs_plant";duration=maxf(.1,game_type.plant_seconds)
		elif not actor.is_attacker() and cs_planted() and bomb_site==i and now<float(site_states[i].bomb_at):
			action="defuse";duration=maxf(.1,game_type.defuse_seconds)*(.5 if game_type.cs_defuse_kits else 1.0)
		if not action.is_empty():return {"key":action+":"+str(i),"text":"Hold %s · %s at %s (%s s)"%[prefs.key_label("interact"),"Plant bomb" if action=="cs_plant" else "Defuse bomb","A" if i==0 else "B",str(duration)],"seconds":duration,"site":i}
	return {}
func complete_cs_interaction(actor: NestActor, choice: Dictionary) -> bool:
	if is_client() or mode!=MODE_CS or cs_round_awarded:return false
	var action=String(choice.key).get_slice(":",0)
	if action=="cs_recover":
		if cs_carrier!=0:return false
		cs_carrier=actor.net_id;actor.bomb_equipped=false;cs_drop_position=Vector3.INF
	elif action=="cs_plant":
		if not actor.is_attacker() or not actor.bomb_equipped or cs_carrier!=actor.net_id or cs_planted() or now>=deadline:return false
		bomb_site=int(choice.site);bomb_planter=actor
		site_states[bomb_site].stage="planted";site_states[bomb_site].bomb_at=now+maxf(1.0,game_type.bomb_timer_seconds)
		cs_carrier=0;actor.bomb_equipped=false;cs_drop_position=Vector3.INF
		announce("bomb_planted");global_objective_sound("bomb_planted_alert")
	elif action=="defuse":
		if actor.is_attacker():return false
		if not cs_planted() or now>=float(site_states[bomb_site].bomb_at):return false
		site_states[bomb_site].stage="defused";announce("bomb_defused")
		cs_win(1-attacking_faction,"Bomb defused")
	else:return false
	return true
func update_cs_round() -> void:
	for actor in actors:
		if actor.bomb_drop_at>0 and now>=actor.bomb_drop_at:
			actor.bomb_drop_at=0
			if actor.alive and cs_carrier==actor.net_id:drop_cs_bomb(actor)
	if is_client() or finished or break_until>now or cs_round_awarded:return
	var counts=[0,0]
	for actor in actors:
		if actor.alive:counts[actor.faction]+=1
	if cs_planted():
		if now>=float(site_states[bomb_site].bomb_at):
			site_states[bomb_site].stage="detonated"
			if is_instance_valid(bomb_planter):bomb_planter.detonations+=1
			cs_win(attacking_faction,"Bomb detonated")
			bomb_impact(arena.sites[bomb_site]+Vector3.UP);sound("blast",arena.sites[bomb_site],false)
			if network_active:objective_blast.rpc(bomb_site,match_session,round_number)
			return
		# Defenders must still defuse after eliminating every attacker.
		if counts[1-attacking_faction]==0:cs_win(attacking_faction,"Defenders eliminated")
	else:
		if now>=deadline:cs_win(1-attacking_faction,"Time expired · bomb not planted")
		elif counts[attacking_faction]==0:cs_win(1-attacking_faction,"Attackers eliminated")
		elif counts[1-attacking_faction]==0:cs_win(attacking_faction,"Defenders eliminated")
	for i in range(site_states.size()):
		arena.set_site_visual(i,site_states[i].stage,now)
		arena.deposit_labels[i].text=("A" if i==0 else "B")+" · BOMB SITE"+(" · ARMED" if cs_planted() and i==bomb_site else "")
func cs_win(team: int, reason: String) -> void:
	if is_client() or cs_round_awarded or finished or break_until>now:return
	cs_round_awarded=true;scores[team]+=1
	round_reason=team_name(team)+" · "+reason
	if scores[team]>=tuning.score_limit:finish_match()
	else:end_round(round_reason)
func bomb_control(actor: NestActor, command: int) -> void:
	if mode!=MODE_CS or not running or finished or break_until>now or not actor.alive or cs_carrier!=actor.net_id or cs_planted() or actor.action_state!="ready":return
	actor.cancel_scope();actor.burst_left=0
	if command==1:
		actor.bomb_equipped=not actor.bomb_equipped
		actor.action_state="switching";actor.action_until=now+.4
	elif command==2:
		actor.bomb_equipped=true;actor.bomb_drop_at=now+1.0
		actor.action_state="bomb_drop";actor.action_until=actor.bomb_drop_at
func cs_summary(viewer: NestActor) -> String:
	if break_until>now:return round_reason
	if cs_planted():return "BOMB %s · %.1f s · %s"%["A" if bomb_site==0 else "B",maxf(0,float(site_states[bomb_site].bomb_at)-now),"Defend the bomb" if viewer.is_attacker() else "Defuse it · hold "+prefs.key_label("interact")]
	if cs_carrier==viewer.net_id:
		if not viewer.is_attacker():return "BOMB RECOVERED · 4 equip / stow · X drop · Defenders cannot plant"
		return "BOMB · 4 equip / stow · X drop · Hold %s at A / B to plant"%prefs.key_label("interact")
	if not viewer.is_attacker():return "Defend bomb sites A / B · Survive until time expires"
	var carrier=actor_by_id(cs_carrier)
	return (carrier.username+" has the bomb · Escort to A / B") if is_instance_valid(carrier) and carrier.faction==viewer.faction else "Locate the bomb · Sites A / B"
func cs_bot_goal(actor: NestActor) -> Vector3:
	if cs_planted():
		var position=arena.sites[bomb_site]
		if not actor.is_attacker() and nearest_objective_actor(actor,position):return position+Vector3(-2.4,0,0)
		var angle=float(actor.net_id%6)*TAU/6.0
		return position+Vector3(cos(angle)*5.0,0,sin(angle)*5.0)
	if actor.is_attacker() and cs_carrier==0 and cs_drop_position.is_finite():return cs_drop_position
	if actor.is_attacker() and cs_carrier!=actor.net_id:
		var carrier=actor_by_id(cs_carrier)
		if is_instance_valid(carrier):
			var escorts=actors.filter(func(a):return a.alive and a.is_attacker() and a.net_id!=cs_carrier)
			var index=escorts.find(actor);var angle=float(maxi(0,index))*TAU/maxi(1,escorts.size())
			var desired=carrier.global_position+Vector3(cos(angle)*2.5,0,sin(angle)*2.5)
			return desired if arena.has_walk_support(desired,.6) else carrier.global_position
	# Use the nearest site before planting; defenders split between sites.
	var site=0 if actor.global_position.distance_squared_to(arena.sites[0])<actor.global_position.distance_squared_to(arena.sites[1]) else 1
	if not actor.is_attacker():site=posmod(actor.net_id,2)
	return arena.sites[site]+Vector3(-2.4,0,0)

func set_personal_team(team: int) -> void:
	if running or team not in [0,1]:return
	if is_client():request_lobby_team.rpc_id(1,team);return
	if network_active:
		if not apply_lobby_team(multiplayer.get_unique_id(),team):return
	else:selected_faction=team
	if has_method("show_lobby"):call_deferred("show_lobby")
func apply_lobby_team(peer: int, team: int) -> bool:
	if matchmaking.active:return false
	if running or team not in [0,1] or not lobby_members.has(peer):return false
	var count=0
	for id in lobby_members:
		if id!=peer and int(lobby_members[id].faction)==team:count+=1
	if lobby_kind!="forge" and count>=team_size:return false
	lobby_members[peer].faction=team;lobby_members[peer].ready=false
	if peer==multiplayer.get_unique_id():selected_faction=team;lobby_ready=false
	if has_method("broadcast_lobby"):call("broadcast_lobby")
	return true
@rpc("any_peer","call_remote","reliable")
func request_lobby_team(team: int) -> void:
	if film_retaining_transport:return
	if not multiplayer.is_server():return
	var peer=multiplayer.get_remote_sender_id()
	if not apply_lobby_team(peer,team):receive_chat.rpc_id(peer,"Team change unavailable: team is full or the match has started.")

func round_bot_count(team: int, human_count: int) -> int:
	if not bot_fill:return 0
	var available=maxi(0,team_size-human_count)
	var requested=game_type.bots_team_0 if team==0 else game_type.bots_team_1
	return available if requested<0 else mini(available,maxi(0,requested))

func create_offline_actors() -> void:
	var actor=NestActor.new()
	actor.game=self; actor.local_player=true; actor.character_choice=selected_character; actor.faction=selected_faction; actor.username=current_username()
	add_child(actor); actors.append(actor); player=actor
	if bot_fill:
		for f in [0,1]:
			for i in range(round_bot_count(f,1 if f==selected_faction else 0)):
				var bot=NestActor.new()
				bot.game=self; bot.faction=f; bot.username=bot_name(f,i); bot.net_id=-(1+f*16+i)
				add_child(bot); actors.append(bot)

@rpc("authority","call_remote","reliable")
func receive_pending_rules(data: Dictionary, session: int) -> void:
	if film_retaining_transport:return
	if not running or session!=match_session:return
	pending_game_type=GameTypeSettings.new();pending_game_type.apply_network_dict(data)
func save_actor_totals() -> Dictionary:
	var totals={}
	for actor in actors:
		var values={}
		for key in ["kills","deaths","assists","delivered","detonations","captures","flag_returns"]:values[key]=actor.get(key)
		totals[actor.net_id]=values
	return totals
func rebuild_round_actors(totals: Dictionary) -> void:
	for actor in actors:
		remove_child(actor);actor.queue_free()
	actors.clear();player=null
	if network_active:create_network_actors()
	else:create_offline_actors()
	for actor in actors:
		var rating=ranked.actor_summary(actor);actor.rank_human=rating.human;actor.rank_practice=rating.practice
		for key in totals.get(actor.net_id,{}):actor.set(key,totals[actor.net_id][key])
func round_roster_signature() -> Dictionary:
	var out={}
	for actor in actors:out[actor.net_id]=actor.faction
	return out
func restart_round_in_match() -> bool:
	if is_client() or not running or finished or applying_round_restart:return false
	applying_round_restart=true
	var old_mode=mode;var old_map=game_type.map_selection;var old_roster=round_roster_signature()
	var previous=match_session;var totals=save_actor_totals()
	if pending_game_type!=null:game_type=pending_game_type;pending_game_type=null
	sync_game_type_to_legacy();ensure_selected_map()
	team_characters.assign(MATCHUPS[matchup])
	match_session=randi_range(1,2147483647)
	while match_session==previous:match_session=randi_range(1,2147483647)
	announcer.reset();audio.stop_all();prepare_match_input()
	shot_authorizations.clear();remote_interactions.clear();remote_shot_clocks.clear();remote_throws.clear()
	rebuild_round_actors(totals);reset_round();save_custom_preset()
	if old_map!=game_type.map_selection or old_mode!=mode or old_roster!=round_roster_signature():ranked.eligible=false
	if network_active:restart_network_round.rpc(previous,active_config(),lobby_members,round_number,scores,now,attacking_faction,totals)
	applying_round_restart=false;announce("round_start")
	if has_method("round_restarted_ui"):call("round_restarted_ui")
	return true
@rpc("authority","call_remote","reliable")
func restart_network_round(previous: int, config: Dictionary, members: Dictionary, number: int, score_state: Array, host_now: float, attacker_team: int, totals: Dictionary) -> void:
	if film_retaining_transport:return
	if not running or match_session!=previous:return
	var old_mode=mode;var old_roster=round_roster_signature()
	applying_round_restart=true;pending_game_type=null
	accept_config(config);lobby_members=members;now=host_now;round_number=number;scores.assign(score_state);attacking_faction=attacker_team;finished=false
	team_characters.assign(MATCHUPS[matchup])
	announcer.reset();audio.stop_all();prepare_match_input()
	rebuild_round_actors(totals);reset_round()
	if old_mode!=mode or old_roster!=round_roster_signature():ranked.eligible=false
	applying_round_restart=false
	if has_method("round_restarted_ui"):call("round_restarted_ui")

@rpc("authority","call_remote","reliable")
func receive_rating_result(packet: Dictionary) -> void:
	if film_retaining_transport:return
	if not running or not is_client():return
	ranked.accept(packet)

@rpc("any_peer","call_remote","reliable")
func request_forge_edit(epoch: int, revision: int, sequence: int, action: String, args: Dictionary) -> void:
	if film_retaining_transport:return
	if not network_active or not multiplayer.is_server():return
	forge_session.execute(multiplayer.get_remote_sender_id(),epoch,revision,sequence,action,args)
@rpc("authority","call_remote","reliable")
func receive_forge_state(epoch: int, revision: int, state: Dictionary, active: bool, peer: int, key: String, message: String) -> void:
	if film_retaining_transport:return
	forge_session.receive(epoch,revision,state,active,peer,key,message)

func mark_first_impact(point: Vector3, normal: Vector3) -> void:
	if not game_type.bullet_impact_debug:return
	if network_active and multiplayer.is_server():receive_debug_impact.rpc(point,normal,match_session,round_number)
	add_debug_impact(point,normal)
func add_debug_impact(point: Vector3, normal: Vector3) -> void:
	var markers=effects.get_children().filter(func(n):return n is NestImpactDebug and not n.is_queued_for_deletion())
	if markers.size()>=128:markers[0].queue_free()
	var marker=NestImpactDebug.new();marker.game=self;marker.position=point+normal*.018;effects.add_child(marker)

@rpc("authority","call_remote","reliable")
func receive_debug_impact(point: Vector3, normal: Vector3, session: int, round_id: int) -> void:
	if film_retaining_transport:return
	if not running or session!=match_session or round_id!=round_number or not point.is_finite() or not normal.is_finite():return
	add_debug_impact(point,normal)

func record_nu_sighting(team: int, target: NestActor) -> void:
	if is_client() or team not in [0,1] or not target.alive:return
	nu_sightings[team][target.net_id]={"pos":target.global_position,"at":now,"life":target.life_id,"round":round_number}

func vision_clear(start: Vector3, finish: Vector3) -> bool:
	# Transparent glass transmits sight, but keeps its ordinary bullet/movement
	# collision. Bound the number of panes; solid cover always ends the query.
	var excluded: Array[RID]=[]
	for i in range(16):
		var hit=trace(start,finish,1,excluded)
		if hit.is_empty():return true
		if surface_tag(hit.collider)!="glass":return false
		excluded.append(hit.collider.get_rid())
	return false

func can_edit_match_traits() -> bool:
	return god_mode and not is_client() and not matchmaking.active
func handle_god_command(text: String) -> bool:
	if text.strip_edges().to_lower() not in ["god",":god"]:return false
	var notice=""
	if not running:notice="God mode can only be toggled from the in-match text box."
	elif is_client() or matchmaking.active:notice="God mode is available only to the custom/practice host."
	else:
		god_mode=not god_mode
		if god_mode:ranked.eligible=false
		else:pending_game_type=null
		notice="GOD MODE "+("ON · Pause → Traits / Bots / Weapons" if god_mode else "OFF · Trait and bot menus locked")
		if has_method("god_access_changed"):call_deferred("god_access_changed")
	messages.append(notice)
	if messages.size()>4:messages.pop_front()
	return true

func nearest_bot_enemy(actor: NestActor,limit: float=35.0) -> NestActor:
	var candidates=[];var squared=limit*limit
	for other in actors:
		if other==actor or not other.alive or (other.faction==actor.faction and mode!=1) or other.cloak_deadline>now:continue
		var distance=actor.global_position.distance_squared_to(other.global_position)
		if distance<squared:candidates.append({"actor":other,"distance":distance})
	candidates.sort_custom(func(a,b):return a.distance<b.distance)
	for entry in candidates:
		var other: NestActor=entry.actor
		if campaign!=null and campaign.active and other.faction==0 and not campaign.members.get(other.net_id,{}).get("connected",false):continue
		var point=other.global_position+Vector3(0,1.2*NestActor.SIZE,0)
		if campaign!=null and campaign.active:
			var offset=point-actor.eye.global_position
			if (offset.length()>10 and actor.aim_direction().dot(offset.normalized())<-.15) or campaign.world.smoke_blocks(actor.eye.global_position,point):continue
		if trace(actor.eye.global_position,point,1,actor.ray_exclusions()).is_empty():return other
	return null
