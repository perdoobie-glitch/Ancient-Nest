extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func frames(n=3):
 for i in range(n):await process_frame
func hit_loss(v,ak: Dictionary,base: float,region: String,shielded: bool) -> float:
 for field in ["damage","damage_shield","damage_body"]:ak[field]=base
 v.respawn();v.set_physics_process(false);v.set_process(false)
 v.shield=v.tuning.shield_capacity if shielded else 0
 var before=v.shield if shielded else v.health
 v.take_damage(base,region,"bullet",false,game.player,game.next_event()*16,Vector3.INF,"ak47")
 return before-(v.shield if shielded else v.health)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 game.bot_fill=false;game.mode=1;game.clear_screen();game.start_game();game.set_physics_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 var ak=NestWeaponCatalog.data().weapons.filter(func(item):return item.kind=="ak47")[0]
 check(ak.damage==60 and ak.damage_shield==60 and ak.damage_body==60,"All three AK damage sources increase by 20 percent")
 check(load("res://resources/ak47.tres").damage==60 and NestWeaponCatalog.profile("ak47").damage==60,"Resource and catalog agree on AK damage")
 check(is_equal_approx(ak.body_hit_multiplier,.65) and ak.magazine==30 and ak.fire_rate_rpm==600,"Body modifier, magazine and fire rate remain intact")
 var v=NestActor.new();v.game=game;v.character_choice=0;v.faction=1;game.add_child(v);game.actors.append(v);v.set_physics_process(false);v.set_process(false)
 for sample in [["torso",true],["head",true],["torso",false]]:
  var old=hit_loss(v,ak,50,sample[0],sample[1]);var updated=hit_loss(v,ak,60,sample[0],sample[1])
  check(absf(updated-old*1.2)<.0001,"Actual Naki %s damage scales 1.2x (shielded=%s)"%[sample[0],sample[1]])
 var annu=NestActor.new();annu.game=game;annu.character_choice=1;annu.faction=1;game.add_child(annu);game.actors.append(annu);annu.set_physics_process(false);annu.set_process(false)
 var old=hit_loss(annu,ak,50,"torso",false);var updated=hit_loss(annu,ak,60,"torso",false)
 check(absf(updated-old*1.2)<.0001,"Actual armored Annu body damage scales 1.2x")
 check(is_equal_approx(game.damage_rules.melee_max_lunge_m,1.22) and is_equal_approx(game.damage_rules.melee_lunge_seconds,.25),"Lunge cap doubles while duration stays fixed")
 p.global_position=Vector3(800,100,800);p.rotation.y=0;p.eye.rotation.x=0;p.reset_aim();p.cooldown=0;p.action_state="ready"
 check(absf(p.melee_lunge().length()-1.22)<.0001,"Free lunge requests the full 1.22 m")
 var displacement=p.melee_lunge();p.start_lunge(displacement)
 check(p.lunge_ticks==15 and absf(p.lunge_velocity.length()-4.88)<.0001,"Prediction uses a 15-tick 4.88 m/s lunge boost")
 p.melee();check(p.presentation.view_knife.visible and not p.weapon_art.visible,"Local knife appears immediately and replaces the gun during a strike")
 var before=p.presentation.left_hand.position;game.now+=.22;p.presentation.update_view_weapon(0)
 check(p.presentation.left_hand.position.distance_to(before)>.05,"The gripping hand follows a visible knife swing")
 v.action_state="melee";v.action_until=game.now+.8;v.presentation.pose_upper_body()
 check(v.presentation.remote_knife.visible and not v.remote_art.visible,"Other players show the knife instead of a punching gun")
 check(v.presentation.remote_knife.get_parent() is BoneAttachment3D and v.presentation.remote_knife.get_parent().bone_name=="hand_l","Third-person knife follows the animated hand")
 p.action_state="ready";p.presentation.update_view_weapon(0);v.action_state="ready";v.presentation.pose_upper_body()
 check(not p.presentation.view_knife.visible and p.weapon_art.visible and not v.presentation.remote_knife.visible and v.remote_art.visible,"Knife stows and guns return after the strike")
 game.stop_game();game.queue_free();await frames(8)
 print("AK KNIFE UPDATE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
