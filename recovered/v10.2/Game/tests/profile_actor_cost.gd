extends SceneTree
class ProfileBot extends NestActor:
 var cost={"physics_us":0,"visual_us":0,"ai_us":0,"movement_us":0,"ticks":0}
 func _physics_process(delta:float):
  var t=Time.get_ticks_usec();super._physics_process(delta);cost.physics_us+=Time.get_ticks_usec()-t;cost.ticks+=1
 func update_visual(delta:float):
  var t=Time.get_ticks_usec();super.update_visual(delta);cost.visual_us+=Time.get_ticks_usec()-t
 func bot_intent(delta:float)->Dictionary:
  var t=Time.get_ticks_usec();var r=super.bot_intent(delta);cost.ai_us+=Time.get_ticks_usec()-t;return r
 func movement_step(move:Vector2,jump:bool,crouch_want:int,yaw:float,delta:float,replaying:bool=false)->bool:
  var t=Time.get_ticks_usec();var r=super.movement_step(move,jump,crouch_want,yaw,delta,replaying);cost.movement_us+=Time.get_ticks_usec()-t;return r
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;game.bot_fill=false;game.mode=2;game.start_game();game.context="pause";Engine.max_fps=120
 var bots=[]
 for i in range(9):
  var bot=ProfileBot.new();bot.game=game;bot.faction=i%2;bot.net_id=-(i+1);game.add_child(bot);game.actors.append(bot);bot.respawn();bots.append(bot)
 await create_timer(8).timeout
 var result={"physics_us":0,"visual_us":0,"ai_us":0,"movement_us":0,"ticks":0}
 for bot in bots:
  for key in result:result[key]+=bot.cost[key]
 print("ACTOR COST ",JSON.stringify(result));game.stop_game();game.queue_free();await process_frame;quit()
