class_name NestCampaign
extends Node
const PROTOCOL="campaign-1"
const PRACTICE=["look","walk","sprint","jump","crouch","interact","aim","fire","reload","switch","flashlight","shield"]
var game
var active=false
var state=NestCampaignState.new()
var data: Dictionary
var save_store=NestCampaignSave.new()
var selected_difficulty="Medium"
var notice=""
var members={}
var credentials={}
var local_slot=1
var token=""
var join_keys={}
var checkpoint={}
var world: NestCampaignWorld
var original_arena: NestArena
var original_rules: GameTypeSettings
var original_tuning: NestTuning
var original_bot_rules={}
var original_selection={}
var cinematic: NestCampaignCinematic
var guide: NestCampaignGuide
var phase_elapsed=0.0
var phase_epoch=0
var sync_at=0.0
var sync_now=0.0
var skip_votes={}
var downed={}
var flashlights={}
var sprint_until={}
var memory={}
var spawn_at=0.0
var supply_at={}
var charge_carrier=0
var personal={}
var reconnect_deadline=0.0
var last_present_phase=""
var overlay: Label
var objective_label: Label
var radio_subtitle: Label
var last_flash=false
var last_sprint=false
var next_sprint=0.0
var next_aim=0.0
var load_deadline=0.0
func paused() -> bool:return active and not game.network_active and (game.context=="pause" or not game.input_window_focused)
func frozen_actors() -> bool:return paused() or (active and (state.phase in ["INTRO","DEPARTURE","CRASH","ENDING","COMPLETE","DEFEAT"] or not all_loaded()))
func _ready():
 process_priority=1100;data=JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_mission1.json"))
func menu():
 if active:exit_campaign()
 NestCampaignUI.menu(self)
func preserve_game():
 if original_rules!=null:return
 original_rules=game.game_type.duplicate_settings();original_tuning=game.tuning.duplicate();original_bot_rules=game.bot_difficulty_rules.duplicate(true)
 original_selection={"mode":game.mode,"matchup":game.matchup,"team_size":game.team_size,"bot_fill":game.bot_fill,"selected_faction":game.selected_faction,"selected_character":game.selected_character,"lobby_kind":game.lobby_kind,"starting_primary":game.starting_primary,"starting_secondary":game.starting_secondary}
func configure_game():
 preserve_game();game.game_type=NestMatchPresets.create(2,3,1);game.game_type.matchup=0;game.pending_game_type=null
 game.game_type.starting_primary=data.weapons.carbine;game.game_type.starting_secondary=data.weapons.naki_pistol;game.game_type.nu_enabled=false;game.game_type.map_weapons=false;game.game_type.max_players=4;game.game_type.score_to_win=1000000;game.game_type.time_limit_seconds=0;game.game_type.round_time_limit_seconds=0
 game.mode=2;game.matchup=0;game.team_characters.assign([0,1]);game.bot_fill=false;game.team_size=4;game.selected_faction=0;game.selected_character=0;game.lobby_kind="campaign"
 game.starting_primary=data.weapons.carbine;game.starting_secondary=data.weapons.naki_pistol;game.tuning=original_tuning.duplicate();game.tuning.score_limit=1000000;game.tuning.round_seconds=0;game.tuning.friendly_fire=false
 game.ranked.clear();game.matchmaking.active=false;game.matchmaking.phase="idle";game.god_mode=false
func local_member(slot: int,peer: int,name: String) -> Dictionary:
 return {"slot":slot,"peer":peer,"name":name,"connected":true,"ready":false,"loaded":-1}
func detach_previous_session():
 if game.matchmaking.active:game.matchmaking.leave()
 elif game.network_active:game.close_connection()
 if game.running:game.stop_game()
func begin_solo(resume_saved: bool):
 var saved=save_store.load_checkpoint() if resume_saved else {}
 if resume_saved and saved.is_empty():notice="No valid campaign checkpoint.";NestCampaignUI.menu(self);return
 detach_previous_session();configure_game();active=true;local_slot=1;members={1:local_member(1,1,"Anki")};members[1].ready=true
 if resume_saved:
  checkpoint=saved.duplicate(true);state.restore(saved);selected_difficulty=state.difficulty;initialize_run();restore_checkpoint(saved)
 else:state.new_run(selected_difficulty);initialize_run();set_phase("INTRO")
func open_coop(hosting: bool,address: String,port: int):
 detach_previous_session();configure_game();active=true;state=NestCampaignState.new();state.difficulty=selected_difficulty;members.clear();credentials.clear();local_slot=1 if hosting else 0
 var endpoint=address+":"+str(port)
 if not join_keys.has(endpoint):join_keys[endpoint]=Crypto.new().generate_random_bytes(32).hex_encode()
 token=join_keys[endpoint]
 var error=game.host_direct(port,game.current_username(),0) if hosting else game.join_direct(address,port,game.current_username(),0)
 if error!=OK:notice=game.network_status;active=false;restore_game();NestCampaignUI.menu(self);return
 game.lobby_kind="campaign"
 if hosting:members[1]=local_member(1,1,game.current_username());members[1].loaded=0
 NestCampaignUI.lobby(self)
func connected():
 game.disable_unreliable_throttle(1);game.network_status="Connected • registering expedition member";enroll.rpc_id(1,game.current_username(),token,PROTOCOL)
@rpc("any_peer","call_remote","reliable")
func enroll(alias: String,key: String,protocol: String):
 if not active or game.is_client() or protocol!=PROTOCOL or key.length()!=64 or not key.is_valid_hex_number(false):return
 var peer=multiplayer.get_remote_sender_id();var slot=int(credentials.get(key,0))
 if slot>0:
  if members[slot].connected and int(members[slot].peer)!=peer:deny.rpc_id(peer,"This expedition seat is already connected.");return
 elif state.phase!="LOBBY":deny.rpc_id(peer,"New members join before the introduction. Enrolled members may reconnect.");return
 else:
  for candidate in range(2,5):
   if not members.has(candidate):slot=candidate;break
  if slot==0:deny.rpc_id(peer,"Expedition is full (four players).");return
  credentials[key]=slot;members[slot]=local_member(slot,peer,game.clean_alias(alias))
 members[slot].peer=peer;members[slot].connected=true;members[slot].loaded=-1;members[slot].ready=false
 var actor=game.actor_by_id(slot)
 if actor!=null:
  actor.remote_peer=peer;actor.cmd_last_seq=0;actor.cmd_queue.clear();actor.net_last_command=game.now;actor.capsule.set_deferred("disabled",not actor.alive)
  for hitbox in actor.hitboxes:hitbox.set_deferred("collision_layer",4 if actor.alive else 0)
 admission.rpc_id(peer,slot);broadcast()
 if state.phase=="LOBBY":NestCampaignUI.lobby(self)
