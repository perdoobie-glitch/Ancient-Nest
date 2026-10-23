extends SceneTree
var game
var failures=0
var role=""
func _initialize():call_deferred("run")
func check(ok,label):
 if ok:print("PASS "+role+" "+label)
 else:failures+=1;push_error(label)
func run():
 role="host" if "host" in OS.get_cmdline_user_args() else "client"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.apply_game_type_settings(NestMatchPresets.create(1));game.bot_fill=false;game.team_size=1;game.mode=1;game.matchup=1
 if role=="host":check(game.host_direct(17991,"CycleHost",0)==OK,"opens")
 else:check(game.join_direct("127.0.0.1",17991,"CycleClient",1)==OK,"connects")
 var deadline=Time.get_ticks_msec()+15000
 while game.lobby_members.size()<2 and Time.get_ticks_msec()<deadline:await process_frame
 if game.lobby_members.size()<2:check(false,"lobby connection");quit(1);return
 if role=="host":
  game.start_game();game.context="pause";await create_timer(.6).timeout
  for kind in ["sniper","plasma_sniper"]:
   var a=game.player;a.weapons[0]=NestWeaponCatalog.profile(kind);a.slot=0;a.ammo[0]=5;a.action_state="ready";a.cooldown=0;a.update_weapon_art();check(a.fire_trigger(),kind+" shot accepted")
   await create_timer(1.8).timeout
 else:
  while not game.running and Time.get_ticks_msec()<deadline:await process_frame
  game.context="pause"
  for kind in ["sniper","plasma_sniper"]:
   var target
   var seen=false
   var until=Time.get_ticks_msec()+6500
   while not seen and Time.get_ticks_msec()<until:
    for a in game.actors:
     if a.net_id==1:target=a
    if target!=null and target.last_shot_kind==kind and NestSniperCycle.phase(target)>0:seen=true
    await process_frame
   check(seen,kind+" identity and active cycle replicate")
  await create_timer(2).timeout
 game.close_connection();game.stop_game();game.queue_free();await create_timer(.3).timeout;print("NETWORK SNIPER "+role+": "+str(failures)+" failures");quit(1 if failures else 0)
