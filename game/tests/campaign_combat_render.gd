extends SceneTree
# Rendered, isolated sanity sample; this does not certify a network session or FPS target.
# A tiny, unfocused offscreen native window hosts an always-rendering GPU SubViewport.
var game
var viewport: SubViewport
var output=""
var report=[]
var shot_count=0
var projectile_count=0
var shooters={}
var connected={}
var failures=0

func _initialize():call_deferred("run")

func offscreen_window():
 root.min_size=Vector2i(1,1);root.size=Vector2i(64,64)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 DisplayServer.window_set_position(Vector2i(-32000,-32000))

func frames(count=3):
 for i in range(count):
  if is_instance_valid(game):game.input_window_focused=true
  await process_frame

func record_shot(_event: int,_time: float,_origin: Vector3,directions: Array,actor_id: int):
 shot_count+=1;projectile_count+=directions.size();shooters[actor_id]=int(shooters.get(actor_id,0))+1

func observe() -> Dictionary:
 var alive=0;var bullets=0
 for actor in game.actors:
  if actor.faction!=1 or not actor.alive:continue
  alive+=1
  if not connected.has(actor.net_id):
   actor.shot_fired.connect(record_shot.bind(actor.net_id));connected[actor.net_id]=true
 for effect in game.effects.get_children():
  if effect.get_script()!=null and effect.get_script().resource_path=="res://scripts/bullet.gd":bullets+=1
 return {"enemies":alive,"bullets":bullets}

func capture(name: String):
 await RenderingServer.frame_post_draw
 var result=viewport.get_texture().get_image().save_png(output+"/"+name+".png")
 if result!=OK:failures+=1;push_error("Capture failed: "+name)

func percentile(sorted: Array,fraction: float) -> float:
 return float(sorted[clampi(ceili(sorted.size()*fraction)-1,0,sorted.size()-1)]) if not sorted.is_empty() else 0.0

