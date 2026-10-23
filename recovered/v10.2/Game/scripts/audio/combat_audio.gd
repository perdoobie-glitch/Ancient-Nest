class_name NestCombatAudio
extends Node
@export_range(0,1,.01) var jump_gain: float = .20
@export_range(0,1,.01) var landing_gain: float = .20
var actor
var manager: NestAudioManager
var config: Dictionary
var timeline: AnimationPlayer
var reload_key: String = ""
var reload_empty: bool = false
var last_slot: int = -1
var last_kind: String = ""
var last_life: int = -1
var last_damage_seq: int = -1
var death_life: int = -1
var fire_counter: int = 0
var last_fire: float = -INF
var handle_at: float = INF
var handle_kind: String = ""
var last_position: Vector3
var step_distance: float = 0
var was_grounded: bool = true
var last_vertical_speed: float = 0
var last_landing_sequence: int = 0
var second_foot_in: float = -1
var landing_foot_cues: int = 0
var last_shield: float = 100
var recharging: bool = false
var loops: Dictionary = {}
var shell_cues: Array[Dictionary] = []

func _ready() -> void:
	manager=actor.game.audio; config=actor.game.audio_config
	last_position=actor.global_position; last_shield=actor.shield
	timeline=AnimationPlayer.new(); timeline.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	timeline.callback_mode_method=AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	add_child(timeline)

func group(suffix: String) -> String:
	return str(actor.get_instance_id())+":"+str(actor.life_id)+":"+suffix
func settings() -> Dictionary:
	return NestWeaponCatalog.for_kind(actor.weapons[actor.slot].kind)
func cue(id: String, suffix: String="action", spatial_override: bool=true) -> Array[Node]:
	if id.is_empty(): return []
	return manager.play_sound(id, actor.eye.global_position, {"group":group(suffix),"spatial":spatial_override,"gain_db":linear_to_db(.2) if actor.local_player and id.begins_with("footstep_") else 0.0})
func weapon_event(key: String, suffix: String="weapon") -> Array[Node]:
	if key=="dry_sound":return manager.play_weapon(actor.weapons[actor.slot],actor.eye.global_position,actor.local_player,group(suffix),"dry")
	return cue(str(settings().get(key,"")),suffix,not actor.local_player)
func equipped() -> void:
	stop_reload()
	manager.stop_group(group("weapon")); fire_counter=0; handle_at=INF
	shell_cues.clear()
	last_slot=actor.slot; last_kind=actor.weapons[actor.slot].kind
	weapon_event("equip_sound","handling")
func on_fire(_first_round: bool) -> void:
	var definition=settings()
	if definition.is_empty(): return
	if actor.game.now-last_fire>=float(definition.interval): fire_counter=0
	manager.play_weapon(actor.weapons[actor.slot],actor.muzzle_position(),actor.local_player,group("weapon"))
	# A shot has one report. No casing, delayed clack or low-ammo layer.
	last_fire=actor.game.now;fire_counter+=1;handle_at=INF;shell_cues.clear()
	if actor.weapons[actor.slot].kind in ["sniper","plasma_sniper"]:
		handle_kind=actor.weapons[actor.slot].kind;handle_at=actor.game.now+actor.fire_interval(actor.weapons[actor.slot].interval)*(.24 if handle_kind=="sniper" else .94)

func start_reload(empty: bool, elapsed: float=0) -> void:
	stop_reload(); reload_empty=empty
	var definition=settings()
	if definition.is_empty(): return
	reload_key=group("reload")
	var animation=Animation.new(); animation.length=actor.reload_duration
	var track=animation.add_track(Animation.TYPE_METHOD); animation.track_set_path(track,NodePath("."))
	if definition.get("per_shell",false):
		var count=actor.weapons[actor.slot].magazine-actor.ammo[actor.slot] if actor.traits.infinite_ammo>0 else mini(actor.weapons[actor.slot].magazine-actor.ammo[actor.slot],actor.reserve[actor.slot])
		for index in range(count):
			animation.track_insert_key(track,actor.reload_interval((index+.5)*float(definition.shell_seconds)),{"method":"emit_reload_stage","args":[0]})
		if empty: animation.track_insert_key(track,animation.length-actor.reload_interval(float(definition.shell_finish_seconds)*.5),{"method":"emit_reload_stage","args":[1]})
	else:
		for index in range(definition.reload_stages.size()):
			var stage=definition.reload_stages[index]
			if not stage.get("empty_only",false) or empty:
				animation.track_insert_key(track,float(stage.ratio)*animation.length,{"method":"emit_reload_stage","args":[index]})
	if timeline.has_animation_library(""): timeline.remove_animation_library("")
	var library=AnimationLibrary.new(); library.add_animation("reload",animation); timeline.add_animation_library("",library)
	timeline.play("reload"); timeline.seek(elapsed,false)

