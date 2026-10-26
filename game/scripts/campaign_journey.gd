class_name NestCampaignJourney
extends RefCounted
# Host-owned campaign progression. Clients receive state, scene and clock snapshots.
var campaign
var motorcycles
var clock=0.0
var stage_spawned=false
var weakpoint: Area3D
var weakpoint_visual: MeshInstance3D
var hit_events={}
var hazard_hits={}
var chapter_cache=[]
var last_visual_stage=-1
var runtime_mission=0
var runtime_session=0
var runtime_world=0
var dialogue_queue=[]
var dialogue_at=0.0
func catalog() -> Array:
 if chapter_cache.is_empty() and FileAccess.file_exists("res://data/campaign_chapters.json"):
  var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_chapters.json"))
  chapter_cache=parsed if parsed is Array else parsed.get("chapters",[])
 return chapter_cache
func chapter(index: int=-1) -> Dictionary:
 var chosen=campaign.state.mission_index if index<0 else index
 for item in catalog():
  if int(item.index)==chosen:return item
 return {}
func title() -> String:return mission_title(campaign.state.mission_index)
func mission_title(index: int) -> String:return str(chapter(index).get("title","Mission "+str(index)))
func dialogue_text(value) -> String:
 if value is Array:
  if value.size()==2 and value[0] is String:return (str(value[0])+": " if not str(value[0]).is_empty() else "")+str(value[1])
  var lines=PackedStringArray()
  for line in value:lines.append(dialogue_text(line))
  return "\n".join(lines)
 return str(value)
func say(value):
 dialogue_queue.clear()
 if value is Array and value.size()==2 and value[0] is String:dialogue_queue.append(value)
 elif value is Array:
  for line in value:
   if line is Array and line.size()==2:dialogue_queue.append(line)
 elif not str(value).is_empty():dialogue_queue.append(["Brutus",str(value)])
 dialogue_at=campaign.game.now;_update_dialogue()
func _update_dialogue():
 if dialogue_queue.is_empty() or campaign.game.now<dialogue_at:return
 var line=dialogue_queue.pop_front();var duration=clampf(str(line[1]).length()*.06,7,16)
 campaign.radio_notice(str(line[0]),str(line[1]));dialogue_at=campaign.game.now+duration;campaign.set_meta("notice_until",dialogue_at)
func ending_text() -> String:return dialogue_text(chapter().get("ending","The route ahead is open."))
func stage_data() -> Dictionary:
 var stages=chapter().get("stages",[])
 return stages[campaign.state.chapter_stage] if campaign.state.chapter_stage<stages.size() else {}
func start_mission(index: int) -> bool:return _start(index,false)
func start_standalone(index: int) -> bool:return _start(index,true)
func _start(index: int,standalone: bool) -> bool:
 var c=campaign;var spec=chapter(index)
 if c.game.is_client() or spec.is_empty():return false
 var stages=6 if index==2 else spec.get("stages",[]).size()
 if not c.state.begin_chapter(index,stages,standalone):return false
 clear_runtime();c.downed.clear();c.memory.clear();c.personal.clear();c.supply_at.clear();c.charge_carrier=0
 c.game.match_session=randi_range(1,2147483647);c.game.prepare_match_input()
 c.set_world("chapter_"+str(index));c.rebuild_heroes();c.apply_difficulty()
 _begin_stage();say(spec.get("briefing",""))
 return true
func _clear_weakpoint():
 if is_instance_valid(weakpoint):
  weakpoint.remove_meta("campaign_weakpoint")
  if weakpoint.get_parent()!=null:weakpoint.get_parent().remove_child(weakpoint)
  weakpoint.queue_free()
 weakpoint=null;weakpoint_visual=null
func clear_runtime():
 _clear_weakpoint()
 if motorcycles!=null:
  for visual in motorcycles.visuals.values():
   if is_instance_valid(visual):
    if visual.get_parent()!=null:visual.get_parent().remove_child(visual)
    visual.queue_free()
 weakpoint=null;weakpoint_visual=null;motorcycles=null;stage_spawned=false;clock=0;dialogue_queue.clear();hit_events.clear();hazard_hits.clear();last_visual_stage=-1
