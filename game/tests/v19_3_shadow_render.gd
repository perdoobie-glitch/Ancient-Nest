extends SceneTree
var game
func _initialize():call_deferred("run")
func capture() -> Image:
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 game.bot_fill=false;game.start_game();game.set_physics_process(false);game.set_process(false);game.context="pause";game.clear_screen();game.current_screen="review";game.hud.visible=false
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.global_position=Vector3(500,30,500);p.camera.current=false
 game.menu_camera.current=true;game.menu_camera.global_position=Vector3(205,34.5,207);game.menu_camera.look_at(Vector3(200,30.7,200));game.menu_camera.fov=65
 game.arena.sun.shadow_enabled=true;game.arena.sun.light_energy=1.2
 game.arena.kit.box(game,Vector3(200,29.85,200),Vector3(30,.2,30),game.arena.kit.material(Color("c5c6c0")))
 var e=NestActor.new();e.game=game;e.faction=1;game.add_child(e);game.actors.append(e);e.set_physics_process(false);e.set_process(false);e.global_position=Vector3(200,30,200);e.update_visual(.016);e.reset_physics_interpolation()
 e.cloak_deadline=game.now+60;e.refresh_model_visibility()
 var camo=await capture();camo.save_png("/workspace/work/v19_3/screenshots/Camo_Shadow.png")
 e.model.visible=false;var hidden=await capture();hidden.save_png("/workspace/work/v19_3/shadow-baseline.png")
 e.cloak_deadline=0;e.refresh_model_visibility();var visible=await capture();visible.save_png("/workspace/work/v19_3/shadow-visible.png")
 var shadow_pixels=0;var body_pixels=0
 for y in range(0,camo.get_height(),2):
  for x in range(0,camo.get_width(),2):
   var c=camo.get_pixel(x,y);var b=hidden.get_pixel(x,y);var v=visible.get_pixel(x,y)
   if (b.r+b.g+b.b)-(c.r+c.g+c.b)>.09:shadow_pixels+=1
   if absf(c.r-v.r)+absf(c.g-v.g)+absf(c.b-v.b)>.12:body_pixels+=1
 var ok=shadow_pixels>50 and body_pixels>50
 print("CAMO RENDER: darkened shadow samples=",shadow_pixels," opaque-body difference samples=",body_pixels," PASS=",ok)
 game.stop_game();game.queue_free();await process_frame;quit(0 if ok else 1)
