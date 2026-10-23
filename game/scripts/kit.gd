class_name NestKit
extends RefCounted
var restrained_architecture: bool=false
var forge_arena
var stone: Material
var gold: StandardMaterial3D
var dark: StandardMaterial3D
var green: ShaderMaterial
var red: ShaderMaterial
var foliage: ShaderMaterial
var lamp: StandardMaterial3D
var bark: StandardMaterial3D
var leaf_mesh: ArrayMesh
var surface_tags: Dictionary
func _init() -> void:
	surface_tags=JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_audio.json")).surface_materials
	gold = material(Color("aa9060"), 0.72)
	gold.roughness=0.42
	dark = material(Color("28353b"), 0.35)
	green = ShaderMaterial.new(); green.shader=load("res://assets/banner.gdshader"); green.set_shader_parameter("cloth_color",Color("435238"))
	red = ShaderMaterial.new(); red.shader=load("res://assets/banner.gdshader"); red.set_shader_parameter("cloth_color",Color("71363b"))
	foliage = ShaderMaterial.new()
	foliage.shader=load("res://assets/foliage.gdshader")
	bark=material(Color("4b4940"))
	lamp = material(Color("ffd98b"))
	lamp.emission_enabled = true
	lamp.emission = Color("f5c774")
	lamp.emission_energy_multiplier = 1.5
	stone = ShaderMaterial.new()
	stone.shader = load("res://assets/stone.gdshader")
	stone.set_shader_parameter("noise_texture",load("res://assets/stone_noise.png"))
	var vertices=PackedVector3Array([Vector3(0,0,-.5),Vector3(-.19,0,0),Vector3(0,.065,0),Vector3(.19,0,0),Vector3(0,0,.5)])
	var uv=PackedVector2Array([Vector2(.5,0),Vector2(0,.5),Vector2(.5,.5),Vector2(1,.5),Vector2(.5,1)])
	var arrays=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP]); arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1,0,3,2,1,2,4,2,3,4])
	leaf_mesh=ArrayMesh.new(); leaf_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
func editable_parent(parent: Node3D, pos: Vector3, label: String) -> Node3D:
	if forge_arena!=null and parent==forge_arena and absf(pos.x)<80 and absf(pos.z)<80 and pos.y>=-5:
		return forge_arena.forge_auto_group(label,pos)
	return parent
func material(color: Color, metal: float = 0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.65
	return m
func mesh(parent: Node3D, shape: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var edit_parent=editable_parent(parent,pos,"Map detail")
	if edit_parent!=parent:parent=edit_parent;pos=Vector3.ZERO
	var m = MeshInstance3D.new()
	m.mesh = shape
	m.material_override = mat
	parent.add_child(m)
	m.position = pos
	return m
func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, solid: bool = false) -> Node3D:
	var edit_parent=editable_parent(parent,pos,"Map structure")
	if edit_parent!=parent:parent=edit_parent;pos=Vector3.ZERO
	var b = BoxMesh.new()
	b.size = size
	var m = mesh(parent, b, pos, mat)
	if solid:
		var body = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 2
		body.set_meta("surface_material",surface_material(mat))
		parent.add_child(body)
		body.position = pos
		var c = CollisionShape3D.new()
		var s = BoxShape3D.new()
		s.size = size
		c.shape = s
		body.add_child(c)
	return m
func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, solid: bool = false) -> Node3D:
	var edit_parent=editable_parent(parent,pos,"Map column")
	if edit_parent!=parent:parent=edit_parent;pos=Vector3.ZERO
	var shape = CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 24
	var m = mesh(parent, shape, pos, mat)
	if solid:
		var body = StaticBody3D.new()
		body.collision_layer = 1
		body.set_meta("surface_material",surface_material(mat))
		parent.add_child(body)
		body.position = pos
		var c = CollisionShape3D.new()
		var s = CylinderShape3D.new()
		s.radius = radius
		s.height = height
		c.shape = s
		body.add_child(c)
	return m
