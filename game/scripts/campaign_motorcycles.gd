class_name NestCampaignMotorcycles
extends RefCounted
const REQUIRED_RIDE_SECONDS=300.0
const SPEED_MULTIPLIER=4.0
var campaign
var bikes={}
var visuals={}
var spawned_ambushes={}
var next_spawn_check=0.0
var stage_saved=0
var engine_stream: AudioStreamWAV
var cockpit: Node3D
var speed_display: Label3D
func setup(stage=0):
 for child in campaign.world.get_children():
  if str(child.name).begins_with("ExpeditionMotorcycle_"):
   campaign.world.remove_child(child);child.queue_free()
 bikes.clear();visuals.clear();spawned_ambushes.clear();stage_saved=clampi(stage,0,5);next_spawn_check=0
 var prior=float(campaign.state.chapter_progress.get("ride_seconds",0))
 for slot in range(1,5):
  var at=NestCampaignMotorcycleWorld.spawn(stage_saved,slot)
  bikes[slot]={"slot":slot,"mounted":false,"crashed":false,"position":at,"heading":NestCampaignMotorcycleWorld.heading(-at.z),"speed":0.0,"pitch":0.0,"roll":0.0,"vertical":0.0,"airtime":0.0,"ride_seconds":prior,"distance":-at.z,"jump_lock":0.0,"crash_until":0.0,"last_ramp":-1.0,"jumps":0,"crashes":0,"interaction_needs_release":false}
  create_visual(slot)
 visual_update()
func create_visual(slot: int):
 if visuals.has(slot) and is_instance_valid(visuals[slot]):return
 var root=Node3D.new();root.name="ExpeditionMotorcycle_%d"%slot;campaign.world.add_child(root)
 var k=campaign.world.kit;var metal=k.material(Color("748c89"),.7);var rubber=k.material(Color("141c1f"));var seat=k.material(Color("313639"));var accent=k.material([Color("8cd1ca"),Color("ccb46c"),Color("b2bb98"),Color("c39f8e")][slot-1],.3)
 for z in [-.95,1.0]:
  var wheel=k.cylinder(root,Vector3(0,.48,z),.46,.23,rubber);wheel.rotation.z=PI*.5
  var hub=k.cylinder(root,Vector3(0,.48,z),.23,.25,metal);hub.rotation.z=PI*.5
  for side in [-1,1]:
   var disc=k.cylinder(root,Vector3(side*.14,.48,z),.32,.025,k.dark);disc.rotation.z=PI*.5
   k.branch(root,Vector3(side*.2,.52,z),Vector3(side*.2,1.12,z+.15),.055,metal)
 k.box(root,Vector3(0,.73,.05),Vector3(.5,.48,1.65),k.dark)
 k.box(root,Vector3(0,1.02,-.35),Vector3(.65,.44,.75),accent)
 k.box(root,Vector3(0,1.12,.45),Vector3(.57,.18,.83),seat)
 k.box(root,Vector3(0,1.13,1.0),Vector3(.85,.24,.42),metal)
 for side in [-1,1]:
  k.box(root,Vector3(side*.42,.76,.78),Vector3(.35,.62,.72),accent)
  k.box(root,Vector3(side*.44,.92,.82),Vector3(.38,.09,.76),k.gold)
  k.branch(root,Vector3(side*.18,.65,-.45),Vector3(side*.48,.32,.6),.06,metal)
  k.box(root,Vector3(side*.43,.42,.08),Vector3(.42,.08,.25),metal)
  var exhaust=k.cylinder(root,Vector3(side*.34,.55,.62),.075,.95,k.dark);exhaust.rotation.x=PI*.5
 k.branch(root,Vector3(-.6,1.35,-.83),Vector3(.6,1.35,-.83),.055,metal)
 for side in [-1,1]:k.box(root,Vector3(side*.5,1.35,-.83),Vector3(.3,.11,.13),rubber)
 k.box(root,Vector3(0,1.12,-1.02),Vector3(.42,.22,.07),k.lamp)
 k.box(root,Vector3(0,1.42,-.6),Vector3(.3,.12,.22),k.dark)
 k.box(root,Vector3(0,1.49,-.62),Vector3(.22,.02,.14),k.lamp)
 var label=k.label(root,Vector3(0,2.1,0),"BIKE %d / HOLD INTERACT"%slot,Color("bce7dc"),21);label.visible=true;label.visibility_range_end=16
 NestRigidBatch.build(root);visuals[slot]=root
 if DisplayServer.get_name()!="headless" and campaign.cinematic!=null:
  if engine_stream==null:engine_stream=campaign.cinematic.engine_track()
  var engine=AudioStreamPlayer3D.new();engine.name="MotorcycleEngine";engine.stream=engine_stream;engine.bus="Campaign_Effects";engine.unit_size=5;engine.max_distance=45;engine.volume_db=-27;root.add_child(engine)