@rpc("authority","call_remote","reliable")
func admission(slot: int):
 if not active or slot<2 or slot>4:return
 local_slot=slot;game.network_status="Expedition member %d • Difficulty selected by host"%slot
@rpc("authority","call_remote","reliable")
func deny(reason: String):
 if not active:return
 notice=reason;exit_campaign()
func disconnected(peer: int):
 if not active or game.is_client():return
 var slot=slot_for_peer(peer)
 if slot<1:return
 if charge_carrier==slot and state.bomb=="carried":state.bomb="missing";charge_carrier=0;state.revision+=1
 members[slot].connected=false;members[slot].ready=false;members[slot].peer=0;skip_votes.erase(slot);sprint_until.erase(slot)
 var actor=game.actor_by_id(slot)
 if actor!=null:
  actor.remote_peer=-1;actor.controlled=Vector3.ZERO;actor.velocity=Vector3.ZERO;actor.target=null;actor.capsule.set_deferred("disabled",true)
  for hitbox in actor.hitboxes:hitbox.set_deferred("collision_layer",0)
 if state.phase=="LOBBY":NestCampaignUI.lobby(self)
 broadcast()
func connection_failed(reason="Cannot reach the campaign host."):
 notice=reason;exit_campaign()
func host_lost():
 notice="The host disconnected. Your squad cannot continue without that host. Rejoin the same host to recover your seat."
 exit_campaign()
func connected_slots() -> Array:
 var result=[]
 for slot in members:
  if members[slot].get("connected",false):result.append(int(slot))
 return result
func slot_for_peer(peer: int) -> int:
 for slot in members:
  if members[slot].connected and int(members[slot].peer)==peer:return int(slot)
 return 0
func everyone_ready() -> bool:
 if connected_slots().is_empty():return false
 for slot in connected_slots():
  if not members[slot].ready:return false
 return true
func all_loaded() -> bool:
 for slot in connected_slots():
  if int(members[slot].get("loaded",-1))<phase_epoch:return false
 return true
func start_expedition():
 if game.is_client() or state.phase!="LOBBY" or not everyone_ready():return
 var chosen=state.difficulty;state.new_run(chosen);checkpoint={};initialize_run();set_phase("INTRO")
func initialize_run():
 configure_game();game.now=0;game.network_clock=0;game.match_session=randi_range(1,2147483647);game.round_number=1;game.scores.assign([0,0]);game.finished=false;game.break_until=0;game.deadline=INF;game.prepare_match_input();game.site_states.assign([{"stage":"sealed","bomb_at":0.0},{"stage":"sealed","bomb_at":0.0}]);game.pad_stock.clear();game.kill_feed.clear();game.damage_events.clear();game.running=true
 set_world("preparation");rebuild_heroes();ensure_cinematic();spawn_at=0;memory.clear();downed.clear();personal.clear();supply_at.clear();notice="";set_meta("notice_until",0);phase_elapsed=0;phase_epoch=0
 if is_instance_valid(game.menu_music):game.menu_music.stop()
func set_world(region: String):
 if world!=null and world.region==region:return
 if original_arena==null:
  original_arena=game.arena;game.remove_child(original_arena)
 if world!=null:game.remove_child(world);world.queue_free()
 world=NestCampaignWorld.new();world.name="CampaignWorld";world.region=region;world.quality=int(game.prefs.values.graphics_quality);game.arena=world;game.add_child(world)
 world.sun.shadow_enabled=NestGraphicsQuality.shadows_enabled(game.prefs.values)
func make_actor(id: int,hero: bool,peer: int,name: String) -> NestActor:
 var actor=NestActor.new();actor.game=game;actor.net_id=id;actor.faction=0 if hero else 1;actor.character_choice=0 if hero else 1;actor.username=name;actor.remote_peer=peer;actor.local_player=hero and id==local_slot;actor.name="CampaignActor_"+str(id);game.add_child(actor);game.actors.append(actor)
 if actor.local_player:game.player=actor
 actor.respawn();loadout(actor,hero);actor.respawn_at=INF
 return actor
func loadout(actor: NestActor,hero: bool):
 actor.weapons.clear();actor.ammo.clear();actor.reserve.clear()
 for id in ([data.weapons.carbine,data.weapons.naki_pistol] if hero else [data.weapons.annu_primary,data.weapons.annu_secondary]):
  var weapon=NestWeaponCatalog.profile(id).duplicate();weapon.title=({"assault_rifle":"Naki Carbine","plasma_pistol":"Naki Pistol","ak47":"AK-47","magnum":"Magnum"}).get(id,weapon.title)
  actor.weapons.append(weapon);actor.ammo.append(weapon.magazine);actor.reserve.append(weapon.reserve*2 if hero else weapon.reserve)
 actor.slot=0;actor.action_state="ready";actor.update_weapon_art()
func clear_actors():
 for actor in game.actors:
  game.remove_child(actor);actor.queue_free()
 game.actors.clear();game.player=null;flashlights.clear();game.clear_effects()
func rebuild_heroes():
 clear_actors()
 for slot in members:make_actor(int(slot),true,int(members[slot].peer),"Anki" if int(slot)==1 else str(members[slot].name))
func choose_spawn(actor: NestActor) -> Vector3:
 if actor.faction==0:return world.spawns[0][posmod(actor.net_id-1,4)]+Vector3.UP*.25
 var approaches=world.spawns[1]
 return approaches[posmod(abs(actor.net_id),maxi(1,approaches.size()))]+Vector3.UP*.25 if not approaches.is_empty() else Vector3(0,.25,-15)
func ensure_cinematic():
 if cinematic!=null:return
 cinematic=NestCampaignCinematic.new();cinematic.campaign=self;add_child(cinematic)
 guide=NestCampaignGuide.new();guide.campaign=self;add_child(guide)
