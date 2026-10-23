class_name NestLobbyVote
extends Node
const SECONDS=15.0
var game
var state: Dictionary={"stage":"idle","epoch":0,"votes":{},"mode":2,"map":0,"life":1,"result":""}
var deadline=0.0
var electorate: Array=[]
var rng=RandomNumberGenerator.new()
func _ready():rng.randomize()
func clock()->float:return Time.get_ticks_msec()/1000.0
func active()->bool:return state.stage in ["map","mode","life"]
func complete()->bool:return state.stage=="complete"
func members()->Array:
 var ids=game.lobby_members.keys() if game.network_active else [1]
 ids.sort();return ids
func snapshot()->Dictionary:
 var out=state.duplicate(true);out.seconds=maxf(0,deadline-clock()) if active() else 0;return out
func accept(data: Dictionary):
 if not game.is_client():return
 state=data.duplicate(true);deadline=clock()+float(data.get("seconds",0))
func start()->bool:
 if game.is_client() or game.running or game.matchmaking.active or active() or game.lobby_kind!="custom":return false
 electorate=members();state={"stage":"map","epoch":int(state.epoch)+1,"votes":{},"mode":game.mode,"map":game.game_type.map_selection,"life":1,"result":""};deadline=clock()+SECONDS;publish();return true
func reset():
 state={"stage":"idle","epoch":int(state.epoch)+1,"votes":{},"mode":game.mode,"map":game.game_type.map_selection,"life":1,"result":""};deadline=0
func vote(value: int):
 if game.is_client():submit.rpc_id(1,int(state.epoch),value)
 else:record(1,int(state.epoch),value)
@rpc("any_peer","call_remote","reliable")
func submit(epoch: int,value: int):
 if game.is_client() or not game.network_active or not game.multiplayer.is_server():return
 record(game.multiplayer.get_remote_sender_id(),epoch,value)
func options()->Array:
 return range(NestArena.MAP_NAMES.size()) if state.stage=="map" else NestMatchPresets.MODES if state.stage=="mode" else [1,2]
func record(peer: int,epoch: int,value: int)->bool:
 if game.is_client() or not active() or game.running or epoch!=int(state.epoch) or peer not in electorate or peer not in members() or value not in options():return false
 state.votes[peer]=value;publish()
 if state.votes.size()==electorate.size():resolve()
 return true
static func winner(ballots: Array,choices: Array,total: int,random: RandomNumberGenerator)->int:
 var most=0;var leaders=[]
 for option in choices:
  var votes=ballots.count(option)
  if votes>most:most=votes;leaders=[option]
  elif votes==most:leaders.append(option)
 return int(leaders[random.randi_range(0,leaders.size()-1)])
func resolve():
 if not active() or game.is_client():return
 if members()!=electorate:reset();state.result="Players changed. Start a new vote.";publish();return
 var chosen=winner(state.votes.values(),options(),electorate.size(),rng)
 if state.stage=="map":state.map=chosen;next_stage("mode")
 elif state.stage=="mode":
  state.mode=chosen
  if chosen==0:state.life=3;finish()
  else:next_stage("life")
 else:state.life=chosen;finish()
func next_stage(stage: String):
 state.stage=stage;state.epoch+=1;state.votes={};deadline=clock()+SECONDS;publish()
func finish():
 state.stage="complete";state.epoch+=1;state.votes={};deadline=0
 game.select_normal_preset(int(state.mode),int(state.map),int(state.life),false)
 state.result="%s · %s · %s"%[NestArena.MAP_NAMES[state.map],game.MODE_NAMES[state.mode],"Annu vs Naki" if state.mode==0 else "Naki vs Naki" if state.life==1 else "Annu vs Annu"]
 publish()
func publish():
 if game.network_active and game.multiplayer.is_server():game.broadcast_lobby()
 if game.current_screen=="lobby":game.call_deferred("show_lobby")
func _process(_delta):
 if game.is_client() or game.running or not active():return
 if members()!=electorate:reset();state.result="Players changed. Start a new vote.";publish()
 elif clock()>=deadline:resolve()
static func show(game,parent: VBoxContainer):
 var vote: NestLobbyVote=game.lobby_vote
 var content=VBoxContainer.new();content.name="LobbyVotePanel";content.add_theme_constant_override("separation",10);parent.add_child(content);parent=content
 parent.add_child(game.label("LOBBY VOTE",15,game.GOLD))
 if vote.active():
  var stage=String(vote.state.stage)
  if stage!="map":parent.add_child(game.label("Selected map: "+NestArena.MAP_NAMES[vote.state.map],14,game.IVORY))
  if stage=="life":parent.add_child(game.label("Selected mode: "+game.MODE_NAMES[vote.state.mode],14,game.IVORY))
  var caption=game.label("",14,game.GOLD);caption.name="VoteCountdown";parent.add_child(caption)
  caption.text="VOTE "+stage.to_upper()+" · "+str(ceili(maxf(0,vote.deadline-vote.clock())))+"s"
  var timer=Timer.new();timer.wait_time=.25;timer.autostart=true;caption.add_child(timer)
  timer.timeout.connect(func():caption.text="VOTE "+stage.to_upper()+" · "+str(ceili(maxf(0,vote.deadline-vote.clock())))+"s")
  for value in vote.options():
   var title=NestArena.MAP_NAMES[value] if stage=="map" else game.MODE_NAMES[value] if stage=="mode" else "Naki vs Naki" if value==1 else "Annu vs Annu"
   var count=vote.state.votes.values().count(value)
   var button=game.button(title+"  ·  "+str(count)+" votes",func():vote.vote(value));button.name="LobbyVote_%d"%value;parent.add_child(button)
  parent.add_child(game.label("One ballot per connected player. Majority wins; otherwise random.\nEach stage ends when everyone votes or its timer expires.",12,game.MUTED))
 else:
  parent.add_child(game.label(String(vote.state.result) if vote.complete() else "Map → game type → life type. Extraction uses Annu vs Naki.",13,game.MUTED))
  if vote.complete():
   var start=game.button("Vote Again",func():vote.start());start.name="StartLobbyVote";start.disabled=game.is_client();parent.add_child(start)
