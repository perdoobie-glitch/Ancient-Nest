extends Node3D
var game
var editing=false
var testing: bool:
 get:return game.forge_session.testing
var camera: Camera3D
var ui: Control
var panel: PanelContainer
var toolbar: GridContainer
var status: Label
var selected_label: Label
var transform_label: Label
var picker: OptionButton
var structures: OptionButton
var object_list: OptionButton
var mode_picker: OptionButton
var team_picker: OptionButton
var material_picker: OptionButton
var light_color: ColorPickerButton
var light_energy: SpinBox
var light_range: SpinBox
var light_angle: SpinBox
var mechanism_controls: VBoxContainer
var target_fields=[]
var flight_time: SpinBox
var light_controls: VBoxContainer
var material_controls: VBoxContainer
var light_shadows: CheckButton
var inspector_snapshot={}
var position_fields=[]
var rotation_fields=[]
var size_fields=[]
var selected_key=""
var clipboard={}
var clipboard_pose={}
var moving=false
var ghost: Node3D
var selected: Node3D:
 get:return game.forge_session.model.node_for(selected_key) if game.forge_session.model!=null else null
var step_size=.5
var drag_distance=12.0
var snap_toggle: CheckButton
var object_filter: LineEdit
var outline: MeshInstance3D
var last_view_size=Vector2.ZERO
var edit_mode=0
var last_roster_signature=""
var roster: VBoxContainer
func open_editor() -> void:
 editing=true;edit_mode=game.mode
 camera=Camera3D.new();camera.name="ForgeCamera";camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;add_child(camera);camera.position=Vector3(23,16,14);camera.look_at(Vector3(29,13,6));camera.fov=75;camera.current=true
 outline=MeshInstance3D.new();add_child(outline);outline.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("f4d181");outline.material_override=mat
 game.current_screen="forge";game.context="forge";game.clear_screen();game.hud.visible=false;game.menu_camera.current=false;build_ui();game.forge_session.model.set_editor_visible(true,edit_mode);release_mouse()
 tell("Shared Nest Forge · edits are validated by the host. Select from the world or searchable list.")
func small_button(parent: Node,text: String,action: Callable,name: String="") -> Button:
 var b=Button.new();b.text=text;b.custom_minimum_size.y=30;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.pressed.connect(action)
 if name!="":b.name=name
 parent.add_child(b);return b
func heading(parent: Node,text: String) -> void:parent.add_child(game.label(text,12,game.GOLD))
func number(parent: Node,min_value: float,max_value: float,value: float,step: float=.1) -> SpinBox:
 var n=SpinBox.new();n.min_value=min_value;n.max_value=max_value;n.step=step;n.value=value;n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;n.custom_minimum_size.x=70;n.add_theme_font_size_override("font_size",14);n.get_line_edit().add_theme_font_size_override("font_size",14);parent.add_child(n);return n
func axis_row(parent: Node,label: String,min_value: float,max_value: float) -> Array:
 heading(parent,label);var grid=GridContainer.new();grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(grid);var fields=[]
 for axis in ["X","Y","Z"]:grid.add_child(game.label(axis,11));fields.append(number(grid,min_value,max_value,0,1.0 if label.begins_with("ROTATION") else .01))
 return fields
