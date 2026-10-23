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
 game.bot_fill=false;game.team_size=2;game.mode=4;game.matchup=1;game.game_type=NestMatchPresets.create(4);game.game_type.bots_stand_still=true;game.game_type.bots_dont_shoot=true
 if role=="host":check(game.host_direct(17989,"BombHost",0)==OK,"host opens")
 else:check(game.join_direct("127.0.0.1",17989,"BombClient",0)==OK,"client connects")
 var until=Time.get_ticks_msec()+15000
 while game.lobby_members.size()<2 and Time.get_ticks_msec()<until:await process_frame
 if game.lobby_members.size()<2:check(false,"lobby connection");quit(1);return
 if role=="host":
  game.start_game();game.context="pause"
  var defender=NestActor.new();defender.game=game;defender.faction=1;defender.net_id=40;game.add_child(defender);game.actors.append(defender);defender.respawn();defender.global_position=Vector3(80,10,80);defender.set_physics_process(false)
  for actor in game.actors:
   if actor.remote_peer>1:game.cs_carrier=actor.net_id
  await create_timer(3.5).timeout
  check(game.cs_carrier==0 and game.cs_drop_position.is_finite(),"host completes remote drop")
  await create_timer(1).timeout
 else:
  while not game.running and Time.get_ticks_msec()<until:await process_frame
  while game.cs_carrier!=game.player.net_id and Time.get_ticks_msec()<until:await process_frame
  check(game.cs_carrier==game.player.net_id,"carrier assigned through snapshot")
  game.request_remote_action("bomb",1);await create_timer(.7).timeout
  check(game.player.bomb_equipped,"equip state replicated")
  check(not game.player.fire_trigger(),"client shooting blocked while equipped")
  game.request_remote_action("bomb",2);await create_timer(.3).timeout
  check(game.player.action_state=="bomb_drop" and game.player.bomb_drop_at>game.now,"drop animation state replicated")
  await create_timer(1.1).timeout
  check(game.cs_carrier==0 and not game.player.bomb_equipped,"drop completion replicated")
  await create_timer(1).timeout
 game.close_connection();game.stop_game();game.queue_free();await create_timer(.3).timeout
 print("NETWORK BOMB "+role+": "+str(failures)+" failures");quit(1 if failures else 0)
