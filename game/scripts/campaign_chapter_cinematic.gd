class_name NestCampaignChapterCinematic
extends RefCounted
# Three five-second shots use existing expedition/Annu actors and authored terrain.
# Staged sentries use the established Annu rig; this director creates no actors.
const DURATION=15.0
const SHOT_SECONDS=5.0
var presenter
var presented_heroes=[]
func present(elapsed: float,outro: bool):
 var c=presenter.campaign;var chapter=c.journey.chapter();var shot=clampi(int(elapsed/SHOT_SECONDS),0,2);var u=clampf(fmod(elapsed,SHOT_SECONDS)/SHOT_SECONDS,0,1)
 if c.state.mission_index==9 and is_instance_valid(c.world.ship_root):
  var departure=smoothstep(0,1,clampf((elapsed-10.0)/5.0,0,1)) if outro else 0.0
  c.world.ship_root.position=Vector3(0,departure*18,-departure*12)
 present_actors(c)
 animate_sentries(c,elapsed)
 var cues=chapter.get("ending" if outro else "briefing",[])
 var cue=cues[shot] if shot<cues.size() else ["Brutus","The expedition continues."]
 var frame=shot_frame(c,shot,u,outro)
 presenter.camera.global_position=frame.position;presenter.camera.look_at(frame.target,Vector3.UP);presenter.camera.fov=58.0 if shot==2 else 65.0
 presenter.title.text="%02d / %s / %s"%[c.state.mission_index,str(chapter.get("title","Old Earth")).to_upper(),"DEPARTURE" if outro else "ARRIVAL"]
 var speaker=str(cue[0]);presenter.subtitle.text=(speaker.to_upper()+": " if not speaker.is_empty() else "")+str(cue[1])
 if c.all_loaded():
  var id="chapter_%d_%s_%d"%[c.state.mission_index,"outro" if outro else "intro",shot]
  var path="res://audio/campaign/"+id+".wav"
  if ResourceLoader.exists(path):presenter.play_slot(id,path,fmod(elapsed,SHOT_SECONDS))
  else:presenter.speak_fallback(id,str(cue[1]),.8 if speaker=="Ancient AI" else .9 if speaker=="Brutus" else .94 if speaker.begins_with("Annu") else 1.0)
func shot_frame(c,shot: int,u: float,outro: bool) -> Dictionary:
 var world=c.world;var stage=3 if outro else 0
 if c.state.mission_index==9 and outro and shot==2 and is_instance_valid(world.ship_root):
  var ship=world.ship_position+world.ship_root.position
  return {"position":safe_camera(world,ship+Vector3(17,9,28).lerp(Vector3(24,13,35),u)),"target":ship+Vector3.UP*2.0}
 var cues=c.journey.chapter().get("ending" if outro else "briefing",[])
 if shot<cues.size() and str(cues[shot][0]).begins_with("Annu"):
  var sentry=defender_frame(c,u,1 if str(cues[shot][0])=="Annu sentry" else 0)
  if not sentry.is_empty():return sentry
 if c.state.mission_index==2:
  var distance=NestCampaignMotorcycleWorld.ROAD_LENGTH-12 if outro else 32.0
  var road=NestCampaignMotorcycleWorld.point(distance)
  if not outro and shot==2:
   var bikes=NestCampaignMotorcycleWorld.point(8)
   return {"position":safe_camera(world,bikes+Vector3(10,5,16).lerp(Vector3(7,4,13),u)),"target":bikes+Vector3.UP*1.2}
  var aims=[road+Vector3(0,2,-16),road+Vector3(0,2,-26),road+Vector3(0,1.3,8)]
  var starts=[road+Vector3(26,17,29),road+Vector3(-24,9,4),road+Vector3(8,4,20)]
  var ends=[road+Vector3(19,21,17),road+Vector3(-18,11,-7),road+Vector3(5,3.5,14)]
  return {"position":safe_camera(world,starts[shot].lerp(ends[shot],smoothstep(0,1,u))),"target":aims[shot]}
 var objective: Vector3=world.locations.get("objective"+str(stage),world.checkpoint_spawn(stage,1))
 if c.state.mission_index==8:return reserve_frame(c,shot,u,outro,objective)
 var hero=c.game.actor_by_id(c.local_slot)
 var anchor=objective
 if shot==2 and hero!=null and (not outro or hero.global_position.distance_to(objective)<35):anchor=hero.global_position
 var aim=objective+Vector3.UP*2.2
 var start=objective+Vector3(-27,19,30);var finish=objective+Vector3(-17,24,18)
 if shot==1:
  aim=objective+Vector3(0,5,-11);start=objective+Vector3(25,11,9);finish=objective+Vector3(18,13,-3)
 elif shot==2:
  aim=anchor+Vector3.UP*1.3;start=anchor+Vector3(-6,4,9);finish=anchor+Vector3(-3.8,3,6)
 if c.state.mission_index==9 and shot==0:
  var engine=Vector3(0,12,-55);aim=engine;start=Vector3(-33,29,-18);finish=Vector3(-24,33,-36)
  if outro:aim=world.locations.get("exit",objective)+Vector3.UP*5;start=aim+Vector3(-28,20,31);finish=aim+Vector3(-17,25,18)
 var position=safe_camera(world,start.lerp(finish,smoothstep(0,1,u)))
 if position.distance_to(aim)<2:position+=Vector3(0,3,5)
 return {"position":position,"target":aim}
