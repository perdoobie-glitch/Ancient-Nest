extends SceneTree
var game
var failures=0
var checks=0
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error("FAIL "+message)
func _initialize():call_deferred("run")
func run():
 check(NestHybridNetwork.valid_hub_url("wss://matches.example.com"),"Public hub requires TLS")
 check(NestHybridNetwork.valid_hub_url("ws://127.0.0.1:8080"),"Plain WS permitted on exact loopback host")
 check(not NestHybridNetwork.valid_hub_url("ws://localhost:8080@evil.example/"),"URL userinfo cannot bypass secure remote-hub requirement")
 check(not NestHybridNetwork.valid_hub_url("ws://127.0.0.1.evil.example:8080"),"Host prefix cannot bypass secure remote-hub requirement")
 game=load("res://scripts/match.gd").new();game.name="StateTest";root.add_child(game);await process_frame
 var mm=game.matchmaking;mm.active=true;mm.local_slot=2;mm.hybrid.enabled=true;mm.hybrid.session.frozen=true
 mm.configure_rules(2,0)
 game.game_type.matchup=0;game.sync_game_type_to_legacy()
 var members={}
 for id in range(2,8):members[id]={"name":"Test"+str(id),"faction":0 if id<5 else 1,"character":-1,"peer":id,"rating":{"human":0,"practice":0}}
 game.match_session=77;game.begin_network_match(game.active_config(),members);game.now=22
 check(game.actors.size()==6,"Six stable identities instantiated")
 var naki=game.actor_by_id(2);var annu=game.actor_by_id(5)
 check(naki.damage_model()=="naki" and annu.damage_model()=="annu","Faction shield/armour rules retained")
 naki.health=73;naki.shield=61;naki.overshield=17;naki.over_deadline=82;naki.last_damage=21.5;naki.ammo[0]=11;naki.reserve[0]=67;naki.kills=4
 naki.cooldown=22.8;naki.action_state="reloading";naki.action_until=23.5;naki.reload_duration=2;naki.body_phase=false;naki.damage_given={5:{"damage":27,"shots":2}};naki.burst_left=2;naki.burst_next=22.1
 annu.health=64;annu.shield=0;annu.armor=39;annu.helmet_hp=12
 game.scores.assign([7,5]);game.round_number=3;game.round_started=12;game.deadline=123;game.event_sequence=400;game.damage_events={"dedup-key":true};game.pad_next=150
 game.site_states[0].stage="planted";game.bomb_site=0;game.bomb_planter=annu
 game.launch_bullet(naki,NestWeaponCatalog.profile("rocket"),Vector3(0,45,0),Vector3.UP,0)
 game.launch_grenade(annu,0,false,4096,Vector3(4,45,0),Vector3.UP,Vector3.ZERO)
 var bird=game.nu.spawn(annu,Vector3(10,40,0),.4,.1);bird.velocity=Vector3(1,2,3)
 naki.action_state="ready";naki.cooldown=0
 check(not naki.fire_trigger() and naki.ammo[0]==11 and not naki.input_active(),"Frozen authority cannot consume a local shot or accept gameplay input")
 naki.action_state="reloading";naki.cooldown=22.8
 var bytes=NestMigrationState.pack(game);var cp=bytes_to_var(bytes)
 check(NestMigrationState.valid(cp,game.NETWORK_VERSION),"Versioned checkpoint validates without Object deserialization")
 check(cp.projectiles.size()==2 and cp.birds.size()==1,"Flying rocket, grenade and Nu are included")
 check(not NestMigrationState.valid({"schema":99},game.NETWORK_VERSION),"Wrong/incomplete schema rejected")
 for size in [2,3,4,5,6,7,8,9,10]:
  var sized=cp.duplicate(true);sized.actors=[];sized.config.game_type.max_players=size+size%2
  for i in range(size):
   var actor=cp.actors[i%cp.actors.size()].duplicate(true);actor.id=100+i;sized.actors.append(actor)
  check(NestMigrationState.valid(sized,game.NETWORK_VERSION),"Checkpoint accepts a %d-player roster"%size)
 var mismatch=cp.duplicate(true);mismatch.config.game_type.max_players=8
 check(not NestMigrationState.valid(mismatch,game.NETWORK_VERSION),"Checkpoint rejects roster/config size mismatch")
 naki.health=1;naki.shield=0;naki.ammo[0]=0;naki.cooldown=0;annu.armor=0;game.scores.assign([0,0]);game.damage_events.clear()
 check(NestMigrationState.restore(game,bytes,members,88),"Full checkpoint restores at a new gameplay session")
 check(game.match_session==88 and game.actors.size()==6,"Fresh session fences old packets without duplicating actors")
 check(naki.health==73 and naki.shield==61 and naki.overshield==17 and naki.over_deadline==82 and naki.last_damage==21.5,"Naki hidden health, shields, overshield and recharge timing restored")
 check(annu.health==64 and annu.shield==0 and annu.armor==39 and annu.helmet_hp==12,"Annu body/head armour and health restored without adding shields")
 check(naki.ammo[0]==11 and naki.reserve[0]==67 and naki.cooldown==22.8 and naki.action_state=="reloading" and naki.action_until==23.5,"Ammo, simulation cooldown and active reload preserved")
 check(naki.kills==4 and naki.damage_given.has(5) and game.scores==[7,5],"Combat ledger and scores survive restoration")
 check(game.event_sequence==cp.game.event_sequence and game.damage_events.has("dedup-key"),"Damage deduplication and event counter preserved")
 check(game.round_number==3 and game.round_started==12 and game.deadline==123 and game.site_states[0].stage=="planted" and game.bomb_planter==annu,"Round clocks and planted-bomb ownership preserved")
 var live=game.effects.get_children().filter(func(n):return n.get_script() in [load("res://scripts/bullet.gd"),load("res://scripts/grenade.gd")])
 check(live.size()==2 and game.nu.birds.size()==1,"Exactly one restored instance of each active projectile and bird")
 check(game.player==naki and naki.cmd_history.is_empty() and naki.pending_shots.is_empty(),"Local identity survives; stale predicted input is discarded")
 mm.hybrid.control_deadline=.000001;mm.hybrid._process(0)
 check(mm.hybrid.control_deadline==0 and mm.hybrid.scheduler.reconnecting and mm.hybrid.scheduler.retry_at>mm.hybrid.clock() and mm.hybrid.scheduler.retry_at<=mm.hybrid.clock()+30,"Unresponsive hub ends request and schedules one bounded reconnect")
 mm.hybrid.enabled=false;mm.active=false;game.network_active=false;game.stop_game();game.queue_free();await create_timer(.75).timeout
 print("MIGRATION STATE: %d checks, %d failures"%[checks,failures]);call_deferred("quit",1 if failures else 0)
