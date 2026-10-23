extends SceneTree
var game
var checks=0
var failures=0
var events: Array[String]=[]
func _initialize(): call_deferred("run")
func check(ok: bool, text: String):
	checks+=1
	if ok: print("PASS: "+text)
	else: failures+=1; push_error("FAIL: "+text)
func ticks(count=3):
	for i in range(count): await physics_frame
func run():
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
	game.mode=2; game.bot_fill=false; game.fair_playing_field=false; game.starting_primary="default"; game.starting_secondary="default"; game.start_game(); game.context="pause"
	game.player.set_physics_process(false); game.audio.sound_started.connect(func(id,_file,_voice): events.append(id))
	game.launch_grenade(game.player,0,false,96000,Vector3(-28,1,7),Vector3.DOWN,Vector3.ZERO)
	var grenade=game.effects.get_children().filter(func(node):return node is RigidBody3D)[0]
	grenade.set_physics_process(false); grenade.freeze=true; grenade.fuse_at=INF
	check(events.count("frag_grenade_throw")==1,"Grenade release emits exactly one throw cue")
	for i in range(3): game.now+=.1; check(grenade.bounce_sound("concrete",3+i),"Eligible concrete collision %d emits a bounce"%(i+1))
	check(events.count("grenade_bounce_concrete")==3,"Three collisions produce exactly three concrete cues")
	check(not grenade.bounce_sound("concrete",.5),"Slow rolling below impact threshold is silent")
	check(not grenade.bounce_sound("concrete",5),"Collision cooldown suppresses duplicate callbacks")
	game.now+=.1; grenade.settled=true; check(not grenade.bounce_sound("concrete",5),"Settled grenade remains silent despite stale contacts")
	grenade.settled=false
	for i in range(6): game.now+=.1; grenade.bounce_sound("metal",5)
	check(grenade.bounce_count==8,"Per-grenade bounce sound cap is enforced")
	check(game.audio.last_variants.has("grenade_bounce_concrete") and game.audio.last_variants.has("grenade_bounce_metal"),"Material-specific sets select independent variations")
	grenade.queue_free(); await ticks()
	events.clear(); game.launch_grenade(game.player,0,false,96100,Vector3(-32,2,-7),Vector3.ZERO,Vector3.ZERO)
	var physical=game.effects.get_children().filter(func(node):return node is RigidBody3D)[0]
	physical.linear_velocity=Vector3.ZERO; physical.previous_velocity=Vector3.ZERO; physical.released=game.now+30
	await ticks(80)
	check(events.count("frag_grenade_throw")==1,"Physical simulation never repeats the throw sound")
	check(events.count("grenade_bounce_concrete")>=1,"Real floor collision triggers bounce audio")
	await ticks(60)
	if is_instance_valid(physical): physical.queue_free()
	await ticks()
	check(events.count("frag_grenade_settle")==1,"Physical resting produces exactly one settle sound")
	game.launch_grenade(game.player,1,false,96200,Vector3(-32,1,-7),Vector3.DOWN,Vector3.ZERO)
	var sticky=game.effects.get_children().filter(func(node):return node is RigidBody3D)[0]
	await ticks(10)
	check(events.has("plasma_grenade_stick"),"Sticky collision has its own electrical stick cue")
	check(events.has("plasma_grenade_fuse"),"Sticky grenade starts its own attached fuse cue")
	await ticks(110)
	check(not is_instance_valid(sticky) and (events.has("plasma_grenade_explosion_close") or events.has("plasma_grenade_explosion_far")),"Sticky detonation stops the fuse and uses its distinct distance-aware explosion")
	check(game.audio.reported_missing.is_empty(),"Grenade events all resolve to declared recordings")
	print("GRENADE AUDIO: %d checks, %d failures"%[checks,failures])
	game.stop_game(); game.queue_free(); await create_timer(.75).timeout; quit(1 if failures else 0)
