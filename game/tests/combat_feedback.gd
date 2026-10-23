extends SceneTree
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func run():
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
	game.bot_fill=false; game.start_game(); game.clear_screen(); game.create_hud(); game.hud.visible=true; game.context="playing"
	for i in range(12): await physics_frame
	var player=game.player
	game.set_physics_process(false); player.set_physics_process(false)
	player.global_position=Vector3(-13,7.1,-17); player.rotation.y=-PI/2; player.reset_physics_interpolation()
	player.update_visual(.016)
	var camera_basis=player.camera.global_basis; var ammo_before=player.ammo[0]
	player.ammo[0]-=3; player.reload_weapon()
	check(player.action_state=="reloading","Reload enters the existing gameplay action")
	game.now=player.action_until-player.weapons[0].reload_seconds*.55
	player.update_visual(.1)
	var magazine=player.weapon_art.find_children("ReloadMagazine*","Node3D",true,false)
	check(not magazine.is_empty(),"Authored rifle contains an independent magazine")
	if not magazine.is_empty():
		var data=player.weapon_art.get_meta("motion_parts")[0]
		check(magazine[0].position.y<data.rest.origin.y-.1,"Magazine visibly leaves its well during reload")
	check(player.weapon_view.rotation.z<-.2,"Reload tilts the first-person gun")
	check(player.presentation.left_hand.position.y<-.1,"Support hand reaches down with the magazine")
	check(player.camera.global_basis.is_equal_approx(camera_basis),"Reload animation does not move aim")
	check(player.ammo[0]==ammo_before-3,"Presentation does not grant ammunition early")
	player.velocity=player.global_basis*Vector3(0,0,-3)
	player.update_visual(.13)
	var leg=player.skeleton.find_bone("thigh_l")
	var leg_before=player.skeleton.get_bone_pose_rotation(leg)
	player.update_visual(.15)
	check(not player.skeleton.get_bone_pose_rotation(leg).is_equal_approx(leg_before),"Legs keep walking while arms reload")
	check("walk" in String(player.animation.current_animation),"Reload preserves the locomotion clip")
	player.action_state="ready"; player.flash_until=game.now+.15; player.update_visual(.05)
	leg_before=player.skeleton.get_bone_pose_rotation(leg); player.update_visual(.13)
	check(not player.skeleton.get_bone_pose_rotation(leg).is_equal_approx(leg_before),"Legs keep walking while firing")
	check(player.weapon_art.get_meta("gun_feedback").flash.visible and player.weapon_view.position.z>-.46,"Shot produces muzzle flash and gun kick")
	check(player.camera.global_basis.is_equal_approx(camera_basis),"Cosmetic gun kick does not change aim")
	var hand=player.skeleton.get_bone_global_pose(player.skeleton.find_bone("hand_r")).origin
	check(hand.distance_to(Vector3(.10,1.245,-.165))<.11,"Right hand holds the gun at chest height")
	check(player.hitboxes.size()==17,"Animations and shield meshes add no damage targets")
	player.velocity=Vector3.ZERO; player.flash_until=-100; player.update_visual(.016)
	if not magazine.is_empty():
		check(magazine[0].transform.is_equal_approx(player.weapon_art.get_meta("motion_parts")[0].rest),"Magazine returns to its authored position")
	for kind in ["sidearm","shotgun","sniper"]:
		player.weapons[0]=load("res://resources/"+kind+".tres"); player.update_visual(.016)
		var mechanism="PistolSlide" if kind=="sidearm" else "Pump" if kind=="shotgun" else "ChargingHandle"
		var moved=false
		player.flash_until=game.now+.15-(.02 if kind=="sidearm" else .30 if kind=="sniper" else .2); player.update_visual(.016)
		for data in player.weapon_art.get_meta("motion_parts"):
			if data.name.begins_with(mechanism): moved=data.node.position.z>data.rest.origin.z+.01
		check(moved,kind+" cycles its firing mechanism")
	player.weapons[0]=load("res://resources/rifle.tres"); player.flash_until=-100; player.update_visual(.016)
	game.now=20; player.health=100; player.shield=100; player.overshield=0; player.reset_damage_visual()
	player.take_damage(12,"torso","bullet",false,null,70001); player.update_visual(.016)
	check(player.shield_flash_at==game.now and player.health_flash_at<0,"Shield hit triggers energy feedback without health feedback")
	var seq=player.damage_fx_seq
	player.take_damage(12,"torso","bullet",false,null,70001)
	check(player.damage_fx_seq==seq,"Duplicate damage does not retrigger shield effects")
	game.now+=.1; player.take_damage(200,"torso","bullet",false,null,70002)
	check(player.shield==0 and player.shield_break_at==game.now,"Depleting shields records a distinct break flash")
	var break_at=player.shield_break_at
	game.now+=.02; player.take_damage(5,"torso","bullet",false,null,70003)
	check(player.health_flash_at==game.now and player.shield_break_at==break_at,"Health hit preserves the preceding shield-break event")
	var enemy=NestActor.new(); enemy.game=game; enemy.faction=1; game.add_child(enemy); game.actors.append(enemy); enemy.set_physics_process(false)
	enemy.take_damage(10,"torso","bullet",false,null,70004)
	check(enemy.shield_flash_at<0 and enemy.health_flash_at==game.now,"Annu receives health feedback without invented base shields")
	enemy.overshield=10; game.now+=.1; enemy.take_damage(10,"torso","bullet",false,null,70005); enemy.update_visual(.016)
	check(enemy.shield_flash_over and enemy.shield_break_at==game.now,"Annu's actual overshield flashes and breaks")
	check(enemy.presentation.hit_electricity.visible,"Remote actors show brief electrical contact arcs")
	player.respawn(); player.update_visual(.016)
	check(player.shield_flash_at<0 and player.shield_break_at<0 and player.health_flash_at<0,"Respawn clears all damage feedback")
	check(game.arena.batch_stats.original_meshes>0 and game.arena.batch_stats.batches<game.arena.batch_stats.original_meshes,"Fixed architecture uses spatial material batches")
	check(not game.arena.get_node("U2Lift") is PhysicsBody3D and game.arena.get_node("U2Lift").has_method("apply_motion") and is_nan(game.lift_physics_y()),"Gravity lift retains its fixed updraft simulation")
	check(game.hurt_overlay.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Shield overlay passes through mouse input")
	game.open_settings("pause"); game.settings_tab="Video"; game.show_settings(); game.draft.shadows=false; game.apply_draft()
	check(not game.arena.sun.shadow_enabled,"Video Shadows switch disables runtime shadows")
	game.prefs.values.shadows=true; game.prefs.save(); game.arena.sun.shadow_enabled=true
	print("COMBAT FEEDBACK: %d checks, %d failures"%[checks,failures])
	game.stop_game(); game.queue_free(); await process_frame; quit(1 if failures else 0)
