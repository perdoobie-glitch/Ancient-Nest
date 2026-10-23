class_name NestShieldFX
extends Node3D
# Third-person Naki shield animations (v0.12):
#  * shield decreased: a ripple across the body from the impact point;
#  * shield depleted: full-body flash, crackle and a burst of hex shards.
# Driven by the replicated shield_flash_at / shield_break_at timestamps, so it
# plays the same on the host and on every client.
const SHARDS: int = 24
var actor: NestActor
var overlay: ShaderMaterial
var shards: CPUParticles3D
var overlay_meshes: Array[MeshInstance3D] = []
var overlay_enabled: bool = true
var warmup_frames: int = 2
var cached_regen_strength:float=-1.0
var seen_flash: float = -100
var seen_break: float = -100
var hit_started: float = -100
var break_started: float = -100
var ripple_count: int = 0
var break_count: int = 0
func _ready() -> void:
	overlay=ShaderMaterial.new(); overlay.shader=load("res://assets/shield_ripple.gdshader")
	apply_overlay()
	shards=CPUParticles3D.new(); shards.name="ShieldShards"; add_child(shards)
	shards.emitting=false; shards.one_shot=true; shards.amount=SHARDS; shards.lifetime=.75; shards.explosiveness=.95
	shards.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE; shards.emission_sphere_radius=.38*NestActor.SIZE
	shards.direction=Vector3.UP; shards.spread=180; shards.initial_velocity_min=2.2; shards.initial_velocity_max=4.2
	shards.gravity=Vector3(0,-6,0); shards.damping_min=1.5; shards.damping_max=3
	shards.angular_velocity_min=-540; shards.angular_velocity_max=540
	shards.scale_amount_min=.6; shards.scale_amount_max=1.1
	var fade=Curve.new(); fade.add_point(Vector2(0,1)); fade.add_point(Vector2(1,0)); shards.scale_amount_curve=fade
	var ramp=Gradient.new(); ramp.colors=PackedColorArray([Color(.65,1,.72,.75),Color(.2,.9,.4,.5),Color(.1,.7,.3,0)]); ramp.offsets=PackedFloat32Array([0,.45,1]); shards.color_ramp=ramp
	var shard=QuadMesh.new(); shard.size=Vector2(.11,.11)
	var mat=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD; mat.vertex_color_use_as_albedo=true; mat.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES; mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	shard.material=mat; shards.mesh=shard
	shards.position=Vector3(0,1.15*NestActor.SIZE,0)
func apply_overlay() -> void:
	if actor.model==null:return
	for node in actor.model.find_children("*","MeshInstance3D",true,false):
		# The skinned body receives the ripple; ornaments, cloth and equipment do not.
		if node.skin==null or "cape" in String(node.name).to_lower():continue
		overlay_meshes.append(node)
		node.material_overlay=overlay
func set_overlay_enabled(enabled: bool) -> void:
	if enabled==overlay_enabled:return
	overlay_enabled=enabled
	for node in overlay_meshes:
		if is_instance_valid(node):node.material_overlay=overlay if enabled else null
func impact_point() -> Vector3:
	var height={"head":1.74,"leg":.65,"arm":1.25}.get(actor.last_damage_region,1.15)*NestActor.SIZE
	var toward=Vector3.FORWARD
	if not actor.directional_hits.is_empty():
		var hit: Vector4=actor.directional_hits[-1]
		var flat=Vector3(hit.x-actor.global_position.x,0,hit.z-actor.global_position.z)
		if flat.length()>.01: toward=flat.normalized()
	return actor.global_position+Vector3(0,height,0)+toward*.3*NestActor.SIZE
func _process(_delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(actor.game): return
	var game=actor.game
	var shielded=actor.damage_model()=="naki" or actor.overshield>0 or actor.shield_flash_over
	# Shield decreased: energy absorbed (shield or overshield), not a body hit.
	if actor.shield_flash_at>seen_flash:
		seen_flash=actor.shield_flash_at
		if shielded and actor.shield_flash_at>-50:
			hit_started=game.now; ripple_count+=1
			overlay.set_shader_parameter("hit_point",impact_point())
			overlay.set_shader_parameter("hit_strength",clampf(actor.shield_flash_strength*1.2,.45,1.0))
			var low=actor.shield>0 and actor.shield/maxf(.01,actor.tuning.shield_capacity)<.3
			overlay.set_shader_parameter("energy_color",Color("52ed72"))
	# Shield depleted: flash, crackle and shards.
	if actor.shield_break_at>seen_break:
		seen_break=actor.shield_break_at
		if actor.shield_break_at>-50 and game.now-actor.shield_break_at<.5:
			break_started=game.now; break_count+=1
			shards.amount=NestGraphicsQuality.effect_count(game,SHARDS)
			shards.restart(); shards.emitting=true
	var hidden=(actor.local_player and not game.nu.birds.has(actor.net_id)) or game.now<actor.cloak_deadline or not actor.alive
	var healing=actor.is_regenerating()
	var regen_strength=.18 if healing else 0.0
	if regen_strength!=cached_regen_strength:
		cached_regen_strength=regen_strength;overlay.set_shader_parameter("regen_strength",regen_strength)
	var active=not hidden and (healing or game.now-hit_started<2.2 or game.now-break_started<1.8)
	# Brief initial attachment prepares the body shader during match startup.
	if warmup_frames>0:
		warmup_frames-=1;active=not hidden
	set_overlay_enabled(active)
	shards.visible=not hidden
	if not active:return
	overlay.set_shader_parameter("hit_age",maxf(0,game.now-hit_started))
	overlay.set_shader_parameter("break_age",100.0 if hidden else maxf(0,game.now-break_started))
	shards.visible=not actor.local_player
