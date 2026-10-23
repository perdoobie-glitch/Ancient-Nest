extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 game.bot_fill=false;game.mode=1;game.start_game();game.set_physics_process(false);game.context="pause";var p=game.player;p.set_physics_process(false);p.set_process(false)
 for kind in ["plasma_br","plasma_auto"]:
  p.weapons.assign([NestWeaponCatalog.profile(kind)]);p.ammo.assign([48]);p.reserve.assign([144]);p.slot=0;p.action_state="ready";p.cooldown=0;p.burst_left=0;p.last_shot_frame=-1;game.now=0
  var before=p.ammo[0]
  check(p.fire_trigger() and p.ammo[0]==before-1,kind+" first eligible press emits immediately")
  var first=p.ammo[0];check(not p.fire_trigger() and p.ammo[0]==first,kind+" duplicate same-frame trigger does not double fire")
  for i in range(1,61):
   game.now=i/60.0;p._physics_process(1.0/60)
   if kind=="plasma_auto" and i<60:p.fire_trigger()
   await process_frame
  var count=before-p.ammo[0]
  print("TIMED ",kind," shots ",count)
  check(count==4 if kind=="plasma_br" else count==15,kind+" retains configured burst/cadence over one simulation second")
  p.ammo[0]=0;p.cooldown=0;game.now+=2;p.burst_left=0;await process_frame;p.fire_trigger();check(p.ammo[0]==0,kind+" empty fire cannot spend negative ammo")
  p.action_state="reloading";p.action_until=game.now+2;p.ammo[0]=1;await process_frame;check(not p.fire_trigger() and p.ammo[0]==1,kind+" reload blocks premature fire")
 print("V19 TIMING: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
