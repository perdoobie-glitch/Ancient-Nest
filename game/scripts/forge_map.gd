class_name NestForgeMap
extends RefCounted
const FORMAT="ancient-nest-forge"
const MAP_ID="sanctuary-v26-forge2"
const SAVE_PATH="user://forge_layout.json"
func map_id() -> String:return "frontier-10.2-"+NestArena.MAP_NAMES[arena.map_selection].to_lower() if arena.map_selection>=3 else "savannah-v9-1" if arena.map_selection==2 else "crossroads-v31-market2" if arena.map_selection==1 else "sanctuary-v31-wide1"
func save_path() -> String:return "user://forge_"+NestArena.MAP_NAMES[game.game_type.map_selection].to_lower()+"_layout.json" if game.game_type.map_selection>=3 else "user://forge_savannah_layout.json" if game.game_type.map_selection==2 else "user://forge_crossroads_market_layout.json" if game.game_type.map_selection==1 else "user://forge_sanctuary_wide_layout.json"
const MAX_ADDED=128
const PICK_LAYER=512
const MATERIALS=["original","stone","gold","dark_metal","glass","naki_green","annu_red","white","bronze"]
const STRUCTURES=["wall","cover","glass","ramp","block","column","platform"]
var game
var arena: NestArena
var content: Node3D
var collisions: Node3D
var records={}
var originals={}
var added_order=[]
var points={}
var markers={}
var next_id=1
var editor_visible=false
var editor_mode=0
var initial_routes=[]
var initial_pads=[]
var default_points={}
var material_cache={}
var dirty_collision={}
var runtime_batches: Node3D
var batched_visuals=[]
var batch_stats={}
func _init(owner):game=owner
func build() -> void:
 var old=game.arena;game.remove_child(old);old.queue_free()
 arena=NestArena.new();arena.map_selection=game.game_type.map_selection;arena.forge_editable=true;game.arena=arena;game.add_child(arena);NestGraphicsQuality.apply_arena(arena,game.prefs.values)
 content=Node3D.new();content.name="ForgeObjects";game.add_child(content)
 collisions=Node3D.new();collisions.name="ForgeEditedCollision";game.add_child(collisions)
 for n in arena.find_children("*","Node3D",true,false):
  if n.has_meta("forge_key"):register_piece(String(n.get_meta("forge_key")),n,String(n.get_meta("forge_label")),"base",{})
 initial_routes=arena.cannon_routes.duplicate(true)
 var lift=arena.get_node_or_null("U2Lift")
 if lift!=null:register_piece("mechanism_lift",lift,"Gravity lift","mechanism",{})
 var cannon_index=0
 for n in arena.get_children():
  if n is NestManCannon:register_piece("mechanism_cannon_%02d"%cannon_index,n,"Launcher "+str(cannon_index+1),"mechanism",{"route_index":cannon_index});cannon_index+=1
 var lights=arena.find_children("*","Light3D",true,false)
 for i in range(lights.size()):register_piece("light_%03d"%i,lights[i],lights[i].name,"light",{})
 for i in range(arena.pad_meshes.size()):
  var n=arena.pad_meshes[i];register_piece("pickup_%02d"%i,n,arena.pad_names[i],"pickup",{"kind":arena.pad_kinds[i]})
  initial_pads.append({"key":"pickup_%02d"%i,"kind":arena.pad_kinds[i],"label":arena.pad_names[i]})
 # Imported scenery not created through Kit still gets one coherent editable root.
 var index=0
 for n in arena.get_children():
  if not n is Node3D or n.has_meta("forge_key") or n is Light3D or n in arena.deposits or n in arena.pad_meshes or n.name=="U2Lift" or n is WorldEnvironment:continue
  if absf(n.global_position.x)>70 or absf(n.global_position.z)>70 or n.global_position.y< -5:continue
  if n is MeshInstance3D or (not n.find_children("*","MeshInstance3D",true,false).is_empty() and not n.get_script()):
   if not n.find_children("*","Node3D",true,false).filter(func(c):return c.has_meta("forge_key")).is_empty():continue
   var root=n
   if n is MeshInstance3D:
    root=Node3D.new();arena.add_child(root);root.global_position=n.global_position
    var body=n.get_meta("forge_solid_body") if n.has_meta("forge_solid_body") else null;n.reparent(root,true)
    if is_instance_valid(body):body.reparent(root,true)
   register_piece("scenery_%03d"%index,root,"Scenery "+String(n.name),"base",{});index+=1
 var defaults={"spawns":{"0":[],"1":[]},"bombs":[],"flags":[]}
 for team in [0,1]:
  for p in arena.spawns[team]:defaults.spawns[str(team)].append(vec(p))
 for p in arena.sites:defaults.bombs.append(vec(p))
 for p in arena.flag_positions:defaults.flags.append(vec(p))
 for mode in range(5):points[str(mode)]=defaults.duplicate(true)
 default_points=points.duplicate(true)
 rebuild_markers();set_editor_visible(false)