func _begin_stage():
 var c=campaign
 clock=0;stage_spawned=false;hit_events.clear();hazard_hits.clear()
 _clear_weakpoint()
 _remove_enemies()
 c.state.prepare_chapter_stage(0 if c.state.mission_index==2 else int(stage_data().get("enemies",4)))
 c.world.set_stage(c.state.chapter_stage)
 if c.state.mission_index==2:
  motorcycles=NestCampaignMotorcycles.new();motorcycles.campaign=c;motorcycles.setup(c.state.chapter_stage)
 _new_epoch();c.checkpoint_now();c.broadcast();c.present_phase()
 say(stage_data().get("dialogue",""))
func _new_epoch():
 var c=campaign
 if c.guide!=null:
  c.guide.stop_voice();c.guide.spoken_step="";c.guide.spoken_text="";c.guide.spoken_until=0;c.guide.spoken_at=-100;c.guide.welcome_until=0
 c.phase_elapsed=0;c.phase_epoch+=1;c.skip_votes.clear();c.load_deadline=c.game.local_clock()+45;c.last_present_phase=""
 for slot in c.members:c.members[slot].loaded=c.phase_epoch if int(slot)==c.local_slot else -1
func _remove_enemies():
 var c=campaign
 for actor in c.game.actors.duplicate():
  if actor.faction==1:c.game.actors.erase(actor);actor.queue_free()
 c.memory.clear()
func restore():
 var c=campaign
 clear_runtime();c.world.set_stage(c.state.chapter_stage);c.apply_difficulty()
 if c.state.mission_index==2:
  motorcycles=NestCampaignMotorcycles.new();motorcycles.campaign=c;motorcycles.setup(c.state.chapter_stage)
 else:
  # Checkpoints are taken before a stage spawns; restored combat is replayed fairly.
  stage_spawned=not c.state.chapter_spawned.is_empty()
  if c.state.chapter_flags.get("armed",false):_ensure_weakpoint()
func tick(delta: float):
 var c=campaign
 if c.game.is_client() or c.state.phase!="CHAPTER":return
 clock+=delta;_update_dialogue()
 if c.state.mission_index==2:
  if motorcycles==null:return
  motorcycles.tick(delta)
  if motorcycles.completed():chapter_complete()
  return
 if not stage_spawned:_spawn_stage()
 for id in c.state.chapter_enemies.keys():
  var enemy=c.game.actor_by_id(int(id))
  if enemy!=null and not enemy.alive:enemy.respawn_at=INF;c.state.defeat_chapter_enemy(int(id))
 var spec=stage_data()
 if c.state.chapter_flags.get("armed",false):
  if str(spec.get("mode","assault"))=="hold":
   var at: Vector3=c.world.locations.get("objective"+str(c.state.chapter_stage),Vector3.ZERO)
   var guarding=false
   for slot in c.connected_slots():
    var actor=c.game.actor_by_id(slot)
    if actor!=null and actor.alive and actor.global_position.distance_to(at)<10:guarding=true
   if guarding:c.state.chapter_progress["hold_seconds"]=minf(float(spec.get("hold_seconds",30)),float(c.state.chapter_progress.get("hold_seconds",0))+delta)
  if c.state.mission_index==9 and c.state.chapter_stage<3:_boss_hazards()
 visual_update()
func _spawn_stage():
 var c=campaign;var points=c.world.encounter_spawns(c.state.chapter_stage)
 if points.is_empty() and c.state.chapter_expected>0:return
 for i in range(c.state.chapter_expected):
  var id=-20000-c.state.mission_index*1000-c.state.chapter_stage*100-i
  if not c.state.register_chapter_enemy(id):continue
  var point: Vector3=points[i%points.size()]+Vector3.UP*.25
  var actor=c.make_actor(id,false,0,"Annu Defender",point)
  if i%3==1:actor.set_meta("ambush_wait",{"until":c.game.now+18,"health":actor.health,"shield":actor.shield})
  actor.rotation.y=0
 stage_spawned=true;c.broadcast()