func create_cockpit(actor):
 if actor.camera==null:return
 cockpit=Node3D.new();cockpit.name="MotorcycleCockpit";actor.camera.add_child(cockpit)
 var k=campaign.world.kit
 k.branch(cockpit,Vector3(-.47,-.38,-.77),Vector3(.47,-.38,-.77),.024,k.dark)
 for side in [-1,1]:
  k.box(cockpit,Vector3(side*.43,-.38,-.77),Vector3(.17,.055,.065),k.dark)
  k.branch(cockpit,Vector3(side*.14,-.5,-.87),Vector3(side*.28,-.38,-.77),.018,k.gold)
  var hand=NestViewArms.create(actor.character,"l" if side<0 else "r","hand");cockpit.add_child(hand);hand.position=Vector3(side*.41,-.37,-.73);hand.scale=Vector3.ONE*.9;hand.rotation.x=-PI*.5
 k.box(cockpit,Vector3(0,-.30,-.87),Vector3(.26,.13,.05),k.dark)
 k.box(cockpit,Vector3(0,-.29,-.838),Vector3(.22,.085,.014),k.lamp)
 speed_display=k.label(cockpit,Vector3(0,-.285,-.825),"0 KM/H",Color("173937"),24);speed_display.pixel_size=.0012;speed_display.billboard=BaseMaterial3D.BILLBOARD_DISABLED;speed_display.visible=true
 NestRigidBatch.build(cockpit)
func pose_rider(actor):
 if handles(actor):
  actor.set_meta("motorcycle_pose",true)
  actor.model.rotation.y=wrapf(float(bikes[actor.net_id].heading)-actor.rotation.y,-PI,PI)
  if actor.presentation!=null:
   actor.presentation.arm_ik("l",Vector3(-.39,1.07,-.65));actor.presentation.arm_ik("r",Vector3(.39,1.07,-.65))
  if actor.remote_weapon!=null:actor.remote_weapon.visible=false
 elif actor.has_meta("motorcycle_pose"):
  actor.remove_meta("motorcycle_pose");actor.model.rotation.y=0
  if actor.remote_weapon!=null:actor.remote_weapon.visible=true
func handles(actor) -> bool:
 return campaign!=null and campaign.active and campaign.state.mission_index==2 and bikes.has(actor.net_id) and bool(bikes[actor.net_id].mounted) and actor.alive
static func normal_speed(actor) -> float:
 return actor.tuning.ground_speed*actor.traits.movement_speed_percent/100.0*actor.traits.walk_speed_percent/100.0
static func max_speed(actor) -> float:return normal_speed(actor)*SPEED_MULTIPLIER
func interaction(actor) -> Dictionary:
 if bikes.has(actor.net_id) and bikes[actor.net_id].get("interaction_needs_release",false):return {}
 if handles(actor):return campaign.choice("bike:dismount:"+str(actor.net_id),"Dismount motorcycle (brake first)",.35) if float(bikes[actor.net_id].speed)<3 else {}
 # Each established squad seat owns one machine. Empty seats remain empty bikes.
 if not bikes.has(actor.net_id):return {}
 var b=bikes[actor.net_id]
 if actor.global_position.distance_to(b.position)>3:return {}
 if b.crashed:
  return campaign.choice("bike:recover:"+str(actor.net_id),"Right overturned motorcycle / exposed to Annu",1.6)
 return campaign.choice("bike:mount:"+str(actor.net_id),"Mount expedition motorcycle %d"%actor.net_id,.6)
