extends SceneTree
var game
func _initialize():call_deferred("run")
func setup(mode: int,map: int):
 if game.running:game.stop_game();await process_frame
 var rules=NestMatchPresets.create(mode,map,1);rules.bots_fill_empty_slots=true;rules.bots_team_0=4;rules.bots_team_1=5
 game.apply_game_type_settings(rules);game.clear_screen();game.start_game();game.context="playing";game.current_screen="playing";game.create_hud();game.hud.visible=true
 game.player.local_player=false;game.player.bot_movement=NestBotMovement.new(game.player)
func run():
 Engine.max_fps=120
 var args=OS.get_cmdline_user_args();var map=int(args[0]);var mode=int(args[1]);var seconds=float(args[2]);seed(1012000+map*13+mode)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.prefs.light_preset();game.prefs.apply();await setup(mode,map)
 var started=Time.get_ticks_msec();var ticks=0;var bad=0;var planted=0;var drilling=0;var flags=0;var kills=0;var captures=0;var delivers=0;var round_max=1;var matches=0;var checkpoint_at=0;var node_max=0.;var memory_start=Performance.get_monitor(Performance.MEMORY_STATIC)
 while Time.get_ticks_msec()-started<seconds*1000:
  await physics_frame;ticks+=1;round_max=maxi(round_max,game.round_number);node_max=maxf(node_max,Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
  if game.mode==4 and game.cs_planted():planted+=1
  for s in game.site_states:
   if game.mode==0 and s.stage=="planted":planted+=1
   if s.stage=="drilling":drilling+=1
  var k=0;var c=0;var d=0
  for actor in game.actors:
   if not actor.position.is_finite() or (actor.alive and actor.global_position.y< -5):bad+=1
   k+=actor.kills;c+=actor.captures;d+=actor.delivered
   if actor.flag_carry>=0:flags+=1
  kills=maxi(kills,k);captures=maxi(captures,c);delivers=maxi(delivers,d)
  if int((Time.get_ticks_msec()-started)/15000)>checkpoint_at:
   checkpoint_at+=1;print("SOAK_PROGRESS ",NestArena.MAP_NAMES[map]," mode=",mode," seconds=",int((Time.get_ticks_msec()-started)/1000)," rounds=",round_max," kills=",kills," planted=",planted," flag_frames=",flags," delivered=",delivers)
  if game.finished:matches+=1;await setup(mode,map)
 var elapsed=(Time.get_ticks_msec()-started)/1000.
 var result={"map":NestArena.MAP_NAMES[map],"map_id":map,"mode":mode,"seconds":elapsed,"ticks":ticks,"tps":ticks/elapsed,"actors":game.actors.size(),"invalid_positions":bad,"planted_frames":planted,"drilling_frames":drilling,"flag_carry_frames":flags,"max_round":round_max,"kills":kills,"captures":captures,"delivered":delivers,"matches_finished":matches,"max_nodes":node_max,"memory_growth_mb":(Performance.get_monitor(Performance.MEMORY_STATIC)-memory_start)/1048576.0}
 print("SOAK_RESULT ",JSON.stringify(result));game.stop_game();game.queue_free();await create_timer(.3).timeout;quit(1 if bad else 0)
