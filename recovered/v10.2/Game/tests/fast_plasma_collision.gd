extends SceneTree
var game
func _initialize():call_deferred("run")
func center(area: Area3D) -> Vector3:
 var shape=area.get_child(0).shape as ConvexPolygonShape3D;var point=Vector3.ZERO
 for p in shape.points:point+=p
 return area.to_global(point/shape.points.size())
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=NestMatchPresets.create(1);rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.set_process(false);game.now=100.;game.break_until=0;game.finished=false
 var shooter=game.player;shooter.set_physics_process(false);shooter.position=Vector3(500,50,520)
 var target=NestActor.new();target.game=game;target.faction=1;target.character_choice=1;target.net_id=301;game.add_child(target);target.set_physics_process(false);target.position=Vector3(500,50,500);target.update_visual(1./60.)
 await physics_frame;await physics_frame
 var area=target.hitboxes.filter(func(a):return a.get_meta("region")=="torso")[0]
 var aim=center(area);var origin=aim+Vector3.BACK*10.
 var wall=StaticBody3D.new();var collider=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(6,6,.1);collider.shape=box;wall.add_child(collider)
 for id in ["plasma_br","plasma_auto","plasma_pistol","viper_pulse_smg","plasma_sniper"]:
  target.health=10000.;target.shield=0.;target.armor=0.;target.helmet_hp=0.;target.alive=true
  var weapon=NestWeaponCatalog.profile(id)
  game.launch_bullet(shooter,weapon,origin,Vector3.FORWARD,0,false,game.next_event()*16)
  for i in range(3):await physics_frame
  assert(target.health<10000.,id+" failed to hit at 10m")
  print("PASS: ",id," actual projectile hits target at 10m, speed=",weapon.speed)
  target.health=10000.;game.add_child(wall);wall.global_position=(origin+aim)*.5
  for i in range(2):await physics_frame
  game.launch_bullet(shooter,weapon,origin,Vector3.FORWARD,0,false,game.next_event()*16)
  for i in range(3):await physics_frame
  assert(target.health==10000.,id+" tunneled through a 10cm wall")
  print("PASS: ",id," stopped by 10cm cover at high speed")
  game.remove_child(wall);await physics_frame
 wall.free();target.queue_free();game.stop_game();game.queue_free();await create_timer(.15).timeout;quit()
