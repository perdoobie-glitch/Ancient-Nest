class_name NestActor
extends CharacterBody3D
signal shot_fired(event_id: int, simulation_time: float, origin: Vector3, directions: Array)
var nu_used: bool=false
var nu_launch_until: float=0
var sword_draw: float=0
var sword_lunge_at: float=INF
var sword_lunge: Vector3=Vector3.ZERO
var belt_sword: Node3D
var nu_perch_area: NestNuPerch
var perched_nu: Node3D
var net_id: int = 1
var remote_peer: int = 0
var net_move = Vector2.ZERO
var net_jump: bool = false
var net_jump_until: float = -INF
var net_jump_sequence: int = -1
var net_crouch: bool = false
var net_interact: bool = false
var net_target_pos = Vector3.ZERO
var net_target_yaw: float = 0
var net_grounded: bool = true
var net_last_command: float = -100
var net_position_error = Vector3.ZERO
# Networked movement. Every client physics tick produces one sequenced command.
# The client predicts it immediately, the host simulates the same command once,
# and snapshots acknowledge the last processed sequence with the resulting state.
const NET_TICK: float = 1.0/60
const MAX_COMMAND_HISTORY: int = 128
const RECONCILE_POSITION_EPSILON: float = .02
const RECONCILE_VELOCITY_EPSILON: float = .05
const VIEW_CORRECTION_RATE: float = 12.0
const JUMP_BUFFER_TICKS: int = 7
const COMMAND_CREDIT_CAP: float = 10.0
const COMMAND_STARVE_TICKS: int = 10
const MAX_COMMAND_QUEUE: int = 90
const REMOTE_EXTRAPOLATE_LIMIT: float = .1
const ACK_STALL_SECONDS: float = .5
var ack_seen: int = -2
var ack_changed_at: float = 0
var cmd_history: Array = [] # client: unacknowledged predicted commands
var pending_reconcile: Dictionary = {}
var view_correction = Vector3.ZERO
var cmd_queue: Array = [] # host: received, unprocessed commands sorted by sequence
var cmd_last_seq: int = -1
var command_aims: Dictionary = {}
var cmd_credit: float = 0
var cmd_starved: int = 0
var cmd_template: Dictionary = {}
var cmd_deferred: Array = []
var server_jump_buffer: int = 0
var snap_buffer: Array = [] # client: timestamped remote snapshots for interpolation
var hitbox_shapes: Array[Shape3D] = []
var shield_fx: Node3D
var flag_carry: int = -1 # Capture the Flag: team index of the flag carried
var captures: int = 0
var flag_returns: int = 0
static var NET_TRACE: bool = OS.has_environment("NEST_NET_TRACE") # opt-in netcode trace
var host_jump_seqs: Array[int] = [] # diagnostics: command sequences the host jumped on
var game: Node3D
# Body size (v0.12: players are 20% bigger). Collision, eye/camera height,
# crouch shapes and the model with its hitboxes all scale from these.
const SIZE: float = 1.26
const STAND_HEIGHT: float = 1.9*SIZE
const CROUCH_HEIGHT: float = 1.25*SIZE
const BODY_RADIUS: float = .35*SIZE
const STAND_CENTER: float = .95*SIZE
const CROUCH_CENTER: float = .625*SIZE
const AIR_DUCK_CENTER: float = 1.275*SIZE
const EYE_HEIGHT: float = 1.65*SIZE
const CROUCH_EYE_HEIGHT: float = 1.05*SIZE
const TUCK: float = STAND_HEIGHT-CROUCH_HEIGHT
const LUNGE_TICKS: int = 15 # melee lunge lasts 0.25 s at 60 Hz
var melee_contact_at: float = INF
var melee_contact_until: float = -INF
var placement_retry_at: float=0
var bomb_equipped: bool=false
var bomb_drop_at: float=0
var melee_ready_at: float=0
var melee_event_id: int = 0
var remote_melee_id: int = -1
var melee_life: int = -1
var melee_round: int = -1
var melee_session: int = -1
var lunge_ticks: int = 0
var lunge_velocity = Vector3.ZERO
var faction: int = 0: # team: spawns, scores, friend/foe
	set(value):
		faction=value
		# Changing team means playing that team's character.
		if character_choice<0 and character>=0 and is_instance_valid(game) and is_inside_tree(): set_character(game.team_characters[value])
var tracer_sequence: int = 0
var character_choice: int = -1 # -1 follows team defaults, otherwise an explicit personal choice.
var character: int = -1 # 0 Naki, 1 Annu: model, loadout, protection type
var local_player: bool = false
var username: String = "Player"
var traits: NestCharacterTraits
var tuning: NestTuning
var camera: Camera3D
var model: Node3D
var cloak_meshes: Array[MeshInstance3D] = []
var cloak_shadow_modes: Array[int] = []
var camo_renderer: NestCamoPresentation
var applied_cloak: int = -1
var team_cape_key: String = ""
var skeleton: Skeleton3D
var animation: AnimationPlayer
var clips: Dictionary = {}
var pose_offsets: Dictionary = {}
var carried_visual: Node3D
var remote_weapon: Node3D
var weapon_art: Node3D
var remote_art: Node3D
var art_kind: String = ""
var visual_motion = Vector3.ZERO
var capsule: CollisionShape3D
var eye: Node3D
var view_grip_parts: Array[Node3D] = []
var view_position_anchor: Node3D
var weapon_view: Node3D
var muzzle_flash: MeshInstance3D
var enemy_name_tag: Label3D
var name_tag_target: bool = false
var name_tag_hold_until: float = 0.0
var next_name_tag_check: float = 0.0
var hitboxes: Array[Area3D] = []
var controlled = Vector3.ZERO
var external = Vector3.ZERO
var cannon_takeoff: bool = false
var health: float = 100
var shield: float = 100
var armor: float = 100
var regen_anchor_damage: float=-INF
var regen_start_health: float=0
var regen_start_shield: float=0
var overshield: float = 0
var over_deadline: float = 0
var cloak_deadline: float = 0
var last_damage: float = -100
var alive: bool = true
var respawn_at: float = 0
var life_id: int = 1
var carrying: bool = false
var bag_id: int = -1
var crouched: bool = false
var air_duck: bool = false
var rank_human: int=0
var rank_practice: int=0
var kills: int = 0
var deaths: int = 0
var delivered: int = 0
var detonations: int = 0
var assists: int = 0
var contributors: Dictionary = {}
var damage_received: Dictionary = {}
var damage_given: Dictionary = {}
var death_recap: Dictionary = {}
var recap_announced_life: int = -1
var weapons: Array[NestWeapon] = []
var ammo: Array[int] = []
var reserve: Array[int] = []
var slot: int = 0
var cooldown: float = 0
var action_until: float = 0
var action_state: String = "ready"
var reload_duration: float = 0
var reload_was_empty: bool = false
var body_phase: bool = false
var helmet_hp: float = 100
var hit_stun_until: float = 0
var last_damage_origin: Vector3 = Vector3.INF
var last_impact_point: Vector3 = Vector3.INF
var last_damage_weapon: String = ""
var last_damage_region: String = "torso"
var combat_audio: NestCombatAudio
var grenades: Array[int] = [2,2]
var grenade_kind: int = 0
var throw_kind: int = 0
var throw_started: float = -INF
var throw_release: float = INF
var throw_life: int = -1
var throw_pending_kind: int = -1
var auto_reload_at: float = INF
var auto_reload_slot: int = -1
var burst_left: int = 0
var burst_next: float = 0
var recoil: float = 0
var aim_punch = Vector2.ZERO
# Only the optional enemy-hover sensitivity gain is blended; mouse angles are never filtered.
const HOVER_TRANSITION_SECONDS: float = .06
var hover_look_gain: float = 1.0
var scope_level: int = 0
var combat_recovery_at: float = 0
var last_shot_frame: int = -1
var remote_shot_id: int = -1
var accepted_shots: int = 0
var pending_shots: Array = []
var shell_next: float = INF
var shell_remaining: int = 0
var accuracy_penalty: float = 0
var shots_in_sequence: int = 0
var ak_spray_count: int = 0
var ak_spray_last: float = -INF
var ak_spray_event: int = -1
var ak_spray_command_clock: bool = false
var ak_spray_last_arrival: float = -INF
var last_shot_kind: String = ""
var last_shot_at: float = -100
var ignore_fire_until_release: bool = false
const INPUT_BUFFER_SECONDS: float = .12
var stair_obstruction: KinematicCollision3D=KinematicCollision3D.new()
var stair_landing: KinematicCollision3D=KinematicCollision3D.new()
var jump_pending_until: float = -INF
var fire_pending_until: float = -INF
var jump_key_down: bool = false
var fire_key_down: bool = false
var jump_sequence: int = 0
var suppressed_actions: Dictionary = {}
var flash_render_pending: bool = false
var flash_until: float = 0
var presentation: NestCombatPresentation
var damage_fx_seq: int = 0
var shield_flash_at: float = -100
var shield_flash_strength: float = 0
var shield_flash_over: bool = false
var shield_break_at: float = -100
var health_flash_at: float = -100
var health_flash_strength: float = 0
var directional_hits: Array[Vector4] = []
var target: NestActor
var ray_exclusion_cache: Array[RID]=[]
var bot_route: Array[Vector3] = []
var bot_movement: NestBotMovement
var bot_target_ready: float = 0
var bot_aim_offset=Vector3.ZERO
var bot_destination = Vector3.ZERO
var bot_repath: float = 0
var bot_fire: float = 0
var bot_jump: float = 0
var bot_stuck: float = 0
var last_position = Vector3.ZERO
var seen: Dictionary = {}
func _ready() -> void:
	if character<0: character=character_choice if NestCharacterCatalog.valid_index(character_choice) else game.team_characters[faction]
	refresh_traits()
	collision_layer = 2
	collision_mask = 3
	floor_snap_length = 0.2
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(45)
	safe_margin = 0.03
	platform_floor_layers = 1
	platform_on_leave=CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	capsule = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.height = STAND_HEIGHT
	shape.radius = BODY_RADIUS
	capsule.shape = shape
	capsule.position.y = STAND_CENTER
	add_child(capsule)
	eye = Node3D.new()
	eye.position.y = EYE_HEIGHT
	add_child(eye)
	if local_player:
		view_position_anchor=Node3D.new();view_position_anchor.name="ViewPositionAnchor"
		view_position_anchor.position=eye.position
		view_position_anchor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
		add_child(view_position_anchor)
		camera = Camera3D.new()
		camera.keep_aspect=Camera3D.KEEP_HEIGHT
		camera.top_level=true
		eye.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		camera.fov = game.prefs.values.fov
		camera.near = 0.04
		eye.add_child(camera)
		camera.current = true
		RenderingServer.frame_post_draw.connect(_view_drawn)
	build_model()
	build_enemy_name_tag()
	next_name_tag_check=fmod(absf(float(net_id))*0.013,0.08)
	if local_player: build_view_weapon()
	reset_loadout()
	presentation=NestCombatPresentation.new(self); presentation.setup()
	combat_audio=NestCombatAudio.new(); combat_audio.actor=self; add_child(combat_audio)
func refresh_traits() -> void:
	traits=NestCharacterTraits.new(game.pending_game_type if game.pending_game_type!=null else game.game_type,NestCharacterCatalog.by_index(character).id)
	tuning=game.tuning.duplicate()
	tuning.respawn_seconds=traits.respawn_seconds
	tuning.health_capacity=(float(traits.settings.annu_body_health) if damage_model()=="annu" else float(game.damage_rules.body_health_max))*traits.max_health_percent/100.0
	tuning.shield_capacity=float(traits.settings.naki_shield_capacity)*traits.shield_strength_percent/100.0 if traits.shields_enabled else 0.0
	tuning.armor_capacity=float(traits.settings.annu_body_armor)*traits.armor_strength_percent/100.0
	tuning.shield_delay=traits.shield_recharge_delay
	tuning.shield_rate=float(game.damage_rules.shield_recharge_rate)*traits.shield_recharge_rate_percent/100.0 if traits.shields_enabled else 0.0
func build_model() -> void:
	ray_exclusion_cache.clear()
	art_kind=""
	model = Node3D.new()
	add_child(model)
	var scene: PackedScene=load(NestCharacterCatalog.by_index(character).visual)
	var visual=scene.instantiate(); model.add_child(visual)
	var skeletons=visual.find_children("*","Skeleton3D",true,false)
	if not skeletons.is_empty(): skeleton=skeletons[0]
	var animators=visual.find_children("*","AnimationPlayer",true,false)
	if not animators.is_empty():
		animation=animators[0]
		animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for name in animation.get_animation_list():
			var short=String(name).get_slice("/",String(name).get_slice_count("/")-1)
			clips[short]=name
			if short in ["idle","walk_forward","walk_backward","strafe_left","strafe_right","crouch_idle","crouch_forward","crouch_backward","crouch_strafe_left","crouch_strafe_right","jump_air","aim_upperbody","interact_hold","carry_gold"]:
				animation.get_animation(name).loop_mode=Animation.LOOP_LINEAR
		if clips.has("idle"): animation.play(clips.idle); animation.advance(0)
	# Convex anatomy is authored from the final visible skinned body per bone.
	# Loose cape/scarf and ornaments are excluded; movement retains its capsule.
	var anatomy=NestCharacterCatalog.hitboxes(character)
	for part in anatomy:
		add_anatomical_hitbox(part)
	build_attachments()
	NestReferenceGear.apply(self)
	model.scale=Vector3.ONE*SIZE
	cache_cloak_meshes()
	refresh_model_visibility()