func interaction(actor: NestActor) -> Dictionary:
 var c=campaign
 if c.state.phase!="CHAPTER" or actor==null or not actor.alive:return {}
 if c.state.mission_index==2:return motorcycles.interaction(actor) if motorcycles!=null else {}
 for i in range(chapter().get("evidence",[]).size()):
  if c.near(actor,"evidence"+str(i)):return c.choice("journey:evidence:"+str(i),"Inspect surviving record",.8)
 for i in range(c.state.chapter_stage_count):
  var supply="supply"+str(i)
  if c.near(actor,supply):return c.choice("journey:supply:"+str(i),"Refill expedition ammunition",.65)
 var key="objective"+str(c.state.chapter_stage)
 if not c.near(actor,key):return {}
 var spec=stage_data();var mode=str(spec.get("mode","assault"))
 if mode=="hold" and not c.state.chapter_flags.get("armed",false):return c.choice("journey:arm",str(spec.get("action","Activate relay")),float(spec.get("seconds",1.5)))
 if not c.state.chapter_clear():return {}
 if c.state.mission_index==9 and c.state.chapter_stage<3:
  if not c.state.chapter_flags.get("armed",false):return c.choice("journey:arm","Vent protective housing / expose machinery core",1.6)
  if float(c.state.chapter_progress.get("core_health",1))>0:return {}
 if mode=="hold" and float(c.state.chapter_progress.get("hold_seconds",0))<float(spec.get("hold_seconds",30)):return {}
 return c.choice("journey:objective",str(spec.get("action","Secure route")),clampf(float(spec.get("seconds",1.5)),.5,12))
func interact(actor: NestActor,action: String) -> bool:
 var c=campaign
 if c.game.is_client() or actor==null or not actor.alive or c.state.phase!="CHAPTER":return false
 if c.state.mission_index==2:return motorcycles.interact(actor,action) if motorcycles!=null else false
 var option=interaction(actor)
 if option.is_empty() or str(option.key).trim_prefix("campaign:")!=action:return false
 if action.begins_with("journey:evidence:"):
  var index=int(action.get_slice(":",2));var records=chapter().get("evidence",[])
  if index<0 or index>=records.size():return false
  say(records[index]);return true
 if action.begins_with("journey:supply:"):
  var key="chapter_supply"+action.get_slice(":",2)
  if c.game.now<float(c.supply_at.get(key,0)):return false
  c.supply_at[key]=c.game.now+20
  for i in range(actor.reserve.size()):actor.reserve[i]=maxi(actor.reserve[i],actor.weapons[i].reserve*2)
  actor.health=minf(actor.tuning.health_capacity,actor.health+actor.tuning.health_capacity*.3)
 elif action=="journey:arm":
  c.state.chapter_flags["armed"]=true;clock=0
  if c.state.mission_index==9 and c.state.chapter_stage<3:
   c.state.chapter_progress["core_health"]=float(stage_data().get("boss_health",220))*maxi(1,c.connected_slots().size())
   _ensure_weakpoint();c.radio_notice("Brutus","Floor lights warn before the discharge. Stay behind the barriers, then shoot the exposed gold core during its cooling cycle.")
  else:c.radio_notice("Brutus","Connection active. Stay within ten metres of the terminal while the transfer runs; the Annu must not hold this route.")
 elif action=="journey:objective":
  c.state.chapter_flags["objective"]=true
  if not c.state.finish_chapter_stage():return false
  if c.state.phase=="CHAPTER_COMPLETE":_finish_presentation()
  else:_begin_stage()
  return true
 else:return false
 c.state.revision+=1;c.broadcast();return true
func chapter_complete() -> bool:
 var c=campaign
 if c.game.is_client() or c.state.phase!="CHAPTER":return false
 # Ride completion is decided only by the physical motorcycle controller.
 if c.state.mission_index!=2 or motorcycles==null or not motorcycles.completed():return false
 c.state.chapter_stage=c.state.chapter_stage_count-1;c.state.chapter_flags["objective"]=true
 if not c.state.finish_chapter_stage():return false
 _finish_presentation();return true
