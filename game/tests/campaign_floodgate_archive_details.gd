extends SceneTree
var game
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func run():
 if OS.get_environment("NEST_ISOLATED_QA")!="1":quit(1);return
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://flood-archive-detail-test.json";c.selected_mission=3;c.begin_solo(false)
 for mission in [3,4]:
  if mission!=3:c.journey.start_standalone(mission)
  c.journey.finish_cinematic();c.set_process(false);game.set_physics_process(false)
  for actor in game.actors:actor.set_physics_process(false)
  await physics_frame
  var w=c.world;var lights=w.get_meta("flood_archive_indicators",[])
  check(not lights.is_empty(),"Chapter %d stage indicators survive static batching"%mission)
  w.set_stage(0);var dormant=true
  for entry in lights:if not is_instance_valid(entry.node) or entry.node.material_override!=w.warning:dormant=false
  check(dormant,"Chapter %d begins with dormant machine indicators"%mission)
  w.set_stage(2);var synchronized=true
  for entry in lights:
   var expected=w.active_material if int(entry.stage)<2 else w.warning
   if entry.node.material_override!=expected:synchronized=false
  check(synchronized,"Chapter %d completion changes only the correct stage machinery"%mission)
  if mission==3:
   var water=w.get_meta("flood_archive_freight_water",[]);var wet=not water.is_empty()
   for node in water:if not node.visible:wet=false
   check(wet,"Freight water stays present before channel pump authorization")
   w.set_stage(3);var dry=true
   for node in water:if node.visible:dry=false
   check(dry,"Only freight surfaces drain when the third hydraulic objective completes")
   var residential=w.get_meta("flood_archive_residential_water",[]);var protected=residential.size()==4
   for node in residential:if not is_instance_valid(node) or not node.visible:protected=false
   check(protected,"Residential supply remains visibly intact after the freight basin drains")
   var needles=w.get_meta("flood_archive_needles",[]);var correct=true
   for entry in needles:
    if not is_equal_approx(entry.node.rotation.z,-.68 if int(entry.stage)<3 else .72):correct=false
   check(correct,"Physical gauge needles reflect restored hydraulic pressure")
  else:
   var rings=w.get_meta("flood_archive_rotors",[]);var aligned=rings.size()==4
   for entry in rings:
    if not is_equal_approx(entry.node.rotation.z,PI*.25 if int(entry.stage)<2 else 0.0):aligned=false
   check(aligned,"Four supported reading instruments align with the recovered archive stages")
   var counts=w.get_meta("flood_archive_detail_counts",{})
   check(int(counts.get("arches",0))==8 and int(counts.get("tablets",0))>=600,"Archive includes eight masonry spans and a stocked physical collection")
 c.exit_campaign();game.queue_free();await process_frame;quit(1 if failures else 0)