func set_phase(next: String):
 if game.is_client():return
 if state.phase!=next and not state.transition(next):return
 phase_elapsed=0;phase_epoch+=1;skip_votes.clear();last_present_phase=""
 load_deadline=game.local_clock()+45
 for slot in members:members[slot].loaded=phase_epoch if int(slot)==local_slot else -1
 if next=="CRASH":
  game.match_session=randi_range(1,2147483647);game.prepare_match_input();set_world("forest");rebuild_heroes()
 if next=="CRASH_ORIENTATION" and world!=null:world.ship_root.position=Vector3.ZERO;world.ship_root.rotation=Vector3.ZERO
 if next in ["PREPARATION","BOARDING"]:checkpoint_now()
 if next=="CRASH_ORIENTATION" and state.completed_waves==0:checkpoint_now()
 if next.begins_with("INTERMISSION_"):checkpoint_now()
 if next=="COMPLETE":checkpoint_now()
 if next.begins_with("WAVE_"):spawn_at=game.now+1;apply_difficulty()
 broadcast();present_phase()
func apply_difficulty():
 var profile=data.difficulties[state.difficulty];var wave=maxi(0,state.wave_index());var intensity=1.0+wave*.055
 game.bot_difficulty_rules["normal"]={"think_seconds":.18,"reaction_seconds":float(profile.reaction)/intensity,"aim_error_m":float(profile.aim_error)/intensity,"tracking_rate":profile.tracking,"fire_chance":profile.fire_chance,"headshot_chance":.04+wave*.01};game.bot_difficulty="normal"
func tick(delta: float):
 if not active or game.is_client() or state.phase=="LOBBY":return
 if not game.network_active and (game.context=="pause" or not game.input_window_focused):return
 if not all_loaded():
  if game.network_active and game.local_clock()>load_deadline:
   for slot in connected_slots():
    if int(members[slot].loaded)<phase_epoch and int(members[slot].peer)>1:
     var peer=int(members[slot].peer);disconnected(peer);game.multiplayer.multiplayer_peer.disconnect_peer(peer)
  return
 var is_cinematic=state.phase in ["INTRO","DEPARTURE","CRASH","ENDING"]
 if not is_cinematic or all_loaded():phase_elapsed+=delta
 if is_cinematic:
  var duration={"INTRO":120.0,"DEPARTURE":20.0,"CRASH":24.0,"ENDING":45.0}[state.phase]
  if all_loaded() and (phase_elapsed>=duration-.00001 or skip_votes.size()>=connected_slots().size()):finish_cinematic()
  return
 if state.phase in ["DEFEAT","COMPLETE"]:return
 for slot in connected_slots():
  var actor=game.actor_by_id(slot)
  if actor!=null and actor.alive and state.phase=="PREPARATION":observe_practice(actor)
  if actor!=null and actor.alive and game.now-float(actor.last_damage)<.3:game.remote_interactions.erase(actor.remote_peer)
 if state.phase=="PREPARATION" and connected_slots().all(func(slot):return practice_complete(slot)):set_phase("BOARDING")
 elif state.phase=="BOARDING" and connected_slots().all(func(slot):return state.practice.get(str(slot),{}).get("boarded",false)):set_phase("DEPARTURE")
 elif state.phase=="CRASH_ORIENTATION" and state.completed_waves==0 and phase_elapsed>=float(data.preparation_seconds):set_phase("WAVE_1")
 elif state.phase.begins_with("INTERMISSION_") and phase_elapsed>=float(data.recovery_seconds):set_phase("WAVE_"+str(state.completed_waves+1))
 elif state.phase.begins_with("WAVE_"):update_wave()
 if state.radio_ready() and state.phase=="CRASH_ORIENTATION":set_phase("RADIO_READY")
 if state.phase not in ["INTRO","DEPARTURE","CRASH","ENDING","COMPLETE","LOBBY"] and not connected_slots().any(func(slot):var actor=game.actor_by_id(slot);return actor!=null and actor.alive):set_phase("DEFEAT")
 if game.player!=null and game.player.alive and game.context=="playing":game.update_player_interaction(delta)
 for slot in downed:
  if game.now-float(downed[slot].at)>float(data.bleedout_seconds):downed[slot].expired=true
func finish_cinematic():
 if game.is_client():return
 match state.phase:
  "INTRO":set_phase("PREPARATION")
  "DEPARTURE":set_phase("CRASH")
  "CRASH":set_phase("CRASH_ORIENTATION")
  "ENDING":
   if state.radio_ready():set_phase("COMPLETE")
func practice_complete(slot: int) -> bool:
 var progress=state.practice.get(str(slot),{})
 return PRACTICE.all(func(key):return progress.get(key,false))
func observe_practice(actor: NestActor):
 var id=str(actor.net_id)
 if not personal.has(id):personal[id]={"start":actor.global_position,"yaw":actor.rotation.y,"pitch":actor.eye.rotation.x,"slot":actor.slot}
 if not state.practice.has(id):state.practice[id]={}
 var p=state.practice[id];var origin=personal[id]
 if absf(actor.rotation.y-float(origin.yaw))>.35 or absf(actor.eye.rotation.x-float(origin.pitch))>.25:p.look=true
 if actor.global_position.distance_to(origin.start)>3:p.walk=true
 if sprinting(actor) and Vector2(actor.velocity.x,actor.velocity.z).length()>2:p.sprint=true
 if actor.global_position.y>.7:p.jump=true
 if actor.crouched:p.crouch=true
 if actor.scope_level>0:p.aim=true
 if actor.accepted_shots>0:p.fire=true
 if actor.action_state=="reloading":p.reload=true
 if actor.slot!=int(origin.slot):p.switch=true
 if bool(flashlights.get(actor.net_id,false)):p.flashlight=true
 if p.get("calibrating",false) and actor.global_position.z>9.4 and actor.global_position.distance_to(world.locations.calibration)>4 and actor.shield>=actor.tuning.shield_capacity*.95:p.shield=true