func cache_cloak_meshes() -> void:
	# Restore old modes before refreshing; only run on model/weapon changes.
	for i in range(cloak_meshes.size()):
		if is_instance_valid(cloak_meshes[i]):cloak_meshes[i].cast_shadow=cloak_shadow_modes[i]
	cloak_meshes.clear();cloak_shadow_modes.clear();applied_cloak=-1
	for item in model.find_children("*","MeshInstance3D",true,false):
		if remote_weapon!=null and remote_weapon.is_ancestor_of(item):continue
		cloak_meshes.append(item);cloak_shadow_modes.append(item.cast_shadow)
func refresh_model_visibility() -> void:
	if model==null:return
	refresh_team_cape()
	model.visible=alive and (not local_player or (game.nu!=null and game.nu.birds.has(net_id)))
	if nu_perch_area!=null:
		var visible_nu=alive and not nu_used and game.game_type.nu_enabled
		var layer=8 if visible_nu else 0
		if nu_perch_area.collision_layer!=layer:nu_perch_area.collision_layer=layer
		perched_nu.visible=visible_nu
	var cloaked=1 if game.now<cloak_deadline else 0
	if camo_renderer==null:camo_renderer=NestCamoPresentation.new(self)
	camo_renderer.update(cloaked==1)
	if applied_cloak==cloaked:return
	applied_cloak=cloaked
	for i in range(cloak_meshes.size()):
		if is_instance_valid(cloak_meshes[i]):cloak_meshes[i].cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if cloaked==1 else cloak_shadow_modes[i]
func refresh_team_cape() -> void:
	var mirror=game.team_characters[0]==game.team_characters[1]
	var key=str([model.get_instance_id(),mirror,faction])
	if key==team_cape_key:return
	team_cape_key=key
	for mesh in model.find_children("Cape","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var base_key="team_cape_base_"+str(surface)
			if not mesh.has_meta(base_key):mesh.set_meta(base_key,mesh.get_active_material(surface))
			var base=mesh.get_meta(base_key)
			if not mirror:
				mesh.set_surface_override_material(surface,base)
			elif base is StandardMaterial3D:
				var cloth=base.duplicate()
				cloth.albedo_color=Color("a52d35") if faction==0 else Color("36834b")
				mesh.set_surface_override_material(surface,cloth)
func build_enemy_name_tag() -> void:
	pass # World names are disabled; avoid allocating hidden labels.
func name_tag_eligible(viewer: NestActor) -> bool:
	if not alive or game.now<cloak_deadline or viewer==null or viewer==self or not viewer.alive:return false
	if faction==viewer.faction and game.mode!=1:return false
	var cam=viewer.camera
	if cam==null:return false
	var head=global_position+Vector3.UP*1.74*SIZE
	var chest=global_position+Vector3.UP*.10*SIZE
	if cam.is_position_behind(head) or cam.is_position_behind(chest):return false
	var bounds=cam.get_viewport().get_visible_rect();var center=bounds.get_center()
	var closest=Geometry2D.get_closest_point_to_segment(center,cam.unproject_position(head),cam.unproject_position(chest))
	if center.distance_to(closest)>clampf(bounds.size.y*.0225,12,24):return false
	# The eligibility ray and the text itself both obey world depth. No cached
	# fade-out can leave a name visible after cover blocks the target.
	return game.trace(cam.global_position,head,1,viewer.ray_exclusions()).is_empty()
func update_enemy_name_tag(delta: float) -> void:
	if not is_instance_valid(enemy_name_tag):return
	var viewer: NestActor=game.player if is_instance_valid(game.player) else null
	name_tag_target=false # In-match world names are disabled.
	var color=enemy_name_tag.modulate
	color.a=move_toward(color.a,.7,delta*7) if name_tag_target else 0.0
	enemy_name_tag.modulate=color;enemy_name_tag.visible=name_tag_target and color.a>.001
	if enemy_name_tag.text!=username:enemy_name_tag.text=username

func set_character(value: int) -> void:
	# Teams exchange characters (every few rounds, or via snapshots on clients):
	# rebuild everything that depends on the character's appearance.
	if value==character or value<0: return
	character=value
	camo_renderer=null
	belt_sword=null;perched_nu=null;nu_perch_area=null
	refresh_traits()
	if model!=null: remove_child(model); model.queue_free()
	hitboxes.clear(); hitbox_shapes.clear(); pose_offsets.clear(); clips.clear()
	skeleton=null; animation=null; remote_weapon=null; remote_art=null; carried_visual=null
	build_model()
	build_enemy_name_tag()
	for h in hitboxes: h.collision_layer=4 if alive else 0
	if weapon_view!=null:
		weapon_view.get_parent().remove_child(weapon_view); weapon_view.queue_free(); weapon_view=null; weapon_art=null
		build_view_weapon()
	art_kind=""
	if presentation!=null and is_instance_valid(presentation.hit_electricity): presentation.hit_electricity.queue_free()
	if shield_fx!=null: shield_fx.queue_free(); shield_fx=null
	presentation=NestCombatPresentation.new(self); presentation.setup()
	update_crouch_shape(false)
	if local_player and game.has_method("local_character_changed"): game.call("local_character_changed")
func add_anatomical_hitbox(part: Dictionary) -> void:
	var area=Area3D.new()
	area.name="Hit_"+String(part.bone)
	area.collision_layer=4;area.collision_mask=0;area.monitoring=false
	area.set_meta("actor",self);area.set_meta("region",String(part.region))
	model.add_child(area)
	area.position=Vector3(part.position[0],part.position[1],part.position[2])
	var shape: ConvexPolygonShape3D=part.shape
	var collision=CollisionShape3D.new();collision.shape=shape;area.add_child(collision)
	hitboxes.append(area);hitbox_shapes.append(shape)
	if skeleton!=null:
		var index=skeleton.find_bone(String(part.bone))
		if index>=0:
			var bone_transform=skeleton.global_transform*skeleton.get_bone_global_pose(index)
			pose_offsets[area.get_instance_id()]={"bone":index,"offset":bone_transform.affine_inverse()*area.global_transform}
func build_view_weapon() -> void:
	view_grip_parts.clear()
	var k = game.arena.kit
	weapon_view = Node3D.new()
	camera.add_child(weapon_view)
	weapon_view.position = Vector3(0.24,-0.22,-0.48)
	weapon_art=NestWeaponArt.create("rifle",character); weapon_view.add_child(weapon_art)
	var arm=NestViewArms.create(character,"r","forearm");weapon_view.add_child(arm);arm.position=Vector3(.035,-.15,.27);arm.scale.y=.31/.25;arm.rotation.x=-PI/2+.22
	var hand=NestViewArms.create(character,"r","hand");weapon_view.add_child(hand);hand.position=Vector3(.012,-.09,.07)
	view_grip_parts.append_array([arm,hand])
	muzzle_flash = k.sphere(weapon_view,Vector3(0,0,-0.43),0.07,k.lamp)
	muzzle_flash.visible = false
func reset_loadout() -> void:
	reset_ak_spray()
	weapons.assign(NestWeaponCatalog.loadout(character,traits.starting_primary,traits.starting_secondary))
	ammo.clear(); reserve.clear()
	for w in weapons: ammo.append(w.magazine); reserve.append(w.reserve)
	slot=0; auto_reload_at=INF;auto_reload_slot=-1;throw_pending_kind=-1;throw_release=INF;grenades=[2,2]; cooldown=0; action_state="ready"; action_until=0; burst_left=0
	reload_duration=weapons[slot].reload_seconds; reload_was_empty=false
	reset_aim();update_weapon_art()
func is_attacker() -> bool:
	return faction==game.attacking_faction
func input_active() -> bool:
	return local_player and not game.matchmaking.blocks_simulation() and not (game.nu!=null and game.nu.blocked(self)) and game.input_window_focused and game.context=="playing" and alive and not game.finished and game.break_until<=game.now
func input_captured() -> bool:
	# Headless ENet test peers have no window and Godot cannot capture a mouse.
	return Input.mouse_mode==Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name()=="headless"
func gameplay_held(action: String) -> bool:
	return not suppressed_actions.has(action) and Input.is_action_pressed(action)
func gameplay_move() -> Vector2:
	var value=Vector2(
		(0.0 if suppressed_actions.has("right") else Input.get_action_strength("right"))-(0.0 if suppressed_actions.has("left") else Input.get_action_strength("left")),
		(0.0 if suppressed_actions.has("backward") else Input.get_action_strength("backward"))-(0.0 if suppressed_actions.has("forward") else Input.get_action_strength("forward")))
	return value.limit_length(1)
func clear_local_input() -> void:
	# Keep held physical keys suppressed until their release, including OS repeats.
	for action in ["left","right","forward","backward","jump","crouch","fire","aim","zoom","interact","reload","grenade","melee","switch_weapon","primary_weapon","secondary_weapon","sword"]:
		if Input.is_action_pressed(action):suppressed_actions[action]=true
	hover_look_gain=1.0
	jump_pending_until=-INF;fire_pending_until=-INF;jump_key_down=false;fire_key_down=false
func update_local_fire() -> void:
	if not input_active() or not input_captured() or ignore_fire_until_release or suppressed_actions.has("fire"):return
	if game.now<=fire_pending_until:
		if fire_trigger():fire_pending_until=-INF
		return
	fire_pending_until=-INF
	if gameplay_held("fire") and (weapons[slot].automatic or NestWeaponCatalog.for_kind(weapons[slot].kind).get("burst_count",1)>1):fire_trigger()
func _view_drawn() -> void:
	flash_render_pending=false
func _process(delta: float) -> void:
	if is_instance_valid(game) and game.running and local_player and not weapons.is_empty() and art_kind!=weapons[slot].kind:update_weapon_art()
	if is_instance_valid(game) and game.running and not game.matchmaking.blocks_simulation() and (local_player or remote_peer==0):stabilize_hitch_clock(delta)
	if not local_player or camera==null or not is_instance_valid(game) or not game.running: return
	# Translation alone uses engine physics interpolation. The top-level camera
	# cannot inherit an interpolated parent rotation or animation pose.
	# Reconciliation moves the simulated body instantly; the view absorbs that
	# shift and decays it over a few frames instead of popping.
	view_correction*=exp(-delta*VIEW_CORRECTION_RATE)
	if view_correction.length_squared()<.000001: view_correction=Vector3.ZERO
	# Interpolate the complete world eye position. Combining an interpolated
	# body origin with an immediate crouch offset produced a false landing dip.
	# Reconciliation used to leave the view up to 2.5 m from the body,
	# exceeding the server's 1.25 m origin validation and rejecting valid shots.
	# Keep interpolation smooth within a bounded half-metre visual offset.
	var desired_view=view_position_anchor.get_global_transform_interpolated().origin+view_correction
	camera.global_position=eye.global_position+(desired_view-eye.global_position).limit_length(.5)
	update_aim(delta)
	update_hover_look(delta)
	update_local_fire()
	if presentation!=null:presentation.update_view(delta)
func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		for action in suppressed_actions.keys():
			if event.is_action_released(action) or (event.is_action_pressed(action) and not (event is InputEventKey and event.echo)):suppressed_actions.erase(action)
		if event.is_action_released("jump"):jump_key_down=false
		if event.is_action_released("fire"):fire_key_down=false
		if event is InputEventKey and event.echo:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed: ignore_fire_until_release=false
	if not input_active(): return
	# Gameplay look runs before GUI event consumption. Menus/chat still own their input.
	if not input_captured():
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			game.capture_mouse(); ignore_fire_until_release=true; get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var motion=event.screen_relative
		# Synthetic input used by integrations may supply only relative; real captured
		# events use unscaled window counts, independent of viewport stretch and FPS.
		if motion==Vector2.ZERO: motion=event.relative
		var factor=deg_to_rad(0.022*game.prefs.values.sensitivity)
		factor*=enemy_hover_look_multiplier()
		if is_scoped():
			# Match magnification mathematically: tan(current FOV/2) / tan(base FOV/2).
			# This follows the current animated FOV every frame, avoiding a sensitivity jump.
			var base_half=tan(deg_to_rad(game.prefs.values.fov)*0.5)
			var zoom_half=tan(deg_to_rad(camera.fov)*0.5)
			var zoom_scale=zoom_half/base_half if absf(base_half)>0.00001 else 1.0
			factor*=zoom_scale*game.prefs.values.aim_sensitivity*game.prefs.values.zoom_feel_tweak
		rotation.y=wrapf(rotation.y-motion.x*factor,-PI,PI)
		eye.rotation.x=clampf(eye.rotation.x-motion.y*factor*(-1 if game.prefs.values.invert_y else 1),deg_to_rad(-89),deg_to_rad(89))
		apply_aim_rotation()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("jump") and not suppressed_actions.has("jump"):
		if not jump_key_down:jump_pending_until=game.now+INPUT_BUFFER_SECONDS
		jump_key_down=true;get_viewport().set_input_as_handled();return
	if (event.is_action_pressed("aim") and not suppressed_actions.has("aim")) or (event.is_action_pressed("zoom") and not suppressed_actions.has("zoom")):
		toggle_scope(); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("reload") and not suppressed_actions.has("reload"): reload_weapon()
	if event.is_action_pressed("grenade") and not suppressed_actions.has("grenade"): throw_grenade()
	if event.is_action_pressed("grenade_type"): grenade_kind=1-grenade_kind
	if event.is_action_pressed("interact") and not suppressed_actions.has("interact") and game.is_client():
		var pickup=game.pickup_choice(self)
		if not pickup.is_empty():game.request_remote_action("pickup",int(pickup.pad))
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_4,KEY_X]:
		var command=1 if event.physical_keycode==KEY_4 else 2
		if game.is_client():game.request_remote_action("bomb",command)
		else:game.bomb_control(self,command)
		get_viewport().set_input_as_handled();return
	if event.is_action_pressed("primary_weapon") and not suppressed_actions.has("primary_weapon"):select_weapon_slot(0)
	if event.is_action_pressed("secondary_weapon") and not suppressed_actions.has("secondary_weapon"):select_weapon_slot(1)
	if event.is_action_pressed("sword") and not suppressed_actions.has("sword"):
		if character==0:wield_sword()
		else:melee()
	if event.is_action_pressed("melee") and not suppressed_actions.has("melee"): melee()
	if event.is_action_pressed("switch_weapon") and not suppressed_actions.has("switch_weapon"): switch_weapon()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: switch_weapon()
	if event.is_action_pressed("fire") and not fire_key_down and not ignore_fire_until_release and not suppressed_actions.has("fire"):
		fire_key_down=true
		fire_pending_until=game.now+INPUT_BUFFER_SECONDS
		update_local_fire(); get_viewport().set_input_as_handled()
