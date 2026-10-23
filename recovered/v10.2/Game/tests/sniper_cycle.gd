extends SceneTree
var game
var actor
var checks=0
var failures=0
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func equip(kind: String):
 actor.weapons[0]=NestWeaponCatalog.profile(kind);actor.slot=0;actor.ammo[0]=5;actor.reserve[0]=30;actor.action_state="ready";actor.cooldown=0;actor.burst_left=0;actor.last_shot_frame=-1;actor.alive=true;actor.bomb_equipped=false;actor.update_weapon_art()
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.game_type=NestMatchPresets.create(1);game.mode=1;game.bot_fill=false;game.start_game();game.set_physics_process(false);game.context="pause";game.tuning.score_limit=100000
 actor=game.player;actor.set_physics_process(false)
 var normal=NestWeaponCatalog.profile("sniper");var plasma=NestWeaponCatalog.profile("plasma_sniper")
 check(is_equal_approx(normal.interval,plasma.interval),"Both sniper intervals match")
 check(is_equal_approx(normal.interval,1.5),"V7 40rpm / 1.5-second cycle applied")
 for kind in ["sniper","plasma_sniper"]:
  equip(kind);game.now=100;check(actor.fire_trigger(),kind+" initial shot fires");var remaining=actor.ammo[0];var duration=actor.fire_interval(actor.weapons[0].interval)
  await process_frame;game.now=100+duration*.5;check(not actor.fire_trigger() and actor.ammo[0]==remaining,kind+" cannot fire halfway through cycle")
  check(absf(NestSniperCycle.phase(actor)-.5)<.001,kind+" animation shares firing timer")
  actor.presentation.animate_parts(actor.weapon_art,-1);NestSniperCycle.update_art(actor.weapon_art,actor,-1);NestSniperCycle.update_view_hand(actor,-1)
  if kind=="sniper":
   var lever=actor.weapon_art.find_child("ChargingHandle*",true,false)
   check(lever!=null and absf(lever.rotation.z)>.9, "Ballistic bolt visibly unlocked")
   check(actor.view_grip_parts[1].position.x>.1,"Right hand reaches bolt")
   actor.presentation.animate_parts(actor.remote_art,-1)
   check(absf(actor.remote_art.find_child("ChargingHandle*",true,false).rotation.z)>.9,"Remote bolt cycles too")
  else:
   check(actor.weapon_art.has_meta("sniper_charge") and actor.remote_art.has_meta("sniper_charge"),"Both first and third person charge banks exist")
   var lights=actor.weapon_art.get_meta("sniper_charge")
   check(lights[0].material_override.emission_energy_multiplier>1 and lights[4].material_override.emission_energy_multiplier<.1,"Charge bank fills progressively")
  await process_frame;game.now=100+duration-.0001;check(not actor.fire_trigger(),kind+" locked immediately before cycle ends")
  await process_frame;game.now=100+duration;check(actor.fire_trigger() and actor.ammo[0]==remaining-1,kind+" ready exactly at cycle end")
  actor.action_state="reloading";check(NestSniperCycle.phase(actor)<0,kind+" reload suppresses cycle")
  actor.action_state="ready";actor.last_shot_kind="rifle";check(NestSniperCycle.phase(actor)<0,kind+" switching from another gun does not fake cycle")
  actor.last_shot_kind=kind;actor.alive=false;check(NestSniperCycle.phase(actor)<0,kind+" death stops animation")
 check(NestMigrationState.ACTOR_FIELDS.has("last_shot_kind"),"Migration retains cycle weapon identity")
 game.stop_game();game.queue_free();await create_timer(.4).timeout;print("SNIPER CYCLE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
