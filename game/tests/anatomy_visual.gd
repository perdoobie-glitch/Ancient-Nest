extends SceneTree
func _initialize():call_deferred("run")
func frames(n=3):
 for i in range(n):await process_frame
func capture(name):
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/work/intro-anatomy/"+name+".png")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames();game.bot_fill=false;game.mode=1;game.start_game();game.set_physics_process(false)
 var layer=CanvasLayer.new();layer.layer=100;root.add_child(layer)
 var container=SubViewportContainer.new();container.size=root.get_visible_rect().size;container.stretch=true;layer.add_child(container)
 var viewport=SubViewport.new();viewport.size=Vector2i(container.size);viewport.own_world_3d=true;container.add_child(viewport)
 var world=Node3D.new();viewport.add_child(world)
 var env=WorldEnvironment.new();var settings=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("14222a");settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("dbe6ef");settings.ambient_light_energy=.6;env.environment=settings;world.add_child(env)
 for spec in [[Vector3(-25,-35,0),1.0,Color("fff0d5")],[Vector3(-15,140,0),.6,Color("8fcaff")]]:
  var light=DirectionalLight3D.new();light.rotation_degrees=spec[0];light.light_energy=spec[1];light.light_color=spec[2];world.add_child(light)
 var camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1.45,-4.6);camera.look_at(Vector3(0,1.25,0));camera.fov=36;camera.current=true
 var actors=[]
 for character in [0,1]:
  var actor=NestActor.new();actor.game=game;actor.character_choice=character;actor.faction=character;world.add_child(actor);game.actors.append(actor);actor.respawn();actor.set_physics_process(false);actor.set_process(false);actor.position=Vector3(-.65 if character==0 else .65,0,0);actor.rotation.y=-.15 if character==0 else .15;actor.update_visual(0);actor.enemy_name_tag.visible=false;actors.append(actor)
  var label=Label3D.new();label.text="NAKI" if character==0 else "ANNU";label.position=Vector3(actor.position.x,2.62,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.pixel_size=.002;label.font_size=42;world.add_child(label)
  if actor.remote_weapon!=null:actor.remote_weapon.visible=false
 var title=Label.new();title.text="ANCIENT NEST   /   HUMAN CONTOURS";title.position=Vector2(36,container.size.y-42);title.add_theme_font_size_override("font_size",24);layer.add_child(title)
 await frames(15);await capture("character-contours")
 for actor in actors:
  for i in range(actor.hitboxes.size()):
   var mesh=MeshInstance3D.new();mesh.mesh=actor.hitbox_shapes[i].get_debug_mesh();actor.hitboxes[i].add_child(mesh)
   var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(0.2,1,.65,.22);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.no_depth_test=false;mesh.material_override=mat
 title.text="ANCIENT NEST   /   BONE-FOLLOWING DAMAGE HULLS"
 await frames(3);await capture("character-hitboxes")
 layer.queue_free();game.stop_game();game.queue_free();await frames(8);quit()
