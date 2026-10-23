class_name NestHitElectricity
extends Node3D
var actor: NestActor
var mesh_node: MeshInstance3D
var material: StandardMaterial3D
var mesh = ImmediateMesh.new()
var last_sequence: int = 0
var last_life: int = -1
var active_until: float = -100
var next_warning: float = 0
var low_shield: bool = false
var pulse_count: int = 0
func _ready() -> void:
	mesh_node=MeshInstance3D.new(); mesh_node.name="ElectricalContact"; mesh_node.mesh=mesh; mesh_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mesh_node)
	material=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.emission_enabled=true; material.emission_energy_multiplier=1.6
	mesh_node.material_override=material; visible=false
func ribbon(a: Vector3, b: Vector3, width: float) -> void:
	var direction=(b-a).normalized()
	var side=direction.cross(Vector3.FORWARD).normalized()*width
	if side.length_squared()<.000001: side=Vector3.RIGHT*width
	for axis in [side,direction.cross(side).normalized()*width]:
		for point in [a-axis,b-axis,b+axis,a-axis,b+axis,a+axis]: mesh.surface_add_vertex(point)
func pulse(region: String, color: Color, warning: bool=false) -> void:
	mesh.clear_surfaces(); mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var height={"head":1.74,"leg":.65,"arm":1.25}.get(region,1.15)
	var count=3 if warning else 7
	for arc in range(count):
		var angle=float(arc)*TAU/count+randf_range(-.3,.3)
		var center=Vector3(sin(angle)*.38,height+randf_range(-.25,.25),cos(angle)*.29)
		if warning: center=Vector3((-.33 if arc%2==0 else .33),1.55,.26)
		var previous=center-Vector3(0,.14,0)
		for segment in range(4):
			var next=center+Vector3(randf_range(-.07,.07),-.14+float(segment+1)*.07,randf_range(-.06,.06))
			ribbon(previous,next,.012 if warning else .018);previous=next
	mesh.surface_end()
	material.albedo_color=color; material.emission=color
	active_until=actor.game.now+(.16 if warning else .28);pulse_count+=1;visible=true
func update_feedback() -> void:
	if last_life!=actor.life_id: last_sequence=0;last_life=actor.life_id;active_until=-100;visible=false
	var ratio=actor.shield/maxf(.01,actor.tuning.shield_capacity)
	low_shield=actor.damage_model()=="naki" and actor.shield>0 and ratio<.3
	if actor.damage_fx_seq>last_sequence:
		last_sequence=actor.damage_fx_seq
		var energy=actor.shield_flash_at>=actor.health_flash_at
		pulse(actor.last_damage_region,Color("52ed72") if energy and not low_shield and actor.shield>0 else Color("52ed72") if energy else Color("ffae70"))
	elif low_shield and actor.alive and actor.game.now>=next_warning and actor.game.now>=active_until:
		next_warning=actor.game.now+.9;pulse("torso",Color("52ed72"),true)
	var allowed=not actor.local_player and actor.game.now>=actor.cloak_deadline
	visible=allowed and actor.game.now<active_until
	if visible:
		var remaining=clampf((active_until-actor.game.now)/.28,0,1)
		material.albedo_color.a=remaining*(.65 if low_shield else 1)
