extends Node3D
var cosmetic: bool = false
var game: Node3D
var owner_actor: NestActor
var profile: NestWeapon
var direction: Vector3
var excludes: Array[RID] = []
var event_id: int
var round_id: int
var hit_position: Vector3 = Vector3.INF
var traveled: float = 0
var lifetime: float = 0
var flyby_played: bool = false
var flight_audio: Array[Node] = []
var draw_tracer: bool = true
var corpse_hits: Dictionary = {}
var debug_marked: bool=false
var penetrated: Dictionary={}
var penetration_count: int=0
static var plasma_materials: Dictionary={}
var trail: NestTracer
func _ready() -> void:
	if profile.speed>0:
		var k=game.arena.kit
		var plasma_material: StandardMaterial3D
		if profile.plasma:
			var color_key=profile.plasma_color.to_html()
			if not plasma_materials.has(color_key):
				var mat=k.material(profile.plasma_color);mat.emission_enabled=true;mat.emission=profile.plasma_color;mat.emission_energy_multiplier=3.0;plasma_materials[color_key]=mat
			plasma_material=plasma_materials[color_key]
		var visual: Node3D
		if profile.kind=="rocket":visual=NestRocketArt.create();add_child(visual)
		else:visual=k.box(self,Vector3.ZERO,Vector3(.065,.065,.35) if profile.plasma else Vector3(.025,.025,.3),plasma_material if profile.plasma else k.lamp)
		visual.look_at(global_position+direction,Vector3.FORWARD if absf(direction.dot(Vector3.UP))>.99 else Vector3.UP)
		if draw_tracer:
			trail=NestTracer.attach_projectile(self,direction,.65 if profile.plasma else profile.tracer_opacity)
			if profile.plasma:trail.material.albedo_color=Color(profile.plasma_color,.75);trail.scale.x=.07
			trail.visible=false
	

func _physics_process(delta: float) -> void:
	if game.matchmaking.blocks_simulation():return
	if profile.speed==0: return
	if not game.running or game.finished or round_id!=game.round_number or not is_instance_valid(owner_actor): queue_free(); return
	var remaining=maxf(0,profile.max_range-traveled)
	if remaining<=0:queue_free();return
	var segment=minf(profile.speed*delta,remaining)
	var next=global_position+direction*segment
	if resolve_hit(global_position,next): queue_free(); return
	global_position=next; traveled+=segment; lifetime+=delta
	if trail!=null:trail.visible=true;trail.scale.z=minf(traveled,NestTracer.LENGTH)
	if traveled>=profile.max_range or lifetime>maxf(6.0,profile.max_range/maxf(profile.speed,1.0)+0.25): queue_free()
func resolve_hit(start: Vector3, finish: Vector3) -> bool:
	var result=game.trace(start,finish,13,excludes)
	if not cosmetic:game.push_death_bodies(start,finish if result.is_empty() else result.position,direction,profile,event_id,corpse_hits)
	if result.is_empty():
		check_flyby(start,finish)
		if profile.kind=="sniper" and penetration_count>0:hit_position=finish
		return false
	hit_position=result.position
	if not debug_marked:
		if not cosmetic:game.mark_first_impact(result.position,result.normal)
		debug_marked=true
	if result.collider.has_meta("nu"):
		if not cosmetic:result.collider.get_meta("nu").destroy("shot")
		if profile.explosive:game.explode(result.position,owner_actor,event_id,float(NestWeaponCatalog.for_kind(profile.kind).splash_damage_max),cosmetic,profile.kind)
		return true
	var hit_actor=result.collider.get_meta("actor") if result.collider is Area3D and result.collider.has_meta("actor") else null
	if hit_actor!=game.player:check_flyby(start,hit_position)
	if profile.explosive:
		var definition=NestWeaponCatalog.for_kind(profile.kind)
		if not cosmetic and result.collider is Area3D and result.collider.has_meta("actor"):
			var victim: NestActor=result.collider.get_meta("actor")
			if game.is_client(): game.report_direct_hit.rpc_id(1,event_id,victim.net_id,victim.life_id,game.match_session)
			else: victim.take_damage(float(definition.damage_direct),"torso","heavy",false,owner_actor,event_id,start,profile.kind,0,result.position)
		game.explode(result.position,owner_actor,event_id,float(definition.splash_damage_max),cosmetic,profile.kind)
	elif not cosmetic and result.collider is Area3D and result.collider.has_meta("actor"):
		var victim: NestActor=result.collider.get_meta("actor")
		var damage=profile.damage
		if victim.take_damage(damage,result.collider.get_meta("region"),"bullet",profile.precision,owner_actor,event_id,start,profile.kind,traveled+start.distance_to(result.position),result.position) and game.network_active and game.multiplayer.is_server() and owner_actor.remote_peer>1:
			game.confirm_hit.rpc_id(owner_actor.remote_peer,result.collider.get_meta("region"),not victim.alive,result.position,game.match_session)
	if not profile.explosive and not (result.collider is Area3D and result.collider.has_meta("actor")):
		var material=game.surface_tag(result.collider)
		game.audio.play_sound("bullet_impact_"+material,result.position)
		if material in game.audio_config.ricochet_materials and randf()<float(game.audio_config.ricochet_probability): game.audio.play_sound("ricochet_"+material,result.position)
	# Target electricity and hit responses come from confirmed damage, not prediction.
	if not cosmetic or not (result.collider is Area3D and result.collider.has_meta("actor")):game.impact(result.position,result.normal,profile.explosive)
	# Sniper retains the same ray, range and damage for distinct lined-up players.
	# Exclude every anatomy hull of the hit actor before continuing; world cover
	# is never excluded. The finite cap is above the maximum lobby population.
	if profile.kind=="sniper" and is_instance_valid(hit_actor) and penetration_count<32:
		if not penetrated.has(hit_actor.get_instance_id()):
			penetrated[hit_actor.get_instance_id()]=true;penetration_count+=1
			for area in hit_actor.hitboxes:
				if area.get_rid() not in excludes:excludes.append(area.get_rid())
			var advance=result.position+direction*.002
			if advance.distance_to(finish)>.003:resolve_hit(advance,finish)
	return true
func check_flyby(_start: Vector3, _finish: Vector3) -> void:
	# Bullets emit impact audio only; no whiz/snap/fly-by voices.
	pass

func _exit_tree() -> void:
	if is_instance_valid(game) and game.audio!=null: game.audio.stop_group("rocket:"+str(get_instance_id()))