func cinematic_sentries(c) -> Array:
 var actors=[]
 for actor in c.game.actors:
  if actor.faction==1 and actor.alive:actors.append(actor)
 actors.sort_custom(func(a,b):return a.net_id>b.net_id)
 return actors
func animate_sentries(c,elapsed: float):
 for actor in cinematic_sentries(c):
  if not actor.has_meta("cinematic_annu") and actor.net_id> -90000:continue
  if actor.animation==null or not actor.clips.has("idle"):continue
  var clip=actor.clips.idle
  if actor.animation.current_animation!=clip:actor.animation.play(clip)
  var duration=actor.animation.get_animation(clip).length
  actor.animation.seek(fmod(elapsed+absf(actor.net_id)*.19,maxf(duration,.1)),true)
  if actor.skeleton!=null:
   var head=actor.skeleton.find_bone("head")
   if head>=0:
    if not actor.has_meta("cinematic_head_base"):actor.set_meta("cinematic_head_base",actor.skeleton.get_bone_pose_rotation(head))
    actor.skeleton.set_bone_pose_rotation(head,actor.get_meta("cinematic_head_base")*Quaternion(Vector3.UP,sin(elapsed*.8+actor.net_id)*.12))
func present_actors(c):
 for label in c.world.station_signs.values():label.visible=false
 for actor in c.game.actors:
  if actor.faction!=0 or not actor.alive or not actor.local_player:continue
  if not presented_heroes.has(actor):presented_heroes.append(actor)
  if actor.model!=null:actor.model.visible=true
  if actor.weapon_view!=null:actor.weapon_view.visible=false
  if actor.camera!=null:actor.camera.visible=false
func release_actors():
 if presented_heroes.is_empty():return
 for actor in presented_heroes:
  if not is_instance_valid(actor):continue
  actor.refresh_model_visibility()
  if actor.camera!=null:actor.camera.visible=true
  if actor.weapon_view!=null:actor.weapon_view.visible=actor.alive and not actor.is_motorcycle_rider() and not actor.scoped_overlay() and not actor.weapons.is_empty() and actor.weapons[actor.slot].kind!="none"
 presented_heroes.clear()
 if presenter!=null and presenter.campaign.guide!=null:presenter.campaign.guide.update(true)
func reserve_frame(c,shot: int,u: float,outro: bool,objective: Vector3) -> Dictionary:
 var center=c.world.stage_center(3 if outro else 0)
 var start=center+Vector3(3,6.0,17);var finish=center+Vector3(0,5.4,13)
 var aim=objective+Vector3.UP*2.8
 if shot==2:
  var anchor=objective;var hero=c.game.actor_by_id(c.local_slot)
  if hero!=null and (not outro or hero.global_position.distance_to(objective)<35):anchor=hero.global_position
  aim=anchor+Vector3.UP*1.35;start=anchor+Vector3(6,3.2,8);finish=anchor+Vector3(4,2.9,6)
 return {"position":safe_camera(c.world,start.lerp(finish,smoothstep(0,1,u))),"target":aim}
func defender_frame(c,u: float,speaker_index=0) -> Dictionary:
 var sentries=cinematic_sentries(c)
 if sentries.is_empty():return {}
 var defender=sentries[mini(speaker_index,sentries.size()-1)]
 var aim=defender.global_position+Vector3.UP*1.4
 var lane_x=NestCampaignMotorcycleWorld.center_x(-defender.global_position.z) if c.state.mission_index==2 else 0.0
 var inward=1.0 if defender.global_position.x<lane_x else -1.0
 # Look from the walking lane toward the defender; an outward camera would be
 # inside the vault racks and pipework attached to the outer walls.
 var offset=Vector3(inward*4.6,2.8,6.8).lerp(Vector3(inward*3.2,2.4,5.2),smoothstep(0,1,u))
 var position=safe_camera(c.world,defender.global_position+offset)
 if not c.game.trace(position,aim,1).is_empty():
  for alternative in [Vector3(0,3,6),Vector3(inward*5,3,0),Vector3(0,3,-5),Vector3(inward*2,2.5,2.5)]:
   var candidate=safe_camera(c.world,defender.global_position+alternative)
   if c.game.trace(candidate,aim,1).is_empty():position=candidate;break
 if defender.has_meta("cinematic_annu") or defender.net_id<= -90000:
  var look=position-defender.global_position;defender.rotation.y=atan2(-look.x,-look.z)
 return {"position":position,"target":aim}
func safe_camera(world,position: Vector3) -> Vector3:
 if world.has_method("surface_height"):
  var floor_height=float(world.surface_height(position))
  if is_finite(floor_height) and floor_height> -1000:position.y=maxf(position.y,floor_height+3.0)
 return position