func interaction(actor: NestActor) -> Dictionary:
 if actor==null or not actor.alive or actor.faction!=0:return {}
 for slot in downed:
  var target=game.actor_by_id(int(slot))
  if target!=null and int(slot)!=actor.net_id and not downed[slot].get("expired",false) and actor.global_position.distance_to(target.global_position)<2.4 and game.now-actor.last_damage>.35 and visible_between(actor.eye.global_position,target.global_position+Vector3.UP*.6):return choice("revive:"+str(slot),"Revive expedition member",float(data.revive_seconds))
 if state.phase=="PREPARATION":
  if near(actor,"service"):return choice("service","Perform personal equipment check",.6)
  if near(actor,"calibration"):return choice("calibrate","Load shield / then take cover behind calibration barrier",1)
 if state.phase=="BOARDING":
  if near(actor,"manifest"):return choice("manifest","Inspect sealed excavation charge",.6)
  if near(actor,"board"):return choice("board","Board and secure your position",1)
 if world.region=="forest":
  if near(actor,"radio"):return choice("radio","Transmit position" if state.radio_ready() else "Check damaged radio link",1)
  if state.bomb=="missing" and actor.global_position.distance_to(world.locations["charge"+str(state.charge_site)])<2.8:return choice("charge","Confirm isolated status / Recover excavation charge",1)
  var carrier=game.actor_by_id(charge_carrier)
  if state.bomb=="carried" and carrier!=null and near(carrier,"secure") and near(actor,"secure"):return choice("secure","Secure excavation charge in surviving locker",1)
  for supply in ["ammo0","ammo1","ammo2","weapon"]:
   if near(actor,supply):return choice(supply,"Collect Naki ammunition" if supply!="weapon" else "Collect approved Naki plasma rifle",.5)
 return {}
func choice(id: String,text: String,seconds: float) -> Dictionary:return {"key":"campaign:"+id,"text":"Hold "+game.prefs.key_label("interact")+" • "+text,"seconds":seconds}
func near(actor: NestActor,id: String) -> bool:
 return world.locations.has(id) and actor.global_position.distance_to(world.locations[id])<2.8 and visible_between(actor.eye.global_position,world.locations[id]+Vector3.UP*2.0)
func visible_between(a: Vector3,b: Vector3) -> bool:return game.trace(a,b,1).is_empty() and not world.smoke_blocks(a,b)
func interact(actor: NestActor,selected: Dictionary) -> bool:
 if game.is_client() or actor==null or not actor.alive:return false
 var current=interaction(actor)
 if current.is_empty() or current.key!=selected.key:return false
 var action=str(current.key).trim_prefix("campaign:");var id=str(actor.net_id)
 if action.begins_with("revive:"):return revive(actor,int(action.get_slice(":",1)))
 if action=="service":state.practice[id]["interact"]=true;radio_notice("Brutus","Equipment verified. Follow the marked service route, then calibrate your shield.")
 elif action=="calibrate":
  state.practice[id]["calibrating"]=true;actor.shield=actor.tuning.shield_capacity*.15;actor.last_damage=game.now;radio_notice("Brutus","The shield takes the first impact. Sustained fire will strip it. Break contact. Give the suit time to recover.")
 elif action=="manifest":
  state.practice[id]["manifest"]=true;radio_notice("Technician",str(data.dialogue.boarding[0][1])+"\nAnki: "+str(data.dialogue.boarding[1][1]))
 elif action=="board":
  if not state.practice.get(id,{}).get("manifest",false):radio_notice("Brutus","Inspect the sealed charge at the manifest terminal before boarding.");return false
  state.practice[id]["boarded"]=true
 elif action=="charge":
  if state.bomb!="missing":return false
  state.bomb="carried";charge_carrier=actor.net_id;radio_notice("Brutus","Physical confirmation: isolated and safe. Secure the case in the surviving cargo locker.")
 elif action=="secure":
  if state.bomb!="carried":return false
  state.bomb="secured";charge_carrier=0;merge_durable_charge();radio_notice("Brutus","Excavation charge secured. The radio link is still under repair.")
 elif action=="radio":
  if not state.radio_ready():radio_notice("Brutus","The antenna link is damaged. I am restoring it. We must secure the charge and clear the perimeter first.");return false
  set_phase("ENDING");return true
 elif action.begins_with("ammo") or action=="weapon":
  if game.now<float(supply_at.get(action,0)):radio_notice("Brutus","Supply rack recharging. Another marked rack is available.");return false
  supply_at[action]=game.now+20
  for i in range(actor.reserve.size()):actor.reserve[i]=maxi(actor.reserve[i],actor.weapons[i].reserve*2)
  if action=="weapon":
   actor.weapons[0]=NestWeaponCatalog.profile("plasma_br").duplicate();actor.ammo[0]=actor.weapons[0].magazine;actor.reserve[0]=actor.weapons[0].reserve*2;actor.update_weapon_art()
 state.revision+=1;broadcast();return true
func down(actor: NestActor) -> bool:
 if not active or actor.faction!=0:return false
 if game.is_client():return true
 if downed.has(actor.net_id):return true
 actor.alive=false;actor.health=0;actor.shield=0;actor.action_state="dead";actor.burst_left=0;actor.respawn_at=INF;actor.velocity=Vector3.ZERO;actor.controlled=Vector3.ZERO;actor.capsule.set_deferred("disabled",true)
 for hitbox in actor.hitboxes:hitbox.set_deferred("collision_layer",0)
 downed[actor.net_id]={"at":game.now,"expired":false};flashlights[actor.net_id]=false
 if charge_carrier==actor.net_id and state.bomb=="carried":state.bomb="missing";charge_carrier=0
 broadcast();return true
func revive(helper: NestActor,slot: int) -> bool:
 if not downed.has(slot) or downed[slot].get("expired",false):return false
 var actor=game.actor_by_id(slot)
 if actor==null or helper.global_position.distance_to(actor.global_position)>2.4 or not helper.alive:return false
 var position=actor.global_position;var resources=equipment(actor);actor.respawn();loadout(actor,true);restore_equipment(actor,resources);actor.global_position=position;actor.health=maxf(actor.health,actor.tuning.health_capacity*.6);actor.shield=actor.tuning.shield_capacity*.4;downed.erase(slot);broadcast();return true
func can_damage(actor: NestActor) -> bool:
 return active and not state.phase in ["INTRO","PREPARATION","BOARDING","DEPARTURE","CRASH","ENDING","COMPLETE","DEFEAT"] and (actor.faction!=0 or not downed.has(actor.net_id))