func interact(actor,action: String) -> bool:
 if campaign.game.is_client() or not action.begins_with("bike:") or not bikes.has(actor.net_id):return false
 var parts=action.split(":")
 if parts.size()!=3 or int(parts[2])!=actor.net_id:return false
 var b=bikes[actor.net_id]
 if parts[1]=="dismount" and b.mounted and b.speed<3:
  b.mounted=false;b.interaction_needs_release=true;b.position=actor.global_position;b.speed=0;actor.controlled=Vector3.ZERO;actor.velocity=Vector3.ZERO;actor.reset_crouch();campaign.broadcast();return true
 if b.mounted or actor.global_position.distance_to(b.position)>3:return false
 if parts[1]=="recover" and b.crashed:
  if campaign.game.now<float(b.crash_until):return false
  b.crashed=false;b.interaction_needs_release=true;b.pitch=0;b.roll=0;b.speed=0;b.position.y=.25;b.heading=NestCampaignMotorcycleWorld.heading(-b.position.z);campaign.broadcast();return true
 if parts[1]=="mount" and not b.crashed:
  b.mounted=true;b.interaction_needs_release=true;b.speed=0;b.pitch=0;b.airtime=0;actor.global_position=b.position;actor.controlled=Vector3.ZERO;actor.external=Vector3.ZERO;actor.velocity=Vector3.ZERO;actor.reset_crouch();actor.rotation.y=b.heading;actor.eye.rotation.x=0;actor.reset_aim();campaign.broadcast();return true
 return false
func crash(actor,b: Dictionary,reason: String):
 if campaign.game.is_client():return
 b.mounted=false;b.crashed=true;b.crashes+=1;b.speed=0;b.position=actor.global_position;b.crash_until=campaign.game.now+1.5;b.roll=1.3
 actor.controlled=Vector3.ZERO;actor.velocity=Vector3.ZERO;actor.external=Vector3.ZERO;actor.reset_crouch()
 actor.take_damage(18,"torso","explosion",false,null,campaign.game.next_event()*16)
 campaign.radio_notice("Brutus",reason+" Find cover, then hold Interact to right your motorcycle. Annu have a clear shot when you stop.")
func movement_step(actor,move: Vector2,jump: bool,_yaw: float,delta: float,replaying=false) -> bool:
 if not handles(actor):return false
 # Vehicle physics is host authoritative. Guests transmit ordinary command input
 # and follow authoritative actor transforms, never replay a stale crash state.
 if campaign.game.is_client():
  var predicted=bikes[actor.net_id];var steering_rate=lerpf(1.5,.72,clampf(float(predicted.speed)/max_speed(actor),0,1));var steering_delta=-move.x*steering_rate*delta*clampf(float(predicted.speed)/3,0,1)
  predicted.heading+=steering_delta;actor.rotation.y+=steering_delta
  return jump
 var b=bikes[actor.net_id];var top=max_speed(actor);var supported=actor.is_on_floor();var before=actor.global_position
 var throttle=maxf(0,-move.y);var brake=maxf(0,move.y)
 b.jump_lock=maxf(0,float(b.jump_lock)-delta)
 b.speed=move_toward(float(b.speed),top*throttle,(18.0 if throttle>0 else 7.0)*delta)
 if brake>0:b.speed=maxf(0,float(b.speed)-32*brake*delta)
 var lateral=absf(actor.global_position.x-NestCampaignMotorcycleWorld.center_x(-actor.global_position.z))
 if lateral>11.5:b.speed=move_toward(float(b.speed),top*.34,16*delta)
 var turn_rate=lerpf(1.5,.72,clampf(float(b.speed)/top,0,1))
 var heading_delta=-move.x*turn_rate*delta*clampf(float(b.speed)/3,0,1)
 b.heading+=heading_delta
 if actor.local_player:actor.rotation.y+=heading_delta
 b.roll=lerpf(float(b.roll),-move.x*.36*float(b.speed)/top,minf(1,delta*8))
 var jumped=false
 if supported:
  if float(b.airtime)>.22:
   if absf(float(b.pitch))>.87 and b.speed>top*.35:crash(actor,b,"Bad landing: the bike flipped.");return false
   if float(b.airtime)>.35:b.jumps+=1
  b.airtime=0;b.pitch=move_toward(float(b.pitch),0,delta*3);actor.controlled.y=-.4
  if jump and b.jump_lock<=0 and b.speed>4:
   actor.controlled.y=5.8;b.jump_lock=.6;jumped=true
 else:
  b.airtime+=delta;b.pitch=clampf(float(b.pitch)+move.y*1.35*delta,-2.4,2.4)
  if absf(move.y)<.05:b.pitch=move_toward(float(b.pitch),0,delta*1.8)
  actor.controlled.y=maxf(-30,actor.controlled.y-16*delta)
 # A marked ramp kicks the suspension at its physical crest. Its sloped solid
 # mesh also supports ordinary on-foot traversal and can be taken or bypassed.
 var ramp=NestCampaignMotorcycleWorld.ramp_info(-actor.global_position.z)
 if not ramp.is_empty() and absf(actor.global_position.x-float(ramp.x))<float(ramp.width)*.5 and -actor.global_position.z>=float(ramp.crest) and float(b.last_ramp)!=float(ramp.start) and b.speed>top*.4:
  b.last_ramp=ramp.start;actor.controlled.y=maxf(actor.controlled.y,6.7);b.airtime=.02;b.pitch=-.12;jumped=true
 var direction=Vector3(-sin(float(b.heading)),0,-cos(float(b.heading)))
 actor.controlled.x=direction.x*float(b.speed);actor.controlled.z=direction.z*float(b.speed);actor.external=Vector3.ZERO;actor.velocity=actor.controlled
 actor.move_and_slide()
 if not replaying:
  for index in range(actor.get_slide_collision_count()):
   var normal=actor.get_slide_collision(index).get_normal()
   if normal.y<.5 and -direction.dot(normal)>.3 and b.speed>top*.44:
    crash(actor,b,"Tree or barrier collision: the rider was thrown clear.");return jumped
 var forward=maxf(0,before.z-actor.global_position.z)
 if forward>.01 and b.speed>top*.35:
  b.ride_seconds+=delta;b.distance=maxf(float(b.distance),-actor.global_position.z)
 b.position=actor.global_position
 if actor.global_position.y< -12:crash(actor,b,"The bike left the causeway.");actor.global_position=NestCampaignMotorcycleWorld.point(clampf(float(b.distance),0,NestCampaignMotorcycleWorld.ROAD_LENGTH))+Vector3.UP*.3;b.position=actor.global_position
 return jumped