func sample(mission: int,stage: int,load_ms: float,warmup_ms: float):
 var hero=game.player;var before=hero.health+hero.shield;var simulation_start=game.now
 var samples=[];var over33=0;var over50=0;var over100=0;var draw_samples=[];var objects=[]
 shot_count=0;projectile_count=0;shooters.clear()
 var initial=observe();var maximum=initial.enemies;var peak_bullets=initial.bullets
 var start=Time.get_ticks_usec();var previous=start;var probe_at=start
 while Time.get_ticks_usec()-start<20000000:
  game.input_window_focused=true;await process_frame
  var now=Time.get_ticks_usec();var frame_ms=(now-previous)/1000.0;previous=now;samples.append(frame_ms)
  if frame_ms>33.333:over33+=1
  if frame_ms>50:over50+=1
  if frame_ms>100:over100+=1
  if now>=probe_at:
   probe_at=now+200000;var activity=observe();maximum=maxi(maximum,activity.enemies);peak_bullets=maxi(peak_bullets,activity.bullets)
   draw_samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
 samples.sort();draw_samples.sort();objects.sort()
 var duration=(Time.get_ticks_usec()-start)/1000000.0;var damage=before-hero.health-hero.shield
 var record={"mission":mission,"stage":stage,"mode":str(game.campaign.journey.stage_data().mode),"sample_seconds":duration,"simulation_seconds":game.now-simulation_start,"frames":samples.size(),"median_ms":percentile(samples,.5),"p95_ms":percentile(samples,.95),"p99_ms":percentile(samples,.99),"maximum_ms":samples[-1],"frames_over_33ms":over33,"frames_over_50ms":over50,"frames_over_100ms":over100,"chapter_build_ms":load_ms,"warmup_maximum_ms":warmup_ms,"initial_enemies":initial.enemies,"maximum_enemies":maximum,"final_enemies":observe().enemies,"enemy_shots":shot_count,"emitted_projectiles":projectile_count,"distinct_shooters":shooters.size(),"peak_live_projectiles":peak_bullets,"hero_resource_loss":damage,"hero_alive":hero.alive,"median_draw_calls":percentile(draw_samples,.5),"median_rendered_objects":percentile(objects,.5),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
 record["active_combat_verified"]=maximum>=8 and shot_count>0 and damage>0 and hero.alive and record.median_draw_calls>0
 if not record.active_combat_verified:failures+=1
 report.append(record);print("LIVE_COMBAT_RENDER ",JSON.stringify(record))

func run():
 output=OS.get_environment("NEST_CAMPAIGN_COMBAT_RENDER")
 if output.is_empty() or OS.get_environment("NEST_ISOLATED_QA")!="1" or DisplayServer.get_name()=="headless":quit(1);return
 DirAccess.make_dir_recursive_absolute(output);seed(260026);offscreen_window()
 viewport=SubViewport.new();viewport.name="LiveCombatGPUViewport";viewport.size=Vector2i(1280,800);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game);await frames()
 game.sandbox_mode=true;game.prefs.values.fullscreen=false;game.prefs.values.resolution_width=1280;game.prefs.values.resolution_height=800
 game.prefs.values.graphics_quality=2;game.prefs.values.shadows=true;game.prefs.values.antialiasing=0;game.prefs.values.render_scale=1.0
 game.prefs.values.master=0.0;game.prefs.values.vsync=false;game.prefs.values.fps_limit=0;game.prefs.values.record_films=false;game.prefs.apply();offscreen_window()
 NestGraphicsQuality.apply_viewport(viewport,game.prefs.values);viewport.scaling_3d_scale=1.0
 var c=game.campaign;c.save_store.path="user://live-combat-render.json";c.selected_difficulty="Hard";c.begin_solo(false)
 c.guide.voice_supported=false;c.guide.stop_voice();offscreen_window()
 for mission in [3,8,9]:
  connected.clear();var build_start=Time.get_ticks_usec();c.journey.start_standalone(mission);c.journey.finish_cinematic();c.cinematic.present(0)
  var stage=1 if mission==9 else 3;c.state.chapter_stage=stage;c.journey._begin_stage(false,false)
  var load_ms=(Time.get_ticks_usec()-build_start)/1000.0
  var hero=game.player;hero.health=100000;hero.shield=100000;hero.set_physics_process(false)
  hero.global_position=c.world.locations["objective"+str(stage)]+Vector3(0,.03,2)
  game.input_window_focused=true;await frames()
  if not c.journey.interact(hero,"journey:arm"):failures+=1;push_error("Could not arm real objective in mission "+str(mission))
  if mission!=9:c.state.chapter_progress["hold_seconds"]=float(c.journey.stage_data().hold_seconds)*.6
  c.journey.tick(0)
  if mission==9:hero.global_position=Vector3(21,8.03,-60.5)
  else:hero.global_position=c.world.locations.objective3+Vector3(0,.03,6)
  var look=c.world.stage_center(stage)+Vector3(0,1.6,5)
  if mission==9:look=Vector3(0,10,-55)
  var offset=look-hero.eye.global_position;hero.rotation.y=atan2(-offset.x,-offset.z);hero.eye.rotation.x=atan2(offset.y,Vector2(offset.x,offset.z).length());hero.camera.current=true
  c.guide.stop_voice();game.context="playing";game.hud.visible=true;offscreen_window();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
  observe();var warm_start=Time.get_ticks_usec();var previous=warm_start;var warm_max=0.0
  while Time.get_ticks_usec()-warm_start<4000000:
   game.input_window_focused=true;await process_frame
   var now=Time.get_ticks_usec();warm_max=maxf(warm_max,(now-previous)/1000.0);previous=now;observe()
  await capture("mission-%02d-live-start"%mission);await frames(4)
  await sample(mission,stage,load_ms,warm_max)
  await capture("mission-%02d-live-end"%mission)
 var summary={"gpu":RenderingServer.get_video_adapter_name(),"resolution":[1280,800],"quality":"High","msaa":"4x","shadows":true,"vsync":false,"fps_cap":0,"offscreen_render_target":true,"native_window":"64x64, no focus, outside desktop","master_volume":0,"setup":"Real single-player Hard campaign AI and projectiles. L3/L8 stage3 extraction armed with countdown preset to60% to activate all encounter bands up to the ordinary active cap. L9 stage1 boss armed. Stationary hero physics held, health/shield each100000, no hero fire. Four-second warmup then20-second wall-clock sample per scene; captures excluded from frame samples.","results":report,"failures":failures}
 var file=FileAccess.open(output+"/live-combat-render.json",FileAccess.WRITE);file.store_string(JSON.stringify(summary,"  "));file.close()
 c.exit_campaign();game.queue_free();game=null;c=null;await frames(4);print("LIVE COMBAT RENDER: ",report.size()," scenes, ",failures," failures");quit(1 if failures else 0)
