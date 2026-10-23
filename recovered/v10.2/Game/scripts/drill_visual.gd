class_name NestDrillVisual
extends Node3D
var active: bool=false
var clock: float=0
var head: MeshInstance3D
var shaft: MeshInstance3D
var sparks: MultiMeshInstance3D
var work_audio: AudioStreamPlayer3D
func _ready() -> void:
	name="DrillAnimation"
	var kit=get_parent().get_parent().get_parent().kit
	head=kit.cylinder(self,Vector3(0,.42,0),.30,.32,kit.dark); head.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft=kit.cylinder(self,Vector3(0,.85,0),.07,.9,kit.gold)
	for i in range(5):
		var tooth=kit.box(head,Vector3(sin(i*TAU/5)*.29,-.06,cos(i*TAU/5)*.29),Vector3(.09,.20,.09),kit.gold); tooth.rotation.z=.30
	var mm=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D
	var mesh=SphereMesh.new(); mesh.radius=.018; mesh.height=.036; mesh.radial_segments=6; mesh.rings=3; mm.mesh=mesh; mm.instance_count=18
	sparks=MultiMeshInstance3D.new(); sparks.multimesh=mm; sparks.material_override=kit.lamp; sparks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(sparks); sparks.visible=false
func set_working(value: bool) -> void:
	active=value
	var game=get_parent().get_parent().get_parent().get_parent()
	if active and is_visible_in_tree() and not is_instance_valid(work_audio):
		var voices=game.audio.play_sound("drill_loop",global_position,{"attach_to":self,"group":"drill:"+str(get_instance_id())})
		if not voices.is_empty(): work_audio=voices[0]
	elif not active:
		game.audio.stop_group("drill:"+str(get_instance_id())); work_audio=null
func _exit_tree() -> void:
	if is_instance_valid(work_audio): work_audio.stop(); work_audio.stream=null
func _process(delta: float) -> void:
	if not active or not is_visible_in_tree(): sparks.visible=false; return
	clock+=delta
	head.rotation.y=clock*22; head.position.y=.40+sin(clock*18)*.05
	shaft.position.y=.83+sin(clock*18)*.05; sparks.visible=true
	for i in range(18):
		var phase=fmod(clock*2.4+float(i)/18,1.0); var angle=float(i)*2.399
		var p=Vector3(cos(angle)*phase*.85,.32+phase*.50-phase*phase*.7,sin(angle)*phase*.85)
		var scale=maxf(.1,1-phase)
		sparks.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale),p))
