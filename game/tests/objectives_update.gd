extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;push_error(label)
func run():
 var rules=NestMatchPresets.create(3)
 check(rules.score_to_win==3,"CTF defaults to three editable captures")
 rules.score_to_win=5;rules.validate();check(rules.score_to_win==5,"CTF cap limit remains editable")
 rules=NestMatchPresets.create(4)
 check(rules.score_to_win==11 and rules.rounds==21,"Bomb first to 11 / best of 21")
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.game_type=rules;game.mode=4;game.bot_fill=false;game.start_game();game.set_physics_process(false);game.tuning.score_limit=11
 var a=game.player;a.set_physics_process(false);a.faction=0;a.net_id=1
 var b=NestActor.new();b.game=game;b.faction=0;b.net_id=2;game.add_child(b);game.actors.append(b);b.respawn();b.set_physics_process(false)
 var defender=NestActor.new();defender.game=game;defender.faction=1;defender.net_id=3;game.add_child(defender);game.actors.append(defender);defender.respawn();defender.set_physics_process(false)
 var carriers={}
 for i in range(40):
  game.reset_cs_bomb();carriers[game.cs_carrier]=true
  check(game.cs_carrier in [1,2],"Carrier belongs to attackers")
 check(carriers.size()==2,"Random carrier selection covers both attackers")
 game.cs_carrier=1;a.action_state="ready";game.bomb_control(a,1)
 check(a.bomb_equipped and not a.fire_trigger(),"Bomb equips and prevents shooting")
 a.action_state="ready";game.bomb_control(a,2)
 check(is_equal_approx(a.bomb_drop_at-game.now,1.0),"Backpack removal takes one second")
 var drop_at=a.bomb_drop_at;game.now=drop_at-.01;game.update_cs_round()
 check(game.cs_carrier==1,"Bomb retained until drop animation completes")
 game.now=drop_at;game.update_cs_round()
 check(game.cs_carrier==0 and game.cs_drop_position.is_finite() and not a.bomb_equipped,"Bomb drops after animation")
 game.finished=false;game.break_until=0;game.cs_round_awarded=false
 defender.global_position=game.cs_drop_position
 var pickup=game.cs_interaction(defender)
 check(pickup.get("key","")=="cs_recover","Defender can recover dropped bomb")
 check(game.complete_cs_interaction(defender,pickup),"Defender pickup completes")
 defender.bomb_equipped=true
 check(not game.complete_cs_interaction(defender,{"key":"cs_plant:0","site":0}),"Defender cannot plant even with forged action")
 check(not game.cs_summary(a).contains(defender.username),"Enemy carrier name hidden from attacker HUD")
 a.global_position=Vector3(-100,20,0);a.rotation.y=0;defender.global_position=Vector3(-100,20,-10)
 defender.bomb_equipped=false;game.cs_visual._process(.016)
 check(not game.cs_visual.marker.visible,"Stowed enemy bomb does not show carrier waypoint")
 defender.bomb_equipped=true;game.cs_visual._process(.016)
 check(game.cs_visual.marker.visible,"Visible equipped enemy bomb can be identified")
 var wall=StaticBody3D.new();wall.collision_layer=1;var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(5,5,.5);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.global_position=Vector3(-100,21,-5)
 await physics_frame;await physics_frame
 game.cs_visual._process(.016)
 check(not game.cs_visual.marker.visible,"Wall blocks enemy carrier waypoint")
 a.action_state="ready";a.cooldown=0;a.bomb_equipped=false;game.cs_carrier=1
 game.bomb_control(a,1);a.action_state="ready"
 check(game.complete_cs_interaction(a,{"key":"cs_plant:0","site":0}),"Attacker plants equipped bomb")
 check(game.cs_planted() and not a.bomb_equipped,"Plant clears equipped backpack")
 game.finished=false;game.break_until=0;game.cs_round_awarded=false;game.scores[0]=10;game.cs_win(0,"test")
 check(game.finished and game.scores[0]==11,"Eleventh round win ends match")
 game.finished=false;game.break_until=game.now+.01;game.round_number=10;game.attacking_faction=0
 game.now+=1;game._physics_process(.016)
 check(game.round_number==11 and game.attacking_faction==1,"Sides switch after exactly ten completed rounds")
 game.break_until=0;a.action_state="ready";a.cooldown=0;a.melee_ready_at=0;a.bomb_equipped=false
 a.begin_melee(120,Vector3.ZERO)
 check(is_equal_approx(a.melee_ready_at-game.now,1.8),"Melee start interval fixed to 1.8 seconds")
 var event=a.melee_event_id;a.action_state="ready";a.cooldown=0;game.now+=1.79;a.melee()
 check(a.melee_event_id==event,"Second melee blocked before 1.8 seconds")
 check(NestMigrationState.ACTOR_FIELDS.has("bomb_drop_at") and NestMigrationState.ACTOR_FIELDS.has("melee_ready_at"),"Migration retains bomb and melee timers")
 var caption=game.arena.kit.label(game.arena,Vector3.ZERO,"RAMP ROUTE")
 check(not caption.visible,"Nonobjective world names removed")
 caption=game.arena.kit.label(game.arena,Vector3.ZERO,"BOMB SITE A")
 check(caption.visible,"Objective world text remains visible")
 box=null;shape=null;wall=null;game.stop_game();game.queue_free();await create_timer(.3).timeout
 print("OBJECTIVES UPDATE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
