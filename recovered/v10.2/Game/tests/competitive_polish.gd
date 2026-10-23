extends SceneTree
func _initialize():call_deferred("run")
func run():
 assert(NestWeaponCatalog.profile("magnum").magazine==6 and NestWeaponCatalog.profile("plasma_pistol").magazine==6)
 var probe=NestCloudPeer.new();probe.prepare_probe_payloads();assert(probe.probe_payloads.size()==200)
 var sample={"seen":{},"bytes":0,"first":0.0,"last":0.0}
 for packet in probe.probe_payloads:assert(probe.record_probe_data(sample,packet,1.0))
 assert(sample.bytes==237600 and sample.seen.size()==200)
 assert(not probe.record_probe_data(sample,probe.probe_payloads[0],2.0),"Duplicate samples must not inflate upload")
 var malformed=probe.probe_payloads[0].duplicate();malformed[1]=200
 assert(not probe.record_probe_data(sample,malformed,2.0))
 malformed.resize(4);assert(not probe.record_probe_data(sample,malformed,2.0))
 probe.free()
 var rng=RandomNumberGenerator.new();rng.seed=991
 for i in range(40):assert(NestLobbyVote.winner([0,0,0,0,1,1,1,2,2,2],[0,1,2,3,4],10,rng)==0)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 var rules=NestMatchPresets.create(4);rules.bots_fill_empty_slots=false;rules.plant_seconds=1.;rules.defuse_seconds=2.;rules.bomb_timer_seconds=7.;game.apply_game_type_settings(rules);game.start_game();game.set_process(false);game.set_physics_process(false);game.context="pause";game.now=100.;game.deadline=200.;game.break_until=0.;game.finished=false
 var actor=game.player;actor.set_physics_process(false);game.attacking_faction=actor.faction;game.cs_carrier=actor.net_id;actor.bomb_equipped=true;actor.action_state="ready";game.bomb_site=-1
 assert(actor.helmet_hp==0 if actor.damage_model()=="annu" else true)
 assert(game.complete_cs_interaction(actor,{"key":"cs_plant:0","site":0}));assert(is_equal_approx(float(game.site_states[0].bomb_at)-game.now,7.))
 actor.update_visual(1./60.)
 for area in actor.hitboxes:
  var data=actor.pose_offsets.get(area.get_instance_id())
  if data!=null:
   var expected=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(data.bone)*data.offset
   assert(area.global_transform.is_equal_approx(expected),"Hitbox pose changed")
 var badge=NestRankBadge.new();game.add_child(badge);badge.update_rating(3220,"human",0,0,false);assert(badge.text.text.contains("Angel") and not badge.text.text.contains("Ascendant"));assert(badge.tier.text.contains("SERVER ELO"));badge.queue_free()
 game.create_hud();game.context="playing";game.scoreboard.visible=true;game.scoreboard.begin_inspection();assert(game.context=="scoreboard" and game.scoreboard.inspecting);game.scoreboard.end_inspection();assert(game.context=="playing" and not game.scoreboard.inspecting)
 # A newly inserted wall must change routing; removing it must restore the cell.
 for i in range(4):await physics_frame
 assert(not game.arena.clear_walk(Vector3(-36.72,7.65,-10.2)),"Sanctuary must reject a low-clearance route under its ascent")
 var cell=-1
 for i in range(game.arena.nav_points.size()):
  if not game.arena.blocked_nav.has(i):cell=i;break
 assert(cell>=0)
 var spot=game.arena.nav_points[cell]
 var wall=StaticBody3D.new();wall.collision_layer=1
 var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(1.0,3.0,1.0);collision.shape=box;wall.add_child(collision);game.add_child(wall);wall.global_position=spot+Vector3.UP*1.5
 game.arena.validate_navigation(game.arena.navigation_revision)
 for i in range(4):await physics_frame
 assert(game.arena.nav_graph.is_point_disabled(cell) and game.arena.nearest_nav(spot)!=cell,"AI routes must avoid actual static obstructions")
 wall.queue_free()
 for i in range(3):await physics_frame
 game.arena.validate_navigation(game.arena.navigation_revision)
 for i in range(4):await physics_frame
 assert(not game.arena.nav_graph.is_point_disabled(cell),"Navigation refresh must restore a cleared route")
 var miniature=NestArena.new();miniature.forge_editable=true
 miniature.nav_points.assign([Vector3.ZERO,Vector3(2,0,0),Vector3(0,0,2),Vector3(2,0,2)])
 miniature.nav_links={0:[1,2],1:[0,3],2:[0,3],3:[1,2]};miniature.build_weighted_nav()
 var detour=miniature.route(Vector3.ZERO,Vector3(2,0,2),[0])
 assert(not detour.is_empty() and Vector3.ZERO not in detour,"A blocked nearest cell must not cause an empty-route retry loop")
 miniature.free()
 game.stop_game();game.queue_free();await process_frame;await process_frame
 print("PASS binary probe packet boundaries/duplicates, plurality vote, pistol magazines, bomb timer, exact hitbox pose equivalence, Angel badge and safe scoreboard inspection")
 await create_timer(.75).timeout
 call_deferred("quit")