func sprinting(actor: NestActor) -> bool:return actor.faction==0 and actor.alive and float(sprint_until.get(actor.net_id,0))>game.now and not actor.crouched
func spawn_position(wave: int,index: int) -> Vector3:
 var gates=data.waves[wave].approaches;var gate=int(gates[index%gates.size()]);var origin=world.spawns[1][gate]
 for attempt in range(25):
  var p=origin+Vector3((attempt%5-2)*1.7,.2,(attempt/5-2)*1.7)
  if world.blocked_point(p) or world.route(p,Vector3(0,0,24)).is_empty():continue
  var safe=true
  for slot in connected_slots():
   var actor=game.actor_by_id(slot)
   if actor==null or not actor.alive:continue
   var offset=p+Vector3.UP-actor.eye.global_position;var facing=actor.aim_direction().dot(offset.normalized())
   if offset.length()<12 or (offset.length()<24 and facing<-.5) or (facing>.45 and visible_between(actor.eye.global_position,p+Vector3.UP)):safe=false;break
  if safe:return p
 return Vector3.INF
func update_wave():
 var wave=state.wave_index();var total=0
 for value in state.spawned.values():
  if int(value)==wave:total+=1
 if total<int(data.waves[wave].count) and game.now>=spawn_at:
  var position=spawn_position(wave,total)
  if position.is_finite():
   var id=-1000-wave*100-total
   if state.register_enemy(id):
    var actor=make_actor(id,false,0,"Annu Defender "+str(total+1));actor.global_position=position;actor.rotation.y=atan2(position.x,position.z);spawn_at=game.now+float(data.difficulties[state.difficulty].spawn_gap)/sqrt(maxi(1,connected_slots().size()));broadcast()
  else:spawn_at=game.now+.5
 for id in state.enemies.keys():
  var enemy=game.actor_by_id(int(id))
  if enemy!=null and not enemy.alive:enemy.respawn_at=INF;state.enemy_defeated(int(id))
 if total==int(data.waves[wave].count) and state.enemies.is_empty():
  if state.finish_wave():
   for actor in game.actors.duplicate():
    if actor.faction==1 and not actor.alive:game.actors.erase(actor);actor.queue_free()
   phase_elapsed=0;phase_epoch+=1;load_deadline=game.local_clock()+45
   for slot in members:members[slot].loaded=phase_epoch if int(slot)==local_slot else -1
   checkpoint_now();broadcast();present_phase()
func enemy_goal(actor: NestActor) -> Vector3:
 var seen=memory.get(actor.net_id,{})
 if seen.is_empty():return Vector3(-2,0,23)
 var point: Vector3=seen.position;var profile=data.difficulties[state.difficulty];var wave=maxi(0,state.wave_index())
 var separation=actor.global_position.distance_to(point)
 if actor.target!=null and separation<8+(1-float(profile.aggression))*10:return actor.global_position
 if wave>=1 and float(profile.get("coordination",.3))>.25 and posmod(abs(actor.net_id),3)==0 and separation>12 and fmod(game.now,6)<2.5:return seen.get("anchor",actor.global_position)
 if float(profile.flank)+wave*.04>.3 and posmod(abs(actor.net_id),3)==1:
  var side=-1 if posmod(abs(actor.net_id),2)==0 else 1;point+=Vector3(side*(5+float(profile.flank)*6),0,3)
 if actor.shield<1 and actor.health<actor.tuning.health_capacity*.55 and float(profile.cover)>.5:
  var best=point;var distance=INF
  for cover in world.cover_points:
   var d=actor.global_position.distance_to(cover)
   if d<distance and d<15:best=cover;distance=d
  return best
 return point
func bot_intent(actor: NestActor,delta: float) -> Dictionary:
 if actor.faction==0 or state.phase in ["DEFEAT","COMPLETE","ENDING"]:return {"move":Vector2.ZERO,"jump":false}
 var profile=data.difficulties[state.difficulty];var rules=game.bot_difficulty_rules.normal
 if game.now>=actor.bot_fire:
  actor.bot_fire=game.now+.18;var previous=actor.target;actor.target=game.nearest_bot_enemy(actor,float(profile.awareness))
  if actor.target!=previous:actor.bot_target_ready=game.now+float(rules.reaction_seconds)
  if actor.target!=null:
   memory[actor.net_id]={"position":actor.target.global_position,"at":game.now,"anchor":memory.get(actor.net_id,{}).get("anchor",actor.global_position)};var error=float(rules.aim_error_m);actor.bot_aim_offset=Vector3(randf_range(-error,error),1.2*NestActor.SIZE+randf_range(-error,error),randf_range(-error,error))
 if actor.target!=null and actor.target.alive and visible_between(actor.eye.global_position,actor.target.eye.global_position):
  var offset=actor.target.global_position+actor.bot_aim_offset-actor.eye.global_position;var blend=1-exp(-delta*float(profile.tracking));actor.rotation.y=lerp_angle(actor.rotation.y,atan2(-offset.x,-offset.z),blend);actor.eye.rotation.x=lerpf(actor.eye.rotation.x,atan2(offset.y,Vector2(offset.x,offset.z).length()),blend)
  var close=offset.length()<8
  if actor.action_state=="ready" and actor.slot!=(1 if close else 0):actor.select_weapon(1 if close else 0)
  if actor.ammo[actor.slot]==0:actor.reload_weapon()
  var period=float(profile.burst_on)+float(profile.burst_off);var on=fmod(game.now+abs(actor.net_id)*.13,period)<float(profile.burst_on)
  if on and game.now>=actor.bot_target_ready and actor.aim_direction().dot(offset.normalized())>cos(deg_to_rad(5)) and randf()<float(profile.fire_chance):actor.fire_trigger()
 else:actor.target=null
 if actor.bot_movement==null:actor.bot_movement=NestBotMovement.new(actor)
 return actor.bot_movement.update(delta)
func equipment(actor: NestActor) -> Dictionary:
 var kinds=[]
 for weapon in actor.weapons:kinds.append(weapon.kind)
 return {"weapons":kinds,"ammo":actor.ammo.duplicate(),"reserve":actor.reserve.duplicate(),"health":actor.health,"shield":actor.shield,"slot":actor.slot}
