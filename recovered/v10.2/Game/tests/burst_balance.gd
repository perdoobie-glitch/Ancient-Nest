extends SceneTree
var game
var shooter
var victim
var times=[]
var kind=""
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error(label)
func on_shot(id: int,time: float,_origin: Vector3,_directions: Array):
 times.append(time)
 victim.take_damage(shooter.weapons[0].damage,"head","bullet",true,shooter,id,shooter.eye.global_position,kind,0)
func trial(weapon: String,character: int) -> Dictionary:
 kind=weapon;game.now=0;game.finished=false;game.break_until=0;times.clear()
 victim.set_character(character);victim.respawn();victim.global_position=Vector3(75,10,75)
 shooter.weapons[0]=NestWeaponCatalog.profile(weapon);shooter.slot=0;shooter.ammo[0]=shooter.weapons[0].magazine;shooter.reserve[0]=100;shooter.action_state="ready";shooter.cooldown=0;shooter.burst_left=0;shooter.last_shot_frame=-1;shooter.alive=true;shooter.bomb_equipped=false
 for tick in range(1200):
  game.now=float(tick)/600
  shooter._physics_process(1.0/600)
  shooter.fire_trigger()
  await process_frame
  if not victim.alive:break
 return {"count":times.size(),"time":float(times[-1])-float(times[0]) if times.size()>0 else INF}
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.game_type=NestMatchPresets.create(1);game.mode=1;game.bot_fill=false;game.start_game();game.set_physics_process(false);game.tuning.score_limit=100000;game.context="pause"
 shooter=game.player;shooter.set_physics_process(false);shooter.shot_fired.connect(on_shot)
 victim=NestActor.new();victim.game=game;victim.faction=1;victim.net_id=99;game.add_child(victim);game.actors.append(victim);victim.set_physics_process(false)
 for character in [0,1]:
  var br=await trial("burst_scoped",character)
  var ak=await trial("ak47",character)
  print("MEASURED ",character," BR ",br," AK ",ak)
  check(br.count==(6 if character==0 else 5),"Scoped BR measured head-hit count")
  check(ak.count==(9 if character==0 else 8),"AK measured head-hit count")
  check(absf(br.time-ak.time-(.2 if character==0 else .2104166667))<.004,"Measured AK remains faster than scoped BR")
 var plasma=await trial("plasma_br",0)
 check(plasma.count==5 and absf(plasma.time-.67)<.004,"Five-round plasma burst / five-head-hit kill has correct cadence")
 game.stop_game();game.queue_free();await create_timer(.3).timeout;print("BURST BALANCE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
