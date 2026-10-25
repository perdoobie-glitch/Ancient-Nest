extends SceneTree
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1;print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func frames():
 for i in range(4):await process_frame
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frames();game.sandbox_mode=true
 var c=game.campaign;c.save_store.path="user://guide-qa.json";c.begin_solo(false);c.send_action("skip",{});c.tick(0);await frames()
 var guide=c.guide
 check(c.state.phase=="PREPARATION" and guide.next_step().id=="look","Normal intro handoff begins a guided, playable orientation")
 c.state.practice["1"]={};c.personal.clear();c.observe_practice(game.player);c.state.practice["1"].look=true;c.personal.clear();c.observe_practice(game.player)
 check(c.state.practice["1"].look,"Restored practice evidence survives first observation after reload")
 c.state.practice["1"]={}
 for entry in [["look","look"],["walk","walk"],["sprint","sprint"],["jump","jump"],["service","interact"],["calibrate","calibrating"],["recover","shield"],["aim","aim"],["fire","fire"],["reload","reload"],["switch","switch"],["crouch","crouch"],["flashlight","flashlight"]]:
  var step=guide.next_step();check(step.id==entry[0] and not step.voice.is_empty() and not step.keys.is_empty(),"Instruction, controls and narration cue: "+str(entry[0]));c.state.practice["1"][entry[1]]=true
 check(c.practice_complete(1),"Guidance covers every required personal check")
 game.prefs.keys.interact=KEY_K;c.state.practice["1"].interact=false
 check(guide.next_step().keys.contains("K"),"Guidance displays the player's rebound interaction key")
 c.state.practice["1"].interact=true;game.prefs.keys.interact=KEY_E
 c.state.phase="BOARDING";check(guide.next_step().id=="manifest","Cargo inspection is explicitly explained before boarding")
 c.state.practice["1"].manifest=true;check(guide.next_step().id=="board" and c.world.locations.board.z<-10,"Boarding waypoint is inside the expedition cabin")
 var before=c.state.pack();guide.repeat_current();check(c.state.pack()==before,"Repeating spoken guidance cannot advance authoritative progress")
 game.context="pause";guide.update(true);check(guide.pause_since>=0 and not guide.panel.visible,"Solo pause suspends briefing and hides gameplay prompts")
 game.context="playing";guide.update(true);check(guide.pause_since<0 and guide.panel.visible,"Resume restores the briefing without restarting tutorial progress")
 for dimensions in [Vector2i(1920,1080),Vector2i(1280,800),Vector2i(640,480)]:
  root.size=dimensions;root.content_scale_size=dimensions;c.guide.update(true);await frames();c.guide.update(true)
  check(guide.panel.visible and guide.panel.get_global_rect().end.x<=dimensions.x and guide.panel.get_global_rect().end.y<dimensions.y-100,"Guidance panel fits "+str(dimensions))
  check(guide.marker.visible and guide.marker.position.x>=0 and guide.marker.position.y>=0 and guide.marker.position.y<dimensions.y,"Boarding marker remains visible on screen "+str(dimensions))
 var sky=c.world.ambience.sky.sky_material;check(sky is ShaderMaterial and sky.shader.resource_path.ends_with("connectuct_atmosphere.gdshader"),"Connectuct uses the damaged-atmosphere sky")
 check(c.cinematic.phrase_index(PackedStringArray(["One short phrase","A considerably longer narration phrase with more words"]),.9)==1,"Subtitle timing follows phrase length")
 c.state.practice["1"].boarded=true;check(guide.next_step().id=="boarded","Solo and co-op members receive an aboard waiting instruction")
 c.state.phase="DEPARTURE";c.present_phase();guide.update(true);check(not guide.panel.visible and guide.spoken_step.is_empty(),"Departure hides instructions and stops tutorial voice before cinematic audio")
 c.state.phase="CRASH";c.set_world("forest");c.rebuild_heroes();c.state.phase="CRASH_ORIENTATION";c.present_phase();guide.update(true)
 check(guide.current.id=="crash" and guide.panel.visible and guide.current.target=="exit","Post-crash gameplay receives an explicit exit and recovery briefing")
 check(guide.spoken_step.is_empty(),"Post-crash guidance waits for approved story dialogue")
 c.phase_elapsed=24;guide.update(true);check(guide.spoken_step=="crash","Post-crash briefing starts after story dialogue")
 c.state.phase="WAVE_1";c.phase_elapsed=1;guide.update(true);check(guide.spoken_step=="crash" and guide.current.id=="crash","First wave does not cut off the post-crash briefing")
 game.player.global_position=Vector3(0,.25,26);guide.update(true);check(guide.current.id=="charge","Clearing the wreck replaces the exit marker with recovery instructions")
 c.state.bomb="carried";guide.update(true);check(guide.current.id=="secure","Recovered charge immediately takes priority over the crash briefing")
 var path=c.save_store.path;c.exit_campaign();game.queue_free();await frames()
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
 print("CAMPAIGN GUIDANCE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
