class_name NestFilmRecorder
extends Node
## Capture only presentation the local client actually had. Disk work is queued.
const ACTOR_FIELDS=["alive","life_id","health","shield","armor","overshield","slot","ammo","reserve","grenades","scope_level","recoil","aim_punch","accuracy_penalty","action_state","action_until","reload_duration","reload_was_empty","shield_flash_at","shield_flash_strength","shield_flash_over","health_flash_at","health_flash_strength","shield_break_at","directional_hits","last_damage","death_recap","flash_until","last_shot_kind","crouched","air_duck","respawn_at","carrying","bag_id","grenade_kind","ak_spray_count"]
var game
var active=false
var id=""
var track_owner=""
var metadata={}
var frames=[]
var views=[]
var events=[]
var queue=[]
var received_queue=[]
var worker: Thread
var accum=0.0
var flush_at=0.0
var session=-1
var ended=false
var connected_actors={}
var status=""
var metrics={"capture_us":0,"samples":0,"disk_bytes":0,"worker_us":0,"dropped_blocks":0}
var transfer
func _ready():
	process_priority=900
	transfer=load("res://scripts/film_transfer.gd").new();transfer.name="PerspectiveTransfer";transfer.recorder=self;add_child(transfer)
	game.audio.sound_started.connect(sound_event)
func identity_for(actor) -> String:
	var hub=game.matchmaking.hybrid
	if hub.enabled:
		if actor.local_player:return hub.player_id
		for who in hub.roster:
			if int(hub.roster[who].slot)==actor.net_id:return str(who)
	return str(actor.net_id)
func peer_identity(peer: int) -> String:
	var hub=game.matchmaking.hybrid
	if hub.enabled:
		for who in hub.authenticated:
			if int(hub.authenticated[who])==peer:return str(who)
	for who in metadata.get("roster",{}):
		if int(metadata.roster[who].get("peer",0))==peer:return str(who)
	return ""
func begin():
	transfer.offered=false;transfer.host_finished=false;transfer.incoming.clear();transfer.outgoing.clear();transfer.completed.clear()
	session=game.match_session;id=NestFilmArchive.digest((game.NETWORK_VERSION+":"+str(session)).to_utf8_buffer()).hex_encode().substr(0,32)
	track_owner=identity_for(game.player) if is_instance_valid(game.player) else ""
	metadata={"id":id,"protocol":game.NETWORK_VERSION,"sample_hz":29,"created":Time.get_unix_time_from_system(),"duration":0.0,"roster":{},"config":{"game_type":game.game_type.to_network_dict(),"matchup":game.matchup,"session":session},"disclaimer":"Interactive reconstruction; local tracks are player-submitted and are not trusted gameplay evidence."}
	active=true;ended=false;accum=0;flush_at=game.local_clock()+1;frames=[];views=[];events=[];connected_actors.clear();status="Recording film at 29 Hz"
func _process(delta):
	poll_worker()
	# Campaign scene changes are not multiplayer arena Film reconstructions.
	if game.campaign!=null and game.campaign.active:return
	if game.replay_active:return
	if game.running and game.match_session!=session and game.prefs.values.get("record_films",true):
		if active:finish()
		begin()
	if not active:return
	if not game.running or game.finished or game.now>=NestFilmArchive.MAX_SECONDS:finish();return
	refresh_roster()
	accum+=delta
	if accum>=1.0/NestFilmArchive.SAMPLE_HZ:
		accum=fmod(accum,1.0/NestFilmArchive.SAMPLE_HZ)
		capture()
	if game.local_clock()>=flush_at:flush_at=game.local_clock()+1;flush()
func refresh_roster():
	for actor in game.actors:
		var who=identity_for(actor)
		if metadata.roster.size()<10 or metadata.roster.has(who):metadata.roster[who]={"id":actor.net_id,"name":actor.username,"team":actor.faction,"character":actor.character,"peer":actor.remote_peer,"last_seen":game.now}
		if not connected_actors.has(actor.get_instance_id()):
			connected_actors[actor.get_instance_id()]=true
			actor.shot_fired.connect(func(event_id,t,origin,directions):
				if actor.local_player:event("shot",{"id":event_id,"origin":origin,"directions":directions}))
func capture():
	var started=Time.get_ticks_usec()
	if game.is_client() and not game.clock_ready:return
	if not game.is_client():frames.append({"t":float(game.now),"state":identify_state(game.snapshot_state().duplicate(true))})
	if is_instance_valid(game.player):views.append(capture_view())
	metadata.duration=maxf(float(metadata.duration),game.now)
	metrics.samples+=1;metrics.capture_us+=Time.get_ticks_usec()-started
func authoritative_snapshot(match_state: Dictionary, states: Array):
	if active and not game.replay_active and game.is_client() and (frames.is_empty() or float(match_state.now)>float(frames[-1].t)+1.0/29):frames.append({"t":float(match_state.now),"state":identify_state([match_state,states].duplicate(true))})
