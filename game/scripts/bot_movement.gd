class_name NestBotMovement
extends RefCounted
var actor: NestActor
var desired = Vector3.ZERO
var steering = Vector3.ZERO
var probe_at: float = 0
var probe_staggered:bool=false
var progress_at: float = 0
var progress_position = Vector3.INF
var recovery_until: float = 0
var recovery_side: int = 1
var strafe_until: float=0
var strafe_side: float=1
var retreat_until: float=0
var separation_probe_at=0.0
var separation_clear=true
var route_progress_at=0.0
var route_best=INF
var route_goal=Vector3.INF
var route_check_at=0.0
var avoid_nav={}
var motion_parameters=PhysicsTestMotionParameters3D.new()
var motion_result=PhysicsTestMotionResult3D.new()
var motion_actor_count=-1
var repath_earliest=0.0
var contact_probe_at=0.0
var contact_normal=Vector3.ZERO
func vulnerable() -> bool:
	# Annu use body armour and always spawn with zero energy shield. The shared
	# tuning still contains the Naki shield capacity, so it is not an Annu injury.
	var depleted_shield=actor.damage_model()=="naki" and actor.tuning.shield_capacity>0 and actor.shield<actor.tuning.shield_capacity*.15
	return actor.health<actor.tuning.health_capacity*.38 or depleted_shield
func holding_objective() -> bool:
	if actor.game.mode not in [0,actor.game.MODE_CS]:return false
	var action=actor.game.interaction_for(actor)
	return not action.is_empty() and float(action.get("seconds",0))>0 and not str(action.get("key","")).begins_with("pickup:")
func _init(owner: NestActor) -> void:
	actor=owner; recovery_side=1 if owner.get_instance_id()%2==0 else -1
func reset() -> void:
	desired=Vector3.ZERO; steering=Vector3.ZERO; probe_at=0; probe_staggered=false; progress_at=actor.game.now; progress_position=actor.global_position; recovery_until=0;repath_earliest=0;contact_probe_at=0;contact_normal=Vector3.ZERO
func clear_direction(direction: Vector3, distance: float=1.25) -> bool:
	if direction.length_squared()<.001: return false
	var start=actor.global_position
	var end=start+direction*distance
	if actor.is_on_floor():
		var surface=actor.game.arena.bot_surface_height(end,start.y,maxf(.75,distance*1.1))
		if not is_finite(surface):return false
		end.y=surface
	# Sweep the actual standing/crouching collision body. Four thin rays missed
	# ankle-height trim and capsule corners, leaving bots steering into real walls.
	motion_parameters.from=actor.global_transform
	motion_parameters.motion=end-start
	motion_parameters.margin=actor.safe_margin
	if PhysicsServer3D.body_test_motion(actor.get_rid(),motion_parameters,motion_result):
		for i in range(motion_result.get_collision_count()):
			if motion_result.get_collision_normal(i).y<.65:return false
	return true
func choose_direction(wanted: Vector3) -> Vector3:
	if wanted.length_squared()<.001: return Vector3.ZERO
	if clear_direction(wanted): return wanted
	# Compare both sides and keep the escape side briefly instead of flipping
	# into the same obstacle every frame. Wide probes cover the player capsule.
	var best=Vector3.ZERO; var score=-INF
	var angles=[35,65,95,125,155,180]
	var flat_squared=Vector2(wanted.x,wanted.z).length_squared()
	for index in range(angles.size()):
		var angle=angles[index]
		for side in [recovery_side,-recovery_side]:
			var candidate=wanted.rotated(Vector3.UP,deg_to_rad(angle*side))
			if not clear_direction(candidate): continue
			var value=candidate.dot(wanted)+(.08 if side==recovery_side else 0.0)
			if value>score: score=value; best=candidate
		# Later angles turn farther from wanted; bound their best possible score.
		if index+1<angles.size() and best.length_squared()>.001:
			var upper=wanted.y*wanted.y+flat_squared*cos(deg_to_rad(angles[index+1]))+.08
			if score>upper+.000001:return best
	return best
