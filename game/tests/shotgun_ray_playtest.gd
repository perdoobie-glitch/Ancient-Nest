extends SceneTree
class StaticTarget extends NestActor:
 func die(_attacker: NestActor,_reason: String) -> void:alive=false
var game
var shooter
var target
var report=[]
func _initialize():call_deferred("run")
func restore():
 target.alive=true;target.life_id+=1;target.health=target.tuning.health_capacity;target.shield=target.tuning.shield_capacity if target.damage_model()=="naki" else 0.;target.armor=target.tuning.armor_capacity;target.helmet_hp=game.game_type.annu_head_armor;target.overshield=0.
func center(area: Area3D) -> Vector3:
 var shape=area.get_child(0).shape as ConvexPolygonShape3D;var point=Vector3.ZERO
 for p in shape.points:point+=p
 return area.to_global(point/shape.points.size())
func run():
 Engine.max_fps=0;seed(731)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=NestMatchPresets.create(1);rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.set_process(false);game.now=100.;game.break_until=0;game.finished=false
 shooter=game.player;shooter.set_physics_process(false);shooter.weapons[0]=NestWeaponCatalog.profile("shotgun");shooter.slot=0;shooter.position=Vector3(480,50,500)
 target=StaticTarget.new();target.game=game;target.faction=1;target.character_choice=0;target.net_id=1200;game.add_child(target);target.set_physics_process(false);target.position=Vector3(500,50,500)
 if target.combat_audio!=null:target.combat_audio.queue_free();target.combat_audio=null
 for character in [0,1]:
  if target.character!=character:target.set_character(character)
  target.refresh_traits();restore();target.update_visual(1./60.)
  await physics_frame;await process_frame
  for zone in ["torso","head"]:
   var selected: Area3D=null
   for area in target.hitboxes:
    if area.get_meta("region")==zone:selected=area;break
   assert(selected!=null)
   var aim=center(selected)
   for distance in [3.,5.,8.,10.,15.]:
    var origin=aim+Vector3(0,0,distance);var kills=0;var pellets=0;var head_pellets=0;var health_losses=[]
    for trial in range(100):
     restore();game.damage_events.clear()
     var directions=shooter.shot_directions((aim-origin).normalized(),origin,trial*16+16)
     for i in range(directions.size()):
      var hit=game.trace(origin,origin+directions[i]*24.,5,shooter.ray_exclusions())
      if hit.is_empty() or not hit.collider.has_meta("actor") or hit.collider.get_meta("actor")!=target:continue
      pellets+=1
      var region=str(hit.collider.get_meta("region"));if region=="head":head_pellets+=1
      target.take_damage(26.,region,"bullet",false,null,game.next_event()*16+i,origin,"shotgun",origin.distance_to(hit.position))
     if not target.alive:kills+=1
     health_losses.append(target.tuning.health_capacity-target.health)
    var row={"faction":"Naki" if character==0 else "Annu","aim":zone,"distance":distance,"trials":100,"one_shell_kill_percent":kills,"mean_pellets_on_target":pellets/100.,"mean_head_pellets":head_pellets/100.}
    report.append(row);print("RAY TRIAL ",JSON.stringify(row))
    await process_frame
 FileAccess.open("user://shotgun-ray-playtest.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("PASS: 2000 shotgun shells / 16000 pellet rays against actual standing hitboxes")
 target.queue_free();game.stop_game();game.queue_free();await create_timer(.2).timeout;quit()