func surface_material(mat: Material) -> String:
	for property in surface_tags:
		if get(property)==mat: return str(surface_tags[property])
	return "concrete"
func sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var edit_parent=editable_parent(parent,pos,"Map sculpture")
	if edit_parent!=parent:parent=edit_parent;pos=Vector3.ZERO
	var s = SphereMesh.new()
	s.radius = radius
	s.height = radius*2
	s.radial_segments = 12
	s.rings = 6
	return mesh(parent, s, pos, mat)
func label(parent: Node3D, pos: Vector3, text: String, color: Color = Color("f3e9ce"), size: int = 40) -> Label3D:
	var l = Label3D.new()
	l.text = text
	l.visible = text.to_upper().contains("FLAG") or text.to_upper().contains("BOMB") or text.begins_with("A ·") or text.begins_with("B ·") or text.begins_with("A ") or text.begins_with("B ")
	l.font_size = size
	l.pixel_size = 0.011
	l.modulate = color
	l.outline_modulate = Color("172127")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	parent.add_child(l)
	l.position = pos
	return l
func floor_tile(parent: Node3D, center: Vector3, size: Vector2) -> void:
	var edit_parent=editable_parent(parent,center,"Floor slab")
	if edit_parent!=parent:parent=edit_parent;center=Vector3.ZERO
	box(parent, center-Vector3(0,0.4,0), Vector3(size.x,0.8,size.y), stone, true)
	for x in ([] if restrained_architecture else [-1,1]): box(parent, center+Vector3(x*(size.x/2-0.05),0.015,0), Vector3(0.08,0.05,size.y), gold)
	for z in ([] if restrained_architecture else [-1,1]): box(parent, center+Vector3(0,0.015,z*(size.y/2-0.05)), Vector3(size.x,0.05,0.08), gold)
func pillar(parent: Node3D, pos: Vector3, height: float = 5) -> void:
	var edit_parent=editable_parent(parent,pos,"Pillar")
	if edit_parent!=parent:parent=edit_parent;pos=Vector3.ZERO
	box(parent,pos+Vector3(0,0.2,0),Vector3(1.5,0.4,1.5),stone,true)
	box(parent,pos+Vector3(0,height/2,0),Vector3(0.85,height,0.85),stone,true)
	box(parent,pos+Vector3(0,height-0.2,0),Vector3(1.4,0.4,1.4),gold)
	box(parent,pos+Vector3(0,.45,0),Vector3(1.12,.12,1.12),gold)
	box(parent,pos+Vector3(0,height-.5,0),Vector3(1.12,.16,1.12),stone)
	for axis in [0,1]:
		for side in [-1,1]:
			for offset in ([0] if restrained_architecture else [-.24,0,.24]):
				var p=Vector3(offset,height/2,.438*side) if axis==0 else Vector3(.438*side,height/2,offset)
				box(parent,pos+p,Vector3(.055,height-1.1,.018) if axis==0 else Vector3(.018,height-1.1,.055),gold)
	sphere(parent,pos+Vector3(0,height+0.2,0),0.22,lamp)
func arch(parent: Node3D, pos: Vector3, angle: float = 0, width: float = 5) -> void:
	var edit_parent=editable_parent(parent,pos,"Arch")
	if edit_parent!=parent:parent=edit_parent;pos=Vector3.ZERO
	var n = Node3D.new()
	parent.add_child(n)
	n.position = pos
	n.rotation.y = angle
	for x in [-1,1]: pillar(n,Vector3(x*width/2,0,0),3.5)
	for i in range(12):
		var a = PI*float(i)/12
		var b = PI*float(i+1)/12
		var midpoint = Vector3((cos(a)+cos(b))*width/4,3.5+(sin(a)+sin(b))*width/4,0)
		var beam = box(n,midpoint,Vector3(width*PI/24+0.06,0.45,0.75),stone,true)
		beam.rotation.z = a+PI/24+PI/2
		# Rotate matching collision on the same authored segment.
		var body = n.get_child(n.get_child_count()-1)
		body.rotation.z = beam.rotation.z