func update(delta: float) -> Dictionary:
	var game=actor.game; var arena=game.arena
	if motion_actor_count!=game.actors.size():
		motion_actor_count=game.actors.size()
		var dynamic_bodies: Array[RID]=[]
		for other in game.actors:
			if other!=actor:dynamic_bodies.append(other.get_rid())
		motion_parameters.exclude_bodies=dynamic_bodies
	var goal=game.bot_goal(actor)
	if holding_objective():
		steering=Vector3.ZERO
		return {"move":Vector2.ZERO,"jump":false}
	var fighting=is_instance_valid(actor.target)
	if game.now>=repath_earliest and (game.now>=actor.bot_repath or actor.bot_route.is_empty() or goal.distance_to(actor.bot_destination)>2.5):
		repath_earliest=game.now+.35 # Empty/unreachable or rapidly shifting goals must not run AStar every tick.
		actor.bot_destination=goal; actor.bot_route=arena.route(actor.global_position,goal,avoid_nav.keys())
		actor.bot_repath=game.now+1.6+float(actor.get_instance_id()%7)*.09
	# Consume reached points in one frame, avoiding pauses at every grid cell.
	while not actor.bot_route.is_empty():
		var offset=actor.bot_route[0]-actor.global_position
		var reached=Vector2(offset.x,offset.z).length()<=.8 and absf(offset.y)<1.0
		if not reached and actor.bot_route.size()>1:
			var segment=actor.bot_route[1]-actor.bot_route[0]
			reached=segment.length_squared()>.01 and (actor.global_position-actor.bot_route[0]).dot(segment)>0 and actor.global_position.distance_to(actor.bot_route[0])<1.4
		if not reached:break
		actor.bot_route.pop_front()
	# Shorten only physically clear, supported same-level path sections.
	if game.now>=probe_at:
		for i in range(mini(3,actor.bot_route.size()-1),0,-1):
			if arena.walk_segment_clear(game,actor.global_position,actor.bot_route[i],actor.ray_exclusions()):
				for j in range(i): actor.bot_route.pop_front()
				break
	if game.now>=route_check_at and not actor.bot_route.is_empty() and not fighting:
		route_check_at=game.now+1.0
		var remaining=actor.global_position.distance_to(actor.bot_route[0])
		for i in range(1,actor.bot_route.size()):remaining+=actor.bot_route[i-1].distance_to(actor.bot_route[i])
		if route_goal==Vector3.INF or route_goal.distance_to(goal)>3 or remaining<route_best-1.0:
			route_best=remaining;route_progress_at=game.now;route_goal=goal
		elif game.now-route_progress_at>4.0:
			for id in avoid_nav.keys():
				if avoid_nav[id]<game.now:avoid_nav.erase(id)
			var blocked=arena.nearest_nav(actor.bot_route[0])
			if blocked!=arena.nearest_nav(goal):avoid_nav[blocked]=game.now+12
			while avoid_nav.size()>4:avoid_nav.erase(avoid_nav.keys()[0])
			var alternate=arena.recovery_route(game,actor.global_position,goal,actor.ray_exclusions(),avoid_nav.keys())
			if not alternate.is_empty():actor.bot_route=alternate;actor.bot_repath=game.now+3;probe_at=0
			route_best=INF;route_progress_at=game.now
	var offset=actor.bot_route[0]-actor.global_position if not actor.bot_route.is_empty() else Vector3.ZERO
	var wanted=Vector3(offset.x,0,offset.z).normalized()
	if fighting:
		var toward=actor.target.global_position-actor.global_position;toward.y=0
		var distance=toward.length();toward=toward.normalized()
		if game.now>=strafe_until:
			strafe_until=game.now+randf_range(.7,1.35);strafe_side=-strafe_side
		var lateral=toward.cross(Vector3.UP)*strafe_side
		if vulnerable():
			retreat_until=game.now+1.0
		if game.now<retreat_until:
			wanted=(-toward+lateral*.65).normalized()
			# Probe cover at the existing navigation cadence, not every physics frame.
			if game.now>=probe_at:
				var best_score=-INF
				for candidate in [-toward,(-toward+lateral).normalized(),(-toward-lateral).normalized(),lateral,-lateral]:
					if not clear_direction(candidate,1.5):continue
					var point=actor.global_position+candidate*2.0+Vector3.UP
					var covered=not game.trace(actor.target.eye.global_position,point,1,actor.ray_exclusions()).is_empty()
					var score=(3.0 if covered else 0.0)+candidate.dot(-toward)
					if score>best_score:best_score=score;wanted=candidate
		elif distance<23 and game.mode in [1,2]:
			wanted=(lateral*.85+toward*(.4 if distance>12 else -.2)).normalized()
		elif distance<18:
			wanted=(wanted+lateral*.45).normalized()
	if game.now>=probe_at:
		# Spread expensive obstacle/cover probes across ticks after the immediate first probe.
		probe_at=game.now+.12+(float(posmod(actor.net_id,11))*.12/11.0 if not probe_staggered else 0.0)
		probe_staggered=true;desired=choose_direction(wanted)
	# Small separation keeps teammates from trying to occupy one route point.
	var separation=Vector3.ZERO
	for other in game.actors:
		if other==actor or not other.alive or absf(other.global_position.y-actor.global_position.y)>1.4: continue
		var difference=actor.global_position-other.global_position; difference.y=0
		var distance=difference.length()
		if distance>.03 and distance<1.15: separation+=difference/distance*(1.15-distance)*.6
	var direction=(desired+separation).normalized() if desired.length_squared()>.001 else Vector3.ZERO
	if separation.length_squared()>.01:
		if game.now>=separation_probe_at:separation_probe_at=game.now+.1;separation_clear=clear_direction(direction,.8)
		if not separation_clear:direction=desired
	if game.now>=contact_probe_at:
		contact_probe_at=game.now+.12
		contact_normal=Vector3.ZERO
		if direction.length_squared()>.001:
			var excluded=motion_parameters.exclude_bodies
			motion_parameters.exclude_bodies=[];motion_parameters.max_collisions=8
			motion_parameters.from=actor.global_transform;motion_parameters.motion=direction*.35
			if PhysicsServer3D.body_test_motion(actor.get_rid(),motion_parameters,motion_result):
				var opposition=0.0
				for i in range(motion_result.get_collision_count()):
					var normal=motion_result.get_collision_normal(i)
					if normal.y>=.65:continue
					normal.y=0;normal=normal.normalized()
					var strength=-normal.dot(direction)
					if strength>opposition:opposition=strength;contact_normal=normal
			motion_parameters.exclude_bodies=excluded
	if contact_normal.length_squared()>.1 and direction.dot(contact_normal)<0:direction=direction.slide(contact_normal)
	steering=steering.lerp(direction,1-exp(-delta*12))
	if steering.length_squared()<.001: steering=Vector3.ZERO
	if not is_instance_valid(actor.target) and steering.length_squared()>.02:
		actor.rotation.y=lerp_angle(actor.rotation.y,atan2(-steering.x,-steering.z),1-exp(-delta*8))
	var jump=false
	if progress_position==Vector3.INF: progress_position=actor.global_position; progress_at=game.now
	if actor.global_position.distance_to(progress_position)>.65:
		progress_position=actor.global_position; progress_at=game.now
	elif wanted.length_squared()>.01 and game.now-progress_at>1.0 and actor.is_on_floor():
		actor.bot_repath=0; recovery_side=-recovery_side; probe_at=0; progress_at=game.now; recovery_until=game.now+.6
		# Jump only low cover with headroom and supported ground beyond it.
		var low=game.trace(actor.global_position+Vector3.UP*.45,actor.global_position+Vector3.UP*.45+wanted*1.0,1,actor.ray_exclusions())
		var high=game.trace(actor.global_position+Vector3.UP*1.55,actor.global_position+Vector3.UP*1.55+wanted*1.0,1,actor.ray_exclusions())
		jump=not low.is_empty() and high.is_empty() and arena.has_walk_support(actor.global_position+wanted*1.5,1.0) and game.now>actor.bot_jump
		if jump: actor.bot_jump=game.now+1.8
	var local=actor.global_transform.basis.inverse()*steering
	var amount=clampf(Vector2(offset.x,offset.z).length(),.2,1) if not actor.bot_route.is_empty() else (1.0 if fighting else 0.0)
	return {"move":Vector2(local.x,local.z)*amount,"jump":jump}
