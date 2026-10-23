extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 var rules=GameTypeSettings.new();rules.mode=1;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.set_physics_process(false);game.context="pause"
 var p=game.player;p.set_physics_process(false);p.set_process(false);await physics_frame
 var br=NestWeaponCatalog.for_kind("plasma_br");var auto=NestWeaponCatalog.for_kind("plasma_auto");var rifle=NestWeaponCatalog.for_kind("rifle")
 check(br.zoom_factors==[2.5] and br.reticle_style=="circle" and br.scope_overlay,"Plasma BR has only 2.5x zoom and a circular scoped reticle")
 check(auto.automatic and auto.fire_rate_rpm>rifle.fire_rate_rpm and auto.damage_body<rifle.damage_body and auto.damage_shield<rifle.damage_shield,"Automatic plasma fires faster with less damage per round than rifle")
 for kind in ["plasma_br","plasma_auto"]:
  var definition=NestWeaponCatalog.for_kind(kind);var w=NestWeaponCatalog.profile(kind)
  check(w.plasma and w.speed>0 and not w.explosive and w.plasma_color==Color("ffcf42"),kind+" uses gold swept projectiles")
  check(not w.shot_sounds.is_empty() and w.reload_sound!=null,kind+" has preloaded firing and reload audio")
  check(NestWeaponCatalog.choices("primary").any(func(v):return v.id==kind) and NestWeaponCatalog.choices("secondary").any(func(v):return v.id==kind),kind+" is selectable in either loadout slot")
  var art=NestWeaponArt.create(kind,1);game.add_child(art)
  check(art.name in ["PlasmaScopedBR","AutomaticPlasma"] and art.find_children("*","MeshInstance3D",true,false).size()>12,kind+" has distinct energy weapon geometry")
  art.queue_free()
 p.weapons.assign([NestWeaponCatalog.profile("plasma_br")]);p.ammo.assign([36]);p.reserve.assign([144]);p.slot=0;p.action_state="ready";p.scope_level=1;p.camera.fov=game.prefs.values.fov;game.context="playing"
 for i in range(120):p.update_aim(1.0/60)
 var magnification=tan(deg_to_rad(game.prefs.values.fov)*.5)/tan(deg_to_rad(p.camera.fov)*.5)
 check(absf(magnification-2.5)<.001,"Actual camera FOV resolves to 2.5x magnification")
 p.cancel_scope();game.context="pause"
 var enemy=NestActor.new();enemy.game=game;enemy.faction=1;game.add_child(enemy);game.actors.append(enemy);enemy.set_physics_process(false);enemy.set_process(false);game.fair_playing_field=true;game.fair_health_type="naki"
 p.global_position=Vector3(200,30,200)
 for kind in ["plasma_br","plasma_auto"]:
  enemy.respawn();enemy.set_physics_process(false);enemy.global_position=Vector3(200,30,180);enemy.update_visual(.016);await physics_frame
  var w=NestWeaponCatalog.profile(kind);var target=enemy.hitboxes[1].global_position;var origin=target+Vector3.BACK*10;var before=enemy.shield
  game.launch_bullet(p,w,origin,Vector3.FORWARD,0,false,game.next_event()*16)
  check(enemy.shield==before,kind+" is a traveling bolt, not instant client damage")
  for i in range(60):await physics_frame
  check(enemy.shield<before,kind+" swept bolt contacts the target")
  var wall=StaticBody3D.new();var cs=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(3,4,.05);cs.shape=shape;wall.add_child(cs);game.add_child(wall);wall.position=origin+Vector3.FORWARD*2;await physics_frame
  before=enemy.shield;game.launch_bullet(p,w,origin,Vector3.FORWARD,0,false,game.next_event()*16)
  for i in range(60):await physics_frame
  check(enemy.shield==before,kind+" cannot tunnel through thin cover")
  wall.queue_free();await physics_frame
 var a=game.arena;var cannon=a.get_node("C3BottomToTop")
 check(a.cannon_routes.size()==3,"Added third traversal route")
 enemy.queue_free();game.actors.erase(enemy);p.respawn();p.set_physics_process(false);p.global_position=cannon.global_position+Vector3.UP*.08;p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO
 cannon.recent.clear();cannon.launch(p)
 check(p.controlled.y>10,"New bottom-to-top launcher applies its takeoff impulse")
 var top=0.0
 for i in range(280):
  p.movement_step(Vector2.ZERO,false,0,0,1.0/60);await physics_frame;top=maxf(top,p.global_position.y)
 var destination=a.to_global(cannon.destination)
 print("C3 LAND ",p.global_position," target ",destination," apex ",top)
 check(p.alive and p.is_on_floor() and absf(p.global_position.y-destination.y)<.15 and Vector2(p.global_position.x-destination.x,p.global_position.z-destination.z).length()<2.5,"C3 lands on supported top sky garden with actual capsule")
 var palette=a.get_meta("v19_palettes");a.set_sides(0)
 check(palette[0][0].albedo_color==Color("f1eee5") and palette[1][0].albedo_color==Color("101115"),"Naki white/gold and Annu red/black side materials")
 a.set_sides(1);check(palette[1][0].albedo_color==Color("f1eee5") and palette[0][1].emission==Color("f22c29"),"Faction accents follow round side swaps")
 check(a.get_node("V19CastleValley").find_children("*","CollisionObject3D",true,false).is_empty(),"Distant scenery cannot interfere with gameplay collision")
 check(a.pads.size()==14 and a.pad_kinds.has("plasma_br") and a.pad_kinds.has("plasma_auto"),"Both energy weapons also spawn as map pickups")
 for faction in a.spawns:
  for pos in a.spawns[faction]:check(not a.route(pos,a.sites[0]).is_empty() and not a.route(pos,a.sites[1]).is_empty(),"Spawn %s graph retains routes to both bomb sites"%pos)
 print("V19 CONTENT: %d checks, %d failures"%[checks,failures]);game.stop_game();game.queue_free();await process_frame;quit(1 if failures else 0)
