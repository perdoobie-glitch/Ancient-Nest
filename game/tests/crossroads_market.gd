extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func frames(n=3):
 for i in range(n):await process_frame
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: "+label)
 else:failures+=1;push_error("FAIL: "+label)
func reset_player(p,pos):
 p.respawn();p.set_physics_process(false);p.set_process(false);p.global_position=pos+Vector3.UP*.08;p.controlled=Vector3.ZERO;p.external=Vector3.ZERO;p.velocity=Vector3.ZERO;p.rotation=Vector3.ZERO;p.eye.rotation=Vector3.ZERO;p.cannon_takeoff=false;p.reset_aim();p.reset_physics_interpolation()
func go(p,target: Vector3,ticks=240):
 await physics_frame
 for i in range(ticks):
  var delta=Vector2(target.x-p.global_position.x,target.z-p.global_position.z)
  var move=delta.normalized()*clampf(delta.length()*2,0,1) if delta.length()>.12 else Vector2.ZERO
  game.now+=1.0/60;p.movement_step(move,false,0,0,1.0/60)
  await physics_frame
  if p.is_on_floor() and absf(p.global_position.y-target.y)<.15 and delta.length()<.25:return true
 return false
func run():
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 var service=game.lobby_network;service.set_process(false);game.lobby_network=null;await frames()
 var rules=GameTypeSettings.new();rules.map_selection=1;rules.mode=2;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);await physics_frame
 var a=game.arena
 check(is_equal_approx(a.scale.z,.85*1.35) and is_equal_approx(a.scale.x,.85) and is_equal_approx(a.scale.y,.85),"Crossroads is 35% longer with original width/height scaling")
 check(a.has_meta("crossroads_atmosphere") and a.find_children("Shop_*","Node3D",true,false).size()==11,"Eleven wall-backed shopfronts create a market/temple street theme")
 check(ResourceLoader.exists("res://assets/crossroads_masonry.gdshader"),"Masonry texture shader is included")
 check(a.interior_shadow_lights.size()==2,"Only two local shadow accents are added")
 a.set_shadows_enabled(false);check(not a.sun.shadow_enabled and a.interior_shadow_lights.all(func(n):return not n.shadow_enabled),"Shadows off also disables the new accent lights")
 a.set_shadows_enabled(true);check(a.sun.shadow_enabled and a.interior_shadow_lights.all(func(n):return n.shadow_enabled),"Shadows on restores the sun and two accents")
 check(a.find_children("*","StaticBody3D",true,false).all(func(n):return n.global_basis.is_equal_approx(Basis.IDENTITY)),"Length-scaled collision uses orthonormal bodies")
 check(a.spawns[0][0].z>33 and a.spawns[1][0].z< -36,"Both spawn banks follow the longer layout")
 check(a.level_at(-2.04)==0 and a.level_at(0)==1 and a.level_at(2.38)==2,"Tactical map distinguishes alley, street and balcony heights")
 var wall=game.trace(a.to_global(Vector3(-4,8,8)),a.to_global(Vector3(-8,8,8)),1)
 check(not wall.is_empty(),"Raised street walls remain solid above the old wall height")
 check(a.up_routes.any(func(r):return r.name=="SUN ALLEY RETURN") and a.up_routes.any(func(r):return r.name=="MOON ALLEY RETURN"),"Both safe lower routes have ordinary return ramps")
 for point in a.get_meta("crossroads_safe_drops"):
  check(not a.route(a.to_global(point.landing),a.to_global(point.exit)).is_empty(),"Navigation connects "+point.name+" back to the street")
 for point in [Vector3(-33,2.8,-24),Vector3(33,2.8,-25)]:
  check(a.has_walk_support(a.to_global(point),.1) and not a.route(a.spawns[0][0],a.to_global(point)).is_empty(),"Raised court angle is reachable by ramp: "+str(point))
 game.start_game();game.set_physics_process(false);game.context="playing"
 var p=game.player;p.set_physics_process(false);p.set_process(false)
 for point in a.get_meta("crossroads_safe_drops"):
  reset_player(p,a.to_global(point.start));var hp=p.health;var shield=p.shield
  var landed=await go(p,a.to_global(point.landing))
  print("DROP ",point.name," at ",p.global_position," expected ",a.to_global(point.landing))
  check(landed and p.alive and p.health==hp and p.shield==shield,"Walking off into "+point.name+" lands alive without protection loss")
  var ramp=a.up_routes.filter(func(r):return r.name==point.name+" RETURN")[0]
  reset_player(p,ramp.start)
  var returned=await go(p,a.to_global(point.exit))
  print("RETURN ",point.name," at ",p.global_position," expected ",a.to_global(point.exit))
  check(returned and p.alive,"Actual player climbs "+point.name+" return ramp")
 for point in a.get_meta("crossroads_balcony_drops"):
  reset_player(p,a.to_global(point.start));var hp=p.health;var shield=p.shield
  check(await go(p,a.to_global(point.landing)) and p.alive and p.health==hp and p.shield==shield,"Balcony drop lands safely on the court")
 game.stop_game();game.queue_free();await frames(8)
 print("CROSSROADS MARKET: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
