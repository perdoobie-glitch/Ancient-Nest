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
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 var rules=GameTypeSettings.new();rules.mode=1;rules.bots_fill_empty_slots=false;rules.starting_primary="plasma_br";rules.starting_secondary="plasma_auto";rules.validate()
 check(rules.starting_primary=="plasma_br" and rules.starting_secondary=="plasma_auto","Custom lobby settings validate both new weapons")
 game.apply_game_type_settings(rules);game.start_game();game.create_hud();game.hud.visible=true;game.set_physics_process(false);var p=game.player;p.set_physics_process(false);p.set_process(false);p.global_position=Vector3(5,14,6)*.85;p.reset_physics_interpolation();p.reset_aim();game.context="playing";Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;game.input_window_focused=true
 check(p.weapons[0].kind=="plasma_br" and p.weapons[1].kind=="plasma_auto","Actual custom loadout equips both plasma guns")
 p.scope_level=1;for i in range(120):p.update_aim(.016)
 for size in [Vector2i(1280,800),Vector2i(1260,540),Vector2i(1280,360)]:
  root.size=size;await frames(5)
  check(absf(tan(deg_to_rad(game.prefs.values.fov)*.5)/tan(deg_to_rad(p.camera.fov)*.5)-2.5)<.001,"2.5x scope remains exact at "+str(size))
  var center=game.hud_crosshair.size*.5
  check(p.camera.project_ray_normal(center).dot(p.aim_direction())>.99999,"Circle reticle and aim ray align at "+str(size))
  check(game.hud_crosshair.scope_mask.visible and game.hud_crosshair.scope_material.get_shader_parameter("viewport_size")==game.hud_crosshair.size,"Circular mask receives current aspect at "+str(size))
  var before=p.rotation.y;var motion=InputEventMouseMotion.new();motion.screen_relative=Vector2(50,0);motion.relative=Vector2(50,0);Input.parse_input_event(motion)
  check(p.rotation.y!=before,"Scoped mouse input responds immediately at "+str(size))
 check(game.arena.get_node("V19CastleValley").get_child_count()==0,"Panoramic scenery uses the lightweight sky path")
 await RenderingServer.frame_post_draw
 print("V19 NATIVE: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await frames();quit(1 if failures else 0)
