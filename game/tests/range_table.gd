extends SceneTree
var checks=0
var failures=0
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 for entry in NestWeaponCatalog.data().weapons:
  if entry.get("slot","") not in ["primary","secondary"]:continue
  var w=NestWeaponCatalog.definition(entry.id)
  var start=float(w.falloff_start_m);var end=float(w.falloff_end_m)
  check(end>start and float(w.falloff_min_percent)<1,"Range profile exists: "+entry.id)
  check(game.weapon_falloff(w,start)>=game.weapon_falloff(w,(start+end)/2) and game.weapon_falloff(w,end)<=game.weapon_falloff(w,(start+end)/2),"Monotonic range loss: "+entry.id)
 for id in ["falcon_smg","viper_pulse_smg"]:
  var w=NestWeaponCatalog.definition(id)
  check(is_equal_approx(game.weapon_falloff(w,8),1.0),id+" full damage within 8m")
  check(game.weapon_falloff(w,20)<.48,id+" below 48 percent damage at 20m")
  check(is_equal_approx(game.weapon_falloff(w,28),.12),id+" 12 percent damage at 28m")
  check(NestWeaponCatalog.profile(id).spread_half_angle_deg<.75,id+" tighter close-range cone")
 game.stop_game();game.queue_free();await create_timer(.3).timeout;print("RANGE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