func _finish_presentation():
 var c=campaign
 _remove_enemies();_new_epoch();c.checkpoint_now();c.broadcast();c.present_phase()
func ride_checkpoint(sector: int,seconds: float,distance: float):
 var c=campaign
 if c.game.is_client() or c.state.mission_index!=2 or c.state.phase!="CHAPTER" or sector<=c.state.chapter_stage or sector>=6:return
 c.state.chapter_stage=sector;c.state.chapter_progress["ride_seconds"]=seconds;c.state.chapter_progress["ride_distance"]=distance;c.state.revision+=1
 c.checkpoint_now();c.broadcast();say(stage_data().get("dialogue",""))
func objective() -> String:
 var c=campaign
 if c.state.phase=="CHAPTER_COMPLETE":return "MISSION %d COMPLETE / %s"%[c.state.mission_index,title().to_upper()]
 if c.state.mission_index==2:return motorcycles.objective() if motorcycles!=null else "MOUNT THE FOUR EXPEDITION MOTORCYCLES"
 var spec=stage_data();var instruction=str(spec.get("action","Secure route"))
 if c.state.mission_index==9 and c.state.chapter_stage<3 and c.state.chapter_flags.get("armed",false):
  instruction="SHOOT EXPOSED CORE / %d integrity"%int(c.state.chapter_progress.get("core_health",0))
  if float(c.state.chapter_progress.get("core_health",0))<=0:instruction="CORE DISABLED / confirm at marked terminal"
 elif str(spec.get("mode","assault"))=="hold" and c.state.chapter_flags.get("armed",false):instruction="HOLD NEAR RELAY / %d / %d seconds"%[int(c.state.chapter_progress.get("hold_seconds",0)),int(spec.get("hold_seconds",30))]
 elif not c.state.chapter_clear():instruction="CLEAR ANNU DEFENDERS / %d remaining"%maxi(0,c.state.chapter_expected-c.state.chapter_defeated.size())
 return "MISSION %d / %s\n%d / %d: %s\n%s"%[c.state.mission_index,title().to_upper(),c.state.chapter_stage+1,c.state.chapter_stage_count,str(spec.get("title","Route")),instruction]
func guidance() -> Dictionary:
 var c=campaign
 if c.state.phase!="CHAPTER":return {}
 var target="objective"+str(c.state.chapter_stage)
 var line=stage_data().get("dialogue",[]);var voice=str(line[1]) if line is Array and line.size()==2 and str(line[0])=="Brutus" else ""
 return {"id":"chapter_%d_%d"%[c.state.mission_index,c.state.chapter_stage],"title":title(),"text":objective(),"keys":c.game.prefs.key_label("jump")+" / jump    "+c.game.prefs.key_label("interact")+" / interact","voice":voice,"target":target,"target_label":str(stage_data().get("title","Next checkpoint"))}
func enemy_goal(actor: NestActor) -> Vector3:
 var seen=campaign.memory.get(actor.net_id,{})
 if not seen.is_empty():return seen.get("position",actor.global_position)
 return campaign.world.locations.get("objective"+str(campaign.state.chapter_stage),actor.global_position)
func _ensure_weakpoint():
 var c=campaign
 if c.state.mission_index!=9 or c.state.chapter_stage>=3 or is_instance_valid(weakpoint):return
 weakpoint=Area3D.new();weakpoint.name="AncientMachineryVulnerability";weakpoint.collision_layer=4;weakpoint.collision_mask=0;weakpoint.set_meta("campaign_weakpoint",self);c.world.add_child(weakpoint);weakpoint.global_position=c.world.boss_weakpoint(c.state.chapter_stage)
 var shape=CollisionShape3D.new();var sphere=SphereShape3D.new();sphere.radius=1.35;shape.shape=sphere;weakpoint.add_child(shape)
 weakpoint_visual=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=1.1;mesh.height=2.2;weakpoint_visual.mesh=mesh;weakpoint.add_child(weakpoint_visual)
 var material=StandardMaterial3D.new();material.albedo_color=Color("ffd283");material.emission_enabled=true;material.emission=Color("ffbb55");material.emission_energy_multiplier=2;weakpoint_visual.material_override=material
