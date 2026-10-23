extends SceneTree
class TickStart extends Node:
 var stamp:int=0
 func _physics_process(_delta:float):stamp=Time.get_ticks_usec()
class TickEnd extends Node:
 var first:TickStart
 var samples:Array=[]
 func _physics_process(_delta:float):samples.append((Time.get_ticks_usec()-first.stamp)/1000.)
class FrameClock extends Node:
 var stamp:int=0
 var samples:Array=[]
 func _process(_delta:float):
  var next=Time.get_ticks_usec()
  if stamp!=0:samples.append((next-stamp)/1000.)
  stamp=next

func _initialize():call_deferred("run")
func quantile(values:Array, fraction:float)->float:
 var sorted=values.duplicate();sorted.sort();return sorted[mini(sorted.size()-1,int((sorted.size()-1)*fraction))] if not sorted.is_empty() else 0.
func run():
 Engine.max_fps=60
 var args=OS.get_cmdline_user_args();var mode=2;var map=2;var count=12;var seconds=12.
 if args.size()>0:count=int(args[0])
 if args.size()>1:mode=int(args[1])
 if args.size()>2:map=int(args[2])
 if args.size()>3:seconds=float(args[3])
 seed(int(args[4]) if args.size()>4 else 91290)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.prefs.light_preset();game.prefs.apply()
 if args.size()>5:Engine.max_fps=int(args[5])
 var rules=NestMatchPresets.create(mode,map,1);rules.max_players_per_team=8;rules.max_players=16;rules.bots_fill_empty_slots=true;rules.bots_team_0=count/2;rules.bots_team_1=count-count/2;rules.score_to_win=1000
 game.apply_game_type_settings(rules);game.clear_screen();game.start_game();game.context="playing";game.current_screen="playing";game.create_hud();game.hud.visible=true
 assert(game.actors.size()==count+1,"Exact requested bot count")
 var first=TickStart.new();first.process_physics_priority=-2000;root.add_child(first)
 var last=TickEnd.new();last.first=first;last.process_physics_priority=2000;root.add_child(last)
 var frames=FrameClock.new();root.add_child(frames)
 await create_timer(3).timeout
 last.samples.clear();frames.samples.clear()
 var physics=[];var process=[];var bodies=[];var nodes=[];var started=Time.get_ticks_msec();var ticks=0;var bad=0;var travel=0.0;var contact_ticks=0;var positions={}
 while Time.get_ticks_msec()-started<seconds*1000:
  await physics_frame;ticks+=1
  physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
  process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
  nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
  for actor in game.actors:
   if not actor.global_position.is_finite():bad+=1
   var before=positions.get(actor.net_id)
   if before!=null and actor.alive and before.life==actor.life_id:
    var distance=actor.global_position.distance_to(before.pos)
    if distance<2:travel+=distance
   positions[actor.net_id]={"pos":actor.global_position,"life":actor.life_id}
   if actor.alive:
    for index in range(actor.get_slide_collision_count()):
     if actor.get_slide_collision(index).get_collider() is NestActor:contact_ticks+=1;break
 var result={"hud_included":true,"fps_cap":Engine.max_fps,"bots":count,"mode":mode,"map":map,"seconds":(Time.get_ticks_msec()-started)/1000.,"ticks":ticks,"physics_median_ms":quantile(physics,.5),"physics_p95_ms":quantile(physics,.95),"physics_p99_ms":quantile(physics,.99),"process_median_ms":quantile(process,.5),"process_p95_ms":quantile(process,.95),"max_nodes":quantile(nodes,1),"memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.,"invalid_positions":bad,"actors":game.actors.size(),"renderer":DisplayServer.get_name(),"tick_script_median_ms":quantile(last.samples,.5),"tick_script_p95_ms":quantile(last.samples,.95),"tick_script_p99_ms":quantile(last.samples,.99),"frame_median_ms":quantile(frames.samples,.5),"frame_p95_ms":quantile(frames.samples,.95),"frame_count":frames.samples.size()}
 result["travel_m"]=travel;result["actor_contact_ticks"]=contact_ticks;result["kills"]=game.actors.reduce(func(total,a):return total+a.kills,0)
 result["tick_over_budget_fraction"]=float(last.samples.filter(func(ms):return ms>1000.0/60).size())/maxi(1,last.samples.size())
 result["frame_over_50ms_fraction"]=float(frames.samples.filter(func(ms):return ms>50.0).size())/maxi(1,frames.samples.size())
 print("BENCHMARK ",JSON.stringify(result))
 FileAccess.open("user://benchmark-latest.json",FileAccess.WRITE).store_string(JSON.stringify(result))
 game.queue_free();await create_timer(.3).timeout;quit(0 if bad==0 else 1)
