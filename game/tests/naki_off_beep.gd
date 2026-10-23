extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.bot_fill=false;game.mode=1;game.clear_screen();game.start_game();game.set_physics_process(false)
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.shield=0;p.overshield=0
 var audio=p.combat_audio;game.audio.playback_enabled=false
 check(audio.shields_off_warning_active(),"Local Naki receives depleted-shield warning")
 audio.update(.016);check(audio.loops.has("naki_shield_low_warning"),"Depleted shield starts one warning loop")
 audio.update(.016);check(audio.loops.keys().count("naki_shield_low_warning")==1,"Repeated ticks do not duplicate warning loops")
 p.shield=.1;audio.update(.016);check(not audio.loops.has("naki_shield_low_warning"),"First returning shield energy stops the beep")
 p.shield=0;p.overshield=10;check(not audio.shields_off_warning_active(),"Active overshield prevents a misleading shield-off beep")
 p.overshield=0;game.show_pause();audio.update(.016);check(not audio.loops.has("naki_shield_low_warning"),"Pause stops the beep")
 game.resume_game();audio.update(.016);check(audio.loops.has("naki_shield_low_warning"),"Resume restores warning if still unshielded")
 p.alive=false;audio.update(.016);check(not audio.loops.has("naki_shield_low_warning"),"Death stops the beep")
 p.alive=true;p.tuning.shield_capacity=0;check(not audio.shields_off_warning_active(),"Disabled shields never trigger warning")
 p.tuning.shield_capacity=100;p.local_player=false;check(not audio.shields_off_warning_active(),"Remote Naki never beeps on this client's speakers")
 p.local_player=true;p.character=1;check(not audio.shields_off_warning_active(),"Annu never receives the Naki warning")
 var stream=load("res://audio/shields/naki_shields_off_beep.ogg")
 check(stream is AudioStreamOggVorbis and absf(stream.get_length()-1.2)<.02,"Original soft beep asset is a valid 1.2-second loop")
 game.stop_game();game.queue_free();await process_frame;await process_frame
 print("NAKI OFF BEEP: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