func register_piece(key: String,node: Node3D,label: String,kind: String,spec: Dictionary) -> void:
 node.set_meta("forge_key",key)
 var bounds=local_bounds(node)
 var materials=[]
 for m in visuals(node):materials.append({"node":m,"material":m.material_override})
 var templates=[]
 var bodies=node.find_children("*","StaticBody3D",true,false)
 if node is StaticBody3D:bodies.push_front(node)
 for body in bodies:
  body.set_meta("forge_original_surface",body.get_meta("surface_material","concrete"))
  for c in body.find_children("*","CollisionShape3D",true,false):
   if c.shape==null:continue
   var vertices=shape_points(c.shape)
   var transform=node.global_transform.affine_inverse()*c.global_transform
   var local=PackedVector3Array()
   for v in vertices:local.append(transform*v)
   templates.append({"vertices":local,"concave":c.shape is ConcavePolygonShape3D,"surface":body.get_meta("surface_material","concrete")})
 var record={"node":node,"label":label,"kind":kind,"spec":spec.duplicate(true),"bounds":bounds,"materials":materials,"material":"original","templates":templates,"original_bodies":bodies,"baked":[],"proxy":null,"enabled":true if kind=="pickup" else node.visible,"initial":pose(node),"initial_light":light_data(node)}
 records[key]=record
 if kind!="added":originals[key]={"transform":pose(node),"visible":true,"material":"original","light":light_data(node),"mechanism":mechanism_data(node)}
 if templates.is_empty():record.proxy=make_proxy(node,bounds)
 if node is Light3D:
  if not node.has_meta("forge_shadow_preference"):node.set_meta("forge_shadow_preference",node.shadow_enabled or node==arena.sun or (node is SpotLight3D and node in arena.interior_shadow_lights))
  arena.forge_lights.append(node)
  for old in node.find_children("ForgeLightIcon","MeshInstance3D",true,false):old.get_parent().remove_child(old);old.free()
  var icon=MeshInstance3D.new();icon.name="ForgeLightIcon";var sphere=SphereMesh.new();sphere.radius=.15;sphere.height=.3;icon.mesh=sphere;node.add_child(icon)
  var m=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=node.light_color;icon.material_override=m;record.icon=icon
func visuals(node: Node3D) -> Array:
 var all=[]
 if node is MeshInstance3D or node is MultiMeshInstance3D:all.append(node)
 for c in node.find_children("*","VisualInstance3D",true,false):
  if c is MeshInstance3D or c is MultiMeshInstance3D:all.append(c)
 return all
func local_bounds(node: Node3D) -> AABB:
 var box=AABB();var first=true
 for m in visuals(node):
  var b=node.global_transform.affine_inverse()*m.global_transform*m.get_aabb()
  box=b if first else box.merge(b);first=false
 return AABB(Vector3(-.25,-.25,-.25),Vector3.ONE*.5) if first else box
func shape_points(shape: Shape3D) -> PackedVector3Array:
 if shape is ConvexPolygonShape3D:return shape.points
 if shape is ConcavePolygonShape3D:return shape.get_faces()
 if shape is BoxShape3D:
  var result=PackedVector3Array()
  for i in range(8):result.append(Vector3(1 if i&1 else -1,1 if i&2 else -1,1 if i&4 else -1)*shape.size*.5)
  return result
 var mesh=shape.get_debug_mesh();var result=PackedVector3Array()
 for surface in range(mesh.get_surface_count()):result.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
 return result
