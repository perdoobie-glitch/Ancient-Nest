extends SceneTree
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok: bool, description: String):
	checks+=1
	if ok: print("PASS: "+description)
	else: failures+=1; push_error("FAIL: "+description)
func ticks(count: int):
	for i in range(count): await physics_frame
func buttons(node: Node) -> Array[String]:
	var result: Array[String]=[]
	if node is Button: result.append(node.text)
	for child in node.get_children(): result.append_array(buttons(child))
	return result
func run():
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
	check(buttons(game.screen)==["Custom Lobby","Settings","Quit Game"],"Main menu has exactly the three required primary buttons")
	game.bot_fill=false; game.tuning.round_seconds=900
	Input.action_press("fire"); game.start_game(); game.create_hud(); game.hud.visible=true; game.current_screen="playing"
	await ticks(5)
	check(game.player.ammo[0]==game.player.weapons[0].magazine,"A held menu click cannot fire on match start")
	game.open_chat(); game.chat_entry.text="Unsent draft"; game.player.die(null,"test"); await ticks(1)
	check(not game.chat_panel.visible and not game.chat_entry.has_focus() and game.chat_entry.text=="","Death cancels chat and removes text focus")
	check(not "Unsent draft" in " ".join(game.messages),"Death never sends the chat draft")
	await ticks(185)
	check(game.player.alive,"Player respawns with a valid input context after chat death")
	game.player.throw_grenade(); await ticks(5); game.show_pause(); await ticks(15)
	check(game.player.grenades[0]==2,"Pause before grenade release cancels inventory spending")
	game.resume_game(); game.player.throw_grenade(); await ticks(16)
	check(game.player.grenades[0]==1,"Committed grenade release spends exactly one item")
	var grenade
	for child in game.effects.get_children():
		if child is RigidBody3D: grenade=child
	game.show_pause(); await ticks(2)
	check(is_instance_valid(grenade),"Released grenade continues behind the pause menu")
	if is_instance_valid(grenade):
		var wall=StaticBody3D.new(); game.add_child(wall); grenade.contact(wall); var fuse=grenade.fuse_at
		await ticks(10)
		if is_instance_valid(grenade): grenade.contact(wall); check(grenade.fuse_at==fuse,"Repeated contacts never restart a grenade fuse")
		wall.queue_free()
	game.clear_effects(); game.player.respawn(); game.resume_game()
	Input.action_press("fire"); game.show_pause(); game.resume_game(); await ticks(2)
	check(game.player.ammo[0]==game.player.weapons[0].magazine,"Resume clears stale held fire")
	# Loading must complete the full interval, and interruptions reset its draft.
	game.reset_round(); game.player.global_position=game.arena.sites[0]+Vector3(-2.5,0.05,0)
	game.site_states[0].stage="complete"; game.site_states[0].work=45; game.bomb_site=0
	await ticks(5)
	Input.action_press("interact"); await ticks(300)
	check(not game.player.carrying and game.interaction_progress>4.5,"Five seconds of loading cannot grant a bag")
	Input.action_release("interact"); await ticks(2)
	check(game.interaction_progress==0,"Releasing E cancels and resets incomplete loading")
	Input.action_press("interact"); await ticks(585)
	check(not game.player.carrying,"Bag is not granted before the full ten seconds")
	await ticks(25)
	check(game.player.carrying and game.loaded_bags==1 and game.scores[0]==0,"Completed loading grants one bag and no objective point")
	await ticks(60)
	check(game.loaded_bags==1,"Continuing to hold E cannot stack a second carried bag")
	Input.action_release("interact")
	game.player.global_position=game.arena.ship_position+Vector3(0,0.05,0); await ticks(2)
	Input.action_press("interact"); await ticks(2); Input.action_release("interact")
	check(not game.player.carrying and game.scores[0]==1,"Delivery scores once and immediately clears carrying")
	game.player.global_position=game.arena.sites[0]+Vector3(-2.5,0.05,0)
	game.now=game.deadline
	check(not game.complete_interaction(game.player,game.interaction_for(game.player)),"Round expiry rejects same-tick late loading/delivery completions")
	game.reset_round()
	# Melee is legal while aiming at the enemy's upper body; menus cancel windup.
	var victim=NestActor.new(); victim.game=game; victim.faction=1; game.add_child(victim); game.actors.append(victim); victim.set_physics_process(false)
	game.player.global_position=Vector3(-8,7,-17)*.85+Vector3.UP*.06; game.player.rotation.y=0; game.player.eye.rotation.x=0
	victim.global_position=Vector3(-8,7,-17)*.85+Vector3(0,.06,-1.1)
	await ticks(2)
	game.player.melee(); await ticks(3); game.show_pause(); await ticks(12)
	check(victim.health==100 and victim.armor==100,"Pause during melee windup prevents an uncommitted hit")
	game.resume_game(); await ticks(40); game.player.melee(); await ticks(10)
	check(victim.health<100,"Melee can acquire a legal enemy while crosshair aims near the head")
	var hp=victim.health
	await ticks(15)
	check(victim.health==hp,"A melee strike damages its target once")
	await ticks(30)
	var wall=Node3D.new(); game.add_child(wall); game.arena.kit.box(wall,Vector3(-8,7,-17)*.85+Vector3(0,1.1,-.55),Vector3(2.5,3,0.15),game.arena.kit.stone,true); await ticks(2)
	game.player.melee(); await ticks(10)
	check(victim.health==hp,"Melee cannot acquire or damage through a solid wall")
	wall.queue_free(); game.actors.erase(victim); victim.queue_free(); await ticks(2)
	# A new match cannot expose old chat or kill-feed entries.
	game.messages.append("Old player: old match message"); game.kill_feed.append({"text":"Old elimination","until":9999})
	game.stop_game(); await ticks(2); game.selected_faction=1; game.start_game(); game.create_hud(); game.hud.visible=true
	check(game.messages.is_empty() and game.kill_feed.is_empty(),"Match restart clears prior-session chat and kill feed")
	game.player.take_damage(20,"torso","bullet",false,null,game.next_event()); await ticks(360)
	check(is_equal_approx(game.player.health,90) and is_equal_approx(game.player.armor,90),"Annu health and armor remain reduced without regeneration")
	check(game.protection_bars.size()==2 and not "SHIELD" in game.hud_protection.text,"Annu HUD does not show a rechargeable shield meter")
	var session=game.match_session; game.snapshot_received=500; game.close_connection()
	check(game.snapshot_received==-1 and game.snapshot_fragments.is_empty(),"Reconnect clears old snapshot counters and fragment buffers")
	game.stop_game(); game.queue_free(); await create_timer(0.5).timeout
	print("RESULT: %d edge checks, %d failures"%[checks,failures]); quit(1 if failures else 0)
