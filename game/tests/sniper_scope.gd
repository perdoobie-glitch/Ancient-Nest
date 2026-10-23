extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func frames(n=4):
 for i in range(n):await process_frame
func capture(label: String):
 if DisplayServer.get_name()=="headless":return
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("/workspace/work/v20_sniper/screenshots/"+label+".png")==OK,"Rendered "+label)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 var rules=GameTypeSettings.new();rules.mode=1;rules.bots_fill_empty_slots=false;rules.starting_primary="sniper_rifle";game.apply_game_type_settings(rules);game.start_game();game.create_hud();game.clear_screen();game.hud.visible=true;game.set_physics_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.global_position=Vector3(5,14,6)*.85;p.rotation.y=-PI*.6;p.reset_physics_interpolation();game.context="playing";Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;game.input_window_focused=true;p.reset_aim();p.camera.global_transform=p.eye.global_transform
 check(NestWeaponCatalog.for_kind("sniper").zoom_factors==[5.0,15.0],"Sniper primary zoom stays 5x and secondary changes from 10x to 15x")
 check(is_equal_approx(NestReticle.SNIPER_RING_SCALE/.75,.6),"Sniper hip circle radius is 40 percent smaller than previous brackets")
 await capture("Sniper_Hip_Circle")
 for level in [1,2]:
  p.scope_level=level
  for i in range(120):p.update_aim(.016)
  game.hud_crosshair._process(.016);await frames()
  var zoom=tan(deg_to_rad(game.prefs.values.fov)*.5)/tan(deg_to_rad(p.camera.fov)*.5)
  check(absf(zoom-(5.0 if level==1 else 15.0))<.001,"Actual camera settles to "+str(zoom)+"x")
  check(not p.weapon_view.visible,"Sniper weapon hides behind scope at level "+str(level))
  await capture("Sniper_"+("5x" if level==1 else "15x"))
 for size in [Vector2i(1280,800),Vector2i(1260,540),Vector2i(1280,360)]:
  root.size=size;await frames()
  for level in [1,2]:
   p.scope_level=level
   for i in range(120):p.update_aim(.016)
   game.hud_crosshair._process(.016)
   var center=game.hud_crosshair.size*.5
   check(p.camera.project_ray_normal(center).dot(p.aim_direction())>.99999,"Sniper reticle aligns to hit ray at "+str(size)+" zoom "+str(level))
   check(game.hud_crosshair.scope_mask.visible and game.hud_crosshair.scope_material.get_shader_parameter("viewport_size")==game.hud_crosshair.size,"Round scope uses viewport dimensions at "+str(size)+" zoom "+str(level))
 p.scope_level=2;p.toggle_scope();check(p.scope_level==0,"Third scope toggle returns to hip aim")
 p.weapons.assign([NestWeaponCatalog.profile("plasma_br")]);p.slot=0;p.scope_level=1
 for i in range(120):p.update_aim(.016)
 check(absf(tan(deg_to_rad(game.prefs.values.fov)*.5)/tan(deg_to_rad(p.camera.fov)*.5)-2.5)<.001,"Plasma BR remains at existing 2.5x zoom")
 game.stop_game();game.queue_free();await frames();print("SNIPER SCOPE: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