func make_proxy(node: Node3D,bounds: AABB) -> Area3D:
 var a=Area3D.new();a.name="ForgePickProxy";a.collision_layer=PICK_LAYER;a.collision_mask=0;a.monitoring=false;node.add_child(a)
 var c=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=bounds.size.max(Vector3.ONE*.2);c.shape=shape;c.position=bounds.get_center();a.add_child(c);return a
func set_editor_visible(on: bool,mode: int=-1) -> void:
 editor_visible=on
 if mode>=0:editor_mode=mode
 if on:clear_runtime_batches()
 for record in records.values():
  if is_instance_valid(record.proxy):record.proxy.collision_layer=PICK_LAYER if on and record.node.visible else 0
  if record.kind=="pickup" or record.spec.get("type","") in ["weapon","powerup"]:record.node.visible=on and record.get("enabled",true)
  if record.has("icon"):record.icon.visible=on and record.get("enabled",true)
 for i in [0,1]:
  var deposit=arena.deposits[i]
  if on and editor_mode in [0,4]:
   arena.sites[i]=v3(points[str(editor_mode)].bombs[i]);deposit.global_position=arena.sites[i];arena.deposit_labels[i].global_position=arena.sites[i]+Vector3.UP*3;deposit.set_meta("forge_marker","point:%d:bomb:0:%d"%[editor_mode,i])
  elif deposit.has_meta("forge_marker"):deposit.remove_meta("forge_marker")
 for key in markers:
  var m=markers[key];m.visible=on and (mode<0 or int(key.get_slice(":",1))==mode)
  m.get_node("ForgePickProxy").collision_layer=PICK_LAYER if m.visible else 0
func make_marker(key: String,pos: Vector3,label: String,color: Color) -> void:
 var n=Node3D.new();n.name="ForgeMarker";n.set_meta("forge_marker",key);content.add_child(n);n.position=pos
 var mat=arena.kit.material(color);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 arena.kit.sphere(n,Vector3(0,.35,0),.25,mat);arena.kit.cylinder(n,Vector3(0,.04,0),.45,.08,mat)
 var text=arena.kit.label(n,Vector3(0,.9,0),label,color,22);text.no_depth_test=false
 make_proxy(n,AABB(Vector3(-.45,0,-.45),Vector3(.9,1.2,.9)));markers[key]=n
func rebuild_markers() -> void:
 for n in markers.values():content.remove_child(n);n.queue_free()
 markers.clear()
 for mode in range(5):
  var data=points[str(mode)]
  for team in [0,1]:
   for i in range(data.spawns[str(team)].size()):make_marker("point:%d:spawn:%d:%d"%[mode,team,i],v3(data.spawns[str(team)][i]),"SPAWN %s%d"%["A" if team==0 else "B",i+1],Color("8cdaa4") if team==0 else Color("f07979"))
  if mode in [0,4]:
   for i in range(2):make_marker("point:%d:bomb:0:%d"%[mode,i],v3(data.bombs[i]),"SITE "+("A" if i==0 else "B"),Color("efc86a"))
  if mode==3:
   for i in range(2):make_marker("point:%d:flag:%d:%d"%[mode,i,i],v3(data.flags[i]),"FLAG "+("A" if i==0 else "B"),Color("8cdaa4") if i==0 else Color("f07979"))
 set_editor_visible(editor_visible)
func node_for(key: String) -> Node3D:
 return markers.get(key) if key.begins_with("point:") else records.get(key,{}).get("node")
func label_for(key: String) -> String:
 return String(records[key].label) if records.has(key) else key.replace(":"," · ")
func pose(node: Node3D) -> Dictionary:
 return {"p":vec(node.global_position),"r":vec(node.global_rotation),"s":vec(node.global_basis.get_scale())}
