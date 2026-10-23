extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1100,800)
 var stage=Node3D.new();root.add_child(stage)
 var world=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("18242d");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("e9efff");env.ambient_light_energy=.7;world.environment=env;stage.add_child(world)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-35,0);light.light_energy=1.6;stage.add_child(light)
 var fill=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-20,145,0);fill.light_energy=.65;fill.light_color=Color("b1d7ef");stage.add_child(fill)
 var cam=Camera3D.new();stage.add_child(cam);cam.position=Vector3(0,1.05,-3.5);cam.look_at(Vector3(0,1.0,0));cam.fov=43
 for i in [0,1]:
  var visual=load(NestCharacterCatalog.by_index(i).visual).instantiate();stage.add_child(visual);visual.position.x=-.67 if i==0 else .67
  var animator=visual.find_children("*","AnimationPlayer",true,false)[0]
  for clip in animator.get_animation_list():
   if String(clip).ends_with("idle"):animator.play(clip);animator.advance(.1);animator.pause();break
 for i in range(6):await process_frame
 await RenderingServer.frame_post_draw
 var suffix="after" if "after" in OS.get_cmdline_user_args() else "before"
 root.get_texture().get_image().save_png("/workspace/work/v26/body-update/"+suffix+".png")
 quit()
