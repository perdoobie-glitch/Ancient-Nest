extends SceneTree
var game
var checks=0
var failures=0
func check(ok: bool,label: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func frames(n=3):
 for i in range(n):await physics_frame
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://cache-access-qa.json";c.begin_solo(false);game.set_physics_process(false);c.set_process(false)
 for mission in range(2,10):
  c.journey.start_standalone(mission);c.journey.finish_cinematic();c.world.set_stage(3 if mission!=2 else 0)
  game.input_window_focused=true
  for actor in game.actors:actor.set_physics_process(false)
  await frames(150)
  var anchors=c.world.weapon_cache_points()
  for i in range(anchors.size()):
   var id=100000+mission*100+i;var body=c.loot.drops.get(id);var accessible=false
   check(is_instance_valid(body) and not NestWeaponCatalog.for_kind(body.kind).is_empty(),"Mission %d cache %d is an actual catalog firearm"%[mission,i])
   if not is_instance_valid(body):continue
   for offset in [Vector3(0,0,1.5),Vector3(1.5,0,0),Vector3(-1.5,0,0),Vector3(0,0,-1.5)]:
    var at=anchors[i]+offset;var floor_height=c.world.surface_height(at)
    if floor_height< -100:continue
    game.player.global_position=Vector3(at.x,floor_height+.25,at.z);await frames(1)
    var choice=c.interaction(game.player)
    if c.loot.closest(game.player)==body and choice.get("key","")=="campaign:loot:"+str(id):accessible=true;break
   check(accessible,"Mission %d cache %d has a grounded unobstructed pickup approach"%[mission,i])
   check(body.linear_velocity.length()<.7 and absf(body.global_position.y-anchors[i].y)<1.8,"Mission %d cache %d remains physically supported"%[mission,i])
 c.exit_campaign();game.queue_free();await frames()
 print("CACHE ACCESS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
