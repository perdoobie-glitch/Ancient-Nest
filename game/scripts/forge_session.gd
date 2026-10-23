class_name NestForgeSession
extends RefCounted
var game
var model: NestForgeMap
var active=false
var testing=false
var epoch=0
var revision=0
var request_sequence=0
var processed={}
var rate={}
var history=[]
var dirty=false
var rejection=""
func _init(owner):game=owner
func ensure_map() -> NestForgeMap:
 if model==null:model=NestForgeMap.new(game);model.build()
 return model
func layout() -> Dictionary:return {} if model==null else model.capture()
func start() -> void:
 if game.is_client() or game.running:return
 ensure_map();active=true;testing=false;epoch=randi_range(1,2147483647);revision=0;processed.clear();history.clear();rate.clear()
 game.lobby_kind="forge";game.sandbox_mode=true
 for item in game.flag_nodes:item.flag.visible=false;item.base.visible=false
 game.enter_forge_editor()
 if game.network_active:game.receive_forge_state.rpc(epoch,revision,model.capture(),true,0,"","Nest Forge opened")
func prepare_mode(mode: int) -> void:
 if model!=null:model.apply_mode(mode)
func sync_to(peer: int) -> void:
 if model==null or not game.network_active:return
 game.receive_forge_state.rpc_id(peer,epoch,revision,model.capture(),active,0,"","Layout synchronized")
func submit(action: String,args: Dictionary={}) -> bool:
 request_sequence+=1
 if game.is_client():
  game.request_forge_edit.rpc_id(1,epoch,revision,request_sequence,action,args);return true
 return execute(game.multiplayer.get_unique_id() if game.network_active else 1,epoch,revision,request_sequence,action,args)
func execute(peer: int,session: int,expected: int,sequence: int,action: String,args: Dictionary) -> bool:
 rejection=""
 if game.is_client() or not active or game.running or model==null or session!=epoch or (game.network_active and not game.lobby_members.has(peer)):return false
 if sequence<=int(processed.get(peer,-1)):return false
 processed[peer]=sequence
 if expected!=revision:return reject(peer,"Another player changed the layout. Your view was refreshed; try the edit again.")
 var stamp=Time.get_ticks_msec();var window=rate.get(peer,{"at":stamp,"count":0})
 if stamp-window.at>1000:window={"at":stamp,"count":0}
 window.count+=1;rate[peer]=window
 if window.count>20:return reject(peer,"Edits are arriving too quickly. Wait a moment and try again.")
 if var_to_bytes(args).size()>8000:return reject(peer,"Edit request is too large.")
 var before=model.capture();var key=String(args.get("key",""));var selected=key
 match action:
  "spawn":
   if not model.valid_spec(args.get("spec")) or not NestForgeMap.valid_vec(args.get("position")):return reject(peer,"Unsupported object or position.")
   selected=model.create_item(args.spec)
   if selected.is_empty():return reject(peer,"The layout supports up to 128 added objects and 16 added lights.")
   var t=model.pose(model.node_for(selected));t.p=args.position
   if args.has("transform"):
    if not NestForgeMap.valid_pose(args.transform):model.delete_item(selected);return reject(peer,"Unsupported transform.")
    t=args.transform
   model.set_pose(selected,t)
  "transform":
   if key.begins_with("point:"):
    if not NestForgeMap.valid_vec(args.get("position")) or not model.point_move(key,NestForgeMap.v3(args.position)):return reject(peer,"Unsupported objective marker.")
   else:
    if not model.records.has(key) or not NestForgeMap.valid_pose(args.get("transform")):return reject(peer,"Select a valid object and supported dimensions.")
    if model.records[key].kind=="mechanism":
     var scale=NestForgeMap.v3(args.transform.s)
     if not is_equal_approx(scale.x,scale.y) or not is_equal_approx(scale.x,scale.z):return reject(peer,"Traversal devices use uniform scale.")
     if key=="mechanism_lift" and (absf(float(args.transform.r[0]))>.001 or absf(float(args.transform.r[2]))>.001):return reject(peer,"Gravity lifts remain upright; rotate them around Y.")
    model.set_pose(key,args.transform)
  "delete":
   if key.begins_with("point:"):
    if not model.markers.has(key) or key.get_slice(":",2)!="spawn":return reject(peer,"Required bomb/flag sites can be moved but cannot be removed.")
    var mode=key.get_slice(":",1);var team=key.get_slice(":",3);var i=int(key.get_slice(":",4))
    if model.points[mode].spawns[team].size()<=1:return reject(peer,"Keep at least one spawn per team and mode.")
    model.points[mode].spawns[team].remove_at(i);model.rebuild_markers();selected=""
   elif model.records.has(key):model.delete_item(key);selected=""
   else:return reject(peer,"Select an object first.")
  "material":
   if not model.records.has(key) or args.get("material") not in model.MATERIALS:return reject(peer,"Choose an installed surface preset.")
   model.set_material(key,args.material)
  "light":
   if not model.records.has(key) or not model.records[key].node is Light3D or not NestForgeMap.valid_light(args.get("light")) or args.light.is_empty():return reject(peer,"Choose a light and supported lighting values.")
   model.set_light(key,args.light)
  "mechanism":
   if not model.records.has(key) or not model.records[key].node is NestManCannon or not NestForgeMap.valid_mechanism(args.get("mechanism")) or args.mechanism.is_empty():return reject(peer,"Select a launcher and valid landing point/flight time.")
   model.set_mechanism(key,args.mechanism)
  "add_spawn":
   if not NestForgeMap.valid_vec(args.get("position")) or typeof(args.get("mode"))!=TYPE_INT or typeof(args.get("team"))!=TYPE_INT or args.mode not in range(5) or args.team not in [0,1]:return reject(peer,"Choose a mode, team and position.")
   var list=model.points[str(args.mode)].spawns[str(args.team)]
   if list.size()>=32:return reject(peer,"Up to 32 spawns per team and mode are supported.")
   list.append(args.position.duplicate());model.rebuild_markers();selected="point:%d:spawn:%d:%d"%[args.mode,args.team,list.size()-1]
  "undo":
   if peer!=1:return reject(peer,"Global Undo is host-only to avoid undoing another player's work.")
   if history.is_empty():return reject(peer,"Nothing to undo.")
   model.restore(history.pop_back());selected=""
  _:return reject(peer,"Unknown edit operation.")
 if action!="undo":
  remember_state(before)
 revision+=1;dirty=true
 if is_instance_valid(game.forge_editor):game.forge_editor.state_changed(peer,selected,"Edit applied")
 if game.network_active:game.receive_forge_state.rpc(epoch,revision,model.capture(),active,peer,selected,"Edit applied")
 return true