func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.running or game.matchmaking.blocks_simulation(): return
	if game.campaign!=null and game.campaign.frozen_actors():return
	if game.is_client() and not local_player:
		net_interpolate(game.remote_view_time)
		update_visual(delta)
		return
	if placement_retry_at>0 and not game.is_client():
		if game.now>=placement_retry_at:respawn()
		return
	var client_local=game.is_client() and local_player
	var host_remote=remote_peer>1 and game.network_active and not game.is_client()
	if client_local: apply_pending_reconcile()
	if not alive:
		# Dead peers keep the command stream contiguous so sequences stay aligned.
		if client_local: record_client_command(Vector2.ZERO,false,-1,false,rotation.y)
		elif host_remote: process_remote_commands(delta)
		update_visual(delta)
		if not game.is_client() and game.now>=respawn_at and not game.finished and game.break_until<=game.now and game.mode!=game.MODE_CS and not (game.campaign!=null and game.campaign.active): respawn()
		return
	if not game.is_client() and damage_model()=="naki":update_regeneration()
	if not game.is_client() and damage_model()=="annu" and (traits.health_regeneration or (damage_model()=="annu" and game.damage_rules.health_regen_enabled)) and game.now-last_damage>=traits.health_regen_delay: health=minf(tuning.health_capacity,health+(tuning.health_capacity*.2 if traits.health_regeneration else float(game.damage_rules.health_regen_per_second))*delta)
	if not game.is_client() and game.now>=over_deadline: overshield=0
	advance_combat_recovery()
	advance_weapon_timers()
	if game.finished or game.break_until>game.now:burst_left=0;fire_pending_until=-INF
	if burst_left>0 and game.now+.000001>=burst_next and last_shot_frame!=Engine.get_process_frames():
		var scheduled=burst_next
		shoot_round(); burst_left-=1
		var firing=NestWeaponCatalog.for_kind(weapons[slot].kind)
		burst_next=next_deadline(scheduled,fire_interval(float(firing.get("burst_interval",weapons[slot].interval))))
		if burst_left==0:cooldown=maxf(cooldown,next_deadline(scheduled,fire_interval(float(firing.get("burst_delay",0)))))
	if host_remote:
		process_remote_commands(delta)
	else:
		var move = Vector2.ZERO
		var jump = false
		var crouch_want=-1
		var interact=false
		if input_active():
			move=gameplay_move() if input_captured() else Vector2.ZERO
			# Fallback also supports tools/tests using Input.action_press (no event).
			if not gameplay_held("jump"):jump_key_down=false
			elif Input.is_action_just_pressed("jump") and not jump_key_down:
				jump_pending_until=game.now+INPUT_BUFFER_SECONDS;jump_key_down=true
			jump=game.now<=jump_pending_until and input_captured()
			crouch_want=1 if gameplay_held("crouch") and input_captured() else 0
			interact=gameplay_held("interact")
			if not Input.is_action_pressed("fire"): ignore_fire_until_release=false
			update_local_fire()
		elif not local_player and not game.finished and game.break_until<=game.now:
			var intent = bot_intent(delta)
			move=intent.move; jump=intent.jump
			crouch_want=int(intent.get("crouch",0))
		var yaw=quantize(rotation.y) if client_local else rotation.y
		var jumped=movement_step(move,jump,crouch_want,yaw,delta)
		if jumped:jump_pending_until=-INF
		if client_local: record_client_command(move,jumped,crouch_want,interact,yaw)
	if local_player:
		recoil=move_toward(recoil,0,delta*0.1)
	update_visual(delta)
# One simulation tick of character movement. Used unchanged for offline play,
# bots, host simulation of client commands and client replay after correction.
func movement_step(move: Vector2, jump: bool, crouch_want: int, yaw: float, delta: float, replaying: bool=false) -> bool:
	var motorcycle=campaign_motorcycle_controller()
	if motorcycle!=null and motorcycle.handles(self):return motorcycle.movement_step(self,move,jump,yaw,delta,replaying)
	if game.nu!=null and game.nu.blocked(self):move=Vector2.ZERO;jump=false;crouch_want=0
	if crouch_want>=0: set_crouch(crouch_want==1)
	var mult = tuning.carry_multiplier if carrying else 1.0
	var rules = traits
	var move_scale=rules.movement_speed_percent/100.0
	var wish = Basis(Vector3.UP,yaw)*Vector3(move.x,0,move.y)
	var horizontal = Vector3(controlled.x,0,controlled.z)
	var jumped=false
	var supported=is_on_floor()
	var support_normal=get_floor_normal() if supported else Vector3.UP
	var support_velocity=get_platform_velocity() if supported else Vector3.ZERO
	if (is_on_floor() or (jump and can_jump_from_support())) and not cannon_takeoff:
		var stance_scale=rules.crouch_speed_percent/100.0 if crouched else rules.walk_speed_percent/100.0
		var speed=(tuning.crouch_speed if crouched else tuning.ground_speed)*move_scale*stance_scale
		var accel=(tuning.ground_acceleration*rules.acceleration_percent/100.0) if move.length()>0 else (tuning.ground_braking*rules.deceleration_percent/100.0)
		horizontal=horizontal.move_toward(wish*speed*mult,accel*delta)
		controlled.y=0
		if jump:
			controlled.y=tuning.jump_speed*sqrt(maxf(0.0,rules.jump_height_percent*rules.gravity_percent/10000.0))+NestContactMomentum.slope_rise(horizontal,support_normal);external+=support_velocity.limit_length(NestContactMomentum.MAX_CONTACT_SPEED);jumped=true
	else:
		var air_multiplier=rules.air_control_percent/100.0
		var old_horizontal=horizontal
		horizontal=air_move(horizontal,wish,tuning,delta*air_multiplier,mult*move_scale) if air_multiplier>0 else horizontal
		if air_multiplier==0:horizontal=old_horizontal
		var fall_multiplier=1.10 if controlled.y+external.y<=0 else 1.0
		controlled.y=maxf(-35,controlled.y-tuning.gravity*(rules.gravity_percent/100.0)*fall_multiplier*delta)
	controlled.x=horizontal.x; controlled.z=horizontal.z
	external=external.move_toward(Vector3.ZERO,(8 if is_on_floor() else 1)*delta)
	# Analytic lift volume runs in shared movement, including prediction replay.
	var gravity_lift=game.lift_node()
	if gravity_lift!=null and gravity_lift.has_method("apply_motion") and game.game_type.lifts:gravity_lift.apply_motion(self,delta)
	velocity=controlled+external
	if lunge_ticks>0:
		velocity+=lunge_velocity; lunge_ticks-=1
	update_crouch_shape()
	cannon_takeoff=false
	step_up(delta)
	move_and_slide()
	update_crouch_shape()
	if supported and not is_on_floor() and not jumped:
		var rise=NestContactMomentum.slope_rise(horizontal,support_normal)
		if rise>.01:controlled.y=maxf(controlled.y,rise)
		external+=support_velocity.limit_length(NestContactMomentum.MAX_CONTACT_SPEED)
	NestContactMomentum.contacts(self,replaying)
	# Project both stored momentum channels out of blocked normals.
	for i in range(get_slide_collision_count()):
		var normal=get_slide_collision(i).get_normal()
		if normal.y>=cos(floor_max_angle):
			# Preserve requested horizontal movement on floors. Repeatedly projecting
			# it onto a ramp applies artificial braking every simulation tick.
			if controlled.y<0:controlled.y=0
		elif controlled.dot(normal)<0:controlled=controlled.slide(normal)
		if external.dot(normal)<0: external=external.slide(normal)
	if not replaying and global_position.y < -18 and not game.is_client(): die(null,"Fall")
	return jumped
static func quantize(value: float) -> float:
	# Commands carry 32-bit angles; predict with exactly what the host receives.
	return PackedFloat32Array([value])[0]
func campaign_motorcycle_controller():
	if game==null or game.campaign==null or not game.campaign.active:return null
	var journey=game.campaign.get("journey")
	return journey.get("motorcycles") if journey!=null else null
func is_motorcycle_rider() -> bool:
	var motorcycle=campaign_motorcycle_controller()
	return motorcycle!=null and motorcycle.handles(self)
func capture_move_state() -> Dictionary:
	return {"pos":global_position,"ctrl":controlled,"ext":external,"takeoff":cannon_takeoff,"crouched":crouched,"air_duck":air_duck,"grounded":is_on_floor(),"lunge_ticks":lunge_ticks,"lunge_v":lunge_velocity}
# ---- Client: command history, acknowledgement and reconciliation ----
func record_client_command(move: Vector2, jumped: bool, crouch_want: int, interact: bool, yaw: float) -> void:
	game.command_sequence+=1
	cmd_history.append({"seq":game.command_sequence,"move":move,"yaw":yaw,"pitch":quantize(eye.rotation.x),"jump":jumped,"crouch":crouch_want,"interact":interact,"t":game.local_clock(),"state":capture_move_state(),"alive":alive,"lift_y":game.lift_physics_y()})
	while cmd_history.size()>MAX_COMMAND_HISTORY: cmd_history.pop_front()
	if jumped: game.net_stat("client_jumps")
	if NET_TRACE and game.command_sequence%30==0: print("TRACE c seq=",game.command_sequence," pos=",global_position," ack=",ack_seen," hist=",cmd_history.size()," alive=",alive," life=",life_id," pend=",not pending_reconcile.is_empty())
	game.send_commands()
func queue_reconcile(state: Dictionary, server_time: float) -> void:
	var motorcycle=campaign_motorcycle_controller()
	if motorcycle!=null and motorcycle.handles(self):
		# Mounted guests send input normally; only the host integrates vehicle
		# heading, suspension and falls. Keep normal on-foot replay unchanged.
		var previous=global_position
		global_position=state.pos;controlled=state.get("ctrl",state.velocity);velocity=state.velocity;external=Vector3.ZERO
		pending_reconcile={};cmd_history.clear();ack_seen=int(state.ack)
		view_correction=(view_correction+previous-global_position).limit_length(1.5)
		reset_physics_interpolation();return
	var s={"ack":int(state.ack),"pos":state.pos,"ctrl":state.get("ctrl",state.velocity),"ext":state.get("ext",Vector3.ZERO),"takeoff":state.get("takeoff",false),"grounded":state.grounded,"crouch":state.crouch,"air_duck":state.get("air_duck",false),"jbuf":int(state.get("jbuf",0)),"alive":state.alive,"server_time":server_time,"lunge_ticks":int(state.get("lunge_t",0)),"lunge_v":state.get("lunge_v",Vector3.ZERO)}
	# Before the host has simulated any of our commands, or while it has stopped
	# simulating them (stalled stream, frozen body), there is no prediction to
	# reconcile: the host alone moves this body, so follow its state directly.
	if s.ack<0: adopt_authoritative_state(s); return
	if s.ack!=ack_seen: ack_seen=s.ack; ack_changed_at=game.local_clock()
	elif game.local_clock()-ack_changed_at>ACK_STALL_SECONDS: adopt_authoritative_state(s); return
	pending_reconcile=s
func sync_floor_state(grounded: bool) -> void:
	# CharacterBody floor contact comes from the last move_and_slide. Make it
	# match the authoritative state before replaying from that state.
	if grounded:
		if not is_on_floor(): apply_floor_snap()
	elif is_on_floor():
		var keep=global_position; var keep_velocity=velocity
		velocity=Vector3.UP*.01; move_and_slide()
		global_position=keep; velocity=keep_velocity