func emit_reload_stage(index: int) -> void:
	if not actor.alive or actor.action_state!="reloading" or reload_key!=group("reload"): return
	var definition=settings()
	if index>=definition.get("reload_stages",[]).size():
		manager.play_weapon(actor.weapons[actor.slot],actor.eye.global_position,actor.local_player,reload_key,"reload");return
	if index==0 and actor.weapons[actor.slot].reload_sound!=null:
		manager.play_weapon(actor.weapons[actor.slot],actor.eye.global_position,actor.local_player,reload_key,"reload")
	else:cue(definition.reload_stages[index].id,"reload",not actor.local_player)

func stop_reload() -> void:
	if timeline!=null: timeline.stop()
	if manager!=null and not reload_key.is_empty(): manager.stop_group(reload_key)
	reload_key=""

func on_damage(before: Dictionary, region: String, category: String, sequence: int) -> void:
	if sequence<=last_damage_seq: return
	last_damage_seq=sequence
	var local=actor.local_player
	var health_loss=float(before.health)-actor.health
	if actor.damage_model()=="naki":
		var energy_loss=float(before.shield)+float(before.over)-actor.shield-actor.overshield
		if energy_loss>0:
			cue("naki_shield_hit_heavy" if energy_loss>=float(config.heavy_hit_damage) else "naki_shield_hit_light","damage",not local)
			cue("shield_glow_on_hit","damage",not local)
			if actor.shield+actor.overshield<=0:
				cue("naki_shield_break","damage",not local); cue("body_phase_start","damage",not local)
		if health_loss>0: cue("body_hit_shield_down" if actor.shield<=0 else "naki_health_hit","damage",not local)
	else:
		if float(before.over)>actor.overshield: cue("shield_glow_on_hit","damage",not local)
		if health_loss<=0 and float(before.armor)==actor.armor and float(before.get("helmet",0))==actor.helmet_hp: return
		var protected=float(before.get("helmet",0))>actor.helmet_hp if region=="head" else float(before.armor)>actor.armor
		var id="annu_helmet_hit" if region=="head" and protected else "annu_headshot_no_helmet" if region=="head" else "annu_armor_hit" if protected else "annu_body_hit_no_armor"
		cue(id,"damage",not local)
		if config.armor_break_enabled and float(before.armor)>0 and actor.armor<=0: cue("annu_armor_break","damage",not local)
	if category=="melee": cue("melee_hit_shield" if actor.damage_model()=="naki" and float(before.shield)>0 else "melee_hit_armor" if float(before.armor)>actor.armor else "melee_hit_flesh","damage")
	if category=="melee" and actor.health<=0: cue("melee_kill","damage")

func on_death() -> void:
	if death_life==actor.life_id: return
	death_life=actor.life_id; stop_reload(); stop_loops(); handle_at=INF
	manager.stop_group(group("weapon"))
	cue(("naki_death" if actor.damage_model()=="naki" else "annu_death") if actor.local_player else "death_world","death",not actor.local_player)

func on_respawn() -> void:
	stop_reload(); stop_loops(); last_damage_seq=-1; last_shield=actor.shield; recharging=false
	last_position=actor.global_position; step_distance=0; last_life=actor.life_id; was_grounded=true; last_vertical_speed=0
	last_landing_sequence=actor.presentation.landing_sequence if actor.presentation!=null else 0;second_foot_in=-1
	equipped(); cue("respawn","ui",not actor.local_player)

func set_loop(id: String, active: bool, gain: float=0.0) -> void:
	if not manager.playback_enabled:
		if active: loops[id]=null
		else: loops.erase(id)
		return
	if active:
		if not loops.has(id) or not is_instance_valid(loops[id]) or not loops[id].playing or loops[id].get_meta("group","")!=group(id):
			var voices=manager.play_sound(id,Vector3.ZERO,{"spatial":false,"group":group(id),"gain_db":gain})
			if not voices.is_empty(): loops[id]=voices[0]
		elif is_instance_valid(loops[id]): manager.set_voice_gain(loops[id],gain)
	elif loops.has(id):
		manager.stop_group(group(id)); loops.erase(id)
func stop_loops() -> void:
	if manager!=null:
		for id in loops: manager.stop_group(group(id))
	loops.clear()

