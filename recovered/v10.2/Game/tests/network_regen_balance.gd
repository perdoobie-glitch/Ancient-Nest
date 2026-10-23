extends SceneTree
var game
var role=""
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 if ok:print("PASS "+role+" "+label)
 else:failures+=1;push_error(label)
func run():
 role="host" if "host" in OS.get_cmdline_user_args() else "client"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.apply_game_type_settings(NestMatchPresets.create(1));game.bot_fill=false;game.team_size=1;game.mode=1;game.matchup=1
 if role=="host":check(game.host_direct(17990,"RegenHost",0)==OK,"host opens")
 else:check(game.join_direct("127.0.0.1",17990,"RegenClient",1)==OK,"client connects")
 var until=Time.get_ticks_msec()+15000
 while game.lobby_members.size()<2 and Time.get_ticks_msec()<until:await process_frame
 if game.lobby_members.size()<2:check(false,"lobby connection");quit(1);return
 if role=="host":
  game.start_game();game.context="pause"
  var remote
  for actor in game.actors:
   if actor.remote_peer>1:remote=actor
  remote.health=5;remote.shield=25;remote.last_damage=game.now-3;remote.regen_anchor_damage=-INF
  await create_timer(1.2).timeout
  check(remote.health>5 and remote.health<25 and remote.shield>25 and remote.shield<125,"host heals both resources concurrently")
  var health=remote.health;var shield=remote.shield
  remote.take_damage(10,"torso","bullet",false,null,game.next_event()*16,Vector3.ZERO,"unknown",0)
  check(absf(remote.shield-(shield-10))<.01 and absf(remote.health-health)<.01,"host hit uses partial shield")
  await create_timer(.8).timeout
  check(absf(remote.health-health)<.01 and not remote.is_regenerating(),"host healing pauses after hit")
  await create_timer(5.5).timeout
  check(absf(remote.health-25)<.01 and absf(remote.shield-125)<.01,"host finishes restarted regeneration")
 else:
  while not game.running and Time.get_ticks_msec()<until:await process_frame
  await create_timer(.7).timeout
  check(game.player.health>5 and game.player.health<25 and game.player.shield>25 and game.player.shield<125,"client receives partial health and shield recovery")
  check(game.player.is_regenerating(),"client derives healing cue from replicated state")
  await create_timer(1.1).timeout
  check(not game.player.is_regenerating(),"client healing cue stops after damage")
  await create_timer(5.5).timeout
  check(absf(game.player.health-25)<.01 and absf(game.player.shield-125)<.01,"client receives completed regeneration")
  await create_timer(1).timeout
 game.close_connection();game.stop_game();game.queue_free();await create_timer(.3).timeout
 print("NETWORK REGEN "+role+": "+str(failures)+" failures");quit(1 if failures else 0)