func identify_state(state: Array) -> Array:
	for record in state[1]:
		var actor=game.actor_by_id(int(record.id))
		if actor!=null:record.film_identity=identity_for(actor)
	return state
func capture_view() -> Dictionary:
	var actor=game.player;var camera=game.get_viewport().get_camera_3d()
	var state={}
	for field in ACTOR_FIELDS:
		var value=actor.get(field)
		state[field]=value.duplicate(true) if value is Array or value is Dictionary else value
	var rendered=[]
	for other in game.actors:rendered.append({"id":other.net_id,"identity":identity_for(other),"xf":other.get_global_transform_interpolated(),"alive":other.alive,"crouch":other.crouched,"velocity":other.velocity,"animation":other.animation.current_animation if other.animation!=null else "","animation_position":other.animation.current_animation_position if other.animation!=null else 0.0})
	var contacts=[]
	if is_instance_valid(game.get("radar")):
		for contact in game.radar.contacts.values():
			var safe=contact.duplicate();safe.erase("actor");contacts.append(safe)
	var presentation=[]
	if is_instance_valid(actor.weapon_view):capture_nodes(actor.weapon_view,[],presentation)
	var preferences={}
	for key in game.prefs.values:
		if key.begins_with("crosshair") or key.begins_with("radar") or key in ["dynamic_crosshair","fov","chat","hud_scale","hud_opacity","naki_radar_size","annu_radar_size","naki_radar_corner","annu_radar_corner"]:preferences[key]=game.prefs.values[key]
	return {"t":float(game.now),"life":actor.life_id,"camera":camera.global_transform if camera!=null else actor.eye.global_transform,"viewport":game.get_viewport().get_visible_rect().size,"inventory":actor.weapons.map(func(weapon):return weapon.kind),"fov":camera.fov if camera!=null else 90.0,"actor":state,"rendered":rendered,"weapon":actor.weapons[actor.slot].kind,"weapon_nodes":presentation,"weapon_visible":actor.weapon_view.visible if is_instance_valid(actor.weapon_view) else false,"contacts":contacts,"preferences":preferences,"hit_until":game.hit_until,"hurt_until":game.hurt_until,"kill_notice":game.local_kill_notice,"kill_notice_until":game.local_kill_notice_until,"messages":game.messages.duplicate(),"context":game.context,"hud_visible":game.hud.visible if is_instance_valid(game.hud) else false,"scoreboard":game.scoreboard.visible if is_instance_valid(game.scoreboard) else false,"hover":game.hud_crosshair.enemy_hover if is_instance_valid(game.get("hud_crosshair")) else false}
static func capture_nodes(node: Node, path: Array, output: Array):
	if output.size()>=512:return
	if node is Node3D:output.append({"path":path,"xf":node.transform,"visible":node.visible})
	var children=node.get_children().filter(func(child):return not child.is_queued_for_deletion())
	for i in range(children.size()):capture_nodes(children[i],path+[i],output)
func event(kind: String, data: Dictionary={}):
	if active and events.size()<100:events.append({"t":float(game.now),"kind":kind,"data":data})
func sound_event(sound_id: String,_path: String,voice: Node):
	if active:event("sound",{"id":sound_id,"pos":voice.global_position if voice is Node3D else Vector3.ZERO,"spatial":voice is AudioStreamPlayer3D})
func flush():
	if queue.size()>4:
		metrics.dropped_blocks+=1;status="Recording gap: storage queue full";frames=[];views=[];events=[];return
	var block={"metadata":metadata.duplicate(true),"frames":frames,"owner":track_owner,"views":views,"events":events}
	queue.append({"id":id,"payload":block})
	if not track_owner.is_empty():queue.append({"id":id,"track":true,"payload":{"owner":track_owner,"views":views,"events":events}})
	frames=[];views=[];events=[]
func finish():
	if not active:return
	metadata.duration=maxf(float(metadata.duration),game.now);flush();active=false;ended=true;status="Saving film / collecting available perspectives"
func poll_worker():
	if worker!=null and not worker.is_alive():
		var result=worker.wait_to_finish();worker=null
		if result.has("error"):status=result.error
		else:metrics.disk_bytes+=int(result.bytes);metrics.worker_us+=int(result.worker_us)
	if worker==null and (not queue.is_empty() or not received_queue.is_empty()):
		var job=queue.pop_front() if not queue.is_empty() else received_queue.pop_front();worker=Thread.new();worker.start(NestFilmArchive.write_block.bind(job))
func append_received_track(who: String, blocks: Array):
	for block in blocks:
		var safe=block.duplicate();safe.owner=who;safe.erase("metadata");safe.erase("frames")
		received_queue.append({"id":id,"payload":safe})
func _exit_tree():
	# Only shutdown waits. Normal capture, transfers and menus never join a live worker.
	if active:finish()
	if worker!=null:worker.wait_to_finish()
	for job in queue:NestFilmArchive.write_block(job)
	for job in received_queue:NestFilmArchive.write_block(job)
