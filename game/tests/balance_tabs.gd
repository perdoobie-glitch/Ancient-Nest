extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: "+label)
 else:failures+=1;push_error("FAIL: "+label)
func hit(game,target,shooter,kind,region,category="bullet",raw=40.0):
 return target.take_damage(raw,region,category,true,shooter,game.next_event()*16,Vector3.ZERO,kind)
func reset_target(game,target,model=1):
 game.game_type=GameTypeSettings.new();game.game_type.mode=1;game.game_type.bots_fill_empty_slots=false;game.game_type.health_type=model;game.game_type.validate();target.respawn();target.set_physics_process(false);target.set_process(false)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 game.open_game_type_settings();await process_frame
 var editor=game.game_type_editor
 check(editor!=null,"Settings editor opens with new controls")
 for title in ["Weapon Damage","Annu Health","Naki Shields"]:
  editor.jump_to_category(title);check(editor.tabs.get_tab_title(editor.tabs.current_tab)==title,"Can navigate to "+title+" tab")
 check(editor.controls.annu_body_health.value==100 and editor.controls.annu_head_health.value==100,"Annu defaults preserve current health")
 check(editor.controls.annu_body_armor.value==100 and editor.controls.annu_head_armor.value==25,"Annu head/body armour have separate defaults")
 check(is_equal_approx(editor.controls.naki_body_shield_strength.value,1.7) and is_equal_approx(editor.controls.naki_head_shield_strength.value,1.35),"Naki regional shield defaults preserved")
 check(editor.weapon_controls.size()==12,"Every current gun and grenade has an individual damage control")
 for kind in editor.weapon_controls:
  editor.weapon_controls[kind].value=150
  check(editor.draft.weapon_damage_percent.get(kind,0)==150,kind+" damage edits its own draft field")
 check(game.game_type.weapon_damage_percent.is_empty(),"Editing does not mutate active weapon rules")
 editor.set_draft_value("annu_body_health",175);editor.set_draft_value("annu_head_health",125);editor.set_draft_value("annu_head_armor",70);editor.set_draft_value("naki_body_shield_strength",2.3)
 var saved=NestGameTypeLibrary.save_new(editor.draft,"Regional balance fixture");check(saved.ok,"New balance settings save in a named game type")
 var restored=NestGameTypeLibrary.load_saved(saved.id)
 check(restored.annu_body_health==175 and restored.annu_head_health==125 and restored.annu_head_armor==70 and is_equal_approx(restored.naki_body_shield_strength,2.3),"Named game type restores faction values")
 check(restored.weapon_damage_percent.size()==12 and restored.weapon_damage_scale("rocket")==1.5,"Named game type restores all individual gun damage scales")
 var shared=GameTypeSettings.new();check(shared.import_share_code(restored.export_share_code()) and shared.to_network_dict()==restored.to_network_dict(),"Share code preserves all new settings")
 var dirty=GameTypeSettings.new();dirty.weapon_damage_percent={"rifle":NAN,"ak47":-500,"rocket":5000,"unknown":300,"plasma_auto":"oops"};dirty.naki_body_shield_strength=INF;dirty.annu_head_health=-20;dirty.validate()
 check(dirty.weapon_damage_scale("rifle")==1 and dirty.weapon_damage_scale("ak47")==0 and dirty.weapon_damage_scale("rocket")==10 and not dirty.weapon_damage_percent.has("unknown") and not dirty.weapon_damage_percent.has("plasma_auto"),"Weapon damage rejects unknown/nonfinite/non-numeric values and clamps range")
 check(dirty.annu_head_health==10 and is_equal_approx(dirty.naki_body_shield_strength,1.7),"Faction settings clamp invalid values safely")
 editor.restore_defaults();check(editor.draft.weapon_damage_percent.is_empty() and editor.weapon_controls.ak47.value==100 and editor.controls.annu_head_armor.value==25,"Restore Defaults resets weapon and faction controls")
 editor.hide();editor.queue_free();game.game_type_editor=null;await process_frame
 game.game_type=GameTypeSettings.new();game.game_type.mode=1;game.game_type.bots_fill_empty_slots=false;game.sync_game_type_to_legacy();game.start_game();game.set_physics_process(false);game.context="pause"
 var shooter=game.player;shooter.set_physics_process(false);shooter.set_process(false)
 var target=NestActor.new();target.game=game;target.faction=1;game.add_child(target);game.actors.append(target);target.set_physics_process(false);target.set_process(false)
 for kind in ["rifle","ak47","burst","burst_scoped","sidearm","shotgun","plasma_br","plasma_auto"]:
  reset_target(game,target);hit(game,target,shooter,kind,"torso");var base=100-target.shield
  reset_target(game,target);game.game_type.weapon_damage_percent[kind]=50;hit(game,target,shooter,kind,"torso")
  check(is_equal_approx(100-target.shield,base*.5),kind+" selected gun actually deals half body shield damage")
  check(game.game_type.weapon_damage_scale("rocket")==1,kind+" change does not modify other guns")
  reset_target(game,target);game.game_type.weapon_damage_percent[kind]=0;hit(game,target,shooter,kind,"head")
  check(target.shield==100 and target.health==100,kind+" zero damage suppresses head and shield damage")
 reset_target(game,target);game.game_type.weapon_damage_percent.rocket=50
 hit(game,target,shooter,"rocket","torso","explosion",40);check(is_equal_approx(target.shield,80),"Rocket explosion damage uses the individual gun scale")
 reset_target(game,target);game.game_type.weapon_damage_percent.rocket=50
 hit(game,target,shooter,"rocket","torso","heavy",40);check(is_equal_approx(target.shield,80),"Rocket direct damage uses the same scale exactly once")
 reset_target(game,target);game.game_type.weapon_damage_percent.rocket=50
 hit(game,target,shooter,"","torso","explosion",40);check(is_equal_approx(target.shield,60),"Rocket edit does not change grenade damage")
 for kind in ["frag_grenade","plasma_grenade"]:
  reset_target(game,target);game.game_type.weapon_damage_percent[kind]=50;hit(game,target,shooter,kind,"torso","explosion",40)
  check(is_equal_approx(target.shield,80),kind+" explosion damage uses its own independent scale")
 reset_target(game,target);game.game_type.naki_shield_capacity=200;game.game_type.naki_body_shield_strength=2;game.game_type.naki_head_shield_strength=4;target.respawn()
 check(target.shield==200,"Naki shield capacity changes actual spawn protection")
 hit(game,target,shooter,"rifle","torso");check(is_equal_approx(target.shield,194),"Naki body strength uses its independent value")
 hit(game,target,shooter,"rifle","head");check(is_equal_approx(target.shield,191),"Naki head strength uses its independent value")
 reset_target(game,target);game.game_type.naki_body_shield_strength=.5;hit(game,target,shooter,"rifle","torso");check(is_equal_approx(target.shield,76),"Shield strength below 1 makes shields weaker")
 reset_target(game,target,2);game.game_type.annu_body_health=200;game.game_type.annu_head_health=100;game.game_type.annu_body_armor=300;game.game_type.annu_head_armor=60;target.respawn()
 check(target.health==200 and target.armor==300 and target.helmet_hp==60 and target.shield==0,"Annu health and independent armour capacities affect actual spawn")
 hit(game,target,shooter,"rifle","torso");check(is_equal_approx(target.health,191) and is_equal_approx(target.armor,291) and target.helmet_hp==60,"Body shot uses body armour and leaves helmet unchanged")
 hit(game,target,shooter,"rifle","head");check(is_equal_approx(target.health,160.4) and is_equal_approx(target.helmet_hp,57.3) and target.armor==291,"Head shot uses helmet, then head durability, without touching body armour")
 reset_target(game,target,2);game.game_type.annu_head_health=200;hit(game,target,shooter,"plasma_br","head");check(is_equal_approx(target.health,75),"Increasing Annu head health reduces precision head damage")
 reset_target(game,target,2);game.game_type.annu_body_health=200;game.game_type.annu_head_health=100;target.respawn();hit(game,target,shooter,"plasma_br","head");check(target.health==100,"Body health and head durability remain independently adjustable")
 reset_target(game,target,2);game.game_type.annu_precision_ignores_helmet=false;hit(game,target,shooter,"plasma_br","head");check(is_equal_approx(target.health,57.5) and is_equal_approx(target.helmet_hp,17.5),"Optional precision protection applies actual helmet absorption")
 reset_target(game,target,2);game.game_type.sniper_instant_headshots=false;game.game_type.annu_head_health=1000;hit(game,target,shooter,"sniper","head");check(target.alive,"Sniper instant-headshot switch allows numerical head-health tuning")
 reset_target(game,target,2);game.game_type.annu_body_armor=300;game.game_type.annu_head_armor=60
 var character_id=String(NestCharacterCatalog.by_index(target.character).id);game.game_type.character_traits[character_id]={"armor_strength_percent":50.0,"helmet_strength_percent":200.0};game.game_type.validate();target.respawn()
 check(target.armor==150 and target.helmet_hp==120,"Existing character-specific armour traits still multiply the new base capacities")
 # Exercise actual pending-rule lifecycle with the real local actor.
 game.remove_child(target);game.actors.erase(target);target.queue_free();game.game_type=GameTypeSettings.new();game.game_type.mode=1;game.game_type.bots_fill_empty_slots=false;game.sync_game_type_to_legacy();shooter.respawn()
 var next=game.game_type.duplicate_settings();next.health_type=2;next.annu_body_health=180;next.annu_head_armor=80;next.weapon_damage_percent.rifle=50
 check(game.apply_game_type_settings(next) and game.pending_game_type!=null,"Running host stages new balance settings")
 check(shooter.health!=180 and game.game_type.weapon_damage_scale("rifle")==1,"Living traits and active weapon damage stay unchanged until their application points")
 shooter.respawn();check(shooter.health==180 and shooter.helmet_hp==80 and game.game_type.weapon_damage_scale("rifle")==1,"Faction capacities apply on respawn while gun damage remains pending")
 check(game.restart_round_in_match(),"Round restart applies pending rules")
 check(game.player.health==180 and game.game_type.weapon_damage_scale("rifle")==.5,"Round reset commits gun balance and new protection")
 print("BALANCE TABS: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
