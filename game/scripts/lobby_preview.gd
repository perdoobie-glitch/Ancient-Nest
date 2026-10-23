class_name NestLobbyPreview
extends SubViewportContainer
var game
var viewport: SubViewport
var pivots: Array[Node3D]=[]
var characters: Array[int]=[]
var camera: Camera3D
var left_held: bool=false
var right_held: bool=false
var dragging: bool=false
func _ready() -> void:
 custom_minimum_size=Vector2(245,270);stretch=true;mouse_filter=Control.MOUSE_FILTER_STOP
 viewport=SubViewport.new();viewport.size=Vector2i(490,540);viewport.own_world_3d=true;viewport.handle_input_locally=false;add_child(viewport)
 var world=Node3D.new();viewport.add_child(world)
 var env=WorldEnvironment.new();var settings=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("101f27");settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("dbe6ef");settings.ambient_light_energy=.5;env.environment=settings;world.add_child(env)
 for spec in [[Vector3(-35,-35,0),1.1,Color("fff0d5")],[Vector3(-25,140,0),.6,Color("8fcaff")]]:
  var light=DirectionalLight3D.new();light.rotation_degrees=spec[0];light.light_energy=spec[1];light.light_color=spec[2];world.add_child(light)
 camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1.15,-4.2);camera.look_at(Vector3(0,.95,0));camera.fov=37
 for team in [0,1]:
  var pivot=Node3D.new();pivot.position.x=.62 if team==0 else -.62; pivot.rotation.y=game.lobby_preview_yaw;world.add_child(pivot);pivots.append(pivot)
  var pedestal=MeshInstance3D.new();var cylinder=CylinderMesh.new();cylinder.top_radius=.48;cylinder.bottom_radius=.5;cylinder.height=.07;pedestal.mesh=cylinder
  var material=StandardMaterial3D.new();material.albedo_color=Color("284454") if team==0 else Color("685b39");material.metallic=.35;pedestal.material_override=material;pedestal.position=Vector3(pivot.position.x,-.04,0);world.add_child(pedestal)
  var label=Label3D.new();label.name="TeamLabel%d"%team;label.text="TEAM "+("A" if team==0 else "B");label.position=Vector3(pivot.position.x,2.08,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=36;label.pixel_size=.003;world.add_child(label)
 var vs=Label3D.new();vs.text="VS";vs.position=Vector3(0,1.0,-.1);vs.billboard=BaseMaterial3D.BILLBOARD_ENABLED;vs.font_size=42;vs.pixel_size=.003;world.add_child(vs)
 show_matchup()
func strip_gameplay(node: Node) -> void:
 for child in node.get_children():
  if child is CollisionObject3D or child is CollisionShape3D or child is Camera3D:
   node.remove_child(child);child.queue_free();continue
  strip_gameplay(child)
 if node.get_script()!=null:node.set_script(null)
func show_matchup() -> void:
 if viewport==null:return
 var pop=game.last_preview_matchup!=game.matchup;game.last_preview_matchup=game.matchup
 characters.assign(game.MATCHUPS[game.matchup])
 for team in [0,1]:
  for child in pivots[team].get_children():pivots[team].remove_child(child);child.queue_free()
  var spec=NestCharacterCatalog.by_index(characters[team]);var scene=load(spec.visual) as PackedScene
  if scene==null:continue
  var model=scene.instantiate();strip_gameplay(model);pivots[team].add_child(model);NestReferenceGear.apply_trim(model,characters[team])
  viewport.get_child(0).get_node("TeamLabel%d"%team).text="TEAM "+("A" if team==0 else "B")+" · "+String(spec.name).to_upper()
  var meshes=model.find_children("*","GeometryInstance3D",true,false)
  for mesh in meshes:mesh.transparency=0.0;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  if pop:
   var tween=create_tween().set_parallel(true);model.scale=Vector3.ONE*.8;tween.tween_property(model,"scale",Vector3.ONE,.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
   var restores=[]
   # Instance transparency is ignored by Compatibility; fade cloned materials.
   for mesh in meshes:
    if not mesh is MeshInstance3D:continue
    for surface in range(mesh.mesh.get_surface_count()):
     var original=mesh.get_active_material(surface)
     if not original is BaseMaterial3D:continue
     var material=original.duplicate() as BaseMaterial3D;var mode=material.transparency;var alpha=material.albedo_color.a
     material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color.a=0.0;mesh.set_surface_override_material(surface,material)
     tween.tween_property(material,"albedo_color:a",alpha,.25)
     restores.append({"material":material,"mode":mode})
   tween.finished.connect(restore_materials.bind(restores))
  for animator in model.find_children("*","AnimationPlayer",true,false):
   for clip in animator.get_animation_list():
    if String(clip).ends_with("idle"):animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR;animator.play(clip);break
func can_rotate() -> bool:
 if not is_instance_valid(game) or game.current_screen!="lobby" or not is_visible_in_tree() or not game.input_window_focused:return false
 if is_instance_valid(game.game_type_editor) and game.game_type_editor.visible:return false
 if is_instance_valid(game.modal) and game.modal.visible:return false
 var focused=get_viewport().gui_get_focus_owner()
 if focused is LineEdit or focused is TextEdit or focused is SpinBox:return false
 if focused is OptionButton and focused.get_popup().visible:return false
 return true
func turn(amount: float) -> void:
 for pivot in pivots:pivot.rotation.y+=amount
func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.keycode in [KEY_LEFT,KEY_RIGHT]:
  if not event.pressed:
   if event.keycode==KEY_LEFT:left_held=false
   else:right_held=false
  if not can_rotate():return
  if event.keycode==KEY_LEFT:left_held=event.pressed
  else:right_held=event.pressed
  get_viewport().set_input_as_handled()
func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
 if event is InputEventMouseMotion and dragging and can_rotate():turn(event.relative.x*.01);accept_event()
func _process(delta: float) -> void:
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
 if can_rotate():turn(deg_to_rad(120)*delta*((1 if right_held else 0)-(1 if left_held else 0)))
 else:left_held=false;right_held=false;dragging=false

func restore_materials(items: Array) -> void:
 for item in items:item.material.transparency=item.mode
