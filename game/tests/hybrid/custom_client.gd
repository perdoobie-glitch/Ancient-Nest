extends SceneTree
var game
var path=""
var role="host"
func _initialize():call_deferred("run")
func run():
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--status":path=args[i+1]
  if args[i]=="--role":role=args[i+1]
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.sandbox_mode=true;game.set_process(false);Engine.max_fps=60
 process_frame.connect(func():
  var samples=game.matchmaking.hybrid.cpu_samples;samples.resize(180);samples.fill(1.0))
 var mm=game.matchmaking;mm.browser_mode=true;mm.party_mode=true
 await create_timer(3).timeout
 mm.search("ws://127.0.0.1:18080/v1/matchmaking")
 var created=false;var joined=false;var started=false;var code_path=path.get_base_dir()+"/custom-code"
 while true:
  await create_timer(.2).timeout
  if mm.phase=="party":
   if role=="host" and not created:
    mm.party_action("custom_create",{"name":"Native Browser Duel","mode":2,"map":0,"matchup":2,"capacity":2});created=true
   if role=="host" and mm.party.has("custom"):
    var code=FileAccess.open(code_path,FileAccess.WRITE);code.store_string(str(mm.party.code));code.close()
    if mm.party.members.size()==2 and not started:mm.party_action("custom_start");started=true
   if role=="client" and FileAccess.file_exists(code_path) and not joined:
    mm.party_action("join",{"code":FileAccess.get_file_as_string(code_path)});joined=true
  var state={"phase":mm.phase,"status":mm.status,"running":game.running,"frozen":mm.hybrid.session.frozen,"authority":mm.hybrid.authority,"actors":game.actors.size(),"custom":mm.custom_match(),"teams":game.team_characters,"physics":[game.game_type.movement_speed_percent,game.game_type.gravity_percent,game.game_type.jump_height_percent,game.game_type.air_control_percent]}
  var out=FileAccess.open(path,FileAccess.WRITE);out.store_string(JSON.stringify(state));out.close()