func build_ui() -> void:
 ui=Control.new();ui.name="ForgeUI";ui.theme=game.make_theme();ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.screen.add_child(ui);ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for type in ["Button","OptionButton","CheckButton"]:
  ui.theme.set_font_size("font_size",type,13)
  for state in ["normal","hover","pressed","focus","disabled"]:
   var style=ui.theme.get_stylebox(state,type).duplicate();style.content_margin_left=7;style.content_margin_right=7;style.content_margin_top=5;style.content_margin_bottom=5;ui.theme.set_stylebox(state,type,style)
 panel=PanelContainer.new();panel.name="ForgePanel";ui.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE);panel.offset_left=12;panel.offset_right=348;panel.offset_top=12;panel.offset_bottom=-12
 var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
 var box=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",7);scroll.add_child(box)
 box.add_child(game.title("NEST FORGE · v"+String(ProjectSettings.get_setting("application/config/version")).get_slice("-",0).trim_suffix(".0"),26));heading(box,"RMB + WASD: fly · Q/E: down/up · F: frame")
 var hint=game.label("Left click selects / places · Esc cancels grab\nTransforms apply once when you click Apply.",11);box.add_child(hint)
 var tabs=TabContainer.new();tabs.name="ForgeInspectorTabs";tabs.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_child(tabs)
 var objects=VBoxContainer.new();objects.name="Objects";tabs.add_child(objects)
 heading(objects,"WEAPON SPAWNS");picker=OptionButton.new();picker.name="ForgeWeapons";picker.fit_to_longest_item=false
 for item in NestWeaponCatalog.data().weapons:
  if item.get("slot","") in ["primary","secondary"]:picker.add_item(item.title);picker.set_item_metadata(picker.item_count-1,item.kind)
 objects.add_child(picker);small_button(objects,"Spawn Weapon",func():spawn_item({"type":"weapon","kind":picker.get_selected_metadata()}),"ForgeSpawnWeapon")
 heading(objects,"POWERUPS");var powerups=OptionButton.new();powerups.add_item("Shield");powerups.add_item("Active camouflage");objects.add_child(powerups)
 small_button(objects,"Spawn Powerup",func():spawn_item({"type":"powerup","kind":"overshield" if powerups.selected==0 else "cloak"}),"ForgeSpawnPowerup")
 heading(objects,"STRUCTURES");structures=OptionButton.new();structures.fit_to_longest_item=false
 for kind in NestForgeMap.STRUCTURES:structures.add_item(kind.capitalize())
 objects.add_child(structures);small_button(objects,"Spawn Structure",func():spawn_item({"type":"structure","kind":NestForgeMap.STRUCTURES[structures.selected]}),"ForgeSpawnStructure")
 heading(objects,"LIGHTS");var lights=OptionButton.new();lights.add_item("Point light");lights.add_item("Spot light");objects.add_child(lights)
 small_button(objects,"Spawn Light",func():spawn_item({"type":"light","kind":"point" if lights.selected==0 else "spot"}),"ForgeSpawnLight")
 var inspector=VBoxContainer.new();inspector.name="Inspector";tabs.add_child(inspector)
 position_fields=axis_row(inspector,"POSITION (METERS)",-250,250);rotation_fields=axis_row(inspector,"ROTATION (DEGREES)",-180,180);size_fields=axis_row(inspector,"DIMENSIONS: WIDTH / HEIGHT / DEPTH",.02,160)
 small_button(inspector,"Apply Transform / Size",apply_inspector,"ForgeApplySize")
 material_controls=VBoxContainer.new();inspector.add_child(material_controls);heading(material_controls,"EXISTING SKIN / MATERIAL");material_picker=OptionButton.new();material_picker.name="ForgeMaterials";material_picker.fit_to_longest_item=false
 for name in ["Original appearance","Temple stone texture","Antique gold","Dark metal","Glass","Naki green","Annu red","White metal","Bronze"]:material_picker.add_item(name)
 material_controls.add_child(material_picker);small_button(material_controls,"Apply Material",func():command("material",{"key":selected_key,"material":NestForgeMap.MATERIALS[material_picker.selected]}),"ForgeApplyMaterial")
 light_controls=VBoxContainer.new();inspector.add_child(light_controls);heading(light_controls,"LIGHT PROPERTIES");light_color=ColorPickerButton.new();light_color.name="ForgeLightColor";light_color.color=Color.WHITE;light_controls.add_child(light_color)
 heading(light_controls,"Brightness");light_energy=number(light_controls,0,8,1);heading(light_controls,"Range (m)");light_range=number(light_controls,.5,60,10);heading(light_controls,"Spot angle (degrees)");light_angle=number(light_controls,5,85,45,1)
 light_shadows=CheckButton.new();light_shadows.text="Cast shadows";light_controls.add_child(light_shadows);small_button(light_controls,"Apply Light Properties",apply_light,"ForgeApplyLight")
 mechanism_controls=VBoxContainer.new();inspector.add_child(mechanism_controls);target_fields=axis_row(mechanism_controls,"LAUNCHER LANDING POINT",-250,250);heading(mechanism_controls,"FLIGHT TIME (SECONDS)");flight_time=number(mechanism_controls,.5,6,2.8,.1)
 small_button(mechanism_controls,"Apply Launcher Target",apply_mechanism,"ForgeApplyLauncher")
 var objectives=VBoxContainer.new();objectives.name="Objectives";tabs.add_child(objectives)
 heading(objectives,"EDIT MARKERS FOR MODE");mode_picker=OptionButton.new();mode_picker.name="ForgeObjectiveMode";mode_picker.fit_to_longest_item=false
 for name in game.MODE_NAMES:mode_picker.add_item(name)
 mode_picker.select(edit_mode);objectives.add_child(mode_picker);mode_picker.item_selected.connect(func(i):edit_mode=i;selected_key="";game.forge_session.model.set_editor_visible(true,edit_mode);refresh_list();refresh_selection())
 var help=game.label("Each mode keeps its own spawn locations.\nExtraction/CS: move A/B bomb sites.\nCTF: move both flag bases.\nRequired sites cannot be deleted.",12);help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;objectives.add_child(help)
 team_picker=OptionButton.new();team_picker.add_item("Team A / attackers");team_picker.add_item("Team B / defenders");objectives.add_child(team_picker)
 small_button(objectives,"Add Team Spawn at Crosshair",func():command("add_spawn",{"mode":edit_mode,"team":team_picker.selected,"position":NestForgeMap.vec(aim_position())}),"ForgeAddSpawn")
 small_button(objectives,"Use This Mode for Playtest",func():
  if game.is_client():tell("The host selects the playtest mode.");return
  var rules=game.game_type.duplicate_settings();rules.mode=edit_mode;game.apply_game_type_settings(rules);tell("Playtest mode: "+game.MODE_NAMES[edit_mode]))
 box.add_child(HSeparator.new());heading(box,"SELECT OBJECT OR OBJECTIVE")
 object_filter=LineEdit.new();object_filter.name="ForgeFilter";object_filter.placeholder_text="Search objects / lights / sites…";box.add_child(object_filter);object_filter.text_changed.connect(func(_s):refresh_list())
 object_list=OptionButton.new();object_list.name="ForgeObjectList";object_list.fit_to_longest_item=false;box.add_child(object_list);object_list.item_selected.connect(func(i):select_key(String(object_list.get_item_metadata(i))))
 selected_label=game.label("Nothing selected",13);box.add_child(selected_label);transform_label=game.label("",11);box.add_child(transform_label)
 small_button(box,"Frame Selection",frame_selection,"ForgeFrame")
 var copy=HBoxContainer.new();box.add_child(copy);small_button(copy,"Copy",copy_selected,"ForgeCopy");small_button(copy,"Paste",paste_copy,"ForgePaste")
 small_button(box,"Grab / Place",toggle_grab,"ForgeMove")
 var arrows=GridContainer.new();arrows.columns=3;box.add_child(arrows)
 for item in [["−X",Vector3.LEFT],["+Y",Vector3.UP],["+X",Vector3.RIGHT],["−Z",Vector3.FORWARD],["−Y",Vector3.DOWN],["+Z",Vector3.BACK]]:
  var direction: Vector3=item[1];small_button(arrows,item[0],func():nudge(direction))
 var rotation=HBoxContainer.new();box.add_child(rotation);small_button(rotation,"Turn −15°",func():turn_piece(-15));small_button(rotation,"Turn +15°",func():turn_piece(15))
 snap_toggle=CheckButton.new();snap_toggle.text="Snap movement to 0.5 m";snap_toggle.button_pressed=true;box.add_child(snap_toggle)
 var actions=HBoxContainer.new();box.add_child(actions);small_button(actions,"Delete",delete_selected,"ForgeDelete");var undo=small_button(actions,"Undo",func():command("undo"),"ForgeUndo");undo.disabled=game.is_client()
 toolbar=GridContainer.new();toolbar.columns=4;ui.add_child(toolbar);toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);toolbar.offset_left=360;toolbar.offset_right=-12;toolbar.offset_top=12
 small_button(toolbar,"Save Layout",save_layout,"ForgeSave");var load=small_button(toolbar,"Load Layout",load_layout,"ForgeLoad");load.disabled=game.is_client()
 var test=small_button(toolbar,"Playtest",start_test,"ForgePlaytest");test.disabled=game.is_client();small_button(toolbar,"Return to Lobby",request_exit,"ForgeExit")
 small_button(toolbar,"Grab / Place",toggle_grab,"ToolbarGrab");small_button(toolbar,"Copy",copy_selected,"ToolbarCopy");small_button(toolbar,"Paste",paste_copy,"ToolbarPaste");small_button(toolbar,"Delete",delete_selected,"ToolbarDelete")
 var back=PanelContainer.new();ui.add_child(back);back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);back.offset_left=360;back.offset_right=-12;back.offset_top=-75;back.offset_bottom=-12
 status=game.label("",13,Color("a8dce7"));status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;back.add_child(status)
 var aim=game.label("+",25,game.GOLD);aim.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(aim);aim.set_anchors_and_offsets_preset(Control.PRESET_CENTER);aim.offset_left=-8;aim.offset_top=-18
 update_layout();refresh_list();refresh_selection()
