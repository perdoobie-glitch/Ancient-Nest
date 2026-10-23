extends SceneTree
var game
var failures=0
func _initialize():call_deferred("run")
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.bot_fill=false;game.apply_game_type_settings(NestMatchPresets.create(2,2));game.bot_fill=false;game.fair_playing_field=false;game.start_game();game.player.set_physics_process(false);game.player.global_position=Vector3(80,25,80)
 var bot=NestActor.new();bot.game=game;bot.faction=1;game.add_child(bot);game.actors.append(bot);bot.respawn();bot.bot_movement=NestBotMovement.new(bot)
 for ramp in game.arena.up_routes:
  for reverse in [false,true]:
   var start=ramp.end if reverse else ramp.start;var goal=ramp.start if reverse else ramp.end
   bot.global_position=start+Vector3.UP*.08;bot.controlled=Vector3.ZERO;bot.external=Vector3.ZERO;bot.velocity=Vector3.ZERO;bot.target=null;bot.bot_destination=goal;bot.bot_route=game.arena.route(bot.global_position,goal);bot.bot_repath=INF;bot.bot_movement.reset()
   var reached=false;var deadline=Time.get_ticks_msec()+10000
   while Time.get_ticks_msec()<deadline:
    await physics_frame
    if absf(bot.global_position.y-goal.y)<.4 and Vector2(bot.global_position.x-goal.x,bot.global_position.z-goal.z).length()<1.6:reached=true;break
   print("RAMP ",start," -> ",goal," reached=",reached," actual=",bot.global_position)
   if not reached:failures+=1
 print("TRAVERSAL failures=",failures)
 game.stop_game();game.queue_free();await create_timer(.3).timeout;quit(0 if failures==0 else 1)