func set_pose(key: String,t: Dictionary) -> void:
 var record=records[key];var node: Node3D=record.node
 # Bake collision in world space instead of nonuniformly scaling physics bodies.
 for body in record.original_bodies:
  if is_instance_valid(body):body.get_parent().remove_child(body);body.free()
 record.original_bodies.clear()
 node.global_transform=Transform3D(Basis.from_euler(v3(t.r))*Basis.from_scale(v3(t.s)),v3(t.p));node.reset_physics_interpolation()
 rebuild_collision(key)
func rebuild_collision(key: String) -> void:
 var record=records[key]
 for b in record.baked:
  if is_instance_valid(b):collisions.remove_child(b);b.queue_free()
 record.baked.clear()
 if not record.node.visible:return
 for template in record.templates:
  var vertices=PackedVector3Array()
  for v in template.vertices:vertices.append(record.node.global_transform*v)
  if vertices.size()<4:continue
  var shape: Shape3D
  if template.concave:shape=ConcavePolygonShape3D.new();shape.set_faces(vertices)
  else:shape=ConvexPolygonShape3D.new();shape.points=vertices
  var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=2;body.set_meta("forge_owner",key);body.set_meta("surface_material",template.surface);body.set_meta("forge_original_surface",template.surface);collisions.add_child(body)
  var c=CollisionShape3D.new();c.shape=shape;body.add_child(c);record.baked.append(body)
func dimensions(key: String) -> Vector3:
 var record=records[key];return record.bounds.size*record.node.global_basis.get_scale()
func set_visible(key: String,on: bool) -> void:
 var record=records[key];record.node.visible=on;record.enabled=on
 for body in record.original_bodies:
  if is_instance_valid(body):body.collision_layer=1 if on else 0
 for body in record.baked:
  if is_instance_valid(body):body.collision_layer=1 if on else 0
 if is_instance_valid(record.proxy):record.proxy.collision_layer=PICK_LAYER if editor_visible and on else 0
 if on and not record.templates.is_empty() and record.original_bodies.is_empty() and record.baked.is_empty():rebuild_collision(key)
func material_for(id: String) -> Material:
 if material_cache.has(id):return material_cache[id]
 var k=arena.kit;var mat: Material
 match id:
  "stone":mat=k.stone
  "gold":mat=k.gold
  "dark_metal":mat=k.dark
  "naki_green":mat=k.material(Color("435e45"),.3)
  "annu_red":mat=k.material(Color("79333a"),.3)
  "white":mat=k.material(Color("dfdfd6"),.2)
  "bronze":mat=k.material(Color("ad7440"),.65)
  "glass":
   var glass=k.material(Color(.35,.7,.85,.28));glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cull_mode=BaseMaterial3D.CULL_DISABLED;mat=glass
 material_cache[id]=mat;return mat
func set_material(key: String,id: String) -> void:
 var record=records[key]
 if record.material==id:return
 record.material=id
 for item in record.materials:
  if is_instance_valid(item.node):item.node.material_override=item.material if id=="original" else material_for(id)
 var surface="glass" if id=="glass" else "metal" if id in ["gold","dark_metal","bronze"] else "concrete"
 for body in record.original_bodies+record.baked:
  if is_instance_valid(body):body.set_meta("surface_material",surface if id!="original" else body.get_meta("forge_original_surface","concrete"))
func light_data(node: Node3D) -> Dictionary:
 if not node is Light3D:return {}
 return {"color":[node.light_color.r,node.light_color.g,node.light_color.b],"energy":node.light_energy,"range":node.omni_range if node is OmniLight3D else node.spot_range if node is SpotLight3D else 20.0,"angle":node.spot_angle if node is SpotLight3D else 45.0,"shadows":bool(node.get_meta("forge_shadow_preference",node.shadow_enabled))}
func set_light(key: String,data: Dictionary) -> void:
 var n=records[key].node
 if not n is Light3D or data.is_empty():return
 n.light_color=Color(data.color[0],data.color[1],data.color[2]);n.light_energy=data.energy;n.set_meta("forge_shadow_preference",data.shadows);n.shadow_enabled=data.shadows and NestGraphicsQuality.shadows_enabled(game.prefs.values)
 if n is OmniLight3D:n.omni_range=data.range
 if n is SpotLight3D:n.spot_range=data.range;n.spot_angle=data.angle
 if records[key].has("icon"):records[key].icon.material_override.albedo_color=n.light_color
