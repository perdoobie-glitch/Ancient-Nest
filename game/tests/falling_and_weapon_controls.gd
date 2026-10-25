extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if OS.get_environment("NEST_ISOLATED_QA")!="1":
		push_error("This migration fixture writes preferences. Run node scripts/campaign-validation.mjs falling_and_weapon_controls for an isolated profile.");quit(1);return
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.bot_fill=false;game.start_game();game.set_physics_process(false)
	game.context="playing";game.input_window_focused=true;game.finished=false;game.now=100;game.break_until=0
	var actor=game.player
	actor.set_physics_process(false)
	actor.position=Vector3(0,120,0);actor.velocity=Vector3.ZERO;actor.move_and_slide()
	actor.external=Vector3.ZERO
	var dt=1.0/60.0
	var gravity=actor.tuning.gravity*actor.traits.gravity_percent/100.0
	var launch=actor.tuning.jump_speed*sqrt(actor.traits.jump_height_percent*actor.traits.gravity_percent/10000.0)
	actor.controlled=Vector3(0,launch,0)
	var reference_velocity=launch
	var reference_height=120.0
	var reference_peak=120.0
	var actual_peak=120.0
	while reference_velocity>0:
		await physics_frame
		reference_velocity-=gravity*dt
		reference_height+=reference_velocity*dt
		reference_peak=maxf(reference_peak,reference_height)
		actor.movement_step(Vector2.ZERO,false,0,0,dt)
		actual_peak=maxf(actual_peak,actor.position.y)
		assert(absf(actor.controlled.y-reference_velocity)<.0001)
	assert(absf(actual_peak-reference_peak)<.001)
	for replay in [false,true]:
		await physics_frame
		actor.controlled=Vector3(0,-5,0);actor.external=Vector3.ZERO
		actor.movement_step(Vector2.ZERO,false,0,0,dt,replay)
		assert(absf(actor.controlled.y-(-5-gravity*1.10*dt))<.0001)
	# Upward external impulses keep the original ascending acceleration too.
	await physics_frame
	actor.controlled=Vector3(0,-5,0);actor.external=Vector3(0,10,0)
	actor.movement_step(Vector2.ZERO,false,0,0,dt)
	assert(absf(actor.controlled.y-(-5-gravity*dt))<.0001)
	actor.external=Vector3.ZERO;actor.controlled=Vector3(4,-2,0);actor.velocity=actor.controlled
	var presentation=actor.presentation
	presentation.view_speed=4;presentation.view_gait_phase=1.2
	presentation.locomotion_life=actor.life_id;presentation.locomotion_weight=1
	presentation.update_view(dt);presentation.update_locomotion(dt)
	assert(presentation.view_speed==0 and presentation.locomotion_weight==0)
	assert(is_equal_approx(presentation.view_gait_phase,1.2))
	actor.update_visual(dt)
	assert(actor.animation.current_animation==actor.clips.jump_air)
	actor.weapons.assign([NestWeaponCatalog.profile("rifle"),NestWeaponCatalog.profile("sidearm"),NestWeaponCatalog.profile("plasma_sword")])
	actor.slot=0;actor.action_state="ready";actor.action_until=0
	var secondary=InputEventKey.new();secondary.physical_keycode=game.prefs.keys.secondary_weapon;secondary.pressed=true
	actor._input(secondary)
	assert(actor.slot==1 and actor.action_state=="switching")
	game.now=actor.action_until+1;actor.action_state="ready"
	var primary=InputEventKey.new();primary.physical_keycode=game.prefs.keys.primary_weapon;primary.pressed=true
	actor._input(primary)
	assert(actor.slot==0)
	game.now=actor.action_until+1;actor.action_state="ready"
	game.apply_action(actor,"select_weapon",1,actor.life_id,game.round_number,game.match_session)
	assert(actor.slot==1)
	game.now=actor.action_until+1;actor.action_state="ready"
	game.apply_action(actor,"select_weapon",99,actor.life_id,game.round_number,game.match_session)
	assert(actor.slot==1)
	if actor.character==0:
		var melee=InputEventKey.new();melee.physical_keycode=game.prefs.keys.sword;melee.pressed=true
		actor._input(melee)
		assert(actor.weapons[actor.slot].kind=="plasma_sword")
	var cfg=ConfigFile.new();cfg.set_value("meta","schema",5);cfg.set_value("bindings","switch_weapon",KEY_1);cfg.set_value("bindings","crouch",KEY_C)
	assert(cfg.save(NestPreferences.PATH)==OK)
	var migrated=NestPreferences.new();migrated.load_saved()
	assert(migrated.keys.primary_weapon==KEY_1 and migrated.keys.secondary_weapon==KEY_2)
	assert(migrated.keys.switch_weapon not in [KEY_1,KEY_C] and migrated.keys.crouch==KEY_C)
	game.queue_free();await process_frame
	print("MOVEMENT/CONTROLS: unchanged ascending arc/apex, 10% stronger fall and replay, no airborne running bob, direct weapon keys, host validation and saved-binding migration passed")
	quit()
