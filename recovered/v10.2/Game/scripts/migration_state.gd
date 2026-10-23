class_name NestMigrationState
extends RefCounted
## Versioned authority checkpoint. Never deserialize Objects or executable Resources.
const SCHEMA=1
const ACTOR_FIELDS=["last_shot_kind","regen_anchor_damage","regen_start_health","regen_start_shield","placement_retry_at","bomb_equipped","bomb_drop_at","melee_ready_at","nu_used", "nu_launch_until", "sword_draw", "sword_lunge_at", "sword_lunge", "controlled", "external", "cannon_takeoff", "health", "shield", "armor", "overshield", "over_deadline", "cloak_deadline", "last_damage", "alive", "respawn_at", "life_id", "carrying", "bag_id", "crouched", "air_duck", "rank_human", "rank_practice", "kills", "deaths", "delivered", "detonations", "assists", "contributors", "damage_received", "damage_given", "death_recap", "ammo", "reserve", "slot", "cooldown", "action_until", "action_state", "reload_duration", "reload_was_empty", "body_phase", "helmet_hp", "hit_stun_until", "last_damage_origin", "last_impact_point", "last_damage_weapon", "last_damage_region", "grenades", "grenade_kind", "throw_kind", "throw_started", "throw_release", "throw_life", "throw_pending_kind", "auto_reload_at", "auto_reload_slot", "burst_left", "burst_next", "recoil", "aim_punch", "scope_level", "combat_recovery_at", "accepted_shots", "shell_next", "shell_remaining", "accuracy_penalty", "shots_in_sequence", "ak_spray_count", "ak_spray_last", "ak_spray_event", "ak_spray_command_clock", "ak_spray_last_arrival", "last_shot_at", "remote_shot_id", "remote_melee_id", "melee_contact_at", "melee_contact_until", "melee_event_id", "melee_life", "melee_round", "melee_session", "lunge_ticks", "lunge_velocity", "flag_carry", "captures", "flag_returns", "damage_fx_seq", "shield_flash_at", "shield_flash_strength", "shield_flash_over", "shield_break_at", "health_flash_at", "health_flash_strength", "directional_hits", "flash_until"]
const GAME_FIELDS=["now", "round_number", "round_started", "deadline", "attacking_faction", "scores", "finished", "break_until", "round_reason", "event_sequence", "damage_events", "site_states", "bot_progress", "delivered_bags", "loaded_bags", "bomb_site", "pad_stock", "pad_duration", "pad_next", "power_pad_next", "cs_carrier", "cs_drop_position", "cs_round_awarded", "flags", "nu_sightings", "objective_audio_sequence", "received_objective_audio", "last_defuse_cue", "kill_feed"]
static func fields(object: Object, names: Array) -> Dictionary:
 var result={}
 for key in names:result[key]=object.get(key)
 return result
static func set_fields(object: Object, data: Dictionary, names: Array) -> void:
 for key in names:
  if data.has(key):object.set(key,data[key])