func restore_equipment(actor: NestActor,saved: Dictionary):
 if not saved.get("weapons") is Array or saved.weapons.size()!=2:return
 for i in range(2):
  var weapon=NestWeaponCatalog.profile(str(saved.weapons[i]))
  if weapon.kind=="none":return
  actor.weapons[i]=weapon.duplicate();actor.ammo[i]=clampi(int(saved.ammo[i]),0,weapon.magazine);actor.reserve[i]=clampi(int(saved.reserve[i]),0,weapon.reserve*4)
 actor.slot=clampi(int(saved.get("slot",0)),0,1);actor.health=clampf(float(saved.get("health",actor.tuning.health_capacity)),1,actor.tuning.health_capacity);actor.shield=clampf(float(saved.get("shield",actor.tuning.shield_capacity)),0,actor.tuning.shield_capacity);actor.update_weapon_art()
func checkpoint_now():
 if game.is_client() or state.phase=="INTRO":return
 state.equipment={}
 for slot in members:
  var actor=game.actor_by_id(int(slot))
  if actor!=null:state.equipment[str(slot)]=equipment(actor)
 state.supplies={}
 for key in supply_at:state.supplies[key]=maxf(0,float(supply_at[key])-game.now)
 checkpoint=state.pack();checkpoint.enemies={}
 if checkpoint.phase=="CRASH_ORIENTATION" and int(checkpoint.completed_waves)==5:checkpoint.phase="CRASH_ORIENTATION"
 if checkpoint.bomb=="carried":checkpoint.bomb="missing"
 if not save_store.save(checkpoint):notice=save_store.error
func merge_durable_charge():
 if checkpoint.is_empty():return
 checkpoint.bomb="secured";checkpoint.revision=state.revision+1
 save_store.save(checkpoint)
func retry_checkpoint():
 if game.is_client() or state.phase!="DEFEAT":return
 var saved=checkpoint.duplicate(true)
 if saved.is_empty():saved=save_store.load_checkpoint()
 if not saved.is_empty():restore_checkpoint(saved)
func restore_checkpoint(saved: Dictionary):
 var previous_revision=state.revision
 if not state.restore(saved):return
 downed.clear();personal.clear();memory.clear();skip_votes.clear();charge_carrier=0;state.revision=maxi(previous_revision,state.revision)+1
 game.match_session=randi_range(1,2147483647);game.prepare_match_input()
 supply_at={}
 for key in state.supplies:supply_at[key]=game.now+float(state.supplies[key])
 set_world("preparation" if state.phase in ["PREPARATION","BOARDING"] else "forest");rebuild_heroes()
 for slot in members:
  var actor=game.actor_by_id(int(slot))
  if actor!=null:restore_equipment(actor,state.equipment.get(str(slot),{}))
 if state.phase.begins_with("INTERMISSION_"):state.phase="WAVE_"+str(state.completed_waves+1)
 phase_elapsed=0;phase_epoch+=1;spawn_at=game.now+3
 load_deadline=game.local_clock()+45
 for slot in members:members[slot].loaded=phase_epoch if int(slot)==local_slot else -1
 apply_difficulty();broadcast();present_phase()
func replay():
 if game.is_client():return
 state.new_run(state.difficulty);checkpoint={};initialize_run();set_phase("INTRO")
func objective() -> String:
 match state.phase:
  "INTRO":return "THE WORLD WE BUILT • CONNECTUCT"
  "PREPARATION":
   var progress=state.practice.get(str(local_slot),{});var missing=[]
   for key in PRACTICE:
    if not progress.get(key,false):missing.append(key.capitalize())
   return "COMPLETE DEPARTURE READINESS\n"+("Complete • waiting for squad" if missing.is_empty() else "%d / %d personal checks complete"%[PRACTICE.size()-missing.size(),PRACTICE.size()])+"\nFollow Brutus's instructions and the cyan waypoint."
  "BOARDING":return "BOARD THE EXPEDITION SHIP\nInspect sealed charge at manifest terminal; each member boards when ready."
  "CRASH_ORIENTATION":return "EXIT THE WRECK • LOCATE AND SECURE THE DEMOLITION CHARGE" if state.completed_waves==0 else "LOCATE AND SECURE THE DEMOLITION CHARGE"
  "RADIO_READY":return "RETURN TO THE SHIP'S EMERGENCY RADIO"
  "DEFEAT":return "SQUAD DOWN • RETRY CHECKPOINT"
 if state.phase.begins_with("WAVE_"):
  var index=state.wave_index();return "SURVIVE THE ANNU ASSAULT\nWave %d / 5 • %s • %d / %d defeated\nCharge: %s"%[index+1,data.waves[index].name,state.wave_kills(index),data.waves[index].count,state.bomb.to_upper()]
 if state.phase.begins_with("INTERMISSION_"):return "WAVE CLEAR • RECOVER / RESUPPLY\nNext wave in %d seconds • Charge: %s"%[maxi(0,int(float(data.recovery_seconds)-phase_elapsed)),state.bomb.to_upper()]
 return state.phase.replace("_"," ")
func radio_notice(speaker: String,text: String):
 notice=speaker+": "+text;set_meta("notice_until",game.now+9);broadcast()
func present_phase():
 if state.phase=="LOBBY":NestCampaignUI.lobby(self);return
 if state.phase=="DEFEAT":NestCampaignUI.defeat(self);return
 if state.phase=="COMPLETE":NestCampaignUI.complete(self);return
 game.clear_screen();game.current_screen="campaign_playing";game.context="cinematic" if state.phase in ["INTRO","DEPARTURE","CRASH","ENDING"] else "playing"
 if game.context=="cinematic" and guide!=null:guide.stop_voice();guide.spoken_step=""
 if game.context=="playing":
  game.create_hud();game.hud.visible=true
  if game.player!=null and game.player.camera!=null:game.player.camera.current=true
  game.clear_held_input();game.capture_mouse()
 else:game.hud.visible=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 last_present_phase=state.phase
func resume():present_phase()
func handle_input(event: InputEvent) -> bool:
 var dashboard=get_node_or_null("/root/AncientNestDiscordShortcut")
 if not active or (dashboard!=null and dashboard.is_open()):return false
 if event.is_action_pressed("pause"):
  if game.current_screen=="settings":return false
  if game.current_screen=="campaign_pause":resume()
  elif game.running:NestCampaignUI.pause(self)
  else:exit_campaign()
  return true
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ENTER and state.phase in ["INTRO","DEPARTURE","CRASH","ENDING"]:send_action("skip",{});return true
 if game.context=="playing" and event.is_action_pressed("flashlight"):send_action("flashlight",{});return true
 if game.context=="playing" and event.is_action_pressed("campaign_hint"):
  if guide!=null:guide.repeat_current()
  return true
 return false
