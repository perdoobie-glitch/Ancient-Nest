extends SceneTree
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if ok: print("PASS: "+message)
	else: failures+=1; push_error("FAIL: "+message)
func ticks(count):
	for i in range(count): await physics_frame
func fire_at(shooter, victim, area_index: int):
	shooter.aim_punch=Vector2.ZERO
	var offset=victim.hitboxes[area_index].global_position-shooter.camera.global_position
	shooter.rotation.y=atan2(-offset.x,-offset.z)
	shooter.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length()); shooter.apply_aim_rotation()
	shooter.fire_trigger(); await ticks(10); game.now+=.17
func place(victim):
	victim.global_position=Vector3(80,25,70); victim.reset_physics_interpolation(); victim.update_visual(.016)
func run():
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
	game.bot_fill=false; game.selected_faction=1; game.mode=2; game.start_game(); game.clear_screen(); game.create_hud(); game.hud.visible=true
	var shooter=game.player; await ticks(6)
	check(shooter.weapons[0].kind=="ak47" and shooter.ammo[0]==30,"Annu starts with the AK-47 and a 30-round magazine")
	game.set_physics_process(false); shooter.set_physics_process(false); shooter.global_position=Vector3(80,25,80); shooter.rotation=Vector3.ZERO; shooter.eye.rotation=Vector3.ZERO; shooter.reset_aim(); shooter.reset_physics_interpolation()
	var victim=NestActor.new(); victim.game=game; victim.faction=0; game.add_child(victim); game.actors.append(victim); victim.set_physics_process(false); place(victim); await ticks(4)
	check(shooter.art_kind=="ak47" and not shooter.weapon_art.find_children("ReloadMagazine*","Node3D",true,false).is_empty(),"AK-47 artwork has its own removable curved magazine")
	await fire_at(shooter,victim,0)
	check(victim.alive and victim.shield==50 and victim.health==100,"First real AK headshot removes half of full Naki shields")
	await fire_at(shooter,victim,0)
	check(victim.alive and victim.shield==0 and victim.health==100,"Second real AK headshot breaks Naki shields without bullet spillover")
	await fire_at(shooter,victim,0)
	check(not victim.alive and victim.health==0,"Third real AK headshot eliminates the full-health Naki")
	check(shooter.ammo[0]==27,"Three headshots consume exactly three rounds")
	victim.respawn(); place(victim); victim.overshield=100; victim.over_deadline=game.now+40; await ticks(2)
	for i in range(3): await fire_at(shooter,victim,0)
	check(victim.alive and victim.shield==50,"Actual overshield remains extra protection against the AK-47")
	shooter.respawn(); shooter.set_physics_process(false); await ticks(2)
	check(shooter.weapons[0].kind=="ak47" and shooter.ammo[0]==30,"Annu respawns with the AK-47 restored")
	var reserve=shooter.reserve[0]; shooter.ammo[0]=20; shooter.reload_weapon(); game.now=shooter.action_until-.05
	shooter.update_visual(.016); check(shooter.ammo[0]==20,"AK reload animation does not grant ammunition early")
	game.now=shooter.action_until+.01; shooter._physics_process(1.0/60)
	check(shooter.ammo[0]==30 and shooter.reserve[0]==reserve-10,"AK reload completes with the correct magazine and reserve")
	shooter.action_state="ready"; shooter.accuracy_penalty=0; shooter.velocity=Vector3.ZERO
	var still=shooter.current_spread_degrees(); shooter.velocity=Vector3(5,4,2)
	check(is_equal_approx(still,shooter.current_spread_degrees()),"AK accuracy has no movement or jumping penalty")
	print("AK47: %d checks, %d failures"%[checks,failures])
	game.stop_game(); game.queue_free(); await process_frame; quit(1 if failures else 0)