func remember_state(state: Dictionary) -> void:
 history.append(state)
 if history.size()>30:history.pop_front()
func reject(peer: int,message: String) -> bool:
 rejection=message
 if peer==1 and is_instance_valid(game.forge_editor):game.forge_editor.tell(message)
 elif game.network_active:game.receive_forge_state.rpc_id(peer,epoch,revision,model.capture(),active,0,"",message)
 return false
func receive(session: int,number: int,state: Dictionary,on: bool,peer: int,key: String,message: String) -> bool:
 if not game.is_client() or game.running or session<=0 or (session==epoch and number<revision):return false
 var m=ensure_map()
 if not m.validate(state):return false
 var first=not active and on
 epoch=session;revision=number;active=on;m.restore(state);game.sandbox_mode=on
 if on:
  game.lobby_kind="forge"
  if first or not is_instance_valid(game.forge_editor):game.enter_forge_editor()
  game.forge_editor.state_changed(peer,key,message)
 elif is_instance_valid(game.forge_editor):game.leave_forge_editor_ui()
 return true
func stop_editing() -> void:
 if game.is_client():return
 active=false;testing=false;game.sandbox_mode=false
 if model!=null:model.set_editor_visible(false)
 game.leave_forge_editor_ui()
 if game.network_active and model!=null:game.receive_forge_state.rpc(epoch,revision,model.capture(),false,0,"","Returned to lobby")
func start_test() -> void:
 if game.is_client() or not active:return
 active=false;testing=true;game.sandbox_mode=true
 if is_instance_valid(game.forge_editor):game.forge_editor.close_ui()
 model.apply_mode(game.mode);game.start_game();game.network_match_started()
func return_to_editing() -> void:
 if game.is_client():return
 game.stop_game();testing=false;start()
func save() -> bool:
 if model==null:return false
 var state=model.capture()
 if not model.validate(state):return false
 var file=FileAccess.open(model.save_path()+".tmp",FileAccess.WRITE)
 if file==null:return false
 file.store_string(JSON.stringify(state));file.flush();var ok=file.get_error()==OK;file.close()
 if not ok:return false
 var err=DirAccess.rename_absolute(ProjectSettings.globalize_path(model.save_path()+".tmp"),ProjectSettings.globalize_path(model.save_path()))
 if err==OK:dirty=false
 return err==OK
func load_saved() -> bool:
 if game.is_client():return false
 var path="user://forge_"+NestArena.MAP_NAMES[game.game_type.map_selection].to_lower()+"_layout.json" if game.game_type.map_selection>=3 else "user://forge_savannah_layout.json" if game.game_type.map_selection==2 else "user://forge_crossroads_market_layout.json" if game.game_type.map_selection==1 else "user://forge_sanctuary_wide_layout.json"
 var f=FileAccess.open(path,FileAccess.READ)
 if f==null or f.get_length()>2000000:return false
 var parser=JSON.new();var err=parser.parse(f.get_as_text());f.close()
 if err!=OK:return false
 var m=ensure_map()
 var state=m.upgrade_legacy(parser.data)
 if not m.validate(state):return false
 remember_state(m.capture());m.restore(state);revision+=1;dirty=false
 if is_instance_valid(game.forge_editor):game.forge_editor.state_changed(0,"","Saved layout loaded")
 if game.network_active:
  game.update_lobby.rpc(game.lobby_members,game.active_config())
  if active:game.receive_forge_state.rpc(epoch,revision,m.capture(),active,0,"","Saved layout loaded")
 return true
func accept_layout(state: Dictionary) -> bool:
 if state.is_empty():return true
 var m=ensure_map()
 if not m.validate(state):return false
 m.restore(state);m.set_editor_visible(false);return true
func clear() -> void:
 active=false;testing=false;history.clear();processed.clear();epoch=0;revision=0
 if model!=null:
  model.destroy();model=null
  var old=game.arena;game.remove_child(old);old.queue_free();game.arena=NestArena.new();game.arena.map_selection=game.game_type.map_selection;game.add_child(game.arena);NestGraphicsQuality.apply_arena(game.arena,game.prefs.values)
 game.flag_bases.assign(game.arena.flag_positions)
