class_name NestBlastFX
extends Node3D
var visual_multiplier: float=1.0
var smoke_seconds: float=1.0
var age: float=0
var core: MeshInstance3D
var core_material: ShaderMaterial
var ring: MeshInstance3D
var ring_material: StandardMaterial3D
var smoke: Array[MeshInstance3D]=[]
var smoke_material: StandardMaterial3D
var fragments: Array[MeshInstance3D]=[]
var velocities: Array[Vector3]=[]
func _ready() -> void:
	name="BombExplosionFX"
	scale=Vector3.ONE*visual_multiplier
	var game=get_parent().get_parent()
	var kit=game.arena.kit
	core=kit.sphere(self,Vector3(0,.3,0),.7,kit.lamp); core.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core_material=ShaderMaterial.new(); core_material.shader=load("res://assets/blast_fire.gdshader"); core.material_override=core_material
	ring=MeshInstance3D.new(); var torus=TorusMesh.new(); torus.inner_radius=.94; torus.outer_radius=1.02; torus.rings=32; torus.ring_segments=6; ring.mesh=torus
	ring_material=kit.material(Color(1,.60,.20,.65)); ring_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; ring_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override=ring_material; ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(ring); ring.position.y=.08
	smoke_material=kit.material(Color(.24,.23,.20,.32)); smoke_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; smoke_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var rng=RandomNumberGenerator.new(); rng.seed=1987
	for i in range(NestGraphicsQuality.effect_count(game,6)):
		var cloud=kit.sphere(self,Vector3(sin(i*2.4)*.6,.5,cos(i*2.4)*.6),.45,smoke_material); cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; smoke.append(cloud)
	for i in range(NestGraphicsQuality.effect_count(game,10)):
		var rock=kit.box(self,Vector3(0,.4,0),Vector3.ONE*rng.randf_range(.06,.16),kit.dark)
		rock.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; fragments.append(rock)
		velocities.append(Vector3(rng.randf_range(-3,3),rng.randf_range(2.5,6),rng.randf_range(-3,3)))
func _process(delta: float) -> void:
	age+=delta
	core_material.set_shader_parameter("age",age); core.scale=Vector3.ONE*(.35+minf(age,.65)*5); core.visible=age<.65
	ring.scale=Vector3(1,.2,1)*(.35+age*7); ring.visible=age<.65; ring_material.albedo_color.a=maxf(0,.65-age)
	smoke_material.albedo_color.a=maxf(0,.32*(1-age/smoke_seconds))
	for i in range(smoke.size()):
		smoke[i].position+=Vector3(sin(i*2.4)*.25,.5,cos(i*2.4)*.25)*delta; smoke[i].scale=Vector3.ONE*(1+age*1.3)
	for i in range(fragments.size()):
		velocities[i]+=Vector3.DOWN*8*delta; fragments[i].position+=velocities[i]*delta; fragments[i].rotate_x(delta*3); fragments[i].rotate_z(delta*2)
	if age>=maxf(1.0,smoke_seconds): queue_free()