func send_action(action: String,extra: Dictionary):
 if not active:return
 if game.is_client():request.rpc_id(1,action,extra,state.run_id,phase_epoch)
 else:apply_action(local_slot,action,extra)
@rpc("any_peer","call_remote","reliable")
func request(action: String,extra: Dictionary,run: String,epoch: int):
 if not active or game.is_client() or run!=state.run_id or epoch!=phase_epoch:return
 var slot=slot_for_peer(multiplayer.get_remote_sender_id())
 if slot==0 or not game.network_policy.admit(multiplayer.get_remote_sender_id(),"campaign",game.local_clock(),20,24):return
 apply_action(slot,action,extra)
func apply_action(slot: int,action: String,extra: Dictionary):
 if not members.has(slot) or not members[slot].connected:return
 match action:
  "ready":
   if state.phase!="LOBBY":return
   members[slot].ready=not members[slot].ready;broadcast();NestCampaignUI.lobby(self)
  "loaded":
   if int(extra.get("epoch",-1))==phase_epoch:members[slot].loaded=phase_epoch
  "skip":
   if state.phase in ["INTRO","DEPARTURE","CRASH","ENDING"]:skip_votes[slot]=true;broadcast()
  "flashlight":
   var actor=game.actor_by_id(slot)
   if actor!=null and actor.alive:flashlights[slot]=not bool(flashlights.get(slot,false));broadcast()
  "sprint":
   if bool(extra.get("held",false)):sprint_until[slot]=game.now+.5
   else:sprint_until.erase(slot)
  "aim":
   if state.phase=="PREPARATION" and state.practice.has(str(slot)):state.practice[str(slot)].aim=true
func descriptors() -> Array:
 var result=[]
 for actor in game.actors:result.append({"id":actor.net_id,"peer":actor.remote_peer,"name":actor.username,"hero":actor.faction==0,"position":actor.global_position})
 return result
func broadcast():
 if not active or game.is_client() or not game.network_active:return
 var packet={"state":state.pack(),"members":members,"epoch":phase_epoch,"elapsed":phase_elapsed,"now":game.now,"session":game.match_session,"region":world.region if world!=null else "","actors":descriptors(),"downed":downed,"flashlights":flashlights,"sprint":sprint_until,"carrier":charge_carrier,"skip":skip_votes,"notice":notice,"notice_until":float(get_meta("notice_until",0))}
 for slot in connected_slots():
  var peer=int(members[slot].peer)
  if peer>1:receive_state.rpc_id(peer,packet)
@rpc("authority","call_remote","reliable")
func receive_state(packet: Dictionary):
 if not active or not game.is_client() or local_slot<1 or var_to_bytes(packet).size()>65536:return
 var incoming=packet.get("state",{})
 # Lobbies intentionally have no persisted run yet.
 if incoming.get("phase","")=="LOBBY":
  if not incoming.get("difficulty","") in NestCampaignState.DIFFICULTIES:return
  state.difficulty=incoming.difficulty;state.phase="LOBBY";members=packet.members.duplicate(true);NestCampaignUI.lobby(self);return
 if not NestCampaignState.valid(incoming):return
 if incoming.run==state.run_id and int(incoming.revision)<state.revision:return
 var old_phase=state.phase;var old_epoch=phase_epoch;var new_session=int(packet.session)!=game.match_session;state.restore(incoming);members={}
 for slot in packet.members:members[int(slot)]=packet.members[slot].duplicate(true)
 phase_epoch=int(packet.epoch);phase_elapsed=float(packet.elapsed);sync_now=float(packet.now);game.now=maxf(game.now,sync_now);game.match_session=int(packet.session)
 if not game.running:
  configure_game();game.prepare_match_input();game.running=true;game.deadline=INF;game.break_until=0;game.site_states.assign([{"stage":"sealed","bomb_at":0.0},{"stage":"sealed","bomb_at":0.0}]);game.pad_stock.clear();game.finished=false
 elif new_session:clear_actors();game.prepare_match_input()
 if world==null or world.region!=str(packet.region):set_world(str(packet.region));clear_actors()
 var ids=[]
 for description in packet.actors:
  var id=int(description.id);ids.append(id);var actor=game.actor_by_id(id)
  if actor==null:
   actor=make_actor(id,bool(description.hero),int(description.peer),str(description.name));actor.global_position=description.position
  actor.remote_peer=int(description.peer)
  if id==local_slot and not actor.local_player:actor.local_player=true
 for actor in game.actors.duplicate():
  if actor.net_id not in ids:game.actors.erase(actor);actor.queue_free()
 downed=packet.downed.duplicate(true);flashlights=packet.flashlights.duplicate(true);skip_votes=packet.skip.duplicate(true);notice=str(packet.notice);set_meta("notice_until",float(packet.notice_until));ensure_cinematic()
 sprint_until=packet.get("sprint",{}).duplicate(true)
 charge_carrier=int(packet.get("carrier",0))
 if old_phase!=state.phase or old_epoch!=phase_epoch:
  apply_difficulty();present_phase();send_action("loaded",{"epoch":phase_epoch})
func _process(delta: float):
 if not active:return
 if state.phase=="LOBBY":return
 if game.is_client():phase_elapsed+=delta if game.context!="pause" or game.network_active else 0
 if world!=null:world.animate(game.now)
 if not game.is_client() and game.local_clock()>=sync_at:sync_at=game.local_clock()+.2;broadcast()
 if cinematic!=null:cinematic.present(phase_elapsed)
 if game.context=="playing" and game.player!=null and game.player.alive:
  var held=Input.is_action_pressed("sprint") and game.player.input_captured()
  if held:sprint_until[local_slot]=game.now+.5
  else:sprint_until.erase(local_slot)
  if held!=last_sprint or (held and game.now>=next_sprint):last_sprint=held;next_sprint=game.now+.2;send_action("sprint",{"held":held})
  if state.phase=="PREPARATION" and game.now>=next_aim and not state.practice.get(str(local_slot),{}).get("aim",false) and (Input.is_action_pressed("aim") or Input.is_action_pressed("zoom")):next_aim=game.now+.2;send_action("aim",{})
 update_flashlights();update_objective_ui()
 if guide!=null:guide.update()
 if world!=null and world.region=="forest":
  var carrier=game.actor_by_id(charge_carrier)
  world.charge_mesh.position=(carrier.global_position+Vector3(.4,.6,0)) if state.bomb=="carried" and carrier!=null else world.locations["charge"+str(state.charge_site)]+Vector3.UP*.45;world.charge_mesh.visible=state.bomb!="secured";world.secure_mesh.visible=state.bomb=="secured";world.ancient_light.visible=state.phase in ["ENDING","COMPLETE"]
  world.charge_sign.position=world.locations["charge"+str(state.charge_site)]+Vector3.UP*1.6;world.charge_sign.visible=state.bomb=="missing";world.ancient_light.visible=state.phase=="COMPLETE" or (state.phase=="ENDING" and phase_elapsed>=35)
