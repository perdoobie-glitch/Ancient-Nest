extends SceneTree
var game
var target
var checks=0
var failures=0
func _initialize():call_deferred("run")
func frames(n=8):
 for i in range(n):await process_frame
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error(label)
func snap(name):
 target.refresh_model_visibility();await frames(6);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/workspace/work/v6-balance/"+name+".png")
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.bot_fill=false;game.start_game();game.clear_screen();game.context="pause";game.hud.visible=false;game.set_physics_process(false);game.set_process(false)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1280,800));root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.global_position=Vector3(100,0,105);p.rotation.y=0;p.eye.rotation.x=-.16;p.weapon_view.visible=false
 var camera=Camera3D.new();game.add_child(camera);camera.global_position=Vector3(100,1.6,105);camera.look_at(Vector3(100,1.2,100));camera.current=true;game.arena.sun.shadow_enabled=true
 var floor=game.arena.kit.box(game,Vector3(100,-.1,100),Vector3(14,.2,14),game.arena.kit.stone,true)
 target=NestActor.new();target.game=game;target.character=0;target.faction=1;game.add_child(target);game.actors.append(target);target.set_physics_process(false);target.global_position=Vector3(100,0,100);target.update_weapon_art();target.presentation.pose_upper_body();target.rotation.y=0
 game.now=20;target.cloak_deadline=0;await snap("01-visible-back")
 target.cloak_deadline=100;await snap("02-camo-back")
 check(target.camo_renderer.body_count==17,"Gun clipping uses all posed body regions")
 check(target.cloak_meshes.all(func(m):return m.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY),"Invisible body retains shadows")
 check(target.camo_renderer.originals.size()>0,"Gun remains in visible depth-tested pass")
 target.rotation.y=PI;target.presentation.pose_upper_body();await snap("03-camo-front")
 var wall=game.arena.kit.box(game,Vector3(100,1.4,102),Vector3(4,3,.25),game.arena.kit.dark,true);await snap("04-camo-behind-wall")
 wall.queue_free();target.cloak_deadline=0;target.refresh_model_visibility();await frames()
 check(target.camo_renderer.originals.is_empty(),"Normal gun materials restored after camouflage")
 target.last_damage=game.now-4;target.shield=50;target.health=10;await snap("05-green-regeneration")
 check(target.is_regenerating(),"Regeneration condition active for remote player")
 target.cloak_deadline=100;await snap("06-camo-healing")
 game.stop_game();game.queue_free();await create_timer(.3).timeout;print("CAMO VISUAL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