func tick(_delta: float):
 if campaign.game.is_client():return
 for slot in bikes:
  var actor=campaign.game.actor_by_id(slot)
  if actor!=null and bikes[slot].get("interaction_needs_release",false):
   var held=actor.gameplay_held("interact") if actor.local_player else actor.net_interact
   if not held:bikes[slot].interaction_needs_release=false
  if actor!=null and not actor.alive and bikes[slot].mounted:
   bikes[slot].mounted=false;bikes[slot].position=actor.global_position;bikes[slot].speed=0
 var distance=min_progress("distance");var seconds=min_progress("ride_seconds")
 var sector=mini(5,floori(distance/NestCampaignMotorcycleWorld.SECTOR_LENGTH))
 if sector>stage_saved:
  stage_saved=sector;campaign.journey.ride_checkpoint(sector,seconds,distance)
 if campaign.game.now<next_spawn_check:return
 next_spawn_check=campaign.game.now+.5
 for sector_id in range(6):
  var positions=NestCampaignMotorcycleWorld.encounter_spawns(sector_id)
  for index in range(positions.size()):
   var id=-22000-sector_id*100-index
   if spawned_ambushes.has(id):continue
   var at=positions[index];var nearby=false
   for slot in campaign.connected_slots():
    var actor=campaign.game.actor_by_id(slot)
    if actor!=null and actor.alive and absf(actor.global_position.z-at.z)<180:nearby=true;break
   if nearby:
    var enemy=campaign.make_actor(id,false,0,"Annu Road Defender",at+Vector3.UP*.25)
    var sightline=NestCampaignMotorcycleWorld.point(-at.z)-at
    enemy.rotation.y=atan2(-sightline.x,-sightline.z);enemy.set_meta("bike_ambush",true);spawned_ambushes[id]=true
 for enemy in campaign.game.actors.duplicate():
  if not enemy.has_meta("bike_ambush"):continue
  var distant=true
  for slot in campaign.connected_slots():
   var actor=campaign.game.actor_by_id(slot)
   if actor!=null and actor.alive and actor.global_position.distance_to(enemy.global_position)<240:distant=false;break
  if distant:
   campaign.game.actors.erase(enemy);enemy.queue_free()