func update_layout() -> void:
 last_view_size=get_viewport().get_visible_rect().size
 var width=clampf(last_view_size.x*.28,280,336);panel.offset_right=12+width;toolbar.offset_left=panel.get_global_rect().end.x+12;toolbar.columns=2 if last_view_size.x<1000 else 4
func release_mouse() -> void:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;game.clear_held_input()
func tell(text: String) -> void:
 if is_instance_valid(status):status.text=text
func _process(delta: float) -> void:
 if not editing:return
 if get_viewport().get_visible_rect().size!=last_view_size:update_layout()
 if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and game.input_window_focused:
  var v=Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
  var direction=camera.global_basis*v+Vector3.UP*(float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)))
  camera.global_position+=direction.limit_length()*drag_distance*(3 if Input.is_physical_key_pressed(KEY_SHIFT) else 1)*delta
 if moving and is_instance_valid(ghost):ghost.global_position=aim_position()
func _input(event: InputEvent) -> void:
 if not editing:return
 if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  camera.rotation.y-=event.screen_relative.x*.0025;camera.rotation.x=clampf(camera.rotation.x-event.screen_relative.y*.0025,-1.5,1.5);get_viewport().set_input_as_handled()
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and not event.pressed:release_mouse()
func _unhandled_input(event: InputEvent) -> void:
 if not editing:return
 var focus=get_viewport().gui_get_focus_owner()
 if event is InputEventKey and (focus is LineEdit or focus is TextEdit) and event.keycode!=KEY_ESCAPE:return
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_RIGHT:
   if focus!=null:focus.release_focus()
   Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
  elif event.button_index==MOUSE_BUTTON_LEFT:
   if focus!=null:focus.release_focus()
   if moving:finish_move()
   else:select_at(event.position)
  elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:drag_distance=clampf(drag_distance*(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.2),2,50)
  else:return
  get_viewport().set_input_as_handled()
 elif event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE:
   if moving:cancel_move()
   release_mouse()
  elif event.keycode==KEY_F:frame_selection()
  elif event.ctrl_pressed and event.keycode==KEY_C:copy_selected()
  elif event.ctrl_pressed and event.keycode==KEY_V:paste_copy()
  elif event.ctrl_pressed and event.keycode==KEY_Z:command("undo")
  elif event.keycode==KEY_DELETE:delete_selected()
  else:return
  get_viewport().set_input_as_handled()