func apply_pending_reconcile() -> void:
	if pending_reconcile.is_empty(): return
	var s=pending_reconcile; pending_reconcile={}
	while not cmd_history.is_empty() and cmd_history[0].seq<s.ack: cmd_history.pop_front()
	if cmd_history.is_empty() or cmd_history[0].seq!=s.ack: return
	var entry=cmd_history.pop_front()
	if not alive or not s.alive or not entry.alive: return
	var p: Dictionary=entry.state
	var error=p.pos.distance_to(s.pos)
	var velocity_error=(p.ctrl+p.ext).distance_to(s.ctrl+s.ext)
	if error<=RECONCILE_POSITION_EPSILON and velocity_error<=RECONCILE_VELOCITY_EPSILON and p.crouched==s.crouch and p.grounded==s.grounded and int(p.lunge_ticks)==int(s.lunge_ticks):
		game.net_stat("predictions_confirmed"); return
	var before=global_position
	var live_yaw=rotation.y
	if NET_TRACE: print("TRACE correct ack=",s.ack," err=",error," verr=",velocity_error," pred=",p.pos," srv=",s.pos," hist=",cmd_history.size()," now_seq=",game.command_sequence)
	global_position=s.pos; controlled=s.ctrl; external=s.ext; cannon_takeoff=s.takeoff; lunge_ticks=s.lunge_ticks; lunge_velocity=s.lunge_v
	if crouched!=s.crouch or air_duck!=s.air_duck:
		crouched=s.crouch; air_duck=s.air_duck; update_crouch_shape(false)
	sync_floor_state(s.grounded)
	var jump_buffer=int(s.jbuf)
	var lift_now=game.lift_physics_y()
	for c in cmd_history:
		if not c.alive: continue
		# The lift's collision body cannot be moved back for a replay. Replay a
		# rider in the lift's frame instead: offset it by how far the lift has
		# moved since this tick was first simulated, then remove the offset.
		var lift_shift=0.0
		if is_finite(lift_now) and is_finite(float(c.get("lift_y",NAN))) and game.on_lift_column(global_position,float(c.lift_y)): lift_shift=lift_now-float(c.lift_y)
		global_position.y+=lift_shift
		# Mirror the host's bounded jump buffer so replay makes the same choice.
		if c.jump: jump_buffer=JUMP_BUFFER_TICKS
		var jumped=movement_step(c.move,jump_buffer>0,c.crouch,c.yaw,NET_TICK,true)
		if jumped:jump_buffer=0
		elif jump_buffer>0:jump_buffer-=1
		global_position.y-=lift_shift
		c.state=capture_move_state()
	rotation.y=live_yaw
	var shift=before-global_position
	view_correction=Vector3.ZERO if shift.length()>2.5 else (view_correction+shift).limit_length(2.5)
	reset_physics_interpolation()
	game.net_stat("corrections"); game.net_stat("replayed_ticks",cmd_history.size())
	game.net_stat_max("max_correction_m",shift.length()); game.net_stat("correction_sum_m",shift.length())
func adopt_authoritative_state(s: Dictionary) -> void:
	if not alive or not s.alive: return
	var shift=global_position-s.pos
	if NET_TRACE: print("TRACE adopt ack=",s.ack," shift=",shift.length()," srv=",s.pos)
	if shift.length()<=RECONCILE_POSITION_EPSILON and (controlled+external).distance_to(s.ctrl+s.ext)<=RECONCILE_VELOCITY_EPSILON: return
	global_position=s.pos; controlled=s.ctrl; external=s.ext; cannon_takeoff=s.takeoff; lunge_ticks=s.lunge_ticks; lunge_velocity=s.lunge_v
	if crouched!=s.crouch or air_duck!=s.air_duck:
		crouched=s.crouch; air_duck=s.air_duck; update_crouch_shape(false)
	sync_floor_state(s.grounded)
	cmd_history.clear()
	view_correction=Vector3.ZERO if shift.length()>2.5 else (view_correction+shift).limit_length(2.5)
	reset_physics_interpolation()
	game.net_stat("stalled_ack_adoptions")
# ---- Host: ordered, rate-limited processing of client commands ----
func queue_commands(commands: Array) -> void:
	for c in commands:
		if c.seq<=cmd_last_seq: continue
		var index=cmd_queue.size()
		var duplicate=false
		while index>0 and cmd_queue[index-1].seq>=c.seq:
			if cmd_queue[index-1].seq==c.seq: duplicate=true; break
			index-=1
		if not duplicate: cmd_queue.insert(index,c)
	while cmd_queue.size()>MAX_COMMAND_QUEUE:
		cmd_queue.pop_front(); game.net_stat("commands_overflowed")
func process_remote_commands(delta: float) -> void:
	cmd_credit=minf(cmd_credit+1,COMMAND_CREDIT_CAP)
	# A small backlog drains faster; credits stop clients from running ahead of
	# real time even when jitter delivers many commands at once.
	var budget=1+(1 if cmd_queue.size()>3 else 0)+(2 if cmd_queue.size()>8 else 0)
	var processed=0
	while processed<budget and cmd_credit>=1 and not cmd_queue.is_empty():
		var c=cmd_queue.pop_front()
		if c.seq<=cmd_last_seq: continue
		if c.seq>cmd_last_seq+1 and cmd_last_seq>=0: game.net_stat("commands_lost",c.seq-cmd_last_seq-1)
		apply_remote_command(c,delta); processed+=1; cmd_credit-=1
	game.net_stat("host_ticks_with_%d_commands"%mini(processed,3))
	if processed>0: cmd_starved=0
	else:
		cmd_starved+=1
		if cmd_starved>COMMAND_STARVE_TICKS and cmd_credit>=1 and cmd_last_seq>=0:
			# The client stalled. Keep its body simulated with the last held input;
			# the real command for this sequence will be ignored on arrival.
			var filler=cmd_template.duplicate() if not cmd_template.is_empty() else {"move":Vector2.ZERO,"yaw":rotation.y,"pitch":eye.rotation.x,"crouch":-1,"interact":false}
			filler.seq=cmd_last_seq+1; filler.jump=false
			apply_remote_command(filler,delta); cmd_credit-=1; game.net_stat("filler_commands")
	game.run_deferred_commands(self)
func apply_remote_command(c: Dictionary, delta: float) -> void:
	cmd_last_seq=c.seq
	command_aims[c.seq]=-(Basis(Vector3.UP,c.yaw)*Basis(Vector3.RIGHT,c.pitch)).z
	while command_aims.size()>128:command_aims.erase(command_aims.keys()[0])
	var previous: Dictionary=game.command_received.get(remote_peer,{})
	var barrier=int(previous.get("barrier",-1))
	if c.seq<=barrier: c={"seq":c.seq,"move":Vector2.ZERO,"yaw":c.yaw,"pitch":c.pitch,"jump":false,"crouch":-1,"interact":false}
	cmd_template=c.duplicate(); cmd_template.jump=false
	net_move=c.move; net_crouch=c.crouch==1 or (c.crouch<0 and crouched); net_interact=c.interact; net_last_command=game.now
	rotation.y=c.yaw; eye.rotation.x=clampf(c.pitch,-1.55,1.55)
	if alive:
		if c.jump: server_jump_buffer=JUMP_BUFFER_TICKS
		if movement_step(c.move,server_jump_buffer>0,c.crouch,c.yaw,delta):
			server_jump_buffer=0
			game.net_stat("host_jumps"); host_jump_seqs.append(c.seq)
			if host_jump_seqs.size()>64: host_jump_seqs.pop_front()
		elif server_jump_buffer>0:server_jump_buffer-=1
	game.command_received[remote_peer]={"sequence":c.seq,"barrier":barrier,"at":game.now}
	if NET_TRACE and c.seq%30==0: print("TRACE h seq=",c.seq," pos=",global_position," alive=",alive," life=",life_id," q=",cmd_queue.size()," move=",c.move)
	game.run_deferred_commands(self)
# ---- Client: buffered interpolation of other actors ----
func push_net_sample(t: float, state: Dictionary) -> void:
	if not snap_buffer.is_empty() and t<=snap_buffer[-1].t: return
	snap_buffer.append({"t":t,"pos":state.pos,"yaw":state.yaw,"pitch":state.pitch,"vel":state.velocity,"grounded":state.grounded,"crouch":state.crouch,"air_duck":state.get("air_duck",false)})
	while snap_buffer.size()>40: snap_buffer.pop_front()
func net_interpolate(t: float) -> void:
	if snap_buffer.is_empty(): return
	var i=-1
	for k in range(snap_buffer.size()):
		if snap_buffer[k].t<=t: i=k
		else: break
	var sample: Dictionary
	var pos: Vector3; var yaw: float; var pitch: float; var vel: Vector3
	if i<0:
		sample=snap_buffer[0]; pos=sample.pos; yaw=sample.yaw; pitch=sample.pitch; vel=sample.vel
		game.net_stat("interp_underflow_ticks")
	elif i+1<snap_buffer.size():
		var a=snap_buffer[i]; var b=snap_buffer[i+1]
		var f=clampf((t-a.t)/maxf(b.t-a.t,.0001),0,1)
		if a.pos.distance_to(b.pos)>8: f=0.0 if f<.5 else 1.0
		pos=a.pos.lerp(b.pos,f); yaw=lerp_angle(a.yaw,b.yaw,f); pitch=lerpf(a.pitch,b.pitch,f); vel=a.vel.lerp(b.vel,f)
		sample=a if f<.5 else b
		game.net_stat("interp_ticks")
	else:
		sample=snap_buffer[i]
		var dt=minf(t-sample.t,REMOTE_EXTRAPOLATE_LIMIT)
		vel=sample.vel
		var drift=Vector3(vel.x,0 if sample.grounded else vel.y,vel.z)
		pos=sample.pos+drift*dt; yaw=sample.yaw; pitch=sample.pitch
		game.net_stat("extrapolated_ticks")
	if i>1: snap_buffer=snap_buffer.slice(i-1)
	global_position=pos; rotation.y=yaw; eye.rotation.x=pitch; velocity=vel; net_grounded=sample.grounded
	if crouched!=sample.crouch or air_duck!=sample.air_duck:
		crouched=sample.crouch; air_duck=sample.air_duck; update_crouch_shape(false)
static func air_move(horizontal: Vector3, wish: Vector3, cfg: NestTuning, delta: float, multiplier: float=1) -> Vector3:
	if wish.length_squared()<0.0001: return horizontal
	var desired = cfg.ground_speed*multiplier*minf(wish.length(),1)
	var direction=wish.normalized()
	var allowance=minf(desired,cfg.air_projection_cap)-horizontal.dot(direction)
	if allowance>0: horizontal+=direction*minf(allowance,cfg.air_acceleration*desired*delta)
	# Smooth reduction on entering carry state rather than a hard snap.
	var cap=cfg.air_speed_cap*multiplier
	if horizontal.length()>cap: horizontal=horizontal.move_toward(horizontal.normalized()*cap,cfg.ground_braking*delta)
	return horizontal
func step_up(delta: float) -> void:
	if not is_on_floor() or controlled.y>0: return
	var motion=Vector3(velocity.x,0,velocity.z)*delta
	if motion.length()<0.001: return
	var obstruction=stair_obstruction
	if not test_move(global_transform,motion,obstruction): return
	# Walkable slopes are floors, not stair risers. Do not lift off their surface.
	var step_height=.42
	var probe_motion=motion.normalized()*maxf(motion.length(),BODY_RADIUS+.08)
	var raised=global_transform
	raised.origin.y+=step_height
	if test_move(global_transform,Vector3.UP*step_height) or test_move(raised,probe_motion):return
	raised.origin+=probe_motion
	var result=stair_landing
	if test_move(raised,Vector3.DOWN*(step_height+.02),result) and result.get_normal().y>0.7:
		var rise=maxf(0,step_height-result.get_travel().length())
		var first_normal=obstruction.get_normal()
		# A continuous ramp keeps the same normal. Only lift over a true ledge
		# or its transition to a flat landing, never each point of the incline.
		if rise>.03 and (first_normal.y<cos(floor_max_angle) or first_normal.y>.9999 or first_normal.dot(result.get_normal())<.98):global_position.y+=rise