func create_item(spec: Dictionary,id: String="") -> String:
 if added_order.size()>=MAX_ADDED:return ""
 if spec.get("type")=="light" or (spec.get("type")=="copy" and records.get(spec.get("source"),{}).get("node") is Light3D):
  var count=0
  for key in added_order:
   if records[key].node is Light3D:count+=1
  if count>=16:return ""
 if id.is_empty():id="added_%d"%next_id;next_id+=1
 var node: Node3D
 if spec.type=="copy":
  var source=records[spec.source];node=source.node.duplicate();content.add_child(node)
  for child in node.find_children("ForgePickProxy","Area3D",true,false):child.get_parent().remove_child(child);child.free()
 elif spec.type=="light":
  node=OmniLight3D.new() if spec.kind=="point" else SpotLight3D.new();content.add_child(node);node.light_energy=1;node.shadow_enabled=false
 else:
  node=Node3D.new();content.add_child(node)
  if spec.type=="weapon":
   var art=NestWeaponArt.create(spec.kind,0);art.position.y=.8;node.add_child(art)
  elif spec.type=="powerup":
   var color=Color(.2,.9,.4,.58) if spec.kind=="overshield" else Color(.13,.48,1.0,.58)
   var mat=arena.kit.material(color);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=.55;arena.kit.sphere(node,Vector3(0,.9,0),.72,mat)
  else:
   var k=arena.kit
   match spec.kind:
    "wall":k.box(node,Vector3(0,1.5,0),Vector3(5,3,.5),k.stone,true)
    "cover":k.box(node,Vector3(0,.6,0),Vector3(3,1.2,1.2),k.stone,true)
    "glass":k.box(node,Vector3(0,1.5,0),Vector3(4,3,.2),material_for("glass"),true)
    "ramp":
     var ramp=Node3D.new();node.add_child(ramp);ramp.position.y=1;ramp.rotation.x=-atan2(2.0,6.0);k.box(ramp,Vector3(0,-.15,0),Vector3(4,.3,sqrt(40.0)),k.stone,true)
    "block":k.box(node,Vector3(0,1,0),Vector3(2,2,2),k.stone,true)
    "column":k.cylinder(node,Vector3(0,2,0),.6,4,k.stone,true)
    "platform":k.box(node,Vector3.ZERO,Vector3(5,.5,5),k.stone,true)
 var title=NestWeaponCatalog.profile(spec.kind).title if spec.type=="weapon" else label_for(spec.source)+" copy" if spec.type=="copy" else spec.kind.capitalize()+" "+spec.type
 node.visible=true
 register_piece(id,node,title,"added",{"type":spec.type,"source":spec.source} if spec.type=="copy" else {"type":spec.type,"kind":spec.kind});added_order.append(id)
 if spec.type=="copy":
  records[id].templates=records[spec.source].templates.duplicate(true);set_material(id,records[spec.source].material)
  if node is Light3D:set_light(id,light_data(records[spec.source].node))
 return id
func delete_item(key: String) -> void:
 if not records.has(key):return
 if key in originals:set_visible(key,false);return
 var record=records[key]
 for body in record.baked:
  if is_instance_valid(body):collisions.remove_child(body);body.queue_free()
 if record.node is Light3D:arena.forge_lights.erase(record.node)
 record.node.get_parent().remove_child(record.node);record.node.queue_free();records.erase(key);added_order.erase(key)
func capture() -> Dictionary:
 var base=[];var items=[]
 for key in originals:
  var record=records[key];base.append({"key":key,"transform":pose(record.node),"visible":record.get("enabled",record.node.visible),"material":record.material,"light":light_data(record.node),"baked":not record.templates.is_empty() and record.original_bodies.is_empty(),"mechanism":mechanism_data(record.node)})
 for key in added_order:
  var record=records[key];var item=record.spec.duplicate(true);item.id=key;item.transform=pose(record.node);item.visible=record.get("enabled",record.node.visible);item.material=record.material;item.light=light_data(record.node);item.mechanism=mechanism_data(record.node);item.baked=not record.templates.is_empty() and record.original_bodies.is_empty();items.append(item)
 return {"format":FORMAT,"version":2,"map":map_id(),"base":base,"added":items,"points":points.duplicate(true)}