func ray_at(point: Vector2,mask=1|NestForgeMap.PICK_LAYER,skip=false) -> Dictionary:
 var origin=camera.project_ray_origin(point);var direction=camera.project_ray_normal(point);var excludes: Array[RID]=[]
 if skip and game.forge_session.model.records.has(selected_key):
  var r=game.forge_session.model.records[selected_key]
  for body in r.original_bodies+r.baked:
   if is_instance_valid(body):excludes.append(body.get_rid())
 var query=PhysicsRayQueryParameters3D.create(origin,origin+direction*200,mask,excludes);query.collide_with_areas=true;query.hit_from_inside=true
 return get_world_3d().direct_space_state.intersect_ray(query)
func aim_position() -> Vector3:
 var hit=ray_at(get_viewport().get_visible_rect().size*.5,1,true)
 var p: Vector3=hit.position if not hit.is_empty() else camera.global_position-camera.global_basis.z*8
 if moving and game.forge_session.model.records.has(selected_key):
  var r=game.forge_session.model.records[selected_key];p.y-=r.bounds.position.y*r.node.global_basis.get_scale().y
 p=p.clamp(Vector3(-200,-25,-200),Vector3(200,100,200))
 return p.snapped(Vector3.ONE*.5) if snap_toggle!=null and snap_toggle.button_pressed else p
