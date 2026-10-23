extends RigidBody3D
var cosmetic: bool = false
var restoring: bool = false
var game: Node3D
var owner_actor: NestActor
var sticky: bool = false
var event_id: int
var round_id: int
var released: float
var fuse_at: float = INF
var detonated: bool = false
var attached: Node3D
var attachment_offset = Vector3.ZERO
var launch_velocity = Vector3.ZERO
var audio_rules: Dictionary
var audio_id: String
var audio_group: String
var bounce_count: int=0
var last_bounce_at: float=-INF
var settled: bool=false
var water_landed: bool=false
var resting_for: float=0
var last_material: String="concrete"
var previous_velocity: Vector3
var fuse_audio: Node
var debug_audio: bool=false
func _ready() -> void:
	var config=JSON.parse_string(FileAccess.get_file_as_string("res://data/grenades.json"))
	audio_rules=config.defaults; debug_audio=config.debug_audio
	audio_id="plasma_grenade" if sticky else "frag_grenade"; audio_group="grenade:"+str(get_instance_id())
	collision_layer=8
	collision_mask=1 if cosmetic else 3
	continuous_cd=true
	contact_monitor=true
	max_contacts_reported=8
	gravity_scale=16.0/8.1632653
	linear_damp=0.05
	angular_damp=0.2
	var phys=PhysicsMaterial.new()
	phys.bounce=0 if sticky else 0.5625
	phys.friction=0.6
	physics_material_override=phys
	var shape=CollisionShape3D.new()
	var sphere=SphereShape3D.new()
	sphere.radius=0.06
	shape.shape=sphere
	add_child(shape)
	var body_mat=NestGrenadeArt.material(sticky)
	game.arena.kit.sphere(self,Vector3.ZERO,0.09,body_mat)
	linear_velocity=launch_velocity
	angular_velocity=Vector3(4,6,2)
	released=game.now
	add_collision_exception_with(owner_actor)
	if sticky and not game.tuning.friendly_fire:
		for actor in game.actors:
			if actor!=owner_actor and actor.faction==owner_actor.faction and game.mode!=1: add_collision_exception_with(actor)
	body_entered.connect(contact)
	previous_velocity=launch_velocity
	if not restoring:grenade_sound("throw",0,{"doppler_tracking":AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP})
func contact(body: Node) -> void:
	if fuse_at!=INF: return
	if body is NestActor and sticky and is_instance_valid(owner_actor) and body!=owner_actor and body.faction==owner_actor.faction and game.mode!=1 and not game.tuning.friendly_fire: return
	fuse_at=game.now+float(audio_rules.fuse_seconds)
	if sticky:
		if body is Node3D: attached=body; attachment_offset=body.to_local(global_position)
		set_deferred("freeze",true)
		set_deferred("collision_mask",0)
		grenade_sound("stick")
		if body is NestActor and body.local_player: game.audio.play_sound("plasma_grenade_stuck_warning",Vector3.ZERO,{"spatial":false})
		var voices=game.audio.play_sound("plasma_grenade_fuse",global_position,{"attach_to":self,"group":audio_group})
		if not voices.is_empty(): fuse_audio=voices[0]
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	for index in range(state.get_contact_count()):
		var normal=state.get_contact_local_normal(index)
		var relative=previous_velocity-state.get_contact_collider_velocity_at_position(index)
		var speed=absf(relative.dot(normal))
		var body=state.get_contact_collider_object(index)
		if debug_audio: print("[GRENADE_SND] contact / ",game.surface_tag(body)," / ",speed," / normal ",normal," / velocity ",previous_velocity)
		bounce_sound(game.surface_tag(body),speed)
	previous_velocity=state.linear_velocity
func bounce_sound(material: String, speed: float) -> bool:
	if sticky or settled or bounce_count>=int(audio_rules.bounce_sound_cap) or speed<float(audio_rules.min_impact_speed) or game.now-last_bounce_at<float(audio_rules.bounce_cooldown): return false
	last_material=material; last_bounce_at=game.now; bounce_count+=1
	var blend=clampf(inverse_lerp(float(audio_rules.min_impact_speed),float(audio_rules.speed_for_full_gain),speed),0,1)
	var gain=lerpf(float(audio_rules.min_gain_db),0,blend)
	var pitch=lerpf(float(audio_rules.pitch_at_min_speed),float(audio_rules.pitch_at_max_speed),blend)
	game.audio.play_sound("grenade_bounce_"+material,global_position,{"attach_to":self,"group":audio_group,"gain_db":gain,"pitch_scale":pitch})
	debug_event("bounce",material,speed,gain)
	if material=="water": settled=true; water_landed=true
	return true
func grenade_sound(event: String, speed: float=0, options: Dictionary={}) -> void:
	options.merge({"attach_to":self,"group":audio_group},false)
	game.audio.play_sound(audio_id+"_"+event,global_position,options)
	debug_event(event,last_material,speed,float(options.get("gain_db",0)))
func debug_event(event: String, material: String, speed: float, gain: float) -> void:
	if debug_audio: print("[GRENADE_SND] ",event," / ",material," / ",speed," / ",gain)
func _physics_process(delta: float) -> void:
	if game.matchmaking.blocks_simulation():return
	if not game.running or game.finished or round_id!=game.round_number or not is_instance_valid(owner_actor): queue_free(); return
	if game.now-released>0.15 and is_instance_valid(owner_actor): remove_collision_exception_with(owner_actor)
	if sticky and is_instance_valid(attached):
		if attached is NestActor and not attached.alive: attached=null
		else: global_position=attached.to_global(attachment_offset)
	if not sticky:
		if settled and not water_landed and linear_velocity.length()>float(audio_rules.wake_speed): settled=false; resting_for=0
		if not settled and linear_velocity.length()<float(audio_rules.rest_speed) and get_contact_count()>0:
			resting_for+=delta
			if resting_for>=float(audio_rules.rest_seconds): settled=true; grenade_sound("settle")
		else: resting_for=0
	if is_instance_valid(fuse_audio):
		var progress=clampf(1-(fuse_at-game.now)/float(audio_rules.fuse_seconds),0,1)
		fuse_audio.pitch_scale=lerpf(float(audio_rules.fuse_pitch_start),float(audio_rules.fuse_pitch_end),progress)
	if not detonated and (game.now>=fuse_at or game.now-released>=float(audio_rules.max_flight_seconds)):
		detonated=true
		game.audio.stop_group(audio_group)
		var weapon=NestWeaponCatalog.definition(audio_id)
		game.explode(global_position,owner_actor,event_id,float(weapon.splash_damage_max),cosmetic,audio_id)
		queue_free()
func _exit_tree() -> void:
	if is_instance_valid(game) and game.audio!=null: game.audio.stop_group(audio_group)