static func vec(v: Vector3) -> Array:return [v.x,v.y,v.z]
static func v3(a) -> Vector3:return Vector3(float(a[0]),float(a[1]),float(a[2]))
static func valid_vec(v,limit: float=250) -> bool:
 if not v is Array or v.size()!=3:return false
 for x in v:
  if typeof(x) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(x)) or absf(float(x))>limit:return false
 return true
static func valid_pose(t) -> bool:
 if not t is Dictionary:return false
 for key in ["p","r","s"]:
  if not valid_vec(t.get(key)):return false
 for x in t.s:
  if float(x)<.02 or float(x)>20:return false
 return true
static func valid_light(d) -> bool:
 if not d is Dictionary:return false
 if d.is_empty():return true
 if not valid_vec(d.get("color"),1):return false
 for x in d.color:
  if x<0:return false
 for key in ["energy","range","angle"]:
  var x=d.get(key)
  if typeof(x) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(x)):return false
 return d.energy>=0 and d.energy<=8 and d.range>=.5 and d.range<=60 and d.angle>=5 and d.angle<=85 and d.get("shadows") is bool
func validate(state) -> bool:
 if not state is Dictionary or state.get("format")!=FORMAT or state.get("version")!=2 or state.get("map")!=map_id():return false
 if not state.get("base") is Array or not state.get("added") is Array or state.base.size()!=originals.size() or state.added.size()>MAX_ADDED:return false
 var keys={}
 var added_lights=0
 for item in state.base:
  if not valid_record(item) or not originals.has(item.get("key")) or keys.has(item.key):return false
  keys[item.key]=true
 for item in state.added:
  if not valid_record(item) or not item.get("id") is String or not item.id.begins_with("added_") or keys.has(item.id):return false
  var number=item.id.trim_prefix("added_")
  if not number.is_valid_int() or int(number)<1 or int(number)>1000000:return false
  keys[item.id]=true
  if not valid_spec(item,keys):return false
  if item.type=="light" or (item.type=="copy" and records[item.source].node is Light3D):added_lights+=1
  if added_lights>16:return false
 if not state.get("points") is Dictionary or state.points.size()!=5:return false
 for mode in range(5):
  var d=state.points.get(str(mode))
  if not d is Dictionary or not d.get("spawns") is Dictionary:return false
  for team in ["0","1"]:
   var s=d.spawns.get(team)
   if not s is Array or s.is_empty() or s.size()>32:return false
   for p in s:
    if not valid_vec(p):return false
  for key in ["bombs","flags"]:
   if not d.get(key) is Array or d[key].size()!=2:return false
   for p in d[key]:
    if not valid_vec(p):return false
 return true
func valid_record(item) -> bool:
 return item is Dictionary and valid_pose(item.get("transform")) and item.get("visible") is bool and item.get("material") in MATERIALS and valid_light(item.get("light")) and item.get("baked",false) is bool and valid_mechanism(item.get("mechanism",{}))
func valid_spec(spec,available: Dictionary={}) -> bool:
 if not spec is Dictionary:return false
 match spec.get("type",""):
  "weapon":return spec.get("kind") is String and not NestWeaponCatalog.for_kind(spec.kind).is_empty() and NestWeaponCatalog.for_kind(spec.kind).get("slot","") in ["primary","secondary"]
  "powerup":return spec.get("kind") in ["cloak","overshield"]
  "structure":return spec.get("kind") in STRUCTURES
  "light":return spec.get("kind") in ["point","spot"]
  "copy":return spec.get("source") is String and originals.has(spec.source) and records[spec.source].kind!="mechanism" and spec.source!=spec.get("id","")
 return false