func select_at(point: Vector2) -> void:
 var hit=ray_at(point)
 if hit.is_empty():select_key("");return
 var n=hit.collider
 if n.has_meta("forge_owner"):select_key(String(n.get_meta("forge_owner")));return
 while n!=null and n!=game:
  if n.has_meta("forge_marker"):select_key(String(n.get_meta("forge_marker")));return
  if n.has_meta("forge_key"):select_key(String(n.get_meta("forge_key")));return
  n=n.get_parent()
 tell("That is a fixed environment/traversal element. Nearby structures, lights and gameplay markers are editable.")
func select_key(key: String) -> void:
 cancel_move();selected_key=key;refresh_list();refresh_selection()
func select_node(node: Node3D) -> void:select_key(String(node.get_meta("forge_key","")) if node!=null else "")
func refresh_list() -> void:
 if not is_instance_valid(object_list):return
 object_list.clear();object_list.add_item("Select an object…");object_list.set_item_metadata(0,"")
 var model=game.forge_session.model;var filter=object_filter.text.to_lower() if is_instance_valid(object_filter) else ""
 for key in model.records:
  var r=model.records[key]
  if not r.get("enabled",true) or (not filter.is_empty() and not (r.label+" "+key).to_lower().contains(filter)):continue
  object_list.add_item(r.label+" · "+key);object_list.set_item_metadata(object_list.item_count-1,key)
 for key in model.markers:
  if int(key.get_slice(":",1))!=edit_mode:continue
  var text=model.label_for(key)
  if not filter.is_empty() and not text.to_lower().contains(filter):continue
  object_list.add_item(text);object_list.set_item_metadata(object_list.item_count-1,key)
 for i in range(object_list.item_count):
  if object_list.get_item_metadata(i)==selected_key:object_list.select(i)
func refresh_selection() -> void:
 if not is_instance_valid(selected):selected_key="";selected_label.text="Nothing selected";light_controls.visible=false;material_controls.visible=false;mechanism_controls.visible=false;transform_label.text="Select in the world or use the list.";outline.visible=false;return
 var model=game.forge_session.model;var p=selected.global_position;var rotation=selected.global_rotation_degrees
 selected_label.text=model.label_for(selected_key);transform_label.text="X %.2f  Y %.2f  Z %.2f"%[p.x,p.y,p.z]
 var marker=selected_key.begins_with("point:");var light=selected is Light3D
 light_controls.visible=light;material_controls.visible=not light and not marker;mechanism_controls.visible=selected is NestManCannon
 if selected is NestManCannon:
  var data=model.mechanism_data(selected)
  for i in range(3):target_fields[i].value=data.target[i]
  flight_time.value=data.flight
 var dims=model.dimensions(selected_key) if not marker else Vector3.ONE
 for i in range(3):position_fields[i].value=p[i];rotation_fields[i].value=rotation[i];size_fields[i].value=dims[i];size_fields[i].editable=not marker and not light;rotation_fields[i].editable=not marker
 inspector_snapshot={"p":position_fields.map(func(n):return n.value),"r":rotation_fields.map(func(n):return n.value),"s":size_fields.map(func(n):return n.value)}
 if not marker:
  material_picker.select(maxi(0,NestForgeMap.MATERIALS.find(model.records[selected_key].material)))
  if light:
   var d=model.light_data(selected);light_color.color=Color(d.color[0],d.color[1],d.color[2]);light_energy.value=d.energy;light_range.value=d.range;light_angle.value=d.angle;light_shadows.button_pressed=d.shadows;light_range.editable=selected is OmniLight3D or selected is SpotLight3D;light_angle.editable=selected is SpotLight3D
 var box=selected.global_transform*(model.records[selected_key].bounds if not marker else AABB(Vector3(-.45,0,-.45),Vector3(.9,1.2,.9)))
 var wire=ImmediateMesh.new();wire.surface_begin(Mesh.PRIMITIVE_LINES)
 for edge in [[0,1],[1,3],[3,2],[2,0],[4,5],[5,7],[7,6],[6,4],[0,4],[1,5],[2,6],[3,7]]:
  for c in edge:wire.surface_add_vertex(box.position+Vector3(box.size.x if c&1 else 0,box.size.y if c&2 else 0,box.size.z if c&4 else 0))
 wire.surface_end();outline.mesh=wire;outline.visible=true