func planter(parent: Node3D, pos: Vector3, tree: bool = false) -> void:
	var edit_parent=editable_parent(parent,pos,"Planter")
	if edit_parent!=parent:parent=edit_parent;pos=Vector3.ZERO
	box(parent,pos+Vector3(0,0.4,0),Vector3(2.1,0.8,2.1),stone,true)
	box(parent,pos+Vector3(0,0.82,0),Vector3(2.2,0.12,2.2),gold)
	box(parent,pos+Vector3(0,.845,0),Vector3(1.9,.06,1.9),bark)
	var rng=RandomNumberGenerator.new(); rng.seed=int(abs(pos.x*7387+pos.z*9341+pos.y*293))
	var leaves=MultiMesh.new(); leaves.transform_format=MultiMesh.TRANSFORM_3D; leaves.use_colors=true; leaves.mesh=leaf_mesh; leaves.instance_count=800 if tree else 180
	for i in range(leaves.instance_count):
		var a=rng.randf()*TAU; var r=sqrt(rng.randf())*(1.8 if tree else .98)
		var p=pos+Vector3(cos(a)*r,(3.65 if tree else 1.05)+rng.randf_range(-.35,.55)*(1.8 if tree else 1),sin(a)*r)
		var basis=Basis.from_euler(Vector3(rng.randf_range(-.8,.8),rng.randf()*TAU,rng.randf_range(-.6,.6))).scaled(Vector3.ONE*rng.randf_range(.28,.54))
		leaves.set_instance_transform(i,Transform3D(basis,p)); leaves.set_instance_color(i,Color("66744c").lerp(Color("344b37"),rng.randf()))
	var canopy=MultiMeshInstance3D.new(); canopy.multimesh=leaves; canopy.material_override=foliage; parent.add_child(canopy)
	if tree:
		cylinder(parent,pos+Vector3(0,2.2,0),0.19,3.5,bark,true)
		for i in range(8):
			var a=float(i)*2.39
			branch(parent,pos+Vector3(0,2.4+(i%3)*.25,0),pos+Vector3(sin(a)*1.45,3.8+sin(i)*.4,cos(a)*1.45),.065,bark)
			branch(parent,pos+Vector3(sin(a)*1.1,3.6,cos(a)*1.1),pos+Vector3(sin(a+.4)*1.75,4.15,cos(a+.4)*1.75),.025,bark)

func branch(parent: Node3D, start: Vector3, finish: Vector3, radius: float, mat: Material) -> void:
	var shape=CylinderMesh.new(); shape.top_radius=radius*.55; shape.bottom_radius=radius; shape.height=start.distance_to(finish); shape.radial_segments=10
	var m=mesh(parent,shape,(start+finish)/2,mat); m.quaternion=Quaternion(Vector3.UP,(finish-start).normalized())

func banner(parent: Node3D, pos: Vector3, mat: Material) -> MeshInstance3D:
	var vertices=PackedVector3Array(); var uv=PackedVector2Array(); var normals=PackedVector3Array(); var indices=PackedInt32Array()
	var cols=14; var rows=20
	for row in range(rows):
		for col in range(cols):
			var u=float(col)/(cols-1); var v=float(row)/(rows-1)
			vertices.append(Vector3(sin(u*PI*4)*.045,5.4-v*3.8-u*.13,u*2.8)); uv.append(Vector2(u,v)); normals.append(Vector3.RIGHT)
	for row in range(rows-1):
		for col in range(cols-1):
			var i=row*cols+col; indices.append_array(PackedInt32Array([i,i+1,i+cols,i+1,i+cols+1,i+cols]))
	var arrays=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_INDEX]=indices
	var shape=ArrayMesh.new(); shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh(parent,shape,pos,mat)
func ring(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> void:
	var t = TorusMesh.new()
	t.inner_radius = radius-0.04
	t.outer_radius = radius+0.04
	t.rings = 48
	t.ring_segments = 8
	mesh(parent,t,pos,mat)
