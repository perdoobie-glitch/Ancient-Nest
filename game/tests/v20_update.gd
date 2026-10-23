extends SceneTree
var game
var checks=0
var failures=0
var sounds=[]
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func equip(a,kind: String,rounds: int=30):
 a.weapons.assign([NestWeaponCatalog.profile(kind)]);a.ammo.assign([rounds]);a.reserve.assign([100]);a.slot=0;a.action_state="ready";a.action_until=0;a.cooldown=0;a.burst_left=0;a.last_shot_frame=-1;a.art_kind="";a.update_weapon_art()
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 var rules=GameTypeSettings.new();rules.mode=1;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.context="playing";game.set_process(false)
 game.audio.sound_started.connect(func(id,_file,_voice):sounds.append(id))
 var p=game.player;p.set_physics_process(false);p.set_process(false);p.global_position=Vector3(200,30,200);p.rotation.y=0;p.eye.rotation.x=0;p.reset_aim();p.camera.global_transform=p.eye.global_transform;p.camera.current=true
 var e=NestActor.new();e.game=game;e.faction=1;e.username="TargetUser";game.add_child(e);game.actors.append(e);e.set_physics_process(false);e.set_process(false);e.global_position=Vector3(200,30,190);e.reset_physics_interpolation();e.update_visual(.016);await physics_frame
 check(is_equal_approx(NestWeaponCatalog.profile("plasma_br").spread_half_angle_deg,.140625*1.15),"Plasma BR spread increased another 15 percent")
 check(is_equal_approx(NestWeaponCatalog.profile("plasma_auto").spread_half_angle_deg,1.1*1.15),"Automatic plasma spread increased 15 percent")
 check(is_equal_approx(NestWeaponCatalog.profile("burst").spread_half_angle_deg,.140625),"Ballistic BR spread preserved")
 p.camera.look_at(e.global_position+Vector3.UP*1.5*NestActor.SIZE);p.camera.force_update_transform()
 e.update_enemy_name_tag(.2)
 check(e.enemy_name_tag.visible and e.enemy_name_tag.text=="TargetUser" and is_equal_approx(e.enemy_name_tag.modulate.a,.7),"Visible enemy near reticle shows username at 70 percent opacity")
 p.camera.rotate_y(.3);e.update_enemy_name_tag(.016);check(not e.enemy_name_tag.visible,"Enemy away from crosshair has no name")
 p.camera.look_at(e.global_position+Vector3.UP*1.5*NestActor.SIZE)
 var wall=StaticBody3D.new();var cs=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(8,8,.25);cs.shape=box;wall.add_child(cs);game.add_child(wall);wall.position=Vector3(200,32,195);await physics_frame
 e.update_enemy_name_tag(.2);check(not e.enemy_name_tag.visible,"Wall immediately suppresses enemy name, with no lingering fade")
 wall.queue_free();await physics_frame;e.cloak_deadline=game.now+10;e.update_enemy_name_tag(.2);check(not e.enemy_name_tag.visible,"Camo never reveals enemy username");e.cloak_deadline=0
 game.mode=2;e.faction=p.faction;e.update_enemy_name_tag(.2);check(not e.enemy_name_tag.visible,"Friendly name is excluded from enemy targeting tag");e.faction=1;game.mode=1
 for kind in ["rifle","ak47","burst","burst_scoped","sidearm","sniper","shotgun","rocket","plasma_br","plasma_auto"]:
  equip(p,kind);p.presentation.update_view_weapon(0)
  var f=p.weapon_art.get_meta("gun_feedback")
  check(f.ammo.text=="30" and f.flash.name=="UniqueMuzzle_"+kind,kind+" has a real on-gun counter and specific firing visual")
  p.consume_round();p.flash_until=game.now+.15;p.presentation.update_view_weapon(0)
  check(f.ammo.text=="29" and f.flash.visible,kind+" counter decrements and its own muzzle effect appears")
 equip(p,"rifle",1);p.reserve[0]=10;p.last_shot_frame=-1;game.now+=2;p.fire_trigger()
 check(p.ammo[0]==0 and p.action_state=="ready","Last bullet fires before automatic reload starts")
 game.now+=.11;p.advance_weapon_timers();check(p.action_state=="reloading","Empty weapon automatically begins reload animation")
 game.now=p.action_until+.01;p.advance_weapon_timers();check(p.ammo[0]==10 and p.reserve[0]==0,"Automatic reload transfers reserve exactly once")
 equip(p,"plasma_br",1);p.reload_weapon();var cell=p.weapon_art.find_child("ReloadMagazine_EnergyCell",true,false);var rest=cell.position
 p.action_until=game.now+p.reload_duration*.65;p.presentation.animate_parts(p.weapon_art,.35);var low=cell.position
 p.presentation.animate_parts(p.weapon_art,.65);check(low.y<rest.y-.20 and cell.position.y>=rest.y and cell.visible,"Fresh gold plasma cell rises from hip into gun with an upward seating smack")
 equip(p,"rifle");p.grenades.assign([2,2]);p.grenade_kind=0;var start=game.now;p.throw_grenade();p.presentation.update_view_weapon(0)
 check(p.action_state=="throwing" and p.presentation.view_grenade.visible,"Throw begins with visible grenade in first-person hand")
 game.now=start+.199;p.advance_weapon_timers();check(p.grenades[0]==2,"Grenade is not consumed before simulation-time release")
 game.now=start+.20;p.advance_weapon_timers();check(p.grenades[0]==1 and p.throw_pending_kind<0,"Grenade releases once at throw pose release time")
 p.advance_weapon_timers();check(p.grenades[0]==1,"Repeated timer advancement cannot throw twice")
 p.presentation.update_view_weapon(0);check(not p.presentation.view_grenade.visible,"Held grenade disappears at actual release")
 var g=game.effects.get_children().filter(func(v):return v is RigidBody3D and v.get_script()!=null and v.get_script().resource_path.ends_with("grenade.gd"))[-1]
 check(is_equal_approx(g.physics_material_override.bounce,.45*1.25),"Frag restitution increased 25 percent")
 check(NestGrenadeArt.material(false).albedo_color.g>NestGrenadeArt.material(false).albedo_color.r and NestGrenadeArt.material(true).emission_enabled and NestGrenadeArt.material(true).emission.b>.8,"Frag is green; sticky is emissive blue")
 game.now=start+.8;p.advance_weapon_timers();p.throw_grenade();p.action_state="ready";game.now+=.25;p.advance_weapon_timers();check(p.grenades[0]==1,"Cancelled throw cannot release a delayed ghost grenade")
 e.action_state="throwing";e.throw_started=game.now;e.throw_kind=1;e.presentation.pose_upper_body();var wrist=e.skeleton.get_bone_global_pose(e.presentation.bones.hand_l).origin
 game.now+=.17;e.presentation.pose_upper_body();check(e.presentation.remote_grenade.visible and wrist.distance_to(e.skeleton.get_bone_global_pose(e.presentation.bones.hand_l).origin)>.05,"Third-person throwing hand moves with held sticky grenade")
 game.now+=.04;e.presentation.pose_upper_body();check(not e.presentation.remote_grenade.visible,"Remote hand grenade hides at release")
 var blast=NestBlastFX.new();game.effects.add_child(blast);blast.set_process(false);blast._process(.99);check(blast.smoke_material.albedo_color.a>0 and not blast.is_queued_for_deletion(),"Explosion smoke persists until approximately one second")
 blast._process(.02);check(blast.is_queued_for_deletion() and blast.smoke_material.albedo_color.a==0,"Explosion smoke clears at one second")
 check(is_equal_approx(rules.bag_load_seconds,5) and is_equal_approx(rules.defuse_seconds,6),"Default gold load is twice as fast; defuse takes 1.5 times as long")
 game.mode=0;game.tuning.defuse_seconds=6;game.tuning.load_seconds=5;game.deadline=game.now+1000;game.break_until=0;game.bomb_site=-1;p.carrying=false;p.faction=game.attacking_faction;p.global_position=game.arena.sites[0];p.action_state="ready";game.site_states[0].stage="sealed"
 var plant=game.interaction_for(p);check(game.complete_interaction(p,plant) and sounds.count("bomb_planted_alert")==1,"Planting broadcasts one dedicated non-positional arming cue")
 var ba=game.get_node("BombAudio");ba._process(0);game.now+=.81;ba._process(0);check(sounds.count("bomb_armed_tick")==1,"Planted bomb emits audible ongoing tick")
 e.faction=1-game.attacking_faction;e.global_position=game.arena.sites[0];e.alive=true;e.remote_peer=5;e.net_interact=true;e.net_last_command=game.now;e.action_state="ready";equip(e,"rifle")
 game.update_remote_interaction(e,.05);game.update_remote_interaction(e,.05)
 check(sounds.count("bomb_defuse_start")==1,"Starting defuse plays one cue, not one per progress tick")
 var ammo=e.ammo[0];check(not e.fire_trigger() and e.ammo[0]==ammo,"Defusing remote player cannot fire")
 e.remote_peer=0;game.bot_progress[e.get_instance_id()]={"key":"defuse:0","time":.1};check(not e.fire_trigger() and e.ammo[0]==ammo,"Defusing bot cannot fire either");game.bot_progress.clear()
 # Empty-weapon reload waits for the use action, then resumes automatically.
 e.remote_peer=5;e.net_interact=true;e.net_last_command=game.now;e.ammo[0]=0;e.reserve[0]=10;e.action_state="ready";e.queue_auto_reload();game.now+=.11;e.advance_weapon_timers()
 check(e.action_state=="ready" and is_finite(e.auto_reload_at),"Automatic reload waits while the player is defusing")
 e.net_interact=false;game.remote_interactions.clear();e.advance_weapon_timers();check(e.action_state=="reloading","Deferred automatic reload starts when defusing stops")
 # Host bounds early throw requests to its release time instead of losing a press.
 game.mode=1;e.action_state="throwing";e.action_until=game.now+.75;e.grenades.assign([2,2]);var event=game.next_event()*16
 game.remote_throws[5]={"kind":0,"earliest":game.now+.18,"used":false}
 game.apply_grenade(5,e,event,e.life_id,game.round_number,0,e.grenade_release_origin(),Vector3.FORWARD,Vector3.ZERO,game.match_session)
 check(e.grenades[0]==2 and game.remote_throws[5].has("release"),"Early network release is deferred without consuming a grenade")
 game.now+=.18;game.process_pending_grenade_releases();check(e.grenades[0]==1,"Deferred grenade releases at the authoritative wind-up boundary")
 game.apply_grenade(5,e,event,e.life_id,game.round_number,0,e.grenade_release_origin(),Vector3.FORWARD,Vector3.ZERO,game.match_session)
 check(e.grenades[0]==1,"Duplicate deferred grenade request cannot consume another grenade")
 game.mode=1;game.team_characters.assign([0,1]);game.create_hud();game._process(.016);check(game.hud_top.text.contains("#7da680]NAKI") and game.hud_top.text.contains("#b73535]"),"Top scoreboard uses ancient green Naki and red Annu")
 print("V20 UPDATE: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
