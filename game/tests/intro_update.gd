extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 check(ProjectSettings.get_setting("application/run/main_scene")=="res://intro/intro_scene.tscn","Launch scene owns startup artwork followed by creator intro")
 var intro=load("res://intro/intro_scene.tscn").instantiate();root.add_child(intro);current_scene=intro
 check(intro.next_scene=="res://scenes/main.tscn","Intro returns to the original main menu")
 check(intro._names.text=="MISHWAD  &  PERDOOBIE" and intro.music==null,"Both creator names display; menu music remains owned by menu")
 if DisplayServer.get_name()!="headless":
  await create_timer(.9).timeout;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/workspace/work/v26/screenshots/V31_Startup_Screen.png")
  check(intro._cover.visible and intro._names.modulate.a==0,"Startup artwork appears before creator credits")
 for vs in [Vector2(1280,800),Vector2(1920,1080),Vector2(800,600)]:
  intro._responsive_layout(vs)
  var names=intro._names;var font=names.label_settings.font;var final_spacing=7
  var width=font.get_string_size(names.text,HORIZONTAL_ALIGNMENT_LEFT,-1,names.label_settings.font_size).x+(final_spacing-font.spacing_glyph)*names.text.length()
  check(width<vs.x*.98,"Creator names fit at %dx%d including final tracking"%[vs.x,vs.y])
 intro._responsive_layout(root.get_visible_rect().size)
 var emitted=[];intro.intro_finished.connect(func():emitted.append(true))
 intro._skip();intro._skip();intro._skip()
 check(intro._skipping and not intro._done,"Repeated skip presses create one transition")
 await create_timer(.7).timeout
 check(emitted.size()==1 and is_instance_valid(current_scene) and current_scene.scene_file_path=="res://scenes/main.tscn","Skip emits once and loads the real main menu")
 var game=current_scene
 if game.has_method("show_lobby"):
  game.lobby_network.set_process(false);game.lobby_network=null
  check(game.current_screen=="main" and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Menu starts with visible mouse and no gameplay capture")
 current_scene.queue_free();current_scene=null;await process_frame
 # Natural completion, with a shorter exported hold but the original fade timeline.
 var natural=load("res://intro/intro_scene.tscn").instantiate();natural.next_scene="";natural.hold_time=0;root.add_child(natural)
 var complete=[];natural.intro_finished.connect(func():complete.append(true))
 check(natural._cover.visible and not natural._done,"New startup image is the first screen")
 check(natural._cover_art.texture.resource_path=="res://assets/intro/cover.jpg" and natural._cover_art.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"New landscape image is fitted without cropping")
 check(natural.COVER_HOLD_SECONDS==4.0,"Startup holds fully visible for four seconds")
 await create_timer(5.1).timeout
 check(not natural._cover.visible and not natural._done,"Creator intro starts after startup artwork")
 if DisplayServer.get_name()!="headless":
  await create_timer(3.0).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/workspace/work/v26/screenshots/V31_Creator_Intro.png")
  check(natural._names.modulate.a>0.5 and natural._bg.material.shader.get_rid().is_valid(),"Creator credits render after the startup screen")
  await create_timer(3.1).timeout
 else:
  await create_timer(6.1).timeout
 check(complete.size()==1 and natural._done,"Unskipped startup then intro completes once")
 natural.queue_free();await process_frame
 print("INTRO UPDATE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