func upgrade_legacy(state) -> Dictionary:
 if not state is Dictionary:return {}
 if state.get("version")==2:return state
 if state.get("format")!=FORMAT or state.get("version")!=1 or state.get("map")!="sanctuary-v20-forge1" or not state.get("base") is Array or not state.get("added") is Array:return {}
 var result={"format":FORMAT,"version":2,"map":map_id(),"base":[],"added":[],"points":default_points.duplicate(true)}
 var by_key={}
 for key in originals:
  var item=originals[key].duplicate(true);item.key=key;by_key[key]=item
 var seen={}
 for item in state.base:
  if not item is Dictionary or not by_key.has(item.get("key")) or seen.has(item.key) or not valid_pose(item.get("transform")) or not item.get("visible") is bool:return {}
  seen[item.key]=true;by_key[item.key].transform=item.transform;by_key[item.key].visible=item.visible
 for key in by_key:result.base.append(by_key[key])
 for original in state.added:
  if not original is Dictionary:return {}
  var item=original.duplicate(true);item.visible=true;item.material="original";item.light={};result.added.append(item)
 return result
func restore(state: Dictionary) -> void:
 clear_runtime_batches()
 var wanted={}
 for item in state.added:wanted[item.id]=true
 for key in added_order.duplicate():
  if not wanted.has(key):delete_item(key)
 for item in state.base:
  var record=records[item.key]
  if pose(record.node)!=item.transform or (item.get("baked",false) and not record.original_bodies.is_empty()):set_pose(item.key,item.transform)
  set_visible(item.key,item.visible);set_material(item.key,item.material);set_light(item.key,item.light);set_mechanism(item.key,item.get("mechanism",{}))
 for item in state.added:
  var id=String(item.id)
  var spec={"type":item.type,"source":item.source} if item.type=="copy" else {"type":item.type,"kind":item.kind}
  if records.has(id) and records[id].spec!=spec:delete_item(id)
  if not records.has(id):create_item(item,id)
  if pose(records[id].node)!=item.transform or (item.get("baked",false) and not records[id].original_bodies.is_empty()):set_pose(id,item.transform)
  set_visible(id,item.visible);set_material(id,item.material);set_light(id,item.light);set_mechanism(id,item.get("mechanism",{}))
  next_id=maxi(next_id,int(item.id.trim_prefix("added_"))+1)
 added_order.assign(state.added.map(func(item):return String(item.id)))
 if points!=state.points:points=state.points.duplicate(true);rebuild_markers()
func apply_mode(mode: int) -> void:
 var d=points[str(mode)]
 for team in [0,1]:
  arena.spawns[team]=[]
  for p in d.spawns[str(team)]:arena.spawns[team].append(v3(p))
 for i in range(2):
  arena.sites[i]=v3(d.bombs[i]);arena.deposits[i].global_position=arena.sites[i];arena.deposit_labels[i].global_position=arena.sites[i]+Vector3(0,3,0)
 game.flag_bases.assign([v3(d.flags[0]),v3(d.flags[1])])
 if game.flag_nodes.size()==2:
  for i in [0,1]:game.flag_nodes[i].base.global_position=game.flag_bases[i]+Vector3(0,.03,0)
 arena.pads.clear();arena.pad_kinds.clear();arena.pad_names.clear();arena.pad_meshes.clear()
 for item in initial_pads:
  var record=records[item.key]
  if not record.get("enabled",true):continue
  arena.pads.append(record.node.global_position);arena.pad_kinds.append(item.kind);arena.pad_names.append(item.label);arena.pad_meshes.append(record.node)
 for key in added_order:
  var record=records[key]
  if record.spec.type not in ["weapon","powerup"] or not record.get("enabled",true):continue
  arena.pads.append(record.node.global_position);arena.pad_kinds.append(record.spec.kind);arena.pad_names.append(record.label);arena.pad_meshes.append(record.node)
 arena.cannon_routes.clear()
 for key in records:
  var record=records[key]
  if record.node is NestManCannon and record.get("enabled",true):
   var i=int(record.spec.get("route_index",-1))
   if i>=0 and i<initial_routes.size():
    var route=initial_routes[i].duplicate(true);route.start=record.node.global_position;route.end=record.node.get_parent().to_global(record.node.destination);arena.cannon_routes.append(route)
 set_editor_visible(false)
 prepare_runtime_batches()
