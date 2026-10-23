extends SceneTree
var game
var checks=0
var failures=0
var ray_count=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func ticks(n=2):
 for i in range(n):await physics_frame
func wall(pos,size):
 var b=StaticBody3D.new();var c=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size;c.shape=shape;b.add_child(c);game.add_child(b);b.position=pos;return b
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;game.bot_fill=false;game.mode=1;game.start_game();game.set_physics_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.position=Vector3(600,80,600);p.rotation.y=0;p.eye.rotation.x=0;p.reset_aim()
 var v=NestActor.new();v.game=game;v.faction=1;game.add_child(v);game.actors.append(v);v.respawn();v.set_physics_process(false);v.set_process(false)
 var rng=RandomNumberGenerator.new();rng.seed=554433;var mismatch=0;var inside=0;var outside=0;var worst_error=0.
 for character in [0,1]:
  v.set_character(character)
  for pose in range(8):
   v.position=Vector3(600+sin(pose)*.5,80,590);v.rotation.y=pose*.73;v.velocity=Vector3(3,0,pose%2*3);v.crouched=pose%3==0;v.air_duck=pose%3==1;v.update_crouch_shape(false);v.update_visual(.13)
   await ticks()
   var local_mismatch=0
   for i in range(v.hitboxes.size()):
    var h=v.hitboxes[i];var shape=v.hitbox_shapes[i];var low:Vector3=shape.get_meta("minimum");var high:Vector3=shape.get_meta("maximum");var exclude:Array[RID]=p.ray_exclusions()
    for other in v.hitboxes:
     if other!=h:exclude.append(other.get_rid())
    for j in range(30):
     var point=Vector3(lerpf(low.x,high.x,rng.randf_range(-.15,1.15)),lerpf(low.y,high.y,rng.randf_range(-.15,1.15)),0)
     var start=h.global_transform*(point+Vector3(0,0,1));var end=h.global_transform*(point-Vector3(0,0,1));var fraction=NestMatch.ray_shape_fraction(start,end,h.global_transform,shape);var actual=game.trace(start,end,4,exclude);ray_count+=1
     if fraction>=0:inside+=1
     else:outside+=1
     if (fraction>=0)!=not actual.is_empty():local_mismatch+=1
     elif fraction>=0:
      var error=actual.position.distance_to(start.lerp(end,fraction));worst_error=maxf(worst_error,error)
      if error>.004:local_mismatch+=1
   mismatch+=local_mismatch
   check(local_mismatch==0,"Character %d animated/rotated/crouched pose %d: 510 physics vs rewind rays agree"%[character,pose])
 check(inside>1000 and outside>1000,"Stress includes substantial true hits and tight silhouette misses")
 # A world obstruction must win over a character both currently and in rewind.
 v.reset_crouch();v.position=Vector3(600,80,590);v.rotation.y=0;v.update_visual(0);await ticks()
 var target=v.hitboxes[1].global_position;var origin=p.eye.global_position;var cover=wall(origin.lerp(target,.5),Vector3(3,3,.2));await ticks()
 var live=game.trace(origin,target,5,p.ray_exclusions());check(not live.is_empty() and live.collider==cover,"Live hit query stops at cover ahead of a target")
 game.now=10;game.record_hitbox_history();game.now=10.1;game.record_hitbox_history();game.begin_rewind(p,10.02)
 var rewound=game.trace(origin,target,5,p.ray_exclusions());game.end_rewind();check(not rewound.is_empty() and rewound.collider==cover,"Rewound hit query also stops at current world cover")
 cover.queue_free();await ticks()
 # Actual impact/damage pipeline for a moving target with no artificial damage claim.
 v.set_character(0)
 var hits=0;var bad_regions=0;var w=NestWeaponCatalog.profile("ak47")
 for i in range(40):
  v.respawn();v.shield=0;v.position=Vector3(600+sin(i*.7)*2,80,590);v.rotation.y=sin(i)*2;v.velocity=Vector3(6,0,0);v.update_visual(.03);await ticks()
  var head=v.hitboxes[0].global_position
  game.launch_bullet(p,w,p.eye.global_position,(head-p.eye.global_position).normalized(),0,false,game.next_event()*16)
  if not v.alive:hits+=1
  else:bad_regions+=1
 check(hits==40,"40 moving/turning targets receive real hitscan head damage synchronously (40/40)")
 # Nearest surface and shooter exclusions must survive overlapping volumes.
 v.respawn();v.position=p.position;v.update_visual(0);await ticks();var selfhit=game.trace(p.hitboxes[0].global_position,p.hitboxes[0].global_position+Vector3.RIGHT*2,4,p.ray_exclusions())
 check(selfhit.is_empty() or selfhit.collider.get_meta("actor")!=p,"Point-blank overlapping bodies cannot cause self hits")
 print("HIT STRESS METRICS ",JSON.stringify({"rays":ray_count,"inside":inside,"outside":outside,"mismatches":mismatch,"max_contact_error_m":worst_error,"moving_headshots":hits}))
 game.stop_game();game.queue_free();await process_frame;print("HIT DETECTION STRESS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