func update_flashlights():
 for actor in game.actors:
  if actor.faction!=0:continue
  var lamp=actor.eye.get_node_or_null("CampaignFlashlight")
  if lamp==null:
   lamp=SpotLight3D.new();lamp.name="CampaignFlashlight";lamp.position=Vector3(.22,-.15,-.35);lamp.spot_range=32;lamp.spot_angle=24;lamp.light_energy=3.0;lamp.light_color=Color("e1f1e3");lamp.shadow_enabled=actor.local_player and bool(game.prefs.values.shadows);actor.eye.add_child(lamp)
  lamp.visible=bool(flashlights.get(actor.net_id,false)) and actor.alive and actor.slot<actor.weapons.size() and actor.weapons[actor.slot].kind!="plasma_sword"
func update_objective_ui():
 if game.context=="cinematic" or game.current_screen in ["campaign_pause","settings","campaign_complete","campaign_defeat"]:return
 if not is_instance_valid(objective_label):
  objective_label=game.label("",17,Color("e4d69e"));objective_label.name="CampaignObjectives";objective_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.hud.add_child(objective_label);objective_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);objective_label.offset_left=22;objective_label.offset_top=150;objective_label.offset_right=620;objective_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 if is_instance_valid(game.rank_badge):game.rank_badge.visible=false
 var rank_backing=game.hud.get_node_or_null("LiveRankBacking")
 if rank_backing!=null:rank_backing.visible=false
 if is_instance_valid(game.reference_hud):game.reference_hud.top.visible=false
 if is_instance_valid(game.hud_top):game.hud_top.visible=false
 if is_instance_valid(game.hud_role):game.hud_role.visible=false
 if is_instance_valid(game.hud_objective):game.hud_objective.visible=false
 objective_label.add_theme_color_override("font_outline_color",Color.BLACK);objective_label.add_theme_constant_override("outline_size",4)
 objective_label.offset_right=minf(620,game.get_viewport().get_visible_rect().size.x-22)
 objective_label.text="THE LAST DEPARTURE • Difficulty: "+state.difficulty+"\n"+objective()
 if guide!=null and not guide.next_step().is_empty():
  objective_label.offset_top=132 if game.get_viewport().get_visible_rect().size.y>600 else 62
  objective_label.text="THE LAST DEPARTURE • Difficulty: "+state.difficulty
 else:objective_label.offset_top=150
 if game.player!=null and not game.player.alive:objective_label.text+="\nDOWNED • Hold position for a teammate. Full squad down: checkpoint retry."
 if game.player!=null and not game.player.alive:
  if game.hud_death!=null:game.hud_death.text="DOWNED"
  if game.hud_death_status!=null:game.hud_death_status.text="Teammates hold "+game.prefs.key_label("interact")+" to revive. Full squad down: retry checkpoint."
 if world!=null and world.region=="forest" and state.bomb=="missing" and game.player!=null:
  var distance=game.player.global_position.distance_to(world.locations["charge"+str(state.charge_site)])
  if distance<18:objective_label.text+="\nEquipment locator: %d m"%int(distance)
 if game.hud_prompt!=null:game.hud_prompt.text=game.interaction_for(game.player).get("text","") if game.player!=null else ""
 if game.hud_objective!=null:game.hud_objective.text=notice if game.now<float(get_meta("notice_until",0)) else "Flashlight: "+game.prefs.key_label("flashlight")+" • Sprint: "+game.prefs.key_label("sprint")
 if not is_instance_valid(radio_subtitle):
  radio_subtitle=game.label("",19,Color("f1f0dc"));radio_subtitle.name="CampaignRadioSubtitles";radio_subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;radio_subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;radio_subtitle.mouse_filter=Control.MOUSE_FILTER_IGNORE;radio_subtitle.add_theme_color_override("font_outline_color",Color.BLACK);radio_subtitle.add_theme_constant_override("outline_size",5);game.hud.add_child(radio_subtitle);radio_subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);radio_subtitle.offset_left=22;radio_subtitle.offset_right=-22;radio_subtitle.offset_top=-190;radio_subtitle.offset_bottom=-125
 radio_subtitle.text=notice if game.now<float(get_meta("notice_until",0)) else ""
 if radio_subtitle.text.is_empty() and state.phase=="CRASH_ORIENTATION" and state.completed_waves==0 and phase_elapsed<24:
  var cue=data.dialogue.orientation[clampi(int(phase_elapsed/3),0,7)];radio_subtitle.text=str(cue[0]).to_upper()+": "+str(cue[1])
func restore_game():
 if original_arena!=null:
  if world!=null:game.remove_child(world);world.queue_free();world=null
  game.arena=original_arena;game.add_child(original_arena);original_arena=null
 if original_rules!=null:
  game.game_type=original_rules;game.tuning=original_tuning;game.bot_difficulty_rules=original_bot_rules
  for key in original_selection:game.set(key,original_selection[key])
  original_rules=null;game.sync_game_type_to_legacy()
func exit_campaign():
 var was_active=active
 if active and not game.is_client() and not checkpoint.is_empty():save_store.save(checkpoint)
 active=false
 if was_active:
  game.running=false;game.audio.stop_all();clear_actors();game.close_connection()
  if cinematic!=null:cinematic.queue_free();cinematic=null
  if guide!=null:guide.queue_free();guide=null
  restore_game();game.finished=false;game.break_until=0;game.menu_camera.current=true
 members.clear();credentials.clear();state=NestCampaignState.new();last_present_phase="";NestCampaignUI.menu(self)
