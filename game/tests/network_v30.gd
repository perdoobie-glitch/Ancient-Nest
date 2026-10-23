extends SceneTree
class Gate extends Node:
 var marks={}
 @rpc("any_peer","call_remote","reliable")
 func mark(key: String):marks[key]=true
var game
var gate
var role
var peer: int=1
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS "+role+": "+text)
 else:failures+=1;push_error("FAIL "+role+": "+text)
func wait_for(test: Callable):
 var end=Time.get_ticks_msec()+10000
 while not test.call() and Time.get_ticks_msec()<end:await process_frame
 return test.call()
func phase(key):return await wait_for(func():return gate.marks.has(key))
func place():
 for a in game.actors:
  a.set_physics_process(false);a.set_process(false);a.position=Vector3(114 if a.net_id==1 else 110,70,100 if a.net_id==1 else 110);a.rotation=Vector3.ZERO;a.eye.rotation=Vector3.ZERO;a.reset_physics_interpolation();a.reset_aim();a.update_visual(0)
func run():
 role=OS.get_cmdline_user_args()[0]
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=GameTypeSettings.new();rules.mode=2;rules.max_players_per_team=1;rules.bots_fill_empty_slots=false;rules.bullet_impact_debug=true;rules.starting_primary="sniper_rifle";rules.starting_secondary="none";game.apply_game_type_settings(rules)
 gate=Gate.new();gate.name="V30Gate";game.add_child(gate)
 check((game.host_direct(17948,"NakiHost",0) if role=="host" else game.join_direct("127.0.0.1",17948,"AnnuClient",1))==OK,"Real ENet connection opens")
 check(await wait_for(func():return game.lobby_members.size()==2),"Host and separate client connect")
 if role=="host":
  peer=int(game.lobby_members.keys().filter(func(id):return id!=1)[0]);game.start_game();place();game.context="pause";gate.mark.rpc_id(peer,"ready")
  check(await phase("placed"),"Client installs matching placement")
  var a=game.actor_by_id(peer)
  check(a.character==1 and not a.weapons.any(func(w):return w.kind=="plasma_sword"),"Server keeps Nu on Annu and sword off Annu")
  gate.mark.rpc_id(peer,"launch")
  check(await wait_for(func():return a.action_state=="nu_launch"),"Server accepts remote Nu request")
  check(a.nu_used and a.nu_launch_until-game.now>1.2,"Server spends one use and reserves the launch animation")
  check(await wait_for(func():return game.nu.birds.has(peer)),"Server launches authoritative falcon after animation")
  var bird=game.nu.birds.get(peer)
  if bird!=null:
   check(await wait_for(func():return bird.last_seq>2),"Batched sequenced flight controls arrive from the client")
   check(bird.velocity.length()>1 and bird.controls.x>0,"Server simulates submitted thrust without client positions")
   check(await wait_for(func():return bird.boost_active and bird.previous_boost==3.0 and bird.velocity.length()>24),"Server validates and simulates three-times Nu boost")
   check(bird.assist_enabled,"Server uses the client-selected guided flight mode")
   check(not game.nu_sightings[1].is_empty(),"Server records position/time for Annu team Nu contacts")
   var old_seq=bird.last_seq
   check(await phase("flying"),"Client sees flight and tests camera")
   # Server-side bullet query, not a client-reported hit.
   var start=bird.global_position+Vector3.BACK*2
   game.launch_bullet(game.player,NestWeaponCatalog.profile("sniper"),start,Vector3.FORWARD,0,false,game.next_event()*16)
   check(not game.nu.birds.has(peer),"Authoritative bullet destroys Nu")
  gate.mark.rpc_id(peer,"down");check(await phase("returned"),"Client confirms camera returns to living owner")
  gate.mark.rpc_id(peer,"retry");check(await phase("retried"),"Client attempts a duplicate deployment")
  check(not game.nu.birds.has(peer) and a.nu_used,"Second launch in same life is rejected")
  a.respawn();place();gate.mark.rpc_id(peer,"respawn")
  check(await phase("reset"),"Client receives restored use on next life")
  # Remote sword request is rejected for the Annu character.
  gate.mark.rpc_id(peer,"sword_request");check(await phase("sword_sent"),"Client sends forbidden sword request")
  check(a.weapons[a.slot].kind!="plasma_sword","Server rejects Annu sword equip")
  a.update_visual(0);await physics_frame;await physics_frame
  var perch_point=a.perched_nu.global_transform*Vector3(0,.065,-.16);var body_before=a.health
  game.launch_bullet(game.player,NestWeaponCatalog.profile("sniper"),perch_point+Vector3.LEFT*2,Vector3.RIGHT,0,false,game.next_event()*16)
  check(a.nu_used and not a.perched_nu.visible and a.health==body_before,"Server shooting perched Nu spends the ability without body damage")
  gate.mark.rpc_id(peer,"perch_gone");check(await phase("perch_seen"),"Client receives lost shoulder bird")
  a.respawn();place();a.update_visual(0);await physics_frame;await physics_frame
  var leg_origin=a.position+Vector3(-.17,.42,2)
  game.launch_bullet(game.player,NestWeaponCatalog.profile("sniper"),leg_origin,Vector3.FORWARD,0,false,game.next_event()*16)
  check(a.alive and is_equal_approx(a.health,50),"Server leg hitscan leaves Annu alive after the first sniper round")
  gate.mark.rpc_id(peer,"leg_one");check(await phase("leg_one_seen"),"Client receives first leg hit")
  game.launch_bullet(game.player,NestWeaponCatalog.profile("sniper"),leg_origin,Vector3.FORWARD,0,false,game.next_event()*16)
  check(not a.alive,"Server second below-waist hitscan kills Annu")
  gate.mark.rpc_id(peer,"leg_two");check(await phase("leg_two_seen"),"Client receives second-shot leg death")
  a.respawn();place()
  # Host Naki sword must animate before its authoritative contact.
  var n=game.player;n.position=a.position+Vector3.BACK*1.4;n.rotation=Vector3.ZERO;n.eye.rotation=Vector3.ZERO;n.update_visual(0);a.update_visual(0)
  await physics_frame;await physics_frame
  n.action_state="ready";n.cooldown=0;n.slot=0;n.melee();gate.mark.rpc_id(peer,"swing")
  check(is_equal_approx(n.sword_draw,.6/1.15) and a.alive,"Host sword begins with draw and no instant damage")
  var contact_deadline=n.melee_contact_at+.02
  while game.now<contact_deadline:
   n.advance_weapon_timers();await process_frame
  n.advance_weapon_timers()
  check(not a.alive,"Host sword contact kills after its timed windup")
  gate.mark.rpc_id(peer,"slashed");check(await phase("sword_seen"),"Client receives sword death")
  a.set_character(0);a.respawn();game.player.respawn();place()
  a.position=game.player.position+Vector3.BACK*1.4;a.update_visual(0);game.player.update_visual(0)
  gate.mark.rpc_id(peer,"remote_sword")
  check(await wait_for(func():return a.action_state=="melee"),"Server accepts client Naki sword action")
  check(is_equal_approx(a.sword_draw,.6/1.15) and game.player.alive,"Server validates remote draw timing before damage")
  var remote_deadline=a.melee_contact_at+.03
  while game.now<remote_deadline:
   a.advance_weapon_timers();await process_frame
  a.advance_weapon_timers()
  check(not game.player.alive,"Remote Naki sword kills through authoritative contact")
  gate.mark.rpc_id(peer,"remote_hit");check(await phase("remote_seen"),"Client receives its confirmed sword kill")
  gate.mark.rpc_id(peer,"done");await create_timer(.3).timeout
 else:
  check(await wait_for(func():return game.running and game.player!=null),"Client enters match")
  check(await phase("ready"),"Host starts test");place();gate.mark.rpc_id(1,"placed")
  check(await phase("launch"),"Host ready for launch")
  var a=game.player;game.context="playing";var original_camera=a.camera;game.nu.toggle(a)
  check(await wait_for(func():return is_instance_valid(game.nu.local_bird)),"Client receives Nu and takes its camera")
  a.refresh_model_visibility();a.presentation.update_view_weapon(0)
  check(a.model.visible and not a.weapon_view.visible,"Remote-controlled body is visible from Nu without a floating view gun")
  check(game.get_viewport().get_camera_3d()==game.nu.camera and not a.input_active(),"Nu owns view while body gameplay input is blocked")
  var event=InputEventMouseMotion.new();event.screen_relative=Vector2(12,-6);var yaw=game.nu.local_bird.yaw;game.nu._input(event)
  check(game.nu.local_bird.yaw!=yaw and is_equal_approx(game.nu.camera.rotation.y,game.nu.local_bird.yaw),"Nu mouse look rotates immediately without acknowledgement")
  Input.action_press("nu_boost");Input.action_press("forward");Input.action_press("jump");await create_timer(.25).timeout
  check(a.alive and a.nu_used and game.nu.local_bird.velocity.length()>1,"Living owner controls physics-based flight once per life")
  check(await wait_for(func():return not game.nu_sightings[a.faction].is_empty()),"Client receives server Nu map sightings")
  game.nu.update_flight_hud();check("3× BOOST" in game.nu.hint.text and "ASSIST ON" in game.nu.hint.text,"Client HUD shows boost and guided flight modes")
  gate.mark.rpc_id(1,"flying");check(await phase("down"),"Host shot down Nu")
  Input.action_release("nu_boost");Input.action_release("forward");Input.action_release("jump")
  check(await wait_for(func():return not is_instance_valid(game.nu.local_bird)),"Client removes destroyed Nu")
  check(game.get_viewport().get_camera_3d()==original_camera and a.alive and a.input_active(),"Camera and controls return immediately to living Annu")
  check(game.effects.get_children().any(func(n):return n is NestImpactDebug),"Client receives authoritative red first-impact marker")
  gate.mark.rpc_id(1,"returned");check(await phase("retry"),"Host ready for duplicate test");game.nu.toggle(a);await create_timer(.2).timeout
  check(not is_instance_valid(game.nu.local_bird),"No second client falcon in the same life");gate.mark.rpc_id(1,"retried")
  check(await phase("respawn") and await wait_for(func():return not a.nu_used),"Authoritative respawn restores the Nu ability")
  gate.mark.rpc_id(1,"reset");check(await phase("sword_request"),"Host ready for faction validation")
  game.request_remote_action("sword");await create_timer(.2).timeout;gate.mark.rpc_id(1,"sword_sent")
  check(await phase("perch_gone") and await wait_for(func():return a.nu_used and not a.perched_nu.visible),"Client loses perched Nu until respawn")
  gate.mark.rpc_id(1,"perch_seen")
  check(await phase("leg_one") and await wait_for(func():return a.alive and is_equal_approx(a.health,50)),"Client survives first authoritative sniper leg shot")
  gate.mark.rpc_id(1,"leg_one_seen")
  check(await phase("leg_two") and await wait_for(func():return not a.alive),"Client dies to second authoritative sniper leg shot")
  gate.mark.rpc_id(1,"leg_two_seen")
  check(await phase("swing"),"Host begins sword animation")
  check(await wait_for(func():return game.actor_by_id(1).action_state=="melee"),"Client receives host sword action")
  check(await phase("slashed") and await wait_for(func():return not a.alive),"Sword death replicates without client damage claims")
  gate.mark.rpc_id(1,"sword_seen")
  check(await phase("remote_sword") and await wait_for(func():return a.alive and a.character==0),"Next life switches client to Naki for sword validation")
  place();a.position=game.actor_by_id(1).position+Vector3.BACK*1.4;a.rotation=Vector3.ZERO;a.eye.rotation=Vector3.ZERO;a.update_visual(0)
  a.action_state="ready";a.cooldown=0;a.melee()
  check(a.action_state=="melee" and is_equal_approx(a.sword_draw,.6/1.15),"Client predicts draw and swing without claiming damage")
  check(await phase("remote_hit") and await wait_for(func():return not game.actor_by_id(1).alive),"Remote sword kill is server-confirmed")
  gate.mark.rpc_id(1,"remote_seen")
  check(await phase("done"),"Host completes network checks")
 game.stop_game();game.close_connection();game.queue_free();await create_timer(.2).timeout
 print("NETWORK V30 "+role+": %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
