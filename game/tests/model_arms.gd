extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error(label)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.bot_fill=false;game.start_game();game.set_physics_process(false)
 var actor=game.player;actor.set_physics_process(false)
 for character in [0,1]:
  actor.set_character(character)
  for side in ["l","r"]:
   for part in ["hand","forearm"]:
    var view=NestViewArms.create(character,side,part)
    check(view.mesh.get_meta("source_model")==NestCharacterCatalog.by_index(character).model,"Geometry comes from correct character model")
    check(view.mesh.get_meta("source_bone")==part+"_"+side and view.mesh.get_meta("source_vertices")>1000,"Authored fingers / armor geometry retained")
    check(view.mesh.get_surface_count()>0 and view.mesh.surface_get_material(0)!=null,"Character materials preserved")
    check(view.mesh.get_aabb().size.is_finite(),"Finite view geometry")
    view.free()
  check(actor.view_grip_parts.size()==2 and actor.view_grip_parts[0].mesh is ArrayMesh,"Right hand and arm replace primitive placeholders")
  check(actor.presentation.left_hand.get_child(0).mesh is ArrayMesh and actor.presentation.left_forearm.mesh is ArrayMesh,"Left hand and arm replace primitive placeholders")
  var position=actor.global_position;var velocity=actor.velocity
  for kind in NestGunFeedback.STYLES:
   actor.weapons[0]=NestWeaponCatalog.profile(str(kind));actor.slot=0;actor.action_state="ready";actor.update_weapon_art();actor.presentation.update_view(.016)
  check(actor.global_position==position and actor.velocity==velocity,"View changes leave physics unchanged")
 game.stop_game();game.queue_free();await create_timer(.3).timeout
 print("MODEL ARMS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
