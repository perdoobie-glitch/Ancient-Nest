extends SceneTree
var game
var path=""
var actions_done=0
func _initialize():call_deferred("run")
func run():
 Engine.max_fps=60
 var args=OS.get_cmdline_user_args();var name="PartyPlayer";var playlist="tactical_3v3";var hub="ws://127.0.0.1:18080/v1/matchmaking"
 for i in range(args.size()-1):
  if args[i]=="--status":path=args[i+1]
  if args[i]=="--name":name=args[i+1]
  if args[i]=="--playlist":playlist=args[i+1]
  if args[i]=="--hub":hub=args[i+1]
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.prefs.values.username=name
 var mm=game.matchmaking;mm.playlist=playlist;mm.endpoint=hub;mm.open_party()
 while true:
  await create_timer(.15).timeout
  var h=mm.hybrid
  if FileAccess.file_exists(path+".actions"):
   var actions=JSON.parse_string(FileAccess.get_file_as_string(path+".actions"))
   if actions is Array:
    while actions_done<actions.size():
     var message=actions[actions_done];actions_done+=1
     if str(message.action)=="search":mm.begin_search_countdown()
     else:mm.party_action(str(message.action),message.get("extra",{}))
  if mm.phase=="voting":mm.vote(0,2)
  if h.authority and game.running and FileAccess.file_exists(path.get_base_dir()+"/finish"):game.finished=true
  var state={"map":game.game_type.map_selection,"master_connected":h.master_connected(),"master_status":h.master_status(),"phase":mm.phase,"party":mm.party,"id":h.player_id,"running":game.running,"actors":game.actors.size(),"authority":h.authority,"frozen":h.session.frozen,"slot":mm.local_slot,"status":mm.status,"roster":h.roster,"epoch":h.session.epoch}
  var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(state));f.close()