func point_move(key: String,pos: Vector3) -> bool:
 var mode=key.get_slice(":",1);var type=key.get_slice(":",2);var team=key.get_slice(":",3);var index=int(key.get_slice(":",4))
 if not markers.has(key):return false
 if type=="spawn":points[mode].spawns[team][index]=vec(pos)
 elif type=="bomb":points[mode].bombs[index]=vec(pos)
 else:points[mode].flags[index]=vec(pos)
 markers[key].position=pos
 if editor_visible and type=="bomb" and int(mode)==editor_mode:
  arena.sites[index]=pos;arena.deposits[index].global_position=pos;arena.deposit_labels[index].global_position=pos+Vector3.UP*3
 return true
func destroy() -> void:
 clear_runtime_batches()
 for n in [content,collisions]:
  if is_instance_valid(n):game.remove_child(n);n.queue_free()

func clear_runtime_batches() -> void:
 for entry in batched_visuals:
  if is_instance_valid(entry.node):entry.node.visible=entry.visible
 batched_visuals.clear()
 if is_instance_valid(runtime_batches):game.remove_child(runtime_batches);runtime_batches.queue_free()
 runtime_batches=null
func prepare_runtime_batches() -> void:
 if is_instance_valid(runtime_batches):return
 var groups={};var merged=0
 for root in [arena,content]:
  for mesh in root.find_children("*","MeshInstance3D",true,false):
   if mesh.mesh==null or mesh.skin!=null or not mesh.is_visible_in_tree() or mesh.name=="ForgeLightIcon":continue
   var material=mesh.material_override
   if material!=arena.kit.stone and not material is StandardMaterial3D:continue
   if material is StandardMaterial3D and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
   var parent=mesh.get_parent();var dynamic=false
   while parent!=null and parent!=game:
    if parent is AnimatableBody3D or parent in arena.deposits or parent.has_meta("forge_marker"):dynamic=true;break
    var key=String(parent.get_meta("forge_key",""))
    if records.has(key) and (records[key].kind=="pickup" or records[key].spec.get("type","") in ["weapon","powerup"]):dynamic=true;break
    parent=parent.get_parent()
   if dynamic:continue
   var transform=game.global_transform.affine_inverse()*mesh.global_transform;var pos=transform.origin
   var key="%d:%d:%d:%d:%d"%[material.get_instance_id(),floori(pos.x/16),floori(pos.y/8),floori(pos.z/16),mesh.cast_shadow]
   if not groups.has(key):
    var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_material(material);groups[key]={"tool":tool,"shadow":mesh.cast_shadow}
   for i in range(mesh.mesh.get_surface_count()):groups[key].tool.append_from(mesh.mesh,i,transform)
   batched_visuals.append({"node":mesh,"visible":mesh.visible});mesh.visible=false;merged+=1
 runtime_batches=Node3D.new();runtime_batches.name="ForgeRuntimeBatches";game.add_child(runtime_batches)
 for group in groups.values():
  var mesh=MeshInstance3D.new();mesh.mesh=group.tool.commit();mesh.cast_shadow=group.shadow;runtime_batches.add_child(mesh)
 batch_stats={"source_meshes":merged,"batches":groups.size()}

func mechanism_data(node: Node3D) -> Dictionary:
 if node is NestManCannon:return {"target":vec(node.get_parent().to_global(node.destination)),"flight":node.flight_seconds}
 return {}
static func valid_mechanism(data) -> bool:
 if not data is Dictionary:return false
 if data.is_empty():return true
 return valid_vec(data.get("target")) and typeof(data.get("flight")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(data.flight)) and data.flight>=.5 and data.flight<=6
func set_mechanism(key: String,data: Dictionary) -> void:
 if data.is_empty() or not records[key].node is NestManCannon:return
 var n=records[key].node;n.destination=n.get_parent().to_local(v3(data.target));n.flight_seconds=data.flight
