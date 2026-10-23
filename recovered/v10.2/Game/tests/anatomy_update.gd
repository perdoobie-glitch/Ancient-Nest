extends SceneTree
var game
var checks=0
var failures=0
var audio_events=[]
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func frames(n=3):
 for i in range(n):await process_frame
func v(a):return Vector3(a[0],a[1],a[2])
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 game.bot_fill=false;game.team_size=1;game.mode=1;game.start_game();game.set_physics_process(false)
 game.audio.playback_enabled=true;game.audio.sound_started.connect(func(id,_path,_voice):audio_events.append(id))
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.position=Vector3(500,50,500);p.reset_physics_interpolation();p.reset_aim()
 var actors=[]
 for character in [0,1]:
  var actor=NestActor.new();actor.game=game;actor.character_choice=character;actor.faction=1;game.add_child(actor);game.actors.append(actor);actor.respawn();actor.set_physics_process(false);actor.set_process(false);actor.position=Vector3(500+character*3,50,490);actor.update_visual(.016);actors.append(actor)
  check(actor.hitboxes.size()==17 and actor.hitbox_shapes.all(func(shape):return shape is ConvexPolygonShape3D),"Character %d uses 17 convex anatomical damage regions"%character)
  check(actor.pose_offsets.size()==actor.hitboxes.size(),"Every anatomical region follows a valid animation bone")
  check(actor.hitboxes.all(func(h):return h.get_meta("region") in ["head","torso","arm","leg"] and h.collision_layer==4 and h.collision_mask==0),"Damage regions retain collision layer and damage routing")
  check(actor.hitboxes.any(func(h):return String(h.name).begins_with("Hit_hand")) and actor.hitboxes.any(func(h):return String(h.name).begins_with("Hit_foot")),"Hands and feet now have damage geometry")
  check(actor.tuning.health_capacity==100 and (actor.shield==100 if character==0 else actor.shield==0),"Faction health and shield capacities remain unchanged")
  var old=actor.hitboxes[0].global_transform
  var bone=actor.skeleton.find_bone("head");actor.skeleton.set_bone_pose_rotation(bone,Quaternion(Vector3.UP,.4));actor.skeleton.force_update_all_bone_transforms();actor.update_visual(0)
  # update_visual advances the authored pose; verify the actual binding directly.
  var data=actor.pose_offsets[actor.hitboxes[0].get_instance_id()]
  check(actor.hitboxes[0].global_transform.is_equal_approx(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(data.bone)*data.offset),"Animated head and hit region use the same current bone transform")
  actor.update_visual(.016)
 await physics_frame;await physics_frame
 # Compare the engine collision result with analytical rewind on exactly the same posed shapes.
 for actor in actors:
  var mismatches=0;var hits=0;var misses=0
  for i in range(actor.hitboxes.size()):
   var h=actor.hitboxes[i];var shape=actor.hitbox_shapes[i];var low: Vector3=shape.get_meta("minimum");var high: Vector3=shape.get_meta("maximum")
   var exclusions:Array[RID]=[]
   for other in game.actors:
    for area in other.hitboxes:
     if area!=h:exclusions.append(area.get_rid())
   for fx in [-.05,.15,.5,.85,1.05]:
    for fy in [-.05,.2,.5,.8,1.05]:
     var point=Vector3(lerpf(low.x,high.x,fx),lerpf(low.y,high.y,fy),0)
     var start=h.global_transform*(point+Vector3(0,0,1));var end=h.global_transform*(point-Vector3(0,0,1))
     var analytic=NestMatch.ray_shape_fraction(start,end,h.global_transform,shape)
     var actual=game.trace(start,end,4,exclusions)
     if analytic>=0:hits+=1
     else:misses+=1
     if (analytic>=0)!=not actual.is_empty():mismatches+=1
     elif analytic>=0 and start.lerp(end,analytic).distance_to(actual.position)>.004:mismatches+=1
  check(mismatches==0 and hits>0 and misses>0,"Character %d: 425 posed hull rays match physics and rewind, including edge misses (%d mismatches)"%[actor.character,mismatches])
 # Grounded crouch uses a nonuniform transform; both live and rewound shapes must agree.
 for actor in actors:
  actor.crouched=true;actor.air_duck=false;actor.update_crouch_shape(false);actor.update_visual(.2)
 await physics_frame;await physics_frame
 for actor in actors:
  var mismatches=0
  for i in range(actor.hitboxes.size()):
   var h=actor.hitboxes[i];var exclusions:Array[RID]=[]
   for other in game.actors:
    for area in other.hitboxes:
     if area!=h:exclusions.append(area.get_rid())
   var start=h.global_transform*Vector3(0,0,1);var end=h.global_transform*Vector3(0,0,-1)
   var fraction=NestMatch.ray_shape_fraction(start,end,h.global_transform,actor.hitbox_shapes[i]);var hit=game.trace(start,end,4,exclusions)
   if fraction<0 or hit.is_empty() or hit.position.distance_to(start.lerp(end,fraction))>.004:mismatches+=1
  check(mismatches==0,"Character %d crouched nonuniform hull transforms match live physics"%actor.character)
  actor.reset_crouch();actor.update_visual(0)
 # Record a target, move it, and hit the historical convex shape without moving live areas.
 var historical=actors[0];game.now=20;historical.update_visual(0);game.record_hitbox_history();var old_head=historical.hitboxes[0].global_position
 historical.position.x+=3;historical.update_visual(0);game.now=20.1;game.record_hitbox_history();await physics_frame;await physics_frame
 game.begin_rewind(p,20)
 var rewind=game.trace(old_head+Vector3(0,0,2),old_head-Vector3(0,0,2),5,p.ray_exclusions());game.end_rewind()
 check(not rewind.is_empty() and rewind.collider.get_meta("actor")==historical,"Historical ray hits the recorded convex head after the live target moves")
 check(historical.hitboxes[0].global_position.distance_to(old_head)>2.9,"Rewind query leaves live skeleton and hit regions in their current pose")
 # Convex surfaces reject an empty corner of the old overall box.
 var shape=actors[0].hitbox_shapes[0];var low:Vector3=shape.get_meta("minimum");var high:Vector3=shape.get_meta("maximum")
 check(NestMatch.ray_shape_fraction(Vector3(high.x-.001,high.y-.001,1),Vector3(high.x-.001,high.y-.001,-1),Transform3D.IDENTITY,shape)<0,"Ray through an empty helmet bounding-box corner misses its contour")
 check(is_equal_approx(NestActor.SIZE,1.26),"Characters, camera and movement capsule are 5% larger than the previous 1.2 scale")
 # Fixed spread / distribution / deterministic cosmetic agreement.
 var expected={"rifle":1.125,"burst":.140625,"burst_scoped":.140625,"sidearm":.3,"shotgun":4.6875,"sniper":0.,"rocket":0.,"ak47":0.}
 for kind in expected:
  p.weapons.assign([NestWeaponCatalog.profile(kind)]);p.slot=0;p.accuracy_penalty=5;p.crouched=true;p.velocity=Vector3(10,3,0);p.scope_level=1
  check(is_equal_approx(p.current_spread_degrees(),expected[kind]),"%s fixed cone ignores movement, crouch, scope and accumulated bloom"%kind)
 p.crouched=false;p.scope_level=0;p.velocity=Vector3.ZERO;p.accuracy_penalty=0
 var rng=RandomNumberGenerator.new();rng.seed=9231;var max_r=0.;var mean_r2=0.;var mean=Vector2.ZERO
 for i in range(10000):
  var d=p.cone_direction(Vector3.FORWARD,deg_to_rad(1.125),rng);var offset=Vector2(d.x,d.y)*10/-d.z;max_r=maxf(max_r,offset.length());mean_r2+=offset.length_squared();mean+=offset
 check(max_r<=.1964 and max_r>.195 and (mean/10000).length()<.004 and absf(mean_r2/10000-.19637*.19637*.5)<.001,"10000 rifle cone samples stay in the 10m circle with balanced uniform area distribution")
 p.weapons.assign([NestWeaponCatalog.profile("rifle")]);var origin=p.muzzle_position();var a=p.shot_directions(p.aim_direction(),origin,888);var b=p.shot_directions(p.aim_direction(),origin,888)
 check(a==b and a!=p.shot_directions(p.aim_direction(),origin,889),"Same shot ID reproduces directions; different IDs roll different spread")
 # Authoritative existing announcer, one count per confirmed kill; personal delivery.
 game.announcer.reset();game.audio.stop_all();audio_events.clear()
 for i in range(1,17):
  game.now+=10;game.announcer.clock+=10;game.announcer.record_kill(game,p,actors[0],"bullet")
  game.announcer.current="";game.announcer.current_voices.clear();game.announcer.queue.clear();game.audio.stop_all()
 check(audio_events.count("announcer_killing_spree")==1 and audio_events.count("announcer_killing_machine")==1 and audio_events.count("announcer_in_the_building")==1,"5/10/15 streak voices trigger exactly once and 16 triggers none")
 game.announcer.record_death(game,p);check(not game.announcer.streaks.has(p.get_instance_id()),"Environment deaths reset the victim's streak")
 game.mode=2;p.faction=1;game.announcer.record_kill(game,p,actors[0],"bullet")
 check(not game.announcer.streaks.has(p.get_instance_id()),"Team kills do not increase the streak")
 game.mode=1;p.faction=0;game.announcer.record_kill(game,p,actors[0],"bullet");var id=p.get_instance_id();game.announcer.forget_player(id)
 check(not game.announcer.streaks.has(id) and not game.announcer.kill_history.has(id),"Disconnect cleanup removes streak and multi-kill history")
 game.announcer.streaks[id]=4;game.reset_round();check(game.announcer.streaks[id]==4,"Round transitions preserve streaks")
 game.stop_game();check(game.announcer.streaks.is_empty(),"Match stop clears streaks")
 game.queue_free();await frames(8)
 print("ANATOMY UPDATE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
