class_name NestShieldHUD
extends ColorRect
var game
var effect: ShaderMaterial
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	effect=ShaderMaterial.new(); effect.shader=load("res://assets/shield_screen.gdshader"); material=effect
	effect.set_shader_parameter("blood_noise",load("res://assets/stone_noise.png"))
func _process(_delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player): visible=false; return
	var actor=game.player
	var impact=exp(-maxf(0,game.now-actor.shield_flash_at)*7.0)*actor.shield_flash_strength
	var broken=exp(-maxf(0,game.now-actor.shield_break_at)*4.5)
	var health=exp(-maxf(0,game.now-actor.health_flash_at)*8.0)*actor.health_flash_strength
	var recharging=actor.damage_model()=="naki" and actor.shield<actor.tuning.shield_capacity and game.now-actor.last_damage>=actor.tuning.shield_delay
	var edges=Vector4.ZERO
	for hit in actor.directional_hits:
		var strength=exp(-maxf(0,game.now-hit.w)*5.5)
		if strength<.01: continue
		var direction=actor.camera.global_basis.inverse()*(Vector3(hit.x,hit.y,hit.z)-actor.camera.global_position)
		var horizontal=Vector2(direction.x,direction.z).normalized()
		edges.x=maxf(edges.x,maxf(0,-horizontal.x)*strength); edges.y=maxf(edges.y,maxf(0,horizontal.x)*strength)
		edges.z=maxf(edges.z,maxf(0,-horizontal.y)*strength); edges.w=maxf(edges.w,maxf(0,horizontal.y)*strength)
	var health_ratio=clampf(actor.health/maxf(.01,actor.tuning.health_capacity),0,1)
	var no_shields=actor.shield<=0 and actor.overshield<=0 and actor.traits.show_low_health_vignette
	# v0.12: also show the brief shield-hit shimmer and shield-break burst.
	var energy_hit=impact>.01 and (actor.damage_model()=="naki" or actor.shield_flash_over)
	var breaking=broken>.02 and actor.damage_model()=="naki"
	visible=actor.alive and game.context=="playing" and (no_shields or energy_hit or breaking)
	if not visible: return
	effect.set_shader_parameter("no_shields",no_shields)
	effect.set_shader_parameter("low_shield",actor.shield>0 and actor.shield/maxf(.01,actor.tuning.shield_capacity)<.3)
	effect.set_shader_parameter("health_ratio",health_ratio)
	effect.set_shader_parameter("damage_edges",edges)
	effect.set_shader_parameter("impact",impact); effect.set_shader_parameter("broken",broken); effect.set_shader_parameter("health_hit",health)
	effect.set_shader_parameter("shield_level",actor.shield/maxf(.01,actor.tuning.shield_capacity)); effect.set_shader_parameter("shield_user",actor.damage_model()=="naki")
	effect.set_shader_parameter("energy_color",Color("ffd57c") if actor.shield_flash_over else Color("55c5ff"))
	effect.set_shader_parameter("recharge",1.0 if recharging else 0.0); effect.set_shader_parameter("viewport_size",size)
