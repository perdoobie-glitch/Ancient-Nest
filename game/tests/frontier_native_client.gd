extends SceneTree
var game
var status_path=""
var until=0.0
var auto_vote=false
var fixture_done=false
var fired=false
var alias_name=""
func _initialize():call_deferred("run")
func run():
 Engine.max_fps=60
 var args=OS.get_cmdline_user_args();var hub="ws://127.0.0.1:18080";var alias="Human";var playlist="bomb_defuse_5v5";var qa_map=3
 for i in range(args.size()-1):
  if args[i]=="--map":qa_map=int(args[i+1])
  if args[i]=="--hub":hub=args[i+1]
  if args[i]=="--status":status_path=args[i+1]
  if args[i]=="--name":alias=args[i+1]
  if args[i]=="--playlist":playlist=args[i+1]
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 # Multiple local QA processes share one small test CPU; admission itself is tested separately.
 if OS.get_environment("NEST_QA_SHARED_CPU")=="1":
  process_frame.connect(func():
   var samples=game.matchmaking.hybrid.cpu_samples
   samples.resize(180);samples.fill(1.0))
 Engine.max_fps=60 # Preferences are applied during main ready; set the QA cap afterwards.
 # This headless transport harness does not render a menu camera. Leave network
 # nodes processing; resume the normal presentation loop once a match starts.
 game.set_process(false)
 alias_name=alias;game.prefs.values.username=alias
 await create_timer(3).timeout # Same warmup as the production search countdown; let map collision validation finish.
 game.matchmaking.playlist=playlist;game.matchmaking.search(hub)
 while true:
  await create_timer(.25).timeout
  var h=game.matchmaking.hybrid
  game.set_process(game.running)
  if h.session.epoch>1:fixture_done=true # Never reapply fixture data over a restored checkpoint.
  if game.matchmaking.phase=="voting":game.matchmaking.vote(4,qa_map)
  if not fixture_done and h.authority and game.running and not h.session.frozen and FileAccess.file_exists(status_path.get_base_dir()+"/fixture"):
   load(OS.get_environment("NEST_QA_FIXTURE_SCRIPT") if OS.has_environment("NEST_QA_FIXTURE_SCRIPT") else "res://tests/hybrid/fixture.gd").apply(game);fixture_done=true
  if not fired and game.running and not h.session.frozen and is_instance_valid(game.player) and FileAccess.file_exists(status_path.get_base_dir()+"/fire-"+alias_name):
   fired=game.player.fire_trigger()
  if h.authority and game.running and FileAccess.file_exists(status_path.get_base_dir()+"/finish"):
   game.finished=true
  var state={"phase":game.matchmaking.phase,"running":game.running,"frozen":h.session.frozen,"authority":h.authority,"epoch":h.session.epoch,"slot":game.matchmaking.local_slot,"actors":game.actors.size(),"status":game.matchmaking.status,"checkpoint":h.checkpoint_digest,"now":game.now,"scores":game.scores,"sequence":game.command_sequence,"authenticated":h.authenticated.size()}
  state["map"]=game.arena.map_selection;state["mode"]=game.mode;state["teams"]=game.actors.map(func(a):return a.faction);state["bomb_carrier"]=game.cs_carrier
  state["roster_state"]={}
  for a in game.actors:state.roster_state[str(a.net_id)]={"ammo":a.ammo,"shots":a.accepted_shots}
  if is_instance_valid(game.player):state["health"]=game.player.health;state["shield"]=game.player.shield;state["ammo"]=game.player.ammo
  var f=FileAccess.open(status_path,FileAccess.WRITE);f.store_string(JSON.stringify(state));f.close()