static func pack(game) -> PackedByteArray:
 var actors=[]
 for a in game.actors:
  actors.append({"id":a.net_id,"state":fields(a,ACTOR_FIELDS),"pos":a.global_position,"yaw":a.rotation.y,"pitch":a.eye.rotation.x,"velocity":a.velocity,"character":a.character,"weapons":a.weapons.map(func(w):return w.kind)})
 var projectiles=[]
 for n in game.effects.get_children():
  if n.get_script()==load("res://scripts/bullet.gd") and not n.cosmetic and n.profile.speed>0:
   projectiles.append({"type":"bullet","owner":n.owner_actor.net_id,"kind":n.profile.kind,"pos":n.global_position,"direction":n.direction,"event":n.event_id,"round":n.round_id,"traveled":n.traveled,"lifetime":n.lifetime})
  elif n.get_script()==load("res://scripts/grenade.gd") and not n.cosmetic:
   var attached_id=n.attached.net_id if is_instance_valid(n.attached) and n.attached is NestActor else 0
   projectiles.append({"type":"grenade","owner":n.owner_actor.net_id,"pos":n.global_position,"rotation":n.rotation,"event":n.event_id,"round":n.round_id,"sticky":n.sticky,"velocity":n.linear_velocity,"angular":n.angular_velocity,"released":n.released,"fuse":n.fuse_at,"attached":attached_id,"offset":n.attachment_offset,"frozen":n.freeze,"collision":n.collision_mask,"settled":n.settled,"bounces":n.bounce_count,"rest":n.resting_for})
 var drops=[]
 for id in game.bags:drops.append({"id":id,"position":game.bags[id].position})
 var birds=game.nu.snapshot()
 for id in birds:
  var b=game.nu.birds[id];birds[id].merge({"controls":b.controls,"control_at":b.control_at,"clock":b.clock,"next_spot":b.next_spot,"previous_boost":b.previous_boost})
 var cp={"schema":SCHEMA,"build":game.NETWORK_VERSION,"config":game.active_config(),"pending":game.pending_game_type.to_network_dict() if game.pending_game_type!=null else {},"game":fields(game,GAME_FIELDS),"actors":actors,"drops":drops,"projectiles":projectiles,"birds":birds,"planter":game.bomb_planter.net_id if is_instance_valid(game.bomb_planter) else 0,"ranked":{"roster":game.ranked.roster,"channel":game.ranked.channel,"eligible":game.ranked.eligible,"submitted":game.ranked.submitted,"last_packet":game.ranked.last_packet},"rng":seed_state()}
 return var_to_bytes(cp) # Objects are never allowed in the decoder.
static func seed_state() -> int:
 # Global RNG has no state getter; authoritative future randomness starts with
 # this committed seed on migration. Existing trajectories are preserved.
 return randi()
static func valid(cp, version: String) -> bool:
 if not cp is Dictionary or cp.get("schema")!=SCHEMA or cp.get("build")!=version:return false
 if not cp.get("config") is Dictionary or not cp.get("game") is Dictionary or not cp.get("actors") is Array or cp.actors.size()<2 or cp.actors.size()>10 or cp.actors.size()%2!=0:return false
 var expected=int(cp.config.get("game_type",{}).get("max_players",cp.actors.size()))
 if expected!=cp.actors.size():return false
 var ids={}
 for a in cp.actors:
  if not a is Dictionary or not a.get("state") is Dictionary or not a.get("pos") is Vector3 or not a.pos.is_finite() or ids.has(a.get("id")):return false
  ids[a.id]=true
 return cp.get("projectiles") is Array and cp.projectiles.size()<=256 and cp.get("birds") is Dictionary
