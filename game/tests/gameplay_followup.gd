extends SceneTree
var game
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func frames(count=4):
 for i in range(count):await process_frame
func settle_recording():
 var limit=Time.get_ticks_msec()+15000
 while (game.film_recorder.worker!=null or not game.film_recorder.queue.is_empty()) and Time.get_ticks_msec()<limit:await process_frame
func capture(name: String):
 var folder=OS.get_environment("NEST_FOLLOWUP_CAPTURES")
 if DisplayServer.get_name()=="headless" or folder.is_empty():return
 DirAccess.make_dir_recursive_absolute(folder);await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/"+name+".png")
func run():
 if OS.get_environment("NEST_ISOLATED_QA")!="1":quit(1);return
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.sandbox_mode=true
 game.prefs.values.fullscreen=false;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=800;game.prefs.apply();root.size=Vector2i(1280,800)
 game.lobby_network.set_process(false);game.close_connection();game.show_lobby();await frames()
 var picker=game.screen.find_child("LobbyMap",true,false)
 check(picker!=null and picker.is_visible_in_tree() and picker.item_count==6,"Map selection is visible in the default lobby Game Setup")
 picker.item_selected.emit(1);await frames();check(game.game_type.map_selection==1 and game.arena.map_selection==1,"Host map selection updates both rules and playable arena")
 game.open_forge();game.start_forge_session();await frames()
 check(not root.disable_3d and game.forge_editor.camera.current,"Forge enables 3D rendering and its editor camera")
 await capture("forge-visible");game.forge_session.stop_editing();game.show_main();await frames()
 var c=game.campaign;c.save_store.path="user://followup-campaign.json";c.begin_solo(false);c.state.phase="PREPARATION";c.present_phase();await frames()
 var actor=game.player
 check(actor.weapons[0].kind=="plasma_br" and actor.weapons[1].kind=="plasma_pistol","Campaign starts with plasma carbine and plasma pistol")
 actor.wield_sword();check(actor.weapons[actor.slot].kind=="plasma_sword" and actor.action_state=="switching","Campaign melee weapon can be wielded")
 var saved=c.equipment(actor);c.checkpoint_now();check(NestCampaignState.valid(c.state.pack()) and not c.save_store.read_valid(c.save_store.path).is_empty(),"Three-slot campaign inventory survives strict JSON checkpoint readback")
 for entry in [["ship_sniper","plasma_sniper"],["ship_assault","plasma_auto"]]:
  actor.global_position=c.world.locations[entry[0]]+Vector3(0,0,1.4);await frames();var choice=c.interaction(actor)
  check(choice.get("key","")=="campaign:"+entry[0] and c.interact(actor,choice) and actor.weapons[0].kind==entry[1],"Ship rack equips usable "+str(entry[1]))
 c.restore_equipment(actor,saved);check(actor.weapons[actor.slot].kind=="plasma_sword","Restoring campaign equipment preserves melee wield slot")
 c.state.phase="CRASH";c.set_world("forest");c.rebuild_heroes();c.set_phase("CRASH_ORIENTATION");await frames()
 check(c.world.locations.has("ship_sniper") and c.world.locations.has("ship_assault"),"Both weapon racks survive at the crashed ship")
 c.exit_campaign();await frames();game.close_connection()
 # Record actual running matches rather than constructing synthetic film payloads.
 for completed in [false,true]:
  var rules=GameTypeSettings.new();rules.mode=2;rules.bots_fill_empty_slots=true;rules.max_players_per_team=2
  game.apply_game_type_settings(rules);game.clear_screen();game.start_game();game.create_hud();game.hud.visible=true;game.current_screen="playing";await frames(150)
  var id=game.film_recorder.id;var filename=NestFilmArchive.path(id)
  game.finished=completed;game.stop_game();await settle_recording()
  var decoded=NestFilmArchive.read(filename)
  check(not decoded.has("error") and decoded.get("frames",[]).size()>2,"Actual "+("completed" if completed else "quit")+" match recording reopens: "+str(decoded.get("error","valid")))
  check(FileAccess.file_exists(NestFilmArchive.ROOT+"/"+id+".json"),"Concluded match has a finalized library summary")
  if DisplayServer.get_name()!="headless":check(FileAccess.file_exists(NestFilmArchive.ROOT+"/"+id+".png"),"Rendered match has an actual preview thumbnail")
  if completed:check(game.host_direct(0,"Replay fixture",0)==OK,"An idle lobby connection is available before Film playback")
  game.open_films();await frames()
  check(game.film_viewer.find_child("FilmOpen_"+id,true,false)!=null and game.film_viewer.find_child("FilmPreview",true,false)!=null,"Concluded match appears as a playable preview card")
  await capture("film-library");var viewer=game.film_viewer;viewer.load_film(filename)
  var limit=Time.get_ticks_msec()+15000
  while viewer.film.is_empty() and Time.get_ticks_msec()<limit:await process_frame
  check(not viewer.film.is_empty(),"Actual match loads into Film viewer")
  if not viewer.film.is_empty():
   var before=viewer.timestamp;await frames(10);check(viewer.timestamp>before and not viewer.selected.is_empty(),"Film automatically plays a participant perspective")
   viewer.toggle_playback();var stopped=viewer.timestamp;await frames(4);check(viewer.timestamp==stopped,"Film Pause stops timeline advancement")
   viewer.seek(float(viewer.film.metadata.duration));viewer.paused=true;viewer.toggle_playback();await frames(3);check(viewer.timestamp<float(viewer.film.metadata.duration),"Play at the end restarts the film")
   await capture("film-playing")
  viewer.close();await frames()
 game.queue_free();await frames();print("GAMEPLAY FOLLOWUP: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
