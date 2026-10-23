extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool, message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func ticks(n=2):
 for i in range(n):await physics_frame
func settle(p, pos: Vector3):
 p.respawn();p.set_physics_process(false);p.set_process(false);p.global_position=pos+Vector3.UP*.08;p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO;p.reset_physics_interpolation()
 for i in range(12):p.movement_step(Vector2.ZERO,false,0,0,1.0/60);await physics_frame
func capsule_clear(pos: Vector3) -> bool:
 var q=PhysicsShapeQueryParameters3D.new();var cap=CapsuleShape3D.new();cap.height=NestActor.STAND_HEIGHT;cap.radius=NestActor.BODY_RADIUS
 q.shape=cap;q.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*(NestActor.STAND_CENTER+.03));q.collision_mask=1
 return game.get_world_3d().direct_space_state.intersect_shape(q).is_empty()
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);await process_frame
 var rules=GameTypeSettings.new();rules.mode=1;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.create_hud();game.set_physics_process(false);game.context="pause"
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 var a=game.arena;var lift=game.lift_node();await ticks()
 check(lift!=null and not lift is PhysicsBody3D and is_nan(game.lift_physics_y()),"Gravity lift no longer uses moving-platform replay")
 check(a.interior_shadow_lights.size()==2,"Exactly two indoor shadow accents")
 a.set_shadows_enabled(false);check(a.interior_shadow_lights.all(func(l):return not l.shadow_enabled) and not a.sun.shadow_enabled,"Shadows preference disables all shadow-casting lights")
 a.set_shadows_enabled(true);check(a.interior_shadow_lights.all(func(l):return l.shadow_enabled),"Shadow accents return when enabled")
 check(a.scale.is_equal_approx(Vector3.ONE*.85),"Original 15-percent map scale preserved")
 for positions in a.spawns.values():
  for spawn in positions:
   check(capsule_clear(spawn),"Full standing capsule clears original spawn "+str(spawn))
   check(not game.trace(spawn+Vector3.UP*.1,spawn-Vector3.UP*.6,1).is_empty(),"Original spawn retains floor support "+str(spawn))
 for entry in [Vector3(39,0,0),Vector3(39.8,0,-.5),Vector3(38.2,0,-.5)]:
  await settle(p,entry*.85)
  for i in range(210):p.movement_step(Vector2.ZERO,false,0,0,1.0/60);await physics_frame
  print("LIFT EXIT ",entry," -> ",p.global_position," floor ",p.is_on_floor())
  check(p.alive and p.is_on_floor() and absf(p.global_position.y-11.9)<.2 and p.global_position.z>1.7,"Gravity lift exits onto top deck from "+str(entry))
 for path in a.up_routes:
  await settle(p,path.start)
  var direction=path.end-path.start;var yaw=atan2(-direction.x,-direction.z)
  var count=ceili(direction.length()/p.tuning.ground_speed*60)+90
  for i in range(count):
   p.movement_step(Vector2(0,-1),false,0,yaw,1.0/60);await physics_frame
   if absf(p.global_position.y-path.end.y)<.15 and Vector2(p.global_position.x-path.end.x,p.global_position.z-path.end.z).length()<.6:break
  print("ROUTE ",path.name," ",p.global_position," -> ",path.end)
  check(p.alive and absf(p.global_position.y-path.end.y)<.3,"Actual capsule traverses "+path.name)
 # Verify supported, empty headroom along rafter spine and outside walk centerlines.
 for raw in [Vector3(0,22.8,-16),Vector3(0,22.8,0),Vector3(0,22.8,16),Vector3(-25,22.8,-20),Vector3(25,22.8,12),Vector3(47,14,14),Vector3(-45,14,-17)]:
  check(capsule_clear(raw*.85),"Standing headroom on added route "+str(raw))
  check(not game.trace((raw+Vector3.UP*.1)*.85,(raw-Vector3.UP*.5)*.85,1).is_empty(),"Solid floor under added route "+str(raw))
 # Fixture far from architecture for self-grenade timing/damage checks.
 var body=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(20,1,20);shape.shape=box;body.add_child(shape);game.add_child(body);body.position=Vector3(600,99.5,600);await ticks()
 await settle(p,Vector3(600,100,600));p.controlled.y=p.tuning.jump_speed
 var origin=p.global_position+Vector3.UP*.07;var initial=p.shield
 game.explode(origin,p,game.next_event(),100,false,"frag_grenade")
 check(p.alive and p.shield<initial,"Grenade jump keeps real self-damage")
 check(p.external.y>=6 and p.controlled.y+p.external.y>12,"A single close grenade adds upward momentum to a jump")
 var id=game.next_event();p.external=Vector3.ZERO;game.explode(origin,p,id,1,false,"frag_grenade");var ext=p.external;game.explode(origin,p,id,1,false,"frag_grenade")
 check(p.external.is_equal_approx(ext),"Repeated explosion event does not grant duplicate impulse")
 # Live editor uses a draft, preserves structural match rules and avoids healing.
 p.respawn();p.set_physics_process(false);p.health=50;p.shield=25;game.scores.assign([3,2]);game.show_pause();game.open_game_type_settings();await process_frame
 var editor=game.game_type_editor
 check(editor!=null and editor.editable and editor.visible,"Pause menu opens host-editable live traits")
 editor.controls.max_health_percent.value=150;editor.controls.shield_strength_percent.value=200;editor.controls.gravity_percent.value=80
 check(game.game_type.gravity_percent==100,"Live editor changes remain a draft until Apply")
 editor.draft.mode=3;editor.draft.matchup=2;editor.apply_changes();await process_frame;await process_frame
 check(game.mode==1 and game.matchup==0 and game.scores==[3,2],"Live Apply preserves mode, teams and scores")
 check(p.health==50 and p.shield==25 and p.tuning.health_capacity==150 and p.tuning.shield_capacity==200 and p.traits.gravity_percent==80,"Live capacities update without a free heal")
 check(game.current_screen=="pause" and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Apply returns to pause instead of lobby/gameplay")
 game.show_join_notification("TestPlayer");check(game.join_notice_rows.size()==1,"Join notification displays accepted player's name")
 game.show_pause();check(game.join_notice_rows.size()==1,"Join notification survives screen rebuild")
 for name in ["Second","Third","Fourth"]:game.show_join_notification(name)
 check(game.join_notice_rows.size()==3 and game.join_notices.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Notification stack is bounded and ignores mouse input")
 for notice in game.join_notice_rows:notice.until=0
 game.update_join_notifications();check(game.join_notice_rows.is_empty(),"Expired join notifications are removed")
 check(is_equal_approx(NestPreferences.DEFAULTS.hover_sensitivity_multiplier,.75*.95),"Enemy-hover default is another five percent slower")
 game.stop_game();game.current_screen="main";game.update_menu_music(1)
 check(game.menu_music.playing and game.menu_music.stream.get_length()>86,"New menu theme is loaded and plays in main menu")
 game.current_screen="lobby";game.update_menu_music(1);check(game.menu_music.playing,"New theme plays in custom lobby")
 game.current_screen="settings";game.update_menu_music(1);check(not game.menu_music.playing,"Menu theme stays off other screens")
 game.running=true;game.current_screen="playing";game.update_menu_music(1);check(not game.menu_music.playing,"Music stays off during gameplay")
 print("V16 UPDATE: %d checks, %d failures"%[checks,failures]);game.running=false;game.queue_free();await process_frame;quit(1 if failures else 0)