static func restore(game, bytes: PackedByteArray, members: Dictionary, new_session: int) -> bool:
 if bytes.size()>1048576:return false
 var cp=bytes_to_var(bytes)
 if not valid(cp,game.NETWORK_VERSION):return false
 if game.running:
  game.clear_effects();game.nu.clear()
 else:
  game.begin_network_match(cp.config,members)
 game.accept_config(cp.config);game.lobby_members=members
 game.match_session=new_session;game.pending_game_type=null
 if not cp.pending.is_empty():game.pending_game_type=GameTypeSettings.new();game.pending_game_type.apply_network_dict(cp.pending)
 set_fields(game,cp.game,GAME_FIELDS)
 game.bomb_planter=game.actor_by_id(int(cp.planter));game.reset_network_timing();game.command_sequence=0
 game.snapshot_sequence=0;game.snapshot_received=-1;game.snapshot_fragments.clear()
 game.command_received.clear();game.shot_authorizations.clear();game.remote_shot_clocks.clear();game.remote_interactions.clear();game.remote_throws.clear()
 for s in cp.actors:
  var a=game.actor_by_id(int(s.id))
  if a==null:return false
  a.set_character(int(s.character));a.refresh_traits();set_fields(a,s.state,ACTOR_FIELDS)
  a.weapons.clear()
  for kind in s.weapons:a.weapons.append(NestWeaponCatalog.profile(kind))
  a.remote_peer=int(members.get(a.net_id,{}).get("peer",0));a.local_player=a.net_id==game.matchmaking.local_slot and not game.matchmaking.dedicated
  a.global_position=s.pos;a.rotation.y=s.yaw;a.eye.rotation.x=s.pitch;a.velocity=s.velocity
  a.cmd_history.clear();a.cmd_queue.clear();a.cmd_deferred.clear();a.cmd_template.clear();a.cmd_last_seq=-1;a.cmd_credit=0;a.cmd_starved=0;a.pending_reconcile={};a.pending_shots.clear();a.snap_buffer.clear();a.view_correction=Vector3.ZERO
  a.remote_shot_id=-1;a.remote_melee_id=-1;a.melee_session=new_session
  a.clear_local_input();a.reset_physics_interpolation();a.net_target_pos=s.pos;a.net_target_yaw=s.yaw
  a.capsule.disabled=not a.alive
  for box in a.hitboxes:box.collision_layer=4 if a.alive else 0
  a.refresh_model_visibility()
  if a.local_player:game.player=a;a.camera.current=true;a.reset_aim()
 var rank=cp.ranked;game.ranked.roster=rank.roster.duplicate(true);game.ranked.channel=rank.channel;game.ranked.eligible=false;game.ranked.submitted=rank.submitted;game.ranked.last_packet=rank.last_packet
 for id in game.bags:
  if is_instance_valid(game.bags[id].node):game.bags[id].node.queue_free()
 game.bags.clear()
 for drop in cp.drops:
  var node=Node3D.new();game.effects.add_child(node);node.position=drop.position
  game.arena.kit.box(node,Vector3(0,.3,0),Vector3(.5,.4,.4),game.arena.kit.gold)
  game.bags[drop.id]={"node":node,"position":drop.position}
 seed(int(cp.rng))
 for id in cp.birds:
  var s=cp.birds[id];var actor=game.actor_by_id(int(id))
  if actor==null:continue
  var b=game.nu.spawn(actor,s.pos,s.yaw,s.pitch);b.velocity=s.vel;b.last_seq=-1;b.controls=Vector3.ZERO;b.control_at=game.now
  b.assist_enabled=s.assist;b.boost_active=s.boost;b.previous_boost=s.previous_boost;b.clock=s.clock;b.next_spot=s.next_spot;b.spots.assign(s.spots)
 for s in cp.projectiles:
  var owner=game.actor_by_id(int(s.owner))
  if owner==null:continue
  if s.type=="bullet":
   var n=load("res://scripts/bullet.gd").new();n.game=game;n.owner_actor=owner;n.profile=NestWeaponCatalog.profile(s.kind);n.direction=s.direction;n.event_id=s.event;n.round_id=s.round;n.position=s.pos;n.traveled=s.traveled;n.lifetime=s.lifetime;n.excludes=owner.ray_exclusions();n.cosmetic=game.is_client();game.effects.add_child(n)
  else:
   var n=load("res://scripts/grenade.gd").new();n.restoring=true;n.game=game;n.owner_actor=owner;n.sticky=s.sticky;n.event_id=s.event;n.round_id=s.round;n.position=s.pos;n.launch_velocity=s.velocity;n.cosmetic=game.is_client();game.effects.add_child(n)
   n.rotation=s.rotation;n.angular_velocity=s.angular;n.released=s.released;n.fuse_at=s.fuse;n.attached=game.actor_by_id(int(s.attached));n.attachment_offset=s.offset;n.freeze=true;n.set_meta("migration_frozen",s.frozen);n.collision_mask=s.collision;n.settled=s.settled;n.bounce_count=s.bounces;n.resting_for=s.rest
 game.running=true;game.context="playing";game.get_viewport().disable_3d=false;game.clear_held_input()
 return true
