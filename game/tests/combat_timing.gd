extends SceneTree
var game
var checks=0
var failures=0
var shots=[]
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func frames(n=2):
 for i in range(n):await process_frame
func click(pressed):
 var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;Input.parse_input_event(e)
func equip(kind):
 var p=game.player;p.weapons.assign([NestWeaponCatalog.profile(kind)]);p.slot=0;p.ammo.assign([p.weapons[0].magazine]);p.reserve.assign([p.weapons[0].reserve]);p.action_state="ready";p.action_until=0;p.cooldown=game.now;p.burst_left=0;p.reset_aim();p.clear_local_input();p.suppressed_actions.clear()
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await frames()
 game.bot_fill=false;game.mode=1;game.fair_playing_field=false;game.selected_faction=0;game.clear_screen();game.start_game();game.set_physics_process(false);game.player.set_physics_process(false)
 var p=game.player;p.global_position=Vector3(100,30,100);p.rotation.y=0;p.eye.rotation.x=.2;p.reset_aim()
 p.shot_fired.connect(func(id,t,origin,directions):shots.append({"id":id,"time":t,"origin":origin,"directions":directions,"frame":Engine.get_process_frames()}))
 equip("sidearm");await frames();click(true)
 check(shots.size()==1 and p.ammo[0]==p.weapons[0].magazine-1,"Eligible press emits its shot synchronously")
 var pre=p.aim_punch;
 game.now+=.2;p.presentation.update_view_weapon(0);check(p.weapon_art.get_meta("gun_feedback").flash.visible,"Flash survives simulation expiry until its first rendered frame");
 game.now-=.2;check(pre.y>0,"Recoil feedback starts immediately after the shot")
 click(true);click(false);await frames();check(shots.size()==1,"Duplicate press consumes no extra ammunition")
 game.now+=p.weapons[0].interval-.04;click(true);click(false);game.now+=.05;await frames()
 check(shots.size()==2,"Released short click is buffered across cooldown")
 var penalty=p.accuracy_penalty;var punch=p.aim_punch;game.now+=.2;p.advance_combat_recovery();var recovered=p.accuracy_penalty;var recovered_punch=p.aim_punch
 p.update_aim(1.0/30);p.update_aim(1.0/144)
 check(p.accuracy_penalty==recovered and p.aim_punch.is_equal_approx(recovered_punch),"Render updates cannot advance simulation-time recovery")
 check(recovered<=penalty and recovered_punch.length()<punch.length(),"Simulation time advances recoil and spread recovery")
 equip("rifle");p.ammo[0]=0;await frames();var count=shots.size();click(true);click(false);check(shots.size()==count and p.ammo[0]==0,"Empty ammunition produces no shot or negative ammo")
 equip("rifle");p.ammo[0]=2;var reserve=p.reserve[0];p.reload_weapon();click(true);click(false);check(shots.size()==count,"Reload state blocks immediate firing")
 game.now=p.action_until;p.advance_weapon_timers();check(p.ammo[0]==p.weapons[0].magazine and p.reserve[0]==reserve-(p.weapons[0].magazine-2),"Simulation deadline transfers exactly the missing ammunition")
 equip("shotgun");p.ammo[0]=3;reserve=p.reserve[0];p.reload_weapon();game.now=p.shell_next;p.advance_weapon_timers();check(p.ammo[0]==4 and p.reserve[0]==reserve-1,"Shell insertion is simulation driven without animation advancement")
 p.combat_audio.emit_reload_stage(0);check(p.ammo[0]==4,"Cosmetic shell callback cannot insert a duplicate shell")
 p.weapons.append(NestWeaponCatalog.profile("ak47"));p.ammo.append(30);p.reserve.append(90);p.switch_weapon();var after=p.ammo[0];game.now+=2;p.advance_weapon_timers();check(p.ammo[0]==after and p.slot==1,"Switching cancels the old shell reload")
 equip("rifle");var a=p.shot_directions(Vector3.FORWARD,p.eye.global_position,160);var b=p.shot_directions(Vector3.FORWARD,p.eye.global_position,160)
 check(a==b,"Identical shot ID and simulation state sample identical spread")
 var standing=p.current_spread_degrees();p.velocity=Vector3(6,2,0);check(p.current_spread_degrees()==standing,"Moving and airborne firing retain existing accuracy rules")
 game.stop_game();game.queue_free();await frames(6);print("COMBAT TIMING: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
