extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func frames(n=5):
 for i in range(n):await process_frame
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS VISUAL: "+text)
 else:failures+=1;push_error(text)
func capture(name: String):
 await frames();await RenderingServer.frame_post_draw
 var error=root.get_texture().get_image().save_png("/workspace/work/v26/screenshots/"+name+".png")
 check(error==OK,"Saved rendered "+name)
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 var rules=GameTypeSettings.new();rules.mode=2;rules.max_players_per_team=2;rules.bots_stand_still=true;rules.bots_dont_shoot=true;game.apply_game_type_settings(rules)
 game.clear_screen();game.start_game();game.create_hud();game.set_physics_process(false)
 var p=game.player
 for i in range(game.actors.size()):
  var a=game.actors[i];a.set_physics_process(false);a.set_process(false);a.position=Vector3(120+i*4,35,120);a.rotation=Vector3.ZERO;a.eye.rotation=Vector3.ZERO;a.update_visual(0)
 var a=game.actors.filter(func(n):return n.character==1)[0]
 p.position=Vector3(99.15,30,100);a.position=Vector3(100.85,30,100);p.model.visible=true;a.model.visible=true;p.weapon_view.visible=false;game.hud.visible=false
 p.presentation.pose_upper_body();a.presentation.pose_upper_body()
 var k=game.arena.kit;k.box(game,Vector3(100,29.92,100),Vector3(6,.12,4),k.stone)
 var camera=Camera3D.new();game.add_child(camera);camera.position=Vector3(100,31.55,94.8);camera.look_at(Vector3(100,31.12,100));camera.fov=49;camera.current=true
 await capture("V31_Reference_Suits")
 for actor in [p,a]:
  check(actor.model.has_meta("reference_skin_details"),"Reference skin applied to live actor")
  for clip in ["walk_forward","reload","melee"]:
   actor.animation.play(actor.clips[clip]);actor.animation.advance(.3);actor.skeleton.force_update_all_bone_transforms();await frames()
   check(actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("hand_r")).is_finite(),"Animated hands remain valid during "+clip)
  actor.animation.play(actor.clips.idle);actor.animation.advance(0)
 camera.position=Vector3(100,31.5,105.2);camera.look_at(Vector3(100,31.12,100))
 await capture("V31_Reference_Suits_Back")
 game.stop_game();game.queue_free();await frames(8)
 print("REFERENCE SKIN VISUAL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