func hit_weakpoint(actor: NestActor,amount: float,event_id: int) -> bool:
 var c=campaign
 if c.game.is_client() or actor==null or not actor.alive or actor.faction!=0 or c.state.phase!="CHAPTER" or c.state.mission_index!=9 or not c.state.chapter_flags.get("armed",false):return false
 if not is_finite(amount) or amount<=0 or not is_instance_valid(weakpoint):return false
 var cycle=fmod(clock,6.0)
 if cycle>3.2 or float(c.state.chapter_progress.get("core_health",0))<=0:return false
 var key=str(actor.net_id)+":"+str(event_id)
 if hit_events.has(key):return false
 hit_events[key]=true;c.state.chapter_progress["core_health"]=maxf(0,float(c.state.chapter_progress.core_health)-minf(amount,150));c.state.revision+=1
 c.game.hit_until=c.game.now+.16;c.broadcast();return true
func _boss_hazards():
 var c=campaign;var cycle=fmod(clock,6.0);var beat=int(clock/6)
 if cycle<5.2:return
 var center=Vector3(-24+posmod(beat,3)*24,0,-55)
 for slot in c.connected_slots():
  var actor=c.game.actor_by_id(slot)
  if actor==null or not actor.alive:continue
  var offset=actor.global_position-center
  # Alternating floor lanes leave clear side pockets and solid cover protects.
  var in_lane=absf(offset.x)<6.5 and absf(offset.z)<33
  var event="%d:%d"%[beat,slot]
  if in_lane and not hazard_hits.has(event) and c.visible_between(Vector3(0,8,-55),actor.global_position+Vector3.UP*.7):
   hazard_hits[event]=true;actor.take_damage(35 if c.state.difficulty=="Easy" else 55,"torso","heavy",false,null,700000+c.state.chapter_stage*10000+beat*10+slot,center+Vector3.UP*3,"",0,actor.global_position)
func visual_update():
 var c=campaign
 if c.world==null or c.state.mission_index<2:return
 if last_visual_stage!=c.state.chapter_stage:
  _clear_weakpoint();c.world.set_stage(c.state.chapter_stage);last_visual_stage=c.state.chapter_stage
 if c.state.mission_index==9:
  c.world.set_boss_state(c.state.chapter_stage,clock if c.state.chapter_flags.get("armed",false) else -1)
  if c.state.chapter_flags.get("armed",false) and c.state.chapter_stage<3:_ensure_weakpoint()
  elif is_instance_valid(weakpoint):_clear_weakpoint()
  if is_instance_valid(weakpoint_visual):
   var cycle=fmod(clock,6.0);weakpoint_visual.visible=float(c.state.chapter_progress.get("core_health",0))>0;weakpoint_visual.scale=Vector3.ONE*(1.0 if cycle<=3.2 else .65)
func pack() -> Dictionary:return {"clock":clock,"motorcycles":motorcycles.pack() if motorcycles!=null else {}}
func receive(packet: Dictionary):
 var c=campaign
 if c.world==null:return
 var world_id=c.world.get_instance_id()
 if runtime_mission!=c.state.mission_index or runtime_session!=c.game.match_session or runtime_world!=world_id:
  clear_runtime();runtime_mission=c.state.mission_index;runtime_session=c.game.match_session;runtime_world=world_id
 clock=maxf(0,float(packet.get("clock",0)))
 if c.state.mission_index==2:
  if motorcycles==null:motorcycles=NestCampaignMotorcycles.new();motorcycles.campaign=c;motorcycles.setup(c.state.chapter_stage)
  motorcycles.receive(packet.get("motorcycles",{}))
 visual_update()
