extends SceneTree
var game
var checks=0
var failures=0
var attacker
var defender
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func freeze():
 game.set_physics_process(false);game.set_process(false)
 for actor in game.actors:actor.set_physics_process(false);actor.set_process(false)
func fresh():
 game.finished=false;game.context="pause";game.reset_round();freeze()
 attacker=game.actors.filter(func(a):return a.is_attacker())[0]
 defender=game.actors.filter(func(a):return not a.is_attacker())[0]
func place(actor,site: int):
 for offset in [Vector3(0,0,2.4),Vector3(0,0,-2.4),Vector3(-2.4,0,0),Vector3(2.4,0,0)]:
  actor.global_position=game.arena.sites[site]+offset;actor.force_update_transform()
  if not game.cs_interaction(actor).is_empty():return
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 game.show_lobby();await process_frame
 check(game.lobby_character.item_count==3 and game.lobby_character.get_item_text(2)=="Annu","Character menu contains Team default, Naki and Annu")
 check(game.lobby_faction.item_count==2 and game.lobby_faction.get_item_text(1).contains("Annu"),"Your team menu includes second Annu team")
 check(not game.lobby_faction.disabled,"Own-team selector is usable")
 var a=game.find_child("TeamAFaction",true,false);var b=game.find_child("TeamBFaction",true,false)
 check(a!=null and b!=null and a.item_count==2 and b.item_count==2,"Independent matchup controls both contain Naki and Annu")
 a.item_selected.emit(1);await process_frame
 check(game.matchup==2,"Team A can change to Annu without losing the second side")
 b=game.find_child("TeamBFaction",true,false);b.item_selected.emit(0);await process_frame
 check(game.matchup==3,"Reverse Annu vs Naki matchup can be selected and saved")
 check(game.MATCHUPS[3]==[1,0],"Saved matchup index includes reverse orientation")
 for mode in range(5):
  var template=NestGameTypeLibrary.load_type("builtin:"+str(mode));check(template!=null and template.mode==mode,"Built-in template loads mode "+str(mode))
 var rules=NestGameTypeLibrary.load_type("builtin:4");rules.max_players_per_team=1;rules.matchup=0
 var saved=NestGameTypeLibrary.save_new(rules,"Bomb test variant")
 check(saved.ok,"Edited template can save as a separate new game type")
 var copy=NestGameTypeLibrary.load_saved(saved.id);copy.damage_dealt_percent=120
 check(NestGameTypeLibrary.load_saved(saved.id).damage_dealt_percent==100,"Editing loaded preset does not modify saved original")
 check(game.apply_game_type_settings(rules),"Host applies Counter-Strike template")
 game.open_game_type_settings();await process_frame
 var editor=game.game_type_editor
 check(editor.saved_types.item_count>=7,"Editor offers all built-in templates and named variants")
 editor.set_draft_value("health_type",2);editor.sync_draft_controls()
 check(not editor.controls.shields_enabled.get_parent().visible and editor.controls.armor_strength_percent.get_parent().visible,"Annu health shows armor traits and hides Naki shields")
 check(editor.controls.damage_resistance_percent.get_parent().get_child(0).text=="Annu damage resistance","Resistance label names selected Annu health system")
 editor.set_draft_value("health_type",1);editor.sync_draft_controls()
 check(editor.controls.shields_enabled.get_parent().visible and not editor.controls.armor_strength_percent.get_parent().visible,"Naki health shows shields and hides Annu armor")
 editor.close_editor();await process_frame
 game.start_game();freeze();fresh()
 check(game.mode==4 and is_equal_approx(game.deadline-game.now,120),"Bomb round has a two-minute timer")
 check(game.actors.size()==2 and game.actors[0].net_id!=game.actors[1].net_id,"Offline combatants have unique bomb carrier identities")
 check(game.cs_carrier==attacker.net_id and game.cs_drop_position==Vector3.INF,"Exactly one attacker receives the carried bomb")
 for kind in ["plasma_auto","plasma_br"]:
  var c=NestWeaponCatalog.for_kind(kind)
  check(is_equal_approx(float(c.damage_body),5.1 if kind=="plasma_auto" else 19.125) and is_equal_approx(float(c.damage_shield),4.08 if kind=="plasma_auto" else 12.75),kind+" body/shield damage uses requested nerf")
  defender.character_choice=0;defender.set_character(0);defender.respawn();defender.set_physics_process(false)
  defender.take_damage(100,"torso","bullet",false,attacker,game.next_event()*16,Vector3.ZERO,kind)
  check(is_equal_approx(defender.shield,100-float(c.damage_shield)/1.7),kind+" actual Naki shield damage uses catalog and body durability")
  defender.character_choice=1;defender.set_character(1);defender.respawn();defender.set_physics_process(false)
  defender.take_damage(100,"torso","bullet",false,attacker,game.next_event()*16,Vector3.ZERO,kind)
  check(is_equal_approx(defender.health,100-float(c.damage_body)*.5),kind+" actual Annu body damage preserves armor absorption")
 var rocket=NestWeaponCatalog.for_kind("rocket")
 check(is_equal_approx(rocket.damage_direct,320) and is_equal_approx(rocket.splash_damage_max,240) and is_equal_approx(rocket.splash_radius_m,6.4),"Rocket direct damage, splash and radius are each 60 percent larger")
 var trail=NestTracer.new();trail.game=game;game.effects.add_child(trail);trail.setup(Vector3(200,30,200),Vector3(200,30,100),.1,true)
 var born=game.now
 check(is_equal_approx(trail.expires-born,2),"Sniper tracer lifetime is two seconds")
 game.now=born+.5;trail._process(0);check(is_equal_approx(trail.material.albedo_color.a,.125),"Sniper tracer retains opacity through first half second")
 game.now=born+1.25;trail._process(0);check(is_equal_approx(trail.material.albedo_color.a,.0625),"Sniper trail fades halfway between 0.5 and 2 seconds")
 game.now=born+2;trail._process(0);check(trail.is_queued_for_deletion(),"Sniper trail expires exactly at two seconds")
 fresh();game.game_type.health_type=2;game.game_type.armor_strength_percent=150;game.game_type.helmet_strength_percent=200;game.refresh_live_traits();attacker.respawn()
 check(attacker.damage_model()=="annu" and attacker.shield==0 and attacker.armor==150 and attacker.helmet_hp==50,"Naki artwork can use Annu health with edited armor/helmet capacities")
 game.game_type.health_type=1;game.refresh_live_traits();defender.respawn()
 check(defender.damage_model()=="naki" and defender.shield==100,"Annu artwork can use Naki health with shields")
 game.game_type.health_type=0;game.game_type.armor_strength_percent=100;game.game_type.helmet_strength_percent=100
 fresh();place(attacker,0);var plant=game.interaction_for(attacker)
 check(plant.get("key","")=="cs_plant:0" and is_equal_approx(plant.get("seconds",0),3.2),"Carried bomb offers 3.2-second plant at site A using actual map LOS")
 check(game.complete_interaction(attacker,plant) and game.cs_planted(),"Host plants one authoritative bomb at A")
 check(is_equal_approx(float(game.site_states[0].bomb_at)-game.now,40),"Planted fuse lasts forty seconds")
 check(game.cs_carrier==0 and game.cs_drop_position==Vector3.INF,"Plant consumes carried bomb without leaving a duplicate")
 attacker.global_position=game.arena.sites[1]+Vector3(0,0,1);check(game.cs_interaction(attacker).is_empty(),"Second site cannot receive a second bomb in the same round")
 place(defender,0);var defuse=game.interaction_for(defender)
 check(defuse.get("key","")=="defuse:0" and defuse.get("seconds",0)==10,"Defuse without a kit requires ten seconds")
 game.game_type.cs_defuse_kits=true;check(game.interaction_for(defender).get("seconds",0)==5,"Defuse with a kit requires five seconds")
 game.game_type.cs_defuse_kits=false
 var before=game.scores[defender.faction];check(game.complete_interaction(defender,defuse),"Host accepts completed defuse")
 check(game.scores[defender.faction]==before+1 and game.break_until>game.now,"Defuse gives defenders one round and starts break")
 game.cs_win(defender.faction,"duplicate");check(game.scores[defender.faction]==before+1,"Duplicate round wins cannot add a second point")
 fresh();place(attacker,1);plant=game.interaction_for(attacker)
 check(plant.get("key","")=="cs_plant:1" and game.complete_interaction(attacker,plant),"Site B also accepts the single carried bomb")
 attacker.alive=false;game.update_cs_round();check(game.break_until==0,"Eliminating attackers after plant does not win for defenders")
 game.deadline=game.now;game.update_cs_round();check(game.break_until==0,"Planted bomb continues after the round clock expires")
 before=game.scores[attacker.faction];game.now=float(game.site_states[1].bomb_at);game.update_cs_round()
 check(game.scores[attacker.faction]==before+1 and game.round_reason.contains("detonated"),"Fuse expiry gives attackers the round")
 fresh();game.now=game.deadline;before=game.scores[defender.faction];game.update_cs_round()
 check(game.scores[defender.faction]==before+1 and game.round_reason.contains("Time expired"),"Unplanted round timeout gives defenders the round")
 fresh();attacker.alive=false;before=game.scores[defender.faction];game.update_cs_round()
 check(game.scores[defender.faction]==before+1,"All attackers dead before planting gives defenders the round")
 fresh();defender.alive=false;before=game.scores[attacker.faction];game.update_cs_round()
 check(game.scores[attacker.faction]==before+1,"Eliminating defenders gives attackers the round")
 fresh();var old_life=attacker.life_id;attacker.die(defender,"test");freeze();var dropped=game.cs_drop_position
 check(game.cs_carrier==0 and dropped.is_finite(),"Carrier death drops a recoverable bomb on supported ground")
 game.now=attacker.respawn_at+1;attacker._physics_process(1.0/60)
 check(not attacker.alive and attacker.life_id==old_life,"Dead combatant cannot respawn inside a bomb round")
 attacker.respawn();freeze();attacker.global_position=dropped
 var recovery=game.cs_interaction(attacker);check(recovery.get("key","")=="cs_recover" and game.complete_interaction(attacker,recovery),"Attacker recovers dropped bomb with Use")
 fresh();place(attacker,0);game.complete_interaction(attacker,game.interaction_for(attacker));place(defender,0)
 defuse=game.interaction_for(defender);game.now=float(game.site_states[0].bomb_at)
 check(not game.complete_interaction(defender,defuse),"Defuse completing at or after detonation time is rejected")
 fresh();place(attacker,0)
 var barrier=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(5,5,.12);shape.shape=box;barrier.add_child(shape);game.add_child(barrier);barrier.global_position=(attacker.eye.global_position+game.arena.sites[0]+Vector3.UP*1.2)*.5
 await physics_frame
 check(game.cs_interaction(attacker).is_empty(),"A real intervening wall blocks planting")
 barrier.queue_free();await physics_frame
 fresh();var team=attacker.faction;var character=attacker.character;var initial_life=attacker.life_id
 game.round_number=15;game.end_round("transition test");game.now=game.break_until;game._physics_process(1.0/60);freeze()
 check(game.round_number==16 and game.attacking_faction!=team,"Bomb roles swap after fifteen completed rounds")
 check(attacker.character==character and attacker.alive and attacker.life_id==initial_life+1,"Side swap keeps character and restores exactly one round life")
 var normal=GameTypeSettings.new();normal.time_limit_seconds=180;game.stop_game();game.apply_game_type_settings(normal)
 game.open_game_type_settings();await process_frame
 check(game.game_type_editor.controls.time_limit_seconds.value==180 and game.game_type_editor.controls.time_limit_seconds.max_value==3600,"Loading a non-bomb type restores normal time slider limits")
 game.game_type_editor.close_editor();await process_frame
 game.apply_game_type_settings(NestGameTypeLibrary.load_type("builtin:4"));game.team_size=1;game.start_game();fresh()
 game.scores[attacker.faction]=game.tuning.score_limit-1;defender.alive=false;game.update_cs_round()
 check(game.finished and game.scores[attacker.faction]==game.tuning.score_limit,"Reaching round score target ends match")
 game.stop_game();game.queue_free();await process_frame
 print("V20 UPDATE2: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
