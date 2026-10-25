extends SceneTree
var failures=0
var checks=0
var display_viewport: Viewport
func check(ok: bool,message: String):
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
	display_viewport=root
	if "--qa-preview" in OS.get_cmdline_user_args():
		root.hide();var viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);display_viewport=viewport
	var game=load("res://scenes/main.tscn").instantiate();display_viewport.add_child(game);await process_frame
	var rules=GameTypeSettings.new();rules.mode=2;rules.max_players_per_team=5;rules.bots_fill_empty_slots=true;rules.starting_primary="sniper_rifle"
	game.apply_game_type_settings(rules);game.start_game();game.context="pause"
	for actor in game.actors:actor.set_physics_process(false)
	await create_timer(.25).timeout
	check(game.film_recorder.active,"Local film recorder starts with gameplay")
	check(game.actors.size()==10,"Fixture contains all ten participants")
	game.create_hud();game.hud.visible=true
	var view: Dictionary=game.film_recorder.capture_view()
	check(view.camera is Transform3D and view.weapon_nodes.size()>0,"Local camera and weapon presentation are captured")
	var frame=game.snapshot_state().duplicate(true)
	var roster={};var tracks={};var events={}
	var id=NestFilmArchive.digest("film-playback-fixture".to_utf8_buffer()).hex_encode().substr(0,32)
	for i in range(10):
		var actor=game.actors[i];var who=str(actor.net_id)
		roster[who]={"id":actor.net_id,"name":"Player "+str(i+1),"team":i%2,"character":i%2,"peer":i+1}
		if i==9:continue
		tracks[who]=[];events[who]=[{"t":.31,"kind":"confirmed_hit","data":{"region":"head","killed":false}}]
		for t in [.0,.25,.5,.75,1.0,1.25,1.5]:
			if i==8 and t<.5:continue
			var sample=view.duplicate(true);sample.t=t;sample.camera=Transform3D(Basis.IDENTITY,Vector3(20+i,3,5+t));sample.fov=40.0 if t>=.5 else 90.0;sample.actor.health=50.0+i;sample.actor.alive=t<.5 or t>=1.0;sample.life=1 if t<1.0 else 2;sample.actor.life_id=sample.life;sample.actor.scope_level=1 if t>=.5 else 0;sample.hit_until=.44 if t>=.31 else 0.0
			tracks[who].append(sample)
	var frames=[]
	for t in [.0,.25,.5,.75,1.0,1.25,1.5]:
		var state=frame.duplicate(true);state[0].now=t;frames.append({"t":t,"state":state})
	var metadata={"id":id,"duration":1.5,"sample_hz":29,"roster":roster,"config":{"game_type":rules.to_network_dict(),"matchup":0,"session":1}}
	game.stop_game();await process_frame
	var limit=Time.get_ticks_msec()+15000
	while (game.film_recorder.worker!=null or not game.film_recorder.queue.is_empty()) and Time.get_ticks_msec()<limit:await process_frame
	var filename=NestFilmArchive.path(id)
	if FileAccess.file_exists(filename):DirAccess.remove_absolute(filename)
	check(not NestFilmArchive.write_block({"id":id,"payload":{"metadata":metadata,"frames":frames}}).has("error"),"Main film writes with bounded primitive format")
	for who in tracks:NestFilmArchive.write_block({"id":id,"payload":{"owner":who,"views":tracks[who],"events":events[who]}})
	var decoded=NestFilmArchive.read(filename)
	check(not decoded.has("error") and decoded.tracks.size()==9,"Exportable film reopens with nine available tracks")
	game.open_films();var viewer=game.film_viewer;viewer.load_film(filename)
	limit=Time.get_ticks_msec()+15000
	while viewer.film.is_empty() and Time.get_ticks_msec()<limit:await process_frame
	check(not viewer.film.is_empty(),"Viewer opens film asynchronously")
	viewer.seek(.375);viewer.speed=-2;viewer.paused=true
	for who in roster:
		viewer.select(who)
		check(is_equal_approx(viewer.timestamp,.375) and viewer.speed==-2 and viewer.paused,"Switching to "+str(roster[who].name)+" preserves playback state")
	check(viewer.label_view.text.contains("Reconstructed View"),"Missing track is clearly labeled reconstructed")
	var first=str(roster.keys()[0]);viewer.select(first);viewer.seek(.6)
	check(not game.player.alive and is_equal_approx(viewer.recorded_fov,40),"Death view and recorded zoom restore on seek")
	viewer.seek(1.1);check(game.player.alive and game.player.life_id==2,"Respawn restores a new local life")
	if "--qa-preview" in OS.get_cmdline_user_args():await screenshot("recorded-perspective")
	var before=viewer.camera.global_transform;var motion=InputEventMouseMotion.new();motion.relative=Vector2(100,100);viewer.input(motion)
	check(viewer.camera.global_transform==before,"Mouse cannot change recorded first-person aim")
	viewer.select("");check(viewer.camera.global_transform==before,"Free camera starts at the watched camera position")
	if "--qa-preview" in OS.get_cmdline_user_args():await screenshot("free-camera")
	viewer.select(str(roster.keys()[8]));viewer.seek(.1)
	check(viewer.label_view.text.contains("Reconstructed View"),"Late-join perspective is unavailable before it starts")
	if "--qa-preview" in OS.get_cmdline_user_args():await screenshot("reconstructed-perspective")
	viewer.select(first);viewer.seek(.375)
	game.radar._refresh_contacts();check(game.radar.contacts.size()==view.contacts.size(),"Playback radar never scans hidden authoritative enemies")
	viewer.step(-1);check(viewer.paused and absf(viewer.timestamp-(.375-1.0/29))<.00001,"Frame stepping uses established 29 Hz timeline")
	viewer.close();await process_frame
	check(not game.replay_active and not game.running,"Closing film restores menu and stops replay authority")
	DirAccess.remove_absolute(filename)
	print("FILM PLAYBACK: %d checks, %d failures"%[checks,failures]);game.queue_free();await process_frame;quit(1 if failures else 0)
func screenshot(name: String):
	var folder=OS.get_environment("NEST_FILM_QA_OUTPUT")
	if folder.is_empty():return
	DirAccess.make_dir_recursive_absolute(folder)
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	display_viewport.get_texture().get_image().save_png(folder+"/"+name+".png")