func command(action: String,args: Dictionary={}) -> bool:return game.forge_session.submit(action,args)
func spawn_item(spec: Dictionary,_grab=false) -> Node3D:
 command("spawn",{"spec":spec,"position":NestForgeMap.vec(aim_position())});return selected
func apply_inspector() -> void:
 if not is_instance_valid(selected):tell("Select an object first.");return
 var p=selected.global_position
 for i in range(3):
  if not is_equal_approx(position_fields[i].value,float(inspector_snapshot.p[i])):p[i]=position_fields[i].value
 if selected_key.begins_with("point:"):command("transform",{"key":selected_key,"position":NestForgeMap.vec(p)});return
 var model=game.forge_session.model;var t=model.pose(selected);t.p=NestForgeMap.vec(p)
 for i in range(3):
  if not is_equal_approx(rotation_fields[i].value,float(inspector_snapshot.r[i])):t.r[i]=deg_to_rad(rotation_fields[i].value)
 if not selected is Light3D:
  var dims=model.dimensions(selected_key);var bounds=model.records[selected_key].bounds.size.max(Vector3.ONE*.001)
  for i in range(3):
   if not is_equal_approx(size_fields[i].value,float(inspector_snapshot.s[i])):t.s[i]=size_fields[i].value/bounds[i]
  if model.records[selected_key].kind=="mechanism":
   var factor=1.0
   for i in range(3):
    if not is_equal_approx(size_fields[i].value,float(inspector_snapshot.s[i])):factor=size_fields[i].value/maxf(.001,dims[i]);break
   t.s=NestForgeMap.vec(selected.global_basis.get_scale()*factor)
   if selected_key=="mechanism_lift":t.r[0]=0;t.r[2]=0
 command("transform",{"key":selected_key,"transform":t})
func apply_mechanism() -> void:
 if not selected is NestManCannon:tell("Select a launcher first.");return
 command("mechanism",{"key":selected_key,"mechanism":{"target":[target_fields[0].value,target_fields[1].value,target_fields[2].value],"flight":flight_time.value}})
func apply_light() -> void:
 if not selected is Light3D:tell("Select a point, spot or sunlight object first.");return
 var c=light_color.color;command("light",{"key":selected_key,"light":{"color":[c.r,c.g,c.b],"energy":light_energy.value,"range":light_range.value,"angle":light_angle.value,"shadows":light_shadows.button_pressed}})
func nudge(direction: Vector3) -> void:
 if not is_instance_valid(selected):return
 if selected_key.begins_with("point:"):command("transform",{"key":selected_key,"position":NestForgeMap.vec(selected.global_position+direction*step_size)});return
 var t=game.forge_session.model.pose(selected);t.p=NestForgeMap.vec(selected.global_position+direction*step_size);command("transform",{"key":selected_key,"transform":t})
func turn_piece(degrees: float) -> void:
 if not is_instance_valid(selected) or selected_key.begins_with("point:"):return
 var t=game.forge_session.model.pose(selected);t.r[1]+=deg_to_rad(degrees);command("transform",{"key":selected_key,"transform":t})