func set_crouch(want: bool) -> void:
	if crouched==want: return
	if not want:
		var query=PhysicsShapeQueryParameters3D.new();var standing=CapsuleShape3D.new()
		standing.height=STAND_HEIGHT;standing.radius=BODY_RADIUS
		query.shape=standing;query.transform=Transform3D(Basis(),global_position+Vector3.UP*STAND_CENTER);query.collision_mask=3;query.exclude=[get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(query).is_empty():return
	crouched=want;update_crouch_shape()
func update_crouch_shape(adjust_origin: bool = true) -> void:
	var grounded=net_grounded if game.is_client() and not local_player else is_on_floor()
	var airborne=(crouched and (not grounded or controlled.y>0.01)) if adjust_origin else air_duck
	if adjust_origin and crouched and air_duck and not airborne: global_position.y+=TUCK
	elif adjust_origin and crouched and not air_duck and airborne and capsule.shape.height<(CROUCH_HEIGHT+STAND_HEIGHT)*.5: global_position.y-=TUCK
	air_duck=airborne
	var shape_height=CROUCH_HEIGHT if crouched else STAND_HEIGHT
	if capsule.shape.height!=shape_height:capsule.shape.height=shape_height
	var center=AIR_DUCK_CENTER if air_duck else CROUCH_CENTER if crouched else STAND_CENTER
	if capsule.position.y!=center:capsule.position.y=center
	var eye_y=EYE_HEIGHT if air_duck or not crouched else CROUCH_EYE_HEIGHT
	if eye.position.y!=eye_y:eye.position.y=eye_y
	if view_position_anchor!=null and view_position_anchor.position!=eye.position:view_position_anchor.position=eye.position
	var model_y=SIZE*(1.0 if air_duck or not crouched else CROUCH_HEIGHT/STAND_HEIGHT)
	if model.scale.y!=model_y:model.scale.y=model_y
func reset_crouch() -> void:
	crouched=false;air_duck=false;capsule.shape.height=STAND_HEIGHT;capsule.position.y=STAND_CENTER;eye.position.y=EYE_HEIGHT;model.scale.y=SIZE
	if view_position_anchor!=null:view_position_anchor.position=eye.position
func ray_exclusions() -> Array[RID]:
	if ray_exclusion_cache.is_empty():
		ray_exclusion_cache.append(get_rid())
		for h in hitboxes:ray_exclusion_cache.append(h.get_rid())
		if nu_perch_area!=null:ray_exclusion_cache.append(nu_perch_area.get_rid())
	return ray_exclusion_cache
func aim_direction() -> Vector3:
	if camera!=null:
		apply_aim_rotation()
		return -camera.global_basis.z.normalized()
	return -eye.global_transform.basis.z
func is_scoped() -> bool:
	return scope_level>0 and alive and not weapons.is_empty() and action_state=="ready"
func scoped_overlay() -> bool:
	return is_scoped() and NestWeaponCatalog.for_kind(weapons[slot].kind).get("scope_overlay",false)
func update_regeneration() -> void:
	if not alive or damage_model()!="naki" or game.now-last_damage<tuning.shield_delay:return
	if regen_anchor_damage!=last_damage:
		regen_anchor_damage=last_damage;regen_start_health=health;regen_start_shield=shield
	var duration=3.0*100.0/maxf(1,traits.shield_recharge_rate_percent)
	var progress=clampf((game.now-last_damage-tuning.shield_delay)/duration,0,1)
	health=lerpf(regen_start_health,tuning.health_capacity,progress)
	if traits.shields_enabled:shield=lerpf(regen_start_shield,tuning.shield_capacity,progress)
	if shield>0:body_phase=false
func is_regenerating() -> bool:
	return alive and damage_model()=="naki" and game.now-last_damage>=tuning.shield_delay and (health<tuning.health_capacity-.01 or (traits.shields_enabled and shield<tuning.shield_capacity-.01))
func damage_model() -> String:
	var chosen=int(traits.health_type)
	if chosen>0:return "naki" if chosen==1 else "annu"
	var model=game.active_damage_model()
	return NestCharacterCatalog.by_index(character).damage_model if model=="faction" else model
func toggle_scope() -> void:
	if is_motorcycle_rider():return
	if not input_active() or action_state!="ready" or weapons.is_empty(): return
	var config=NestWeaponCatalog.for_kind(weapons[slot].kind)
	var levels=maxi(config.get("scope_fov",[]).size(),config.get("zoom_factors",[]).size())
	if levels==0: return
	scope_level=(scope_level+1)%(levels+1)
	if combat_audio!=null: combat_audio.weapon_event("zoom_out_sound" if scope_level==0 else "zoom_in_sound" if scope_level==1 else "zoom_step_sound","zoom")
func cancel_scope() -> void:
	if scope_level>0 and combat_audio!=null: combat_audio.weapon_event("zoom_out_sound","zoom")
	scope_level=0
	if weapon_view!=null: weapon_view.visible=not is_motorcycle_rider()
func reset_aim() -> void:
	cancel_scope(); combat_recovery_at=game.now;fire_pending_until=-INF;aim_punch=Vector2.ZERO; accuracy_penalty=0; shots_in_sequence=0; last_shot_at=-100;last_shot_kind=""; recoil=0; ignore_fire_until_release=false
	if camera!=null:
		camera.fov=game.prefs.values.fov;camera.global_position=eye.global_position;apply_aim_rotation()
func apply_aim_rotation() -> void:
	if camera==null: return
	var pitch=clampf(eye.rotation.x+aim_punch.y,deg_to_rad(-89),deg_to_rad(89))
	camera.global_basis=eye.global_basis*Basis.from_euler(Vector3(pitch-eye.rotation.x,aim_punch.x,0))
func update_aim(delta: float) -> void:
	if camera==null: return
	if not input_active(): cancel_scope()
	advance_combat_recovery()
	apply_aim_rotation()
	var target_fov=game.prefs.values.fov
	var config=NestWeaponCatalog.for_kind(weapons[slot].kind)
	if is_scoped():
		var fixed=config.get("scope_fov",[])
		if not fixed.is_empty() and float(fixed[scope_level-1])>0: target_fov=float(fixed[scope_level-1])
		else: target_fov=rad_to_deg(2*atan(tan(deg_to_rad(game.prefs.values.fov)*.5)/float(config.zoom_factors[scope_level-1])))
	camera.fov=lerpf(camera.fov,target_fov,1-exp(-delta*float(config.get("scope_transition",22))))
	if weapon_view!=null: weapon_view.visible=not is_motorcycle_rider() and not scoped_overlay() and weapons[slot].kind!="none"
func advance_combat_recovery() -> void:
	var recoil_dt=maxf(0,game.now-maxf(combat_recovery_at,last_shot_at+.10))
	var spread_dt=maxf(0,game.now-maxf(combat_recovery_at,last_shot_at+.15))
	aim_punch*=exp(-recoil_dt*9)
	var spray_clock=float(cmd_last_seq)*NET_TICK if ak_spray_command_clock else game.now
	if spray_clock-ak_spray_last>=NestAKSpray.RESET_SECONDS-.000001:reset_ak_spray()
	if not weapons.is_empty() and weapons[slot].kind!="ak47":accuracy_penalty=move_toward(accuracy_penalty,0,spread_dt*float(NestWeaponCatalog.for_kind(weapons[slot].kind).get("spread_recover_per_sec",0)))
	if game.now-last_shot_at>.35:shots_in_sequence=0
	combat_recovery_at=game.now
func fire_interval(seconds: float) -> float:
	return seconds*100.0/traits.fire_rate_percent
func reload_interval(seconds: float) -> float:
	return seconds*100.0/traits.reload_speed_percent
func consume_round() -> void:
	if traits.infinite_ammo!=2:ammo[slot]-=1
func advance_weapon_timers() -> void:
	if throw_pending_kind>=0 and (action_state!="throwing" or not alive or throw_life!=life_id):throw_pending_kind=-1;throw_release=INF
	if throw_pending_kind>=0 and game.now+.000001>=throw_release:release_thrown_grenade()
	if game.now>=auto_reload_at:
		if not alive or slot!=auto_reload_slot or ammo[slot]>0:auto_reload_at=INF;auto_reload_slot=-1
		elif action_state=="ready" and not game.is_interacting(self):reload_weapon()
	if is_finite(sword_lunge_at) and game.now>=sword_lunge_at:
		if alive and action_state=="melee":start_lunge(sword_lunge)
		sword_lunge_at=INF
	advance_melee_contact()
	if action_state=="reloading" and shell_remaining>0:
		var seconds=reload_interval(float(NestWeaponCatalog.for_kind(weapons[slot].kind).shell_seconds))
		while shell_remaining>0 and game.now+.000001>=shell_next:
			insert_shell();shell_remaining-=1;shell_next+=seconds
	if game.now+.000001>=action_until and action_state not in ["ready","nu_launch"]:
		if action_state=="reloading" and not NestWeaponCatalog.for_kind(weapons[slot].kind).get("per_shell",false):
			var amount=weapons[slot].magazine-ammo[slot] if traits.infinite_ammo>0 else mini(weapons[slot].magazine-ammo[slot],reserve[slot])
			ammo[slot]+=amount
			if traits.infinite_ammo==0:reserve[slot]-=amount
		action_state="ready";shell_remaining=0;shell_next=INF
func stabilize_hitch_clock(frame_delta: float) -> void:
	if frame_delta<=.075 or last_shot_frame!=Engine.get_process_frames() or game.now-last_shot_at<=1.0/Engine.physics_ticks_per_second+.000001:return
	# A catch-up frame advanced past an already emitted shot. Start the next
	# interval at the completed frame clock instead of draining overdue rounds.
	var config=NestWeaponCatalog.for_kind(weapons[slot].kind)
	if burst_left>0:
		burst_next=maxf(burst_next,game.now+fire_interval(float(config.burst_interval)))
		cooldown=maxf(cooldown,game.now+fire_interval(burst_left*float(config.burst_interval)+float(config.get("burst_delay",0))))
	else:cooldown=maxf(cooldown,game.now+fire_interval(weapons[slot].interval))
	last_shot_at=game.now;combat_recovery_at=game.now;flash_until=game.now+.15
func next_deadline(previous: float, interval: float) -> float:
	# Preserve cadence within one simulation tick; discard an overdue backlog.
	return (previous if game.now-previous<=1.0/Engine.physics_ticks_per_second+.000001 else game.now)+interval
func current_spread_degrees(current_shot: bool=false) -> float:
	if weapons.is_empty(): return 0.0
	# AK bloom is shot-driven only; movement never adds an accuracy penalty.
	var bloom=NestAKSpray.cone(ak_spray_count if current_shot else ak_spray_count+1) if weapons[slot].kind=="ak47" else 0.0
	return (weapons[slot].spread_half_angle_deg+bloom)*traits.spread_percent/100.0
func add_shot_recoil() -> void:
	if game.now-last_shot_at>.35: shots_in_sequence=0
	shots_in_sequence+=1; last_shot_at=game.now
	var kind=weapons[slot].kind
	var config=NestWeaponCatalog.for_kind(kind)
	accuracy_penalty=NestAKSpray.cone(ak_spray_count) if kind=="ak47" else 0.0
	if not local_player: return
	var pitch=.20
	if kind=="rifle": pitch=.42+minf(shots_in_sequence,10)*.065
	elif kind=="ak47": pitch=.55+minf(shots_in_sequence,10)*.075
	elif kind in ["burst","burst_scoped","plasma_br"]: pitch=.38
	elif kind in ["plasma_auto","plasma_smg"]:pitch=.28
	elif kind=="smg":pitch=.27
	elif kind in ["sniper","plasma_sniper"]: pitch=1.38 # 20% above 1.15 degrees per shot
	elif kind=="shotgun": pitch=1.25
	elif kind=="rocket": pitch=.65
	var yaw=sin(float(shots_in_sequence)*1.7)*.11 if kind in ["rifle","ak47","burst"] else 0.0
	aim_punch+=Vector2(deg_to_rad(yaw),deg_to_rad(pitch))*traits.recoil_percent/100.0
	aim_punch.y=minf(aim_punch.y,deg_to_rad(8))
	apply_aim_rotation()
func switch_weapon() -> void:
	if bomb_equipped:
		if game.is_client():game.request_remote_action("bomb",1)
		else:game.bomb_control(self,1)
		return
	if not alive or (game.now<action_until and action_state!="reloading"): return
	if combat_audio!=null: combat_audio.weapon_event("unequip_sound","handling"); combat_audio.stop_reload()
	reset_aim()
	if game.is_client(): game.request_remote_action("switch")
	slot=(slot+1)%weapons.size(); action_state="switching"; action_until=game.now+float(NestWeaponCatalog.for_kind(weapons[slot].kind).get("switch_seconds",0)); burst_left=0
	game.remote_shot_clocks.erase(remote_peer)
func select_weapon_slot(index: int) -> void:
	if index not in [0,1] or index>=weapons.size() or weapons[index].kind in ["none","plasma_sword"] or slot==index:return
	if bomb_equipped or not alive or (game.now<action_until and action_state!="reloading"):return
	if combat_audio!=null:combat_audio.weapon_event("unequip_sound","handling");combat_audio.stop_reload()
	reset_aim()
	if game.is_client():game.request_remote_action("select_weapon",index)
	slot=index;action_state="switching";action_until=game.now+float(NestWeaponCatalog.for_kind(weapons[slot].kind).get("switch_seconds",0));burst_left=0
	game.remote_shot_clocks.erase(remote_peer)
func reload_weapon() -> void:
	if bomb_equipped:return
	if game.is_interacting(self):return
	if action_state!="ready" or ammo[slot]>=weapons[slot].magazine or (reserve[slot]<=0 and traits.infinite_ammo==0) or traits.infinite_ammo==2: return
	auto_reload_at=INF;auto_reload_slot=-1
	if weapons[slot].kind=="ak47":reset_ak_spray()
	cancel_scope()
	if game.is_client(): game.request_remote_action("reload")
	fire_pending_until=-INF;reload_was_empty=ammo[slot]==0; reload_duration=reload_interval(weapons[slot].reload_seconds)
	shell_remaining=0;shell_next=INF
	var config=NestWeaponCatalog.for_kind(weapons[slot].kind)
	if config.get("per_shell",false):
		shell_remaining=weapons[slot].magazine-ammo[slot] if traits.infinite_ammo>0 else mini(weapons[slot].magazine-ammo[slot],reserve[slot]);shell_next=game.now+reload_interval(float(config.shell_seconds))*.5
		reload_duration=reload_interval(shell_remaining*float(config.shell_seconds)+(float(config.shell_finish_seconds) if reload_was_empty else 0))
	action_state="reloading"; action_until=game.now+reload_duration; burst_left=0
	if combat_audio!=null: combat_audio.start_reload(reload_was_empty)
func insert_shell() -> void:
	if action_state=="reloading" and ammo[slot]<weapons[slot].magazine and (reserve[slot]>0 or traits.infinite_ammo>0):
		ammo[slot]+=1
		if traits.infinite_ammo==0:reserve[slot]-=1
func fire_trigger() -> bool:
	var motorcycle=campaign_motorcycle_controller()
	if motorcycle!=null and motorcycle.handles(self):return false
	if bomb_equipped:return false
	if game.matchmaking.blocks_simulation():return false
	if game.nu!=null and game.nu.blocked(self):return false
	if not weapons.is_empty() and weapons[slot].kind=="plasma_sword":return sword_trigger()
	advance_combat_recovery();advance_weapon_timers()
	if not game.running or game.finished or game.break_until>game.now or last_shot_frame==Engine.get_process_frames() or burst_left>0:return false
	if not alive or game.now+.000001<cooldown or game.now<hit_stun_until or action_state!="ready" or game.is_interacting(self): return false
	if weapons[slot].kind=="none": return false
	if ammo[slot]<=0:
		reload_weapon()
		if action_state=="reloading":return true
		if combat_audio!=null: combat_audio.weapon_event("dry_sound")
		cooldown=game.now+fire_interval(weapons[slot].interval); return true
	cooldown=next_deadline(cooldown,fire_interval(weapons[slot].interval))
	shoot_round()
	var config=NestWeaponCatalog.for_kind(weapons[slot].kind)
	if config.get("burst_count",1)>1: burst_left=mini(int(config.burst_count)-1,ammo[slot]); burst_next=game.now+fire_interval(float(config.burst_interval))
	return true
func shot_directions(direction: Vector3, _origin: Vector3, event_id: int, _view_origin: Vector3=Vector3.INF) -> Array:
	var rng=RandomNumberGenerator.new();rng.seed=hash([net_id,event_id,game.match_session])
	var result=[]
	var weapon=weapons[slot]
	for i in range(weapon.pellets):
		var pattern=NestAKSpray.direction(direction.normalized(),ak_spray_count,traits.spread_percent/100.0) if weapon.kind=="ak47" else direction.normalized()
		# Damage and projectile flight start on the view ray. The offset gun model
		# is presentation only; it must not bend or obstruct a clear crosshair shot.
		result.append(cone_direction(pattern,deg_to_rad(current_spread_degrees(true)),rng))
	return result
func shoot_round() -> void:
	if not game.running or game.finished or game.break_until>game.now or ammo[slot]<=0 or not alive or action_state!="ready" or game.is_interacting(self): return
	advance_combat_recovery();consume_round();last_shot_frame=Engine.get_process_frames()
	var w=weapons[slot];last_shot_kind=w.kind;var aim=resolve_shot_aim(w.max_range)
	var shot_id=game.next_event()*16
	accepted_shots+=1
	prepare_ak_shot(shot_id)
	var directions=shot_directions(aim_direction(),aim.origin,shot_id)
	if game.is_client():
		pending_shots.append({"id":shot_id,"slot":slot,"kind":w.kind,"spray_reset":ak_spray_count==1})
		# The command sequence orders the shot against movement on the host; the
		# view time lets the host rewind targets to what this client displayed.
		# Local fire runs before record_client_command in this physics tick.
		# Bind its aim to the upcoming command rather than the previous view.
		game.authorize_shot.rpc_id(1,shot_id,life_id,game.round_number,w.kind,aim.origin,aim_direction(),game.match_session,scope_level,game.command_sequence+1,game.remote_view_time)
	for i in range(directions.size()):game.launch_bullet(self,w,aim.origin,directions[i],i,game.is_client(),shot_id+i,burst_left==0)
	if combat_audio!=null:combat_audio.on_fire(burst_left==0)
	flash_until=game.now+.15
	if local_player:recoil=.045;flash_render_pending=true
	# Query every pellet using pre-shot aim/spread; recoil affects only later shots.
	shot_fired.emit(shot_id,game.now,aim.origin,directions)
	add_shot_recoil()
	queue_auto_reload()
	if local_player and presentation!=null:presentation.update_view_weapon(Vector2(velocity.x,velocity.z).length())
func magnetized_direction(_origin: Vector3, direction: Vector3, _max_range: float) -> Vector3:
	# Compatibility shim for older tests/callers. Ancient Nest intentionally has no
	# aim magnetism: shots always preserve the player's true camera-derived direction.
	return direction
func enemy_hover_look_multiplier() -> float:
	# Called at mouse polling frequency: no physics query, allocations or time integration.
	return hover_look_gain
func update_hover_look(delta: float) -> void:
	if not input_active() or not input_captured():
		hover_look_gain=1.0
		return
	var target=query_enemy_hover_multiplier()
	var span=1.0-float(game.prefs.values.hover_sensitivity_multiplier)
	hover_look_gain=move_toward(hover_look_gain,target,maxf(0,delta)*span/HOVER_TRANSITION_SECONDS)
func query_enemy_hover_multiplier() -> float:
	# Sensitivity-only slowdown. This uses the same world + hitbox ray ordering as
	# shooting, so walls block the effect and the real hitbox must be under the reticle.
	if camera==null or weapons.is_empty() or not alive: return 1.0
	var direction=aim_direction()
	var max_range=maxf(1.0,weapons[slot].max_range)
	var hit=game.trace(camera.global_position,camera.global_position+direction*max_range,5,ray_exclusions())
	if hit.is_empty(): return 1.0
	var collider=hit.get("collider")
	if collider is Area3D and collider.has_meta("actor"):
		var other=collider.get_meta("actor")
		if other is NestActor and other!=self and other.alive and (other.faction!=faction or game.mode==1):
			return float(game.prefs.values.hover_sensitivity_multiplier)
	return 1.0
func muzzle_position() -> Vector3:
	if not weapons.is_empty() and weapons[slot].kind=="rocket":return eye.global_position+global_transform.basis*Vector3(.24,-.18,-.85)
	if not weapons.is_empty() and weapons[slot].kind in ["plasma_br","plasma_auto","plasma_smg","plasma_sniper"]:return eye.global_position+global_transform.basis*Vector3(.24,-.18,-.95)
	return eye.global_position+global_transform.basis*Vector3(0.24,-0.18,-0.55)
func resolve_shot_aim(max_range: float) -> Dictionary:
	var direction=aim_direction()
	var origin=camera.global_position if local_player and camera!=null else eye.global_position
	# Preserve the immediate local view, but do not permit a correction/interpolated
	# camera that crossed solid cover to put the shot origin beyond that cover.
	var guard=game.trace(eye.global_position,origin,1,ray_exclusions())
	if not guard.is_empty():origin=guard.position+guard.normal*.002
	var hit=game.trace(origin,origin+direction*max_range,13,ray_exclusions())
	var point: Vector3=hit.position if not hit.is_empty() else origin+direction*max_range
	return {"origin":origin,"direction":direction,"aim_point":point}
func cone_direction(direction: Vector3, half_angle: float, rng: RandomNumberGenerator=null) -> Vector3:
	var z=lerpf(cos(half_angle),1,rng.randf() if rng!=null else randf())
	var a=(rng.randf() if rng!=null else randf())*TAU
	var side=direction.cross(Vector3.UP).normalized()
	if side.length()<0.1: side=Vector3.RIGHT
	var up=side.cross(direction).normalized()
	return (direction*z+(side*cos(a)+up*sin(a))*sqrt(1-z*z)).normalized()
# Durability modifies only the energy spent by gun hits in shield layers.
# Converting absorbed shield points back to incoming damage preserves health spill.
func shield_hit_durability(region: String, category: String) -> float:
	if damage_model()!="naki" or category!="bullet": return 1.0
	return float(traits.settings.naki_head_shield_strength if region=="head" else traits.settings.naki_body_shield_strength)
func take_damage(amount: float, region: String, category: String, precision: bool, attacker: NestActor, event_id: int, damage_origin: Vector3=Vector3.INF, weapon_kind: String="", hit_distance: float=0, contact_point: Vector3=Vector3.INF) -> bool:
	if game.campaign!=null and game.campaign.active and not game.campaign.can_damage(self):return false
	if not alive or game.finished or game.break_until>game.now or (attacker==self and not traits.self_damage): return false
	if is_instance_valid(attacker) and attacker!=self and attacker.faction==faction and game.mode!=1 and not tuning.friendly_fire: return false
	if game.is_client():
		if is_instance_valid(attacker) and attacker.local_player: game.report_local_hit(self,region,category,amount,event_id,hit_distance)
		return false
	var key="%d:%d:%d"%[event_id,get_instance_id(),life_id]
	if game.damage_events.has(key): return false
	game.damage_events[key]=true
	var old_shield=shield; var old_over=overshield; var old_health=health
	var before={"shield":shield,"over":overshield,"health":health,"armor":armor,"helmet":helmet_hp}
	var config=NestWeaponCatalog.for_kind(weapon_kind)
	# Every firearm uses one authoritative base hit, with exactly 2x for headshots.
	# Defense and explicit game-type modifiers are applied after this shared rule.
	if category=="bullet":amount=NestGunDamage.resolve(config,amount,region,hit_distance,game)
	amount*=game.game_type.weapon_damage_scale(weapon_kind)
	amount*=traits.damage_received_percent/traits.damage_resistance_percent
	if category=="melee":amount*=traits.melee_damage_percent/100.0
	elif category in ["explosion","heavy"]:amount*=traits.explosive_damage_percent/100.0
	if is_instance_valid(attacker): amount*=attacker.traits.damage_dealt_percent/100.0
	if amount<=0:return false
	last_damage=game.now
	last_damage_weapon=weapon_kind; last_damage_region=region
	if damage_origin==Vector3.INF and is_instance_valid(attacker): damage_origin=attacker.eye.global_position
	last_damage_origin=damage_origin;last_impact_point=contact_point
	if damage_origin.is_finite():
		while not directional_hits.is_empty() and (directional_hits.size()>=6 or game.now-directional_hits[0].w>1): directional_hits.pop_front()
		directional_hits.append(Vector4(damage_origin.x,damage_origin.y,damage_origin.z,game.now))
	if is_instance_valid(attacker) and attacker!=self: contributors[attacker.get_instance_id()]={"actor":attacker,"at":game.now}
	var durability=maxf(.1,shield_hit_durability(region,category))
	var head_health_scale=float(traits.settings.annu_body_health)/float(traits.settings.annu_head_health) if damage_model()=="annu" and region=="head" else 1.0
	var instant=false
	var sword_kill=category=="melee" and weapon_kind=="plasma_sword" and is_instance_valid(attacker) and attacker.character==0
	instant=instant or sword_kill
	if sword_kill:shield=0;overshield=0;armor=0;helmet_hp=0
	if instant: health=0
	elif overshield>0:
		var over=minf(amount/durability,overshield); overshield-=over; amount=maxf(0.0,amount-over*durability)
	if not instant and damage_model()=="naki":
		var absorbed=minf(shield,amount/durability)
		shield-=absorbed
		# Preserve excess energy when a hit breaks either shield layer.
		health-=maxf(0.0,amount-absorbed*durability)
	elif not instant:
		var protected=helmet_hp>0 if region=="head" else armor>0
		var reduction=float(traits.helmet_absorption_percent if region=="head" else traits.armor_absorption_percent)/100.0
		var prevented=minf(helmet_hp if region=="head" else armor,amount*reduction) if protected else 0.0
		if region=="head": helmet_hp-=prevented
		else: armor-=prevented
		var health_damage=(amount-prevented)*head_health_scale
		health-=health_damage
	if damage_model()=="naki" and old_shield>0 and shield<=0:
		body_phase=true; hit_stun_until=game.now+float(game.damage_rules.shield_break_stun); burst_left=0
	health=0.0 if health<.0001 else health; shield=maxf(shield,0); armor=maxf(armor,0)
	var actual_damage=maxf(0.0,old_shield-shield)+maxf(0.0,old_over-overshield)+maxf(0.0,old_health-health)
	if actual_damage>0.0 and traits.descope_on_damage:
		cancel_scope()
		if camera!=null: camera.fov=game.prefs.values.fov
	record_damage_exchange(attacker,before,event_id,category,region)
	record_damage_visual(old_shield,old_over,old_health)
	if combat_audio!=null: combat_audio.on_damage(before,region,category,damage_fx_seq)
	if game.network_active and game.multiplayer.is_server(): game.damage_audio_event.rpc(net_id,before,region,category,damage_fx_seq,life_id,game.match_session,game.round_number,health,shield,armor,overshield,helmet_hp)
	if local_player: game.hurt_until=game.now+0.22
	if is_instance_valid(attacker) and attacker.local_player: game.hit_until=game.now+0.13
	if health<=0: die(attacker,"headshot" if region=="head" and category=="bullet" else category)
	if is_instance_valid(attacker) and attacker.local_player: game.audio.play_sound("headshot_kill" if not alive and region=="head" and category=="bullet" else "kill_confirm" if not alive else "hit_head" if region=="head" else "hit_body",global_position)
	if game.damage_rules.damage_debug: print("[HIT_ZONE] ","HEAD" if region=="head" else "BODY"," / ",weapon_kind," / ",hit_distance," m")
	return true
func combat_key() -> String:
	return str(net_id if game.network_active else get_instance_id())+":"+str(life_id)
func record_damage_exchange(attacker: NestActor, before: Dictionary, event_id: int=0, category: String="bullet", region: String="torso") -> void:
	if not is_instance_valid(attacker) or attacker==self: return
	var actual=maxf(0,float(before.health)-health)+maxf(0,float(before.shield)-shield)+maxf(0,float(before.over)-overshield)+maxf(0,float(before.armor)-armor)+maxf(0,float(before.helmet)-helmet_hp)
	if actual<=.0001: return
	var capacity=tuning.health_capacity+(tuning.shield_capacity if damage_model()=="naki" else 0.0)
	var progress=(maxf(0,float(before.health)-health)+maxf(0,float(before.shield)-shield))/capacity*100.0
	var incoming: Dictionary=damage_received.get(attacker.combat_key(),{"damage":0.0,"hits":0,"normalized":0.0})
	var shot_key=str(event_id/16 if category in ["bullet","heavy"] else event_id)+":"+("gun" if category in ["bullet","heavy"] or (category=="explosion" and last_damage_weapon=="rocket") else category)
	if category=="explosion" and last_damage_weapon=="rocket":shot_key=str(event_id/16)+":gun"
	var contacts: Dictionary=incoming.get("contacts",{})
	if not contacts.has(shot_key):
		if category in ["bullet","heavy"] or (category=="explosion" and last_damage_weapon=="rocket"):incoming.shots=int(incoming.get("shots",0))+1
		contacts[shot_key]=true
	if category in ["bullet","heavy"]:
		var zone="head_hits" if region=="head" else "body_hits"
		incoming[zone]=int(incoming.get(zone,0))+1
	incoming.contacts=contacts
	incoming.damage+=actual; incoming.normalized=minf(100,float(incoming.get("normalized",0))+progress); incoming.hits+=1; damage_received[attacker.combat_key()]=incoming
	var outgoing: Dictionary=attacker.damage_given.get(combat_key(),{"damage":0.0,"hits":0,"normalized":0.0})
	outgoing.head_hits=incoming.get("head_hits",0);outgoing.body_hits=incoming.get("body_hits",0);outgoing.shots=incoming.get("shots",0);outgoing.damage+=actual; outgoing.normalized=minf(100,float(outgoing.get("normalized",0))+progress); outgoing.hits+=1; attacker.damage_given[combat_key()]=outgoing
func make_death_recap(attacker: NestActor, reason: String) -> Dictionary:
	if not is_instance_valid(attacker) or attacker==self: return {"environment":true,"reason":reason}
	var key=attacker.combat_key()
	var taken: Dictionary=damage_received.get(key,{"damage":0.0,"hits":0,"shots":0}).duplicate();taken.erase("contacts")
	var given: Dictionary=damage_given.get(key,{"damage":0.0,"hits":0,"shots":0}).duplicate();given.erase("contacts")
	var category="melee" if reason=="melee" else "explosion" if reason=="explosion" else "direct impact" if reason=="heavy" else "headshot" if reason=="headshot" else "head" if last_damage_region=="head" else "body"
	var config=NestWeaponCatalog.for_kind(last_damage_weapon)
	var weapon="Knife" if reason=="melee" else str(config.get("title",{"frag_grenade":"Frag Grenade","plasma_grenade":"Sticky Grenade"}.get(last_damage_weapon,"Unknown weapon")))
	return {"killer":attacker.username,"taken":taken,"given":given,"environment":false,"final_weapon":weapon,"final_kind":last_damage_weapon if reason!="melee" else "melee","final_hit":category,"reason":reason}
func death_recap_text() -> String:
	if death_recap.is_empty(): return ""
	if death_recap.get("environment",false): return "Eliminated: "+str(death_recap.reason)
	return "Killed by %s\nDamage taken: %d/100 (%d hits)  ·  Damage given: %d/100 (%d hits)"%[death_recap.killer,roundi(float(death_recap.taken.get("normalized",0))),death_recap.taken.hits,roundi(float(death_recap.given.get("normalized",0))),death_recap.given.hits]
func death_recap_hud_text() -> String:
	if death_recap.is_empty():return ""
	if death_recap.get("environment",false):return "[color=#e27b7b]Eliminated: "+str(death_recap.get("reason","Environment")).replace("[","[lb]")+"[/color]"
	var taken: Dictionary=death_recap.get("taken",{});var given: Dictionary=death_recap.get("given",{})
	var killer=str(death_recap.get("killer","Unknown")).replace("[","[lb]")
	var weapon=str(death_recap.get("final_weapon","Unknown weapon")).replace("[","[lb]")
	var finish=str(death_recap.get("final_hit","body")).capitalize()
	return "[b][color=#ff5656]Killed by %s[/color][/b]\n[color=#8fd6a1]You dealt: %d/100 · %d shots hit / %d hits\nHead: %d · Body: %d[/color]\n[color=#f28c8c]You took: %d/100 · %d shots hit / %d hits\nHead: %d · Body: %d[/color]\n[color=#e8c984]Final: %s · %s[/color]"%[killer,roundi(float(given.get("normalized",0))),int(given.get("shots",0)),int(given.get("hits",0)),int(given.get("head_hits",0)),int(given.get("body_hits",0)),roundi(float(taken.get("normalized",0))),int(taken.get("shots",0)),int(taken.get("hits",0)),int(taken.get("head_hits",0)),int(taken.get("body_hits",0)),weapon,finish]
func reset_damage_visual() -> void:
	damage_fx_seq=0; shield_flash_at=-100; shield_break_at=-100; health_flash_at=-100
	shield_flash_strength=0; health_flash_strength=0; shield_flash_over=false; flash_until=-100
	directional_hits.clear()
func record_damage_visual(old_shield: float, old_over: float, old_health: float) -> void:
	damage_fx_seq+=1
	var energy_before=old_over+(old_shield if damage_model()=="naki" else 0.0)
	var energy_after=overshield+(shield if damage_model()=="naki" else 0.0)
	if energy_before>energy_after:
		shield_flash_at=game.now; shield_flash_strength=clampf((energy_before-energy_after)/40.0,.35,1)
		shield_flash_over=old_over>overshield
		if energy_after<=0: shield_break_at=game.now
	if old_health>health:
		health_flash_at=game.now; health_flash_strength=clampf((old_health-health)/35.0,.25,1)
func die(attacker: NestActor, reason: String) -> void:
	if not alive: return
	if game.campaign!=null and game.campaign.active and game.campaign.down(self):return
	if game.nu!=null:game.nu.finish(self)
	game.spawn_death_body(self,reason)
	reset_aim()
	death_recap=make_death_recap(attacker,reason)
	if local_player: game.display_death_recap(self)
	if game.network_active and game.multiplayer.is_server() and remote_peer>1: game.receive_death_recap.rpc_id(remote_peer,net_id,life_id,game.match_session,game.round_number,death_recap)
	game.announcer.record_death(game,self)
	alive=false;
	if nu_perch_area!=null:nu_perch_area.collision_layer=0
	deaths+=1; respawn_at=game.now+tuning.respawn_seconds
	if combat_audio!=null: combat_audio.on_death()
	action_state="dead"; burst_left=0; controlled=Vector3.ZERO; external=Vector3.ZERO
	if carrying: game.drop_bag(self)
	if flag_carry>=0: game.drop_flag(self)
	game.drop_cs_bomb(self)
	for h in hitboxes: h.set_deferred("monitorable",false); h.set_deferred("collision_layer",0)
	capsule.set_deferred("disabled",true)
	model.visible=false
	if is_instance_valid(attacker) and attacker!=self:
		attacker.kills+=1
		for data in contributors.values():
			if is_instance_valid(data.actor) and data.actor!=attacker and game.now-data.at<6: data.actor.assists+=1
		game.register_kill(attacker,self,reason)
	if local_player:
		game.interaction_progress=0
		if game.context=="chat": game.close_chat()
func respawn() -> void:
	var safe_spawn=game.choose_spawn(self)
	if not safe_spawn.is_finite():
		placement_retry_at=game.now+.5;alive=false;model.visible=false;capsule.set_deferred("disabled",true);return
	placement_retry_at=0
	regen_anchor_damage=-INF
	nu_used=false;nu_launch_until=0;sword_lunge_at=INF
	if game.nu!=null:game.nu.finish(self)
	tracer_sequence=0;remote_melee_id=-1;melee_contact_at=INF;melee_contact_until=-INF
	refresh_traits()
	game.remote_shot_clocks.erase(remote_peer)
	bomb_equipped=false;bomb_drop_at=0;melee_ready_at=0
	alive=true; life_id+=1; health=tuning.health_capacity; shield=tuning.shield_capacity if damage_model()=="naki" else 0.0; armor=tuning.armor_capacity; helmet_hp=float(traits.settings.annu_head_armor)*traits.helmet_strength_percent/100.0; overshield=0; cloak_deadline=0; body_phase=false; hit_stun_until=0
	last_damage=-100; contributors.clear(); damage_received.clear(); damage_given.clear(); death_recap.clear(); cannon_takeoff=false; carrying=false; bag_id=-1; controlled=Vector3.ZERO; external=Vector3.ZERO; velocity=Vector3.ZERO
	reset_damage_visual()
	net_position_error=Vector3.ZERO;pending_shots.clear();accepted_shots=0;remote_shot_id=-1;last_shot_frame=-1;shell_remaining=0;shell_next=INF;net_jump=false;net_jump_until=-INF;net_jump_sequence=-1;jump_sequence=0
	# The command stream itself continues across lives; only predicted state resets.
	cmd_history.clear();pending_reconcile={};view_correction=Vector3.ZERO;server_jump_buffer=0;cmd_template={};snap_buffer.clear();lunge_ticks=0;lunge_velocity=Vector3.ZERO
	capsule.set_deferred("disabled",false)
	for h in hitboxes: h.set_deferred("collision_layer",4); h.set_deferred("monitorable",true)
	reset_crouch()
	global_position=safe_spawn
	rotation.y=-PI/2 if is_attacker() else PI/2
	eye.rotation.x=0
	reset_loadout(); bot_route.clear(); bot_repath=0; bot_target_ready=0
	bot_fire=game.now+float(posmod(absi(net_id),13))*float(game.bot_difficulty_rules.get(game.bot_difficulty,game.bot_difficulty_rules.normal).think_seconds)/13.0
	if bot_movement!=null: bot_movement.reset()
	if local_player: game.clear_held_input()
	reset_physics_interpolation()
func melee_targets(max_range: float, cone_deg: float) -> NestActor:
	# Best enemy in reach and in a forgiving cone, preferring the aim centre.
	var best: NestActor
	var best_score=-INF
	var aim=aim_direction()
	for other in game.actors:
		if other==self or not other.alive or (other.faction==faction and game.mode!=1) or other.cloak_deadline>game.now: continue
		var chest=other.global_position+Vector3(0,1.25*SIZE*(CROUCH_HEIGHT/STAND_HEIGHT if other.crouched and not other.air_duck else 1.0),0)
		var difference=chest-eye.global_position
		if difference.length()>max_range or difference.normalized().dot(aim)<cos(deg_to_rad(cone_deg)): continue
		if not game.trace(eye.global_position,chest,1,ray_exclusions()).is_empty(): continue
		var score=difference.normalized().dot(aim)-difference.length()*0.1
		if score>best_score: best=other; best_score=score
	return best
func start_lunge(displacement: Vector3) -> void:
	# A short, predicted speed boost (part of movement state, so it replays).
	var flat=Vector3(displacement.x,0,displacement.z)
	if flat.length()<.01: return
	lunge_velocity=flat/(LUNGE_TICKS*NET_TICK); lunge_ticks=LUNGE_TICKS
func melee_lunge() -> Vector3:
	var rules: Dictionary=game.damage_rules
	var best=melee_targets(float(rules.melee_range_m),float(rules.melee_cone_deg))
	var length=float(rules.melee_max_lunge_m)
	var direction=aim_direction()
	if is_instance_valid(best):
		direction=best.global_position-global_position
		length=clampf(Vector2(direction.x,direction.z).length()-float(rules.melee_lunge_stop_m),0,length)
	var flat=Vector3(direction.x,0,direction.z)
	return flat.normalized()*length if flat.length()>.01 else Vector3.ZERO
func schedule_melee_contact(event_id: int) -> void:
	melee_event_id=event_id;melee_life=life_id;melee_round=game.round_number;melee_session=game.match_session
	melee_contact_at=game.now+(sword_draw+.18/melee_speed() if character==0 else float(game.damage_rules.melee_windup_seconds)/1.15)
	# Contact remains active through the short lunge, until one legal target is hit.
	melee_contact_until=game.now+(sword_draw+.7/melee_speed() if character==0 else maxf(float(game.damage_rules.melee_windup_seconds),float(game.damage_rules.melee_lunge_seconds)))
func advance_melee_contact() -> void:
	if not is_finite(melee_contact_at):return
	if not alive or action_state!="melee" or life_id!=melee_life or game.round_number!=melee_round or game.match_session!=melee_session or not game.running or game.finished or game.break_until>game.now or game.now>melee_contact_until+NET_TICK:
		melee_contact_at=INF;return
	if game.now+.000001<melee_contact_at:return
	if game.is_client():melee_contact_at=INF;return
	var victim=melee_targets(float(game.damage_rules.melee_hit_range_m)+EYE_HEIGHT*.25*float(game.damage_rules.get("melee_reach_padding_scale",1.0)),float(game.damage_rules.melee_cone_deg)+10)
	if not is_instance_valid(victim):return
	melee_contact_at=INF
	if victim.take_damage(100000.0 if character==0 else float(game.damage_rules.melee_damage),"torso","melee",false,self,melee_event_id,eye.global_position,"plasma_sword" if character==0 else "knife"):
		if game.network_active and game.multiplayer.is_server() and remote_peer>1:game.confirm_hit.rpc_id(remote_peer,"torso",not victim.alive,victim.global_position,game.match_session)
func melee() -> void:
	if bomb_equipped or game.now<melee_ready_at:return
	if not alive or not game.running or game.finished or game.break_until>game.now or action_state!="ready" or game.now+.000001<cooldown or game.nu.blocked(self) or game.is_interacting(self):return
	cancel_scope()
	var attack_id=game.next_event()*16
	var lunge=melee_lunge()
	if game.is_client():game.authorize_melee.rpc_id(1,attack_id,life_id,game.round_number,game.match_session,game.command_sequence,lunge)
	begin_melee(attack_id,lunge)
	game.sound("melee",global_position,local_player)
	if presentation!=null:
		presentation.update_view_weapon(Vector2(velocity.x,velocity.z).length());presentation.pose_upper_body()
func queue_auto_reload() -> void:
	if ammo[slot]==0 and (reserve[slot]>0 or traits.infinite_ammo>0):auto_reload_slot=slot;auto_reload_at=game.now+.10
func grenade_release_origin() -> Vector3:
	return eye.global_position-global_transform.basis.x*.18-Vector3.UP*.12
func throw_progress() -> float:
	return clampf((game.now-throw_started)/.75,0,1) if action_state=="throwing" else -1.0
func throw_grenade() -> void:
	if bomb_equipped:return
	if action_state!="ready" or grenades[grenade_kind]<=0 or game.now+.000001<cooldown or game.is_interacting(self):return
	cancel_scope();game.audio.play_sound(("frag_grenade" if grenade_kind==0 else "plasma_grenade")+"_arm",global_position)
	if game.is_client():game.request_remote_action("throw_begin",grenade_kind)
	action_state="throwing";action_until=game.now+.75;burst_left=0
	throw_started=game.now;throw_kind=grenade_kind;throw_pending_kind=grenade_kind;throw_release=game.now+.20;throw_life=life_id
func release_thrown_grenade() -> void:
	var selected=throw_pending_kind;throw_pending_kind=-1;throw_release=INF
	if selected<0 or not game.running or not alive or throw_life!=life_id or action_state!="throwing" or grenades[selected]<=0:return
	grenades[selected]-=1
	var grenade_id=game.next_event()*16
	if game.is_client():game.authorize_grenade.rpc_id(1,grenade_id,life_id,game.round_number,selected,grenade_release_origin(),aim_direction(),velocity,game.match_session,game.command_sequence)
	game.launch_grenade(self,selected,false,grenade_id,grenade_release_origin())
func bot_intent(delta: float) -> Dictionary:
	if game.campaign!=null and game.campaign.active:return game.campaign.bot_intent(self,delta)
	if game.game_type.bots_stand_still:
		if not game.game_type.bots_dont_shoot:bot_stationary_fire(delta)
		return {"move":Vector2.ZERO,"jump":false,"crouch":0}
	var rules: Dictionary=game.bot_difficulty_rules.get(game.bot_difficulty,game.bot_difficulty_rules.normal)
	if game.now>bot_fire:
		bot_fire=game.now+float(rules.think_seconds)
		var previous=target
		target=game.nearest_bot_enemy(self)
		if target!=previous: bot_target_ready=game.now+float(rules.reaction_seconds)
		if is_instance_valid(target):
			var error=float(rules.aim_error_m)
			bot_aim_offset=Vector3(randf_range(-error,error),1.72*SIZE if randf()<float(rules.headshot_chance) else 1.15*SIZE+randf_range(-error*.5,error*.5),randf_range(-error,error))
			seen[target.get_instance_id()]={"position":target.global_position,"until":game.now+tuning.spot_memory}
			if ammo[slot]==0: reload_weapon()
			elif not game.game_type.bots_dont_shoot and game.now>=bot_target_ready and randf()<float(rules.fire_chance):
				var offset=target.global_position+bot_aim_offset-eye.global_position
				var projectile_speed=float(weapons[slot].speed)
				if projectile_speed>0:offset+=target.velocity*minf(.35,offset.length()/projectile_speed)
				if aim_direction().dot(offset.normalized())>cos(deg_to_rad(5)) and not game.bot_progress.has(get_instance_id()): fire_trigger()
	if is_instance_valid(target):
		var offset=target.global_position+bot_aim_offset-eye.global_position
		var projectile_speed=float(weapons[slot].speed)
		if projectile_speed>0:offset+=target.velocity*minf(.35,offset.length()/projectile_speed)
		var blend=1-exp(-delta*float(rules.tracking_rate))
		rotation.y=lerp_angle(rotation.y,atan2(-offset.x,-offset.z),blend)
		eye.rotation.x=lerpf(eye.rotation.x,atan2(offset.y,Vector2(offset.x,offset.z).length()),blend)
	else: eye.rotation.x=lerpf(eye.rotation.x,0,1-exp(-delta*5))
	if bot_movement==null: bot_movement=NestBotMovement.new(self)
	var intent=bot_movement.update(delta)
	game.bot_interact(self,delta)
	return intent
func locomotion_grounded() -> bool:
	var motorcycle=campaign_motorcycle_controller()
	if motorcycle!=null and motorcycle.handles(self):return false
	return net_grounded if game.is_client() and not local_player else is_on_floor() and controlled.y<=.01
func update_visual(delta: float) -> void:
	if belt_sword!=null:belt_sword.visible=alive and (weapons.is_empty() or weapons[slot].kind!="plasma_sword") and action_state!="melee"
	if perched_nu!=null:perched_nu.visible=alive and not nu_used and game.game_type.nu_enabled
	refresh_model_visibility()
	update_weapon_art()
	if presentation!=null: presentation.update(delta)
	if combat_audio!=null: combat_audio.update(delta)
	if carried_visual!=null: carried_visual.visible=carrying
	if animation==null: return
	var wanted="idle"
	if not alive: wanted="death"
	elif not locomotion_grounded(): wanted="jump_air"
	else:
		var local_velocity=global_transform.basis.inverse()*velocity
		if Vector2(local_velocity.x,local_velocity.z).length()>0.2:
			if absf(local_velocity.x)>absf(local_velocity.z): wanted="strafe_right" if local_velocity.x>0 else "strafe_left"
			else: wanted="walk_forward" if local_velocity.z<0 else "walk_backward"
		if crouched: wanted="crouch_idle" if wanted=="idle" else "crouch_"+wanted.trim_prefix("walk_")
	if not clips.has(wanted): wanted="idle"
	var motorcycle=campaign_motorcycle_controller()
	if motorcycle!=null and motorcycle.handles(self) and clips.has("crouch_idle"):wanted="crouch_idle"
	if clips.has(wanted) and animation.current_animation!=clips[wanted]: animation.play(clips[wanted],0.0 if wanted=="jump_air" else 0.12)
	animation.advance(delta)
	if presentation!=null: presentation.pose_upper_body()
	if motorcycle!=null:motorcycle.pose_rider(self)
	if weapon_view!=null and is_motorcycle_rider():weapon_view.visible=false
	if skeleton!=null:
		# Same authoritative bone poses, expressed directly in the hitbox parent's space.
		var model_to_skeleton=model.global_transform.affine_inverse()*skeleton.global_transform
		for area in hitboxes:
			var data=pose_offsets.get(area.get_instance_id())
			if data!=null:area.transform=model_to_skeleton*skeleton.get_bone_global_pose(data.bone)*data.offset
func build_attachments() -> void:
	if skeleton==null: return
	var k=game.arena.kit
	var hand=BoneAttachment3D.new(); hand.bone_name="hand_r"; skeleton.add_child(hand)
	remote_weapon=Node3D.new(); hand.add_child(remote_weapon)
	var rest=skeleton.get_bone_global_rest(skeleton.find_bone("hand_r"))
	remote_weapon.transform=rest.affine_inverse()*Transform3D(Basis(),Vector3(0.43,0.845,-0.20))
	remote_art=NestWeaponArt.create("rifle",character); remote_weapon.add_child(remote_art)
	var belt=BoneAttachment3D.new(); belt.bone_name="pelvis"; skeleton.add_child(belt)
	carried_visual=Node3D.new(); belt.add_child(carried_visual)
	carried_visual.transform=skeleton.get_bone_global_rest(skeleton.find_bone("pelvis")).affine_inverse()*Transform3D(Basis(),Vector3(0.28,0.90,0.11))
	k.box(carried_visual,Vector3.ZERO,Vector3(0.24,0.27,0.20),k.gold)
	carried_visual.visible=false

func update_weapon_art() -> void:
	if weapons.is_empty(): return
	var kind=weapons[slot].kind
	if kind==art_kind: return
	art_kind=kind
	if weapon_view!=null:
		if weapon_art!=null: weapon_art.queue_free()
		weapon_art=NestWeaponArt.create(kind,character); weapon_view.add_child(weapon_art);NestRigidBatch.build(weapon_art)
		muzzle_flash.position.z=-.39 if kind=="plasma_pistol" else -.15 if kind=="sidearm" else -.65 if kind=="sniper" else -.52 if kind=="ak47" else -.39 if kind=="rocket" else -.47 if kind=="burst_scoped" else -.50 if kind in ["plasma_br","plasma_auto"] else -.43
	if remote_weapon!=null:
		if remote_art!=null:
			remote_art.get_parent().remove_child(remote_art);remote_art.queue_free()
		remote_art=NestWeaponArt.create(kind,character); remote_weapon.add_child(remote_art);NestRigidBatch.build(remote_art)

	NestGunFeedback.prepare(weapon_art,kind);NestGunFeedback.prepare(remote_art,kind)
	cache_cloak_meshes();refresh_model_visibility()

func reset_ak_spray() -> void:
	ak_spray_count=0;ak_spray_last=-INF;ak_spray_event=-1;ak_spray_command_clock=false;ak_spray_last_arrival=-INF
	if not weapons.is_empty() and weapons[slot].kind=="ak47":accuracy_penalty=0
func prepare_ak_shot(event_id: int, shot_clock: float=-INF, command_clock: bool=false) -> void:
	if weapons[slot].kind!="ak47" or event_id==ak_spray_event:return
	var stamp=shot_clock if is_finite(shot_clock) else game.now
	var elapsed=stamp-ak_spray_last if command_clock==ak_spray_command_clock else game.now-ak_spray_last_arrival
	if elapsed>=NestAKSpray.RESET_SECONDS-.000001:reset_ak_spray()
	elif command_clock==ak_spray_command_clock:stamp=maxf(stamp,ak_spray_last)
	# Changing between command and arrival timing must never grant a free reset.
	ak_spray_last_arrival=game.now
	ak_spray_command_clock=command_clock;ak_spray_count+=1;ak_spray_last=stamp;ak_spray_event=event_id
	accuracy_penalty=NestAKSpray.cone(ak_spray_count)

func can_jump_from_support() -> bool:
	# Called for jump attempts only. A portion of the foot footprint is enough;
	# no upward/sideways wall contacts or distant ground can create an air jump.
	if not alive or cannon_takeoff or controlled.y>.01 or external.y>.5:return false
	if is_on_floor():return true
	var center=global_position+Vector3.UP*(TUCK if air_duck else 0.0)
	var excludes=ray_exclusions()
	for index in range(9):
		var offset=Vector3.ZERO
		if index>0:
			var angle=float(index-1)*TAU/8.0
			offset=Vector3(cos(angle),0,sin(angle))*BODY_RADIUS*.94
		var hit=game.trace(center+offset+Vector3.UP*.18,center+offset-Vector3.UP*.16,1,excludes)
		if not hit.is_empty() and hit.normal.y>=cos(floor_max_angle) and absf(hit.position.y-center.y)<=.18:return true
	return false

func bot_stationary_fire(delta: float) -> void:
	var rules: Dictionary=game.bot_difficulty_rules.get(game.bot_difficulty,game.bot_difficulty_rules.normal)
	if game.now>bot_fire:
		bot_fire=game.now+float(rules.think_seconds)
		var previous=target
		target=game.nearest_bot_enemy(self)
		if target!=previous: bot_target_ready=game.now+float(rules.reaction_seconds)
		if is_instance_valid(target):
			var error=float(rules.aim_error_m)
			bot_aim_offset=Vector3(randf_range(-error,error),1.72*SIZE if randf()<float(rules.headshot_chance) else 1.15*SIZE+randf_range(-error*.5,error*.5),randf_range(-error,error))
			seen[target.get_instance_id()]={"position":target.global_position,"until":game.now+tuning.spot_memory}
			if ammo[slot]==0: reload_weapon()
			elif not game.game_type.bots_dont_shoot and game.now>=bot_target_ready and randf()<float(rules.fire_chance):
				var offset=target.global_position+bot_aim_offset-eye.global_position
				if aim_direction().dot(offset.normalized())>cos(deg_to_rad(5)) and not game.bot_progress.has(get_instance_id()): fire_trigger()
	if is_instance_valid(target):
		var offset=target.global_position+bot_aim_offset-eye.global_position
		var projectile_speed=float(weapons[slot].speed)
		if projectile_speed>0:offset+=target.velocity*minf(.35,offset.length()/projectile_speed)
		var blend=1-exp(-delta*float(rules.tracking_rate))
		rotation.y=lerp_angle(rotation.y,atan2(-offset.x,-offset.z),blend)
		eye.rotation.x=lerpf(eye.rotation.x,atan2(offset.y,Vector2(offset.x,offset.z).length()),blend)
	else: eye.rotation.x=lerpf(eye.rotation.x,0,1-exp(-delta*5))

func wield_sword() -> void:
	if bomb_equipped:return
	if character!=0 or not alive or game.nu.blocked(self) or action_state!="ready" or game.now<cooldown:return
	var index=-1
	for i in range(weapons.size()):
		if weapons[i].kind=="plasma_sword":index=i
	if index<0 or slot==index:return
	if game.is_client():game.request_remote_action("sword")
	reset_aim();slot=index;action_state="switching";action_until=game.now+.6/melee_speed();burst_left=0;update_weapon_art()
func sword_trigger() -> bool:
	if not alive or not game.running or game.finished or game.break_until>game.now or action_state!="ready" or game.now<cooldown or game.is_interacting(self):return false
	melee();return action_state=="melee"
func begin_melee(event_id: int, lunge: Vector3) -> void:
	melee_event_id=event_id;melee_ready_at=game.now+1.8
	sword_draw=.6/melee_speed() if character==0 and weapons[slot].kind!="plasma_sword" else 0.0
	var duration=sword_draw+.7/melee_speed() if character==0 else float(game.damage_rules.melee_cooldown_seconds)/1.15
	action_state="melee";action_until=game.now+duration;cooldown=action_until;burst_left=0
	if character==0:sword_lunge=lunge;sword_lunge_at=game.now+sword_draw
	else:start_lunge(lunge)
	if not game.is_client():schedule_melee_contact(event_id)
func sword_blade_strength() -> float:
	if character!=0:return 0
	if action_state=="switching" and weapons[slot].kind=="plasma_sword":return smoothstep(.45,.6,.6-(action_until-game.now)*melee_speed())
	if action_state=="melee":
		var elapsed=(sword_draw+.7/melee_speed()-(action_until-game.now))*melee_speed()
		return smoothstep(maxf(0,sword_draw*melee_speed()-.15),maxf(.01,sword_draw*melee_speed()),elapsed)
	return 1.0 if weapons[slot].kind=="plasma_sword" else 0.0

func melee_speed() -> float:
	return float(game.damage_rules.get("melee_animation_speed_multiplier",1.0))*1.15

func waist_position() -> Vector3:
	if skeleton!=null:
		var bone=skeleton.find_bone("spine_01")
		if bone>=0:return skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin
	return global_position+Vector3.UP*.99*SIZE
func below_waist(region: String, point: Vector3) -> bool:
	if region=="head":return false
	if point.is_finite():
		if game.rewind_active:
			var pose=game.aim_pose_of(self)
			if pose.has("waist"):return point.y<pose.waist.y
		return point.y<waist_position().y
	return region=="leg"