func bot_intent(actor,delta: float) -> Dictionary:
 if not actor.has_meta("bike_ambush"):return {}
 # Ordinary weapon tracing, cover and shield damage apply. Fast riders still
 # may be hit; slowing gives the same Annu far more tracking and firing time.
 actor.bot_stationary_fire(delta)
 return {"move":Vector2.ZERO,"jump":false}
func min_progress(key: String) -> float:
 var value=INF;var count=0
 for slot in campaign.connected_slots():
  var actor=campaign.game.actor_by_id(slot)
  if actor==null or not actor.alive or not bikes.has(slot):continue
  value=minf(value,float(bikes[slot].get(key,0)));count+=1
 return value if count>0 else 0.0
func completed() -> bool:
 return min_progress("distance")>=NestCampaignMotorcycleWorld.ROAD_LENGTH-5 and min_progress("ride_seconds")>=REQUIRED_RIDE_SECONDS
func objective() -> String:
 var b=bikes.get(campaign.local_slot,{})
 if b.is_empty():return "Reach the floodgate through the forest corridor."
 var distance=maxf(0,NestCampaignMotorcycleWorld.ROAD_LENGTH-float(b.distance));var actor=campaign.game.actor_by_id(campaign.local_slot)
 var top=max_speed(actor) if actor!=null else 26.0
 var status="OVERTURNED / HOLD INTERACT TO RECOVER" if b.crashed else "HOLD INTERACT TO MOUNT" if not b.mounted else "THROTTLE / STEER / BRAKE FOR LANDINGS"
 return "BROKEN CANOPY / %s\n%.1f KM REMAIN / %.0f KM/H / TOP %.0f KM/H (4x)\n%s\nW throttle / S brake / A D steer / Space hop. Release W in air to level.\nAnnu punish slow or fallen riders. Four bikes; one per expedition member."%[NestCampaignMotorcycleWorld.SECTOR_NAMES[clampi(floori(float(b.distance)/NestCampaignMotorcycleWorld.SECTOR_LENGTH),0,5)],distance/1000,float(b.speed)*3.6,top*3.6,status]
func pack() -> Dictionary:
 return {"bikes":bikes.duplicate(true),"stage":stage_saved}
func receive(packet: Dictionary):
 if not packet.get("bikes") is Dictionary or packet.bikes.size()!=4:return
 for slot in range(1,5):
  var incoming=packet.bikes.get(slot,packet.bikes.get(str(slot),{}))
  if not incoming is Dictionary or not incoming.get("position") is Vector3 or not incoming.position.is_finite():return
  for field in ["speed","heading","pitch","roll","ride_seconds","distance"]:
   if not incoming.has(field) or not is_finite(float(incoming[field])):return
 for slot in range(1,5):
  bikes[slot]=packet.bikes.get(slot,packet.bikes.get(str(slot))).duplicate(true)
  create_visual(slot)
 stage_saved=clampi(int(packet.get("stage",0)),0,5)
func visual_update():
 for slot in bikes:
  if not visuals.has(slot) or not is_instance_valid(visuals[slot]):create_visual(slot)
  var b=bikes[slot];var visual=visuals[slot];var actor=campaign.game.actor_by_id(slot)
  var at=actor.global_position if b.mounted and actor!=null else b.position
  visual.visible=not (b.mounted and actor!=null and actor.local_player)
  visual.position=at;visual.rotation=Vector3(float(b.pitch),float(b.heading),float(b.roll))
  for label in visual.find_children("*","Label3D",true,false):label.visible=not b.mounted
  if actor!=null and actor.weapon_view!=null:actor.weapon_view.visible=not b.mounted
  var engine=visual.get_node_or_null("MotorcycleEngine")
  if engine!=null:
   var audible=b.mounted and not campaign.paused() and campaign.state.phase=="CHAPTER"
   if audible and not engine.playing:engine.play()
   elif not audible and engine.playing:engine.stop()
   engine.pitch_scale=.75+clampf(float(b.speed)/27.0,0,1)*1.4;engine.volume_db=-27+minf(float(b.speed)/27.0,1)*5
  if actor!=null and actor.local_player:
   if not is_instance_valid(cockpit):create_cockpit(actor)
   if is_instance_valid(cockpit):
    cockpit.visible=b.mounted and actor.alive
    cockpit.rotation.z=float(b.roll)*.25
    speed_display.text="%d KM/H"%roundi(float(b.speed)*3.6)
