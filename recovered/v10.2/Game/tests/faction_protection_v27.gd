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
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 var rules=GameTypeSettings.new();rules.health_type=0;rules.bots_fill_empty_slots=false;rules.mode=2;game.apply_game_type_settings(rules)
 check(GameTypeSettings.new().health_type==0,"Built-in protection default is character-specific")
 game.clear_screen();game.start_game();game.set_physics_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 for character in [0,1]:
  p.set_character(character);p.respawn();game.create_hud();game._process(0)
  var naki=character==0
  check(p.damage_model()==("naki" if naki else "annu"),"Character %d selects its own protection model"%character)
  check(p.health>0 and (p.shield>0 if naki else p.shield==0 and p.armor>0),"Naki has shields/health; Annu has armor/health and zero normal shields")
  check(game.protection_bars.size()==(1 if naki else 2) and game.hud_protection.text.contains("SHIELD" if naki else "ARMOR"),"Protection HUD matches the actual faction model")
  var health=p.health;var armor=p.armor;var shield=p.shield
  p.take_damage(12,"torso","bullet",false,null,game.next_event()*16,Vector3.INF,"rifle")
  check(p.shield<shield and p.health==health and p.armor==armor if naki else p.shield==0 and p.armor<armor and p.health<health,"Damage routes through Naki shields or Annu armor/health")
  if naki:
   p.shield=0;health=p.health;armor=p.armor;p.take_damage(12,"torso","bullet",false,null,game.next_event()*16,Vector3.INF,"rifle")
   check(p.health<health and p.armor==armor,"Shieldless Naki uses body health rather than Annu armor")
   game._process(0);check(game.protection_bars.size()==1 and not game.hud_protection.text.contains("HEALTH"),"Naki hidden health stays off the HUD after shields drain")
 check(game.hud_protection.text.contains("HEALTH") and game.hud_protection.text.contains("ARMOR"),"Annu shows health and armor on the HUD")
 # Explicit custom health types are still supported and must not be silently removed.
 rules.health_type=1;game.apply_game_type_settings(rules);p.respawn()
 check(p.damage_model()=="naki" and p.shield>0,"An explicit custom Naki-health override remains available")
 rules.health_type=0;game.apply_game_type_settings(rules);p.respawn()
 check(p.damage_model()=="annu" and p.shield==0 and p.armor>0,"Returning to Character default restores Annu armor")
 game.stop_game();game.queue_free();await frames(8)
 print("FACTION PROTECTION V27: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