func update(delta: float) -> void:
	if manager==null: return
	if actor.life_id!=last_life: on_respawn()
	var current_kind=actor.weapons[actor.slot].kind
	if actor.slot!=last_slot or current_kind!=last_kind:
		equipped(); last_slot=actor.slot; last_kind=current_kind
	if not actor.alive:
		on_death(); return
	if actor.action_state=="reloading":
		var elapsed=actor.reload_duration-(actor.action_until-actor.game.now)
		if reload_key.is_empty(): start_reload(actor.reload_was_empty,maxf(0,elapsed))
		if timeline.is_playing(): timeline.advance(maxf(0,elapsed-timeline.current_animation_position))
	elif not reload_key.is_empty(): stop_reload()
	if actor.game.now>=handle_at:
		if current_kind==handle_kind: weapon_event("handling_sound")
		handle_at=INF
	for index in range(shell_cues.size()-1,-1,-1):
		if actor.game.now>=shell_cues[index].at:
			cue(shell_cues[index].id,"foley"); shell_cues.remove_at(index)
	var grounded=actor.net_grounded if actor.game.is_client() and not actor.local_player else actor.is_on_floor()
	var distance=Vector2(actor.global_position.x-last_position.x,actor.global_position.z-last_position.z).length()
	if distance<actor.tuning.ground_speed and grounded and actor.velocity.length()>float(config.min_step_speed):
		step_distance+=distance
		var spacing=float(config.crouch_step_distance if actor.crouched else config.walk_step_distance)
		if step_distance>=spacing:
			step_distance=fmod(step_distance,spacing)
			var hit=actor.game.trace(actor.global_position+Vector3.UP*.15,actor.global_position-Vector3.UP*.3,1)
			cue("footstep_"+actor.game.surface_tag(hit.get("collider"))+ ("_crouch" if actor.crouched else "_walk"),"foley")
	if second_foot_in>=0:
		second_foot_in-=delta
		if second_foot_in<=0:
			second_foot_in=-1
			if grounded:emit_landing_foot(.45)
	if actor.presentation!=null and actor.presentation.landing_sequence!=last_landing_sequence:
		last_landing_sequence=actor.presentation.landing_sequence
		emit_landing_foot(.55);second_foot_in=NestCombatPresentation.SECOND_FOOT_DELAY
	elif was_grounded and not grounded and actor.velocity.y>float(config.jump_min_velocity):
		var hit=actor.game.trace(actor.global_position+Vector3.UP*.2,actor.global_position-Vector3.UP*.6,1)
		surface_movement_cue("footstep_"+actor.game.surface_tag(hit.get("collider"))+"_walk",jump_gain)
	was_grounded=grounded; last_position=actor.global_position; last_vertical_speed=actor.velocity.y
	if actor.local_player:
		var health_low=actor.health/actor.tuning.health_capacity<float(config.health_low_fraction)
		var shield_low=shields_off_warning_active()
		set_loop("naki_shield_low_warning",shield_low,float(config.shield_duck_db) if health_low else 0.0)
		set_loop("naki_health_low" if actor.damage_model()=="naki" else "annu_low_health",health_low,float(config.health_duck_db) if shield_low else 0.0)
		if actor.damage_model()=="naki":
			var rising=actor.shield>last_shield+float(config.recharge_epsilon) and actor.shield<actor.tuning.shield_capacity
			if rising and not recharging: cue("naki_shield_recharge_start","shield",false)
			set_loop("naki_shield_recharge_loop",rising)
			if recharging and actor.shield>=actor.tuning.shield_capacity: cue("naki_shield_full","shield",false)
			recharging=rising
		last_shield=actor.shield

func shields_off_warning_active() -> bool:
	return actor.local_player and actor.character==0 and actor.damage_model()=="naki" and actor.alive and actor.tuning.shield_capacity>0 and actor.shield<=.001 and actor.overshield<=.001 and actor.game.running and not actor.game.finished and actor.game.context=="playing" and actor.game.input_window_focused

func _exit_tree() -> void:
	stop_reload(); stop_loops()
	if manager!=null and is_instance_valid(actor): manager.stop_group_prefix(str(actor.get_instance_id())+":")

func emit_landing_foot(gain: float) -> void:
	landing_foot_cues+=1
	var hit=actor.game.trace(actor.global_position+Vector3.UP*.15,actor.global_position-Vector3.UP*.3,1)
	surface_movement_cue("footstep_"+actor.game.surface_tag(hit.get("collider"))+"_walk",landing_gain*gain)
func surface_movement_cue(id: String, gain: float) -> void:
	if gain<=0:return
	manager.play_sound(id,actor.global_position,{"group":group("foley"),"spatial":not actor.local_player,"gain_db":linear_to_db(gain)})
