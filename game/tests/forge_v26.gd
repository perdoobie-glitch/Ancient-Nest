extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func frames(n=3):
 for i in range(n):await process_frame
func physics(n=3):
 for i in range(n):await physics_frame
func op(action,args={}):return game.forge_session.submit(action,args)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames()
 game.lobby_network.set_process(false);game.lobby_network=null
 game.open_forge();await frames()
 check(game.current_screen=="lobby" and game.lobby_kind=="forge" and game.forge_editor==null,"Nest Forge menu opens a lobby before editing")
 check(game.screen.find_child("PlayersPanel",true,false)!=null and game.screen.find_child("LobbySettingsList",true,false)!=null,"Lobby has settings list and roster panels")
 check(game.screen.find_child("MatchupPreview",true,false)==null,"Lobby has no center character preview")
 check(game.screen.find_child("LobbyRankBadge",true,false)!=null,"Player roster includes current rank emblem and Elo")
 game.start_forge_session();await frames();game.set_physics_process(false)
 var session=game.forge_session;var m=session.model;var editor=game.forge_editor
 check(session.active and editor.editing and game.sandbox_mode,"Host enters Nest Forge sandbox")
 check(m.records.size()>300,"Existing floors, walls, scenery, pickups and lights are registered")
 check(m.records.values().filter(func(r):return r.node is Light3D).size()>15,"Existing map lights are editable")
 check(m.records.values().filter(func(r):return r.kind=="pickup").size()==m.initial_pads.size(),"Existing map weapon/powerup placements are registered")
 check(m.markers.size()==56,"All mode-specific spawn, bomb and flag markers exist")
 check(m.validate(m.capture()),"Fresh expanded map layout validates")
 var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/forge_v1.json"));var upgraded=m.upgrade_legacy(legacy)
 check(m.validate(upgraded),"Actual v25 Nest Forge v1 layout migrates into expanded format")
 check(upgraded.added.size()==legacy.added.size(),"Migration retains all older added weapons and structures")

 check(op("spawn",{"spec":{"type":"structure","kind":"wall"},"position":[100,30,100]}),"Spawn structure command accepted")
 var key=editor.selected_key;var record=m.records[key]
 check(key.begins_with("added_") and record.node.global_position.is_equal_approx(Vector3(100,30,100)),"Created object is selected at requested position")
 var t=m.pose(record.node);t.s=[2,1.5,3]
 check(op("transform",{"key":key,"transform":t}),"Independent nonuniform dimensions accepted")
 check(m.dimensions(key).is_equal_approx(Vector3(10,4.5,1.5)),"Visible width, height and depth match edited dimensions")
 await physics()
 var hit=game.trace(Vector3(104,32,103),Vector3(104,32,97),1)
 check(not hit.is_empty() and hit.collider.get_meta("forge_owner","")==key,"Resized wall collision covers its expanded visible width")
 check(absf(hit.position.z-100.75)<.02,"Ray contact matches resized visual depth")
 check(op("material",{"key":key,"material":"gold"}),"Existing gold skin can be applied")
 check(m.records[key].material=="gold" and m.visuals(record.node)[0].material_override==game.arena.kit.gold,"Skin affects the selected object")
 check(op("material",{"key":key,"material":"original"}),"Original appearance can be restored")
 var capture=m.capture();check(capture.added[0].get("baked",false),"Layout carries exact collision representation for other peers")
 check(op("spawn",{"spec":{"type":"powerup","kind":"cloak"},"position":[97,31,100]}),"Powerup can be spawned in Nest Forge")
 var powerup=editor.selected_key;check(m.records[powerup].spec.kind=="cloak","Camo is stored as a real pickup, not decoration")
 op("delete",{"key":powerup});session.rate.clear()
 var before_revision=session.revision;var invalid=t.duplicate(true);invalid.s[0]=-1
 check(not op("transform",{"key":key,"transform":invalid}) and session.revision==before_revision,"Negative size rejected without revision advance")
 invalid=t.duplicate(true);invalid.p[0]=NAN
 check(not op("transform",{"key":key,"transform":invalid}),"Nonfinite coordinates rejected")
 editor.select_key(key)
 var pose=m.pose(record.node);editor.toggle_grab();editor._process(.016)
 check(editor.moving and m.pose(record.node)==pose,"Grab preview does not mutate authoritative geometry")
 editor.cancel_move();check(not editor.moving and m.pose(record.node)==pose,"Cancel leaves object unchanged")
 editor.camera.global_position=Vector3(104,32,106);editor.camera.look_at(Vector3(104,32,100));await physics();editor.select_at(root.get_visible_rect().size*.5)
 check(editor.selected_key==key,"World picking identifies resized baked collision")
 check(op("delete",{"key":key}),"Added object can be deleted")
 await physics();check(game.trace(Vector3(104,32,103),Vector3(104,32,97),1).is_empty(),"Deletion removes actual collision")
 check(op("undo") and m.records.has(key),"Undo restores deleted object, dimensions and appearance")
 check(op("spawn",{"spec":{"type":"light","kind":"spot"},"position":[95,34,100]}),"A new spot light can be spawned")
 var light_key=editor.selected_key
 var light={"color":[.2,.4,.8],"energy":2.5,"range":18,"angle":60,"shadows":false}
 check(op("light",{"key":light_key,"light":light}),"Light color/brightness/range/cone can be edited")
 check(m.records[light_key].node.light_color.is_equal_approx(Color(.2,.4,.8)) and m.records[light_key].node.spot_range==18,"Light properties apply to the real light")
 check(not op("light",{"key":key,"light":light}),"Light properties cannot target ordinary geometry")
 var bad=light.duplicate(true);bad.energy=INF;check(not op("light",{"key":light_key,"light":bad}),"Nonfinite lighting rejected")
 # Host tools are invoked at human speed; reset request throttle for the rest of this scripted fixture.
 session.rate.clear()
 var point="point:4:bomb:0:0";var original=m.points["0"].bombs[0].duplicate()
 check(op("transform",{"key":point,"position":[8,7,4]}),"CS bomb site can be moved")
 check(NestForgeMap.v3(m.points["4"].bombs[0]).is_equal_approx(Vector3(8,7,4)) and m.points["0"].bombs[0]==original,"Mode-specific objective editing does not change other modes")
 check(not op("delete",{"key":point}),"Required bomb sites are protected from deletion")
 check(op("transform",{"key":"point:3:flag:1:1","position":[24,12,6]}),"CTF flag base can be moved")
 var count=m.points["2"].spawns["0"].size()
 check(op("add_spawn",{"mode":2,"team":0,"position":[100,31,99]}) and m.points["2"].spawns["0"].size()==count+1,"Mode/team spawn can be added")
 check(m.validate(m.capture()),"Edited structures, skins, lights and objective data validate together")
 check(session.save(),"Expanded layout saves atomically")
 var saved=m.capture();op("delete",{"key":light_key});check(session.load_saved() and m.records.has(light_key),"Saved light and its properties restore")
 check(m.light_data(m.records[light_key].node).energy==2.5 and NestForgeMap.v3(m.points["3"].flags[1]).is_equal_approx(Vector3(24,12,6)),"Save/load preserves lighting and per-mode objective positions")
 var corrupt=saved.duplicate(true);corrupt.added[0].type="res://malicious.gd";check(not m.validate(corrupt),"Saved layout cannot instantiate arbitrary scripts/scenes")
 corrupt=saved.duplicate(true);corrupt.base.append(corrupt.base[0]);check(not m.validate(corrupt),"Duplicate or unexpected base entries rejected")
 corrupt=saved.duplicate(true);corrupt.points["2"].spawns["0"]=[];check(not m.validate(corrupt),"Layout cannot remove every team spawn")
 var seq=session.request_sequence+1;session.rate.clear();var rev=session.revision
 check(not session.execute(1,session.epoch,rev-1,seq,"delete",{"key":key}) and m.records.has(key),"Stale shared edit cannot overwrite newer layout")
 session.request_sequence=seq
 seq+=1;check(session.execute(1,session.epoch,session.revision,seq,"material",{"key":key,"material":"bronze"}),"Current sequenced edit accepted")
 check(not session.execute(1,session.epoch,session.revision,seq,"delete",{"key":key}) and m.records.has(key),"Duplicate request ID cannot apply another edit")
 session.request_sequence=seq
 session.rate.clear()
 var devices=m.capture()
 check(m.records.has("mechanism_lift") and m.records.has("mechanism_cannon_00"),"Built-in lift and launcher are selectable objects")
 var lift=m.records.mechanism_lift.node;var lift_pose=m.pose(lift);lift_pose.p=[50,0,0];lift_pose.r=[0,PI/2,0]
 check(op("transform",{"key":"mechanism_lift","transform":lift_pose}) and lift.global_position.is_equal_approx(Vector3(50,0,0)),"Gravity lift can move and rotate with its visible structure")
 var uneven=lift_pose.duplicate(true);uneven.s[1]*=2;check(not op("transform",{"key":"mechanism_lift","transform":uneven}),"Traversal devices reject unsafe nonuniform size")
 op("delete",{"key":"mechanism_lift"});lift.apply_motion(null,.016);check(not lift.visible,"Deleting lift disables its updraft as well as its visual")
 check(op("mechanism",{"key":"mechanism_cannon_00","mechanism":{"target":[20,12,5],"flight":3.0}}),"Launcher landing point and flight time can be edited")
 check(NestForgeMap.v3(m.mechanism_data(m.records.mechanism_cannon_00.node).target).is_equal_approx(Vector3(20,12,5)),"Launcher uses edited world-space destination")
 var changed_devices=m.capture();m.restore(devices);m.restore(changed_devices)
 check(m.mechanism_data(m.records.mechanism_cannon_00.node).flight==3.0 and not m.records.mechanism_lift.node.visible,"State restore retains launcher target and deleted device")
 check(not m.valid_spec({"type":"copy","source":"mechanism_lift"}),"Scripted traversal devices cannot produce unsafe duplicate scripts")
 m.restore(devices);session.rate.clear()
 var shadow_light=m.light_data(m.records[light_key].node);shadow_light.shadows=true;game.prefs.values.shadows=false;op("light",{"key":light_key,"light":shadow_light})
 check(not m.records[light_key].node.shadow_enabled and m.light_data(m.records[light_key].node).shadows,"Global Shadows Off overrides per-light shadows without losing saved preference")
 game.prefs.values.shadows=true;game.arena.set_shadows_enabled(true);check(m.records[light_key].node.shadow_enabled,"Global Shadows On restores added light shadow preference")
 # Ensure mode points route into actual gameplay, not editor-only gizmos.
 m.apply_mode(4);check(game.arena.sites[0].is_equal_approx(Vector3(8,7,4)),"Edited bomb position reaches gameplay site array")
 m.apply_mode(3);check(game.flag_bases[1].is_equal_approx(Vector3(24,12,6)),"Edited flag position reaches gameplay flag base")
 m.apply_mode(2);check(game.arena.spawns[0].any(func(p):return p.is_equal_approx(Vector3(100,31,99))),"Edited spawn reaches gameplay spawn candidates")
 check(is_instance_valid(m.runtime_batches) and m.batch_stats.source_meshes>100,"Runtime batches edited architecture without deleting source meshes")
 m.set_editor_visible(true,game.mode);check(not is_instance_valid(m.runtime_batches),"Returning to editing restores unbatched editable visuals")
 check(game.arena.pad_kinds.size()==game.arena.pads.size() and game.arena.pads.size()==m.initial_pads.size(),"Existing pickup arrays remain aligned")
 session.stop_editing();check(game.current_screen=="lobby" and not session.active and not game.sandbox_mode,"Return to Nest Forge lobby retains layout")
 check(m.records.has(key),"Map edits remain available after leaving editor")
 game.open_custom_lobby();check(game.lobby_kind=="custom" and game.forge_session.model==m,"Edited layout can be used in Custom Games")
 game.close_connection();game.queue_free();await frames();print("NEST FORGE V26: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
