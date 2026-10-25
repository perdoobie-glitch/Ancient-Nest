extends SceneTree
var game
var folder=""
var index=0
var last_command=0
func _initialize():call_deferred("run")
func run():
 var args=OS.get_cmdline_user_args();folder=args[0];index=int(args[1])
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.sandbox_mode=true;game.set_process(false);Engine.max_fps=60;game.prefs.values.username="Playtester"+str(index)
 game.matchmaking.endpoint="ws://127.0.0.1:18080/v1/matchmaking"
 process_frame.connect(func():
  var samples=game.matchmaking.hybrid.cpu_samples;samples.resize(180);samples.fill(1.0))
 await create_timer(3).timeout
 while true:
  await create_timer(.15).timeout
  var mm=game.matchmaking;var hub=mm.hybrid
  var command_path=folder+"/command-"+str(index)+".json"
  if FileAccess.file_exists(command_path):
   var command=JSON.parse_string(FileAccess.get_file_as_string(command_path))
   if command is Dictionary and int(command.get("sequence",0))>last_command:
    last_command=int(command.sequence)
    match str(command.action):
     "browser":game.open_server_browser()
     "matchmaking":mm.playlist=str(command.get("playlist","duel_1v1"));game.open_matchmaking()
     "create":mm.party_action("custom_create",{"name":"Lifecycle Playtest","mode":2,"map":0,"matchup":1,"capacity":int(command.get("capacity",2))})
     "browse":mm.refresh_browser()
     "join":mm.party_action("join",{"code":str(command.code)})
     "leave_party":mm.party_action("leave")
     "search":mm.begin_search_countdown()
     "cancel":
      if mm.search_countdown_until>0:mm.cancel_search_countdown()
      else:mm.party_action("cancel")
     "start":mm.party_action("custom_start")
     "finish":
      if hub.authority:game.finished=true
     "disconnect":mm.leave();game.show_main()
     "drop":mm.leave(false);game.show_main()
     "control_outage":
      hub.session.lease_until=hub.server_time()+2
      hub.master_authenticated=false;hub.scheduler.reconnecting=true;hub.scheduler.permanent=true;hub.scheduler.retry_at=0;hub.ws.close(4000,"QA control outage")
     "control_recover":
      hub.scheduler.permanent=false;hub.scheduler.reconnecting=true;hub.scheduler.retry_at=hub.clock()+.1
  if mm.phase=="voting":mm.vote(2,0,1)
  var roster=[]
  for actor in game.actors:roster.append({"id":actor.net_id,"name":actor.username,"faction":actor.faction,"local":actor.local_player,"peer":actor.remote_peer})
  var camera_ok=is_instance_valid(game.player) and is_instance_valid(game.player.camera) and game.get_viewport().get_camera_3d()==game.player.camera
  var state={"command":last_command,"phase":mm.phase,"status":mm.status,"connected":hub.master_connected(),"running":game.running,"frozen":hub.session.frozen,"authority":hub.authority,"epoch":hub.session.epoch,"actors":game.actors.size(),"roster":roster,"custom":mm.custom_match(),"party":mm.party,"lobbies":mm.browser_lobbies,"camera":camera_ok,"snapshot_ticks":game.snapshot_interval_ticks,"snapshots":game.net_stats.get("snapshots_completed",0),"checkpoint":hub.checkpoint_digest,"screen":game.current_screen}
  state["continuity"]=hub.session.continuity_until;state["lease"]=hub.session.lease_until;state["master_time"]=hub.server_time();state["master_metrics"]=hub.scheduler.metrics
  var out=FileAccess.open(folder+"/state-"+str(index)+".json",FileAccess.WRITE);out.store_string(JSON.stringify(state));out.close()