func copy_selected() -> void:
 if not is_instance_valid(selected) or selected_key.begins_with("point:"):tell("Select a structure, pickup or light to copy.");return
 var r=game.forge_session.model.records[selected_key]
 if r.kind=="mechanism":tell("Traversal devices can move, rotate, scale uniformly and be deleted; they cannot be duplicated.");return
 clipboard=r.spec.duplicate(true) if r.kind=="added" else {"type":"powerup" if r.spec.kind in ["cloak","overshield"] else "weapon","kind":r.spec.kind} if r.kind=="pickup" else {"type":"copy","source":selected_key};clipboard_pose=game.forge_session.model.pose(selected);tell("Copied. Paste places another at the crosshair.")
func paste_copy() -> void:
 if clipboard.is_empty():tell("Copy an object first.");return
 var t=clipboard_pose.duplicate(true);t.p=NestForgeMap.vec(aim_position());command("spawn",{"spec":clipboard,"position":t.p,"transform":t})
func toggle_grab() -> void:
 if moving:finish_move();return
 if not is_instance_valid(selected):tell("Select an object first.");return
 moving=true;ghost=Node3D.new();add_child(ghost);ghost.global_transform=selected.global_transform
 var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=Color(1,.8,.2,.45)
 for source in game.forge_session.model.visuals(selected):
  if not source is MeshInstance3D:continue
  var m=MeshInstance3D.new();m.mesh=source.mesh;m.material_override=mat;ghost.add_child(m);m.transform=selected.global_transform.affine_inverse()*source.global_transform
 if ghost.get_child_count()==0:
  var m=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.3;sphere.height=.6;m.mesh=sphere;m.material_override=mat;ghost.add_child(m)
 tell("Gold ghost previews placement. Click the world or Grab / Place to commit; Esc cancels.")
func finish_move() -> void:
 if not moving or not is_instance_valid(ghost):return
 var p=ghost.global_position;cancel_move()
 if selected_key.begins_with("point:"):command("transform",{"key":selected_key,"position":NestForgeMap.vec(p)})
 else:
  var t=game.forge_session.model.pose(selected);t.p=NestForgeMap.vec(p);command("transform",{"key":selected_key,"transform":t})
func cancel_move() -> void:
 moving=false
 if is_instance_valid(ghost):remove_child(ghost);ghost.queue_free()
 ghost=null
func delete_selected() -> void:cancel_move();command("delete",{"key":selected_key})
func frame_selection() -> void:
 if not is_instance_valid(selected):return
 var radius=3.0
 if game.forge_session.model.records.has(selected_key):radius=clampf(game.forge_session.model.dimensions(selected_key).length(),3,25)
 var target=selected.global_position;camera.global_position=target+Vector3(radius*.6,radius*.5,radius);camera.look_at(target+Vector3.UP*.5)
func state_changed(peer: int,key: String,message: String) -> void:
 if not editing:return
 if moving:cancel_move();message="Placement preview cancelled because the shared layout changed. "+message
 if peer==(game.multiplayer.get_unique_id() if game.network_active else 1):selected_key=key
 if not is_instance_valid(selected):selected_key=""
 game.forge_session.model.set_editor_visible(true,edit_mode);refresh_list();refresh_selection();tell(message)
func save_layout() -> bool:
 var ok=game.forge_session.save();tell("Layout saved on this computer." if ok else "Could not save this layout.");return ok
func load_layout() -> bool:
 var ok=game.forge_session.load_saved();tell("Layout loaded and synchronized." if ok else "No valid saved layout, or only the host can load.");return ok
func start_test() -> void:cancel_move();game.forge_session.start_test()
func return_to_editor() -> void:game.forge_session.return_to_editing()
func request_exit() -> void:
 cancel_move()
 if game.is_client():game.close_connection();game.leave_forge_editor_ui();game.show_main()
 else:game.forge_session.stop_editing()
func close_ui() -> void:
 editing=false;cancel_move();release_mouse()
 if is_instance_valid(ui):
  if ui.get_parent()!=null:ui.get_parent().remove_child(ui)
  if not ui.is_queued_for_deletion():ui.queue_free()
 ui=null
 if is_instance_valid(outline):outline.visible=false
func exit_editor(_show_menu=true) -> void:request_exit()
