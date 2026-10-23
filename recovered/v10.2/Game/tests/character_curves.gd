extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.bot_fill=false;game.clear_screen();game.start_game();game.set_physics_process(false)
 for a in game.actors:a.set_physics_process(false);a.set_process(false)
 for character in [0,1]:
  var actor=NestActor.new();actor.game=game;actor.character_choice=character;actor.faction=character;game.add_child(actor);game.actors.append(actor);actor.set_physics_process(false);actor.set_process(false)
  check(actor.skeleton.get_bone_count()==40,"Character %d retains the 40-bone rig"%character)
  check(actor.clips.size()==21,"Character %d retains all 21 clips"%character)
  check(actor.remote_weapon.get_parent() is BoneAttachment3D and actor.remote_weapon.get_parent().bone_name=="hand_r","Weapon remains attached to the right hand")
  for clip in ["walk_forward","strafe_left","crouch_idle","reload","fire_upperbody","grenade_throw","melee"]:
   actor.animation.play(actor.clips[clip]);actor.animation.advance(.3);actor.skeleton.force_update_all_bone_transforms();await process_frame
   var valid=true
   for name in ["upperarm_l","forearm_l","hand_l","upperarm_r","forearm_r","hand_r"]:
    var index=actor.skeleton.find_bone(name);valid=valid and index>=0 and actor.skeleton.get_bone_global_pose(index).is_finite()
   check(valid,"Character %d has valid arm and hand poses for %s"%[character,clip])
  var bounds={}
  for part in NestCharacterCatalog.hitboxes(character):bounds[part.bone]=part
  var pelvis=bounds.pelvis;var waist=bounds.spine_01
  check(float(pelvis.maximum[0])-float(pelvis.minimum[0])>float(waist.maximum[0])-float(waist.minimum[0]),"Curved pelvis and tapered waist have separate fitted damage bounds")
  check(actor.hitboxes.size()==17 and actor.pose_offsets.size()==17,"Curved body retains 17 bone-following damage regions")
 game.stop_game();game.queue_free();await process_frame;await process_frame
 print("CHARACTER CURVES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
