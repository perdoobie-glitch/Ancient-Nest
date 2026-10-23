extends Control
## One shared artwork from engine splash through threaded menu loading.
signal intro_finished
@export_file("*.tscn") var next_scene="res://scenes/main.tscn"
@export var skippable=true
const COVER_TEXTURE=preload("res://assets/intro/loading.png")
var finishing=false
var overlay: CanvasLayer
var note: Label
func _ready() -> void:
 if OS.has_feature("hybrid_qa"):
  var path="res://tests/hybrid/worker.gd" if "--hybrid-worker" in OS.get_cmdline_user_args() else "res://tests/hybrid/client.gd"
  get_tree().set_script(load(path));get_tree().call_deferred("run");queue_free();return
 if OS.has_feature("dedicated_server") or "--matchmaking-server" in OS.get_cmdline_user_args() or "--hybrid-worker" in OS.get_cmdline_user_args():
  get_tree().call_deferred("change_scene_to_file",next_scene);return
 var preferences=NestPreferences.new();preferences.load_saved();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay=CanvasLayer.new();overlay.layer=100;overlay.set_script(load("res://intro/loading_overlay.gd"));get_tree().root.add_child(overlay)
 var art=TextureRect.new();art.texture=COVER_TEXTURE;art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 note=Label.new();note.text="LOADING ANCIENT NEST…";note.position=Vector2(28,28);note.add_theme_color_override("font_color",Color.WHITE);note.add_theme_color_override("font_outline_color",Color.BLACK);note.add_theme_constant_override("outline_size",4);overlay.add_child(note)
 if ResourceLoader.load_threaded_request(next_scene)!=OK:note.text="Unable to load menu. Please restart Ancient Nest.";return
 get_tree().create_timer(1.0).timeout.connect(_finish)
func _input(event: InputEvent) -> void:
 if NestDisplaySettings.is_fullscreen_shortcut(event):
  var preferences=NestPreferences.new();preferences.load_saved();preferences.values.fullscreen=not preferences.values.fullscreen;preferences.apply();preferences.save();get_viewport().set_input_as_handled();return
 if skippable and ((event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed)):
  get_viewport().set_input_as_handled();_finish()
func _finish() -> void:
 if finishing:return
 finishing=true
 while ResourceLoader.load_threaded_get_status(next_scene)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await get_tree().process_frame
 var packed=ResourceLoader.load_threaded_get(next_scene) as PackedScene
 if packed==null:note.text="Unable to load menu. Please restart Ancient Nest.";return
 for action in InputMap.get_actions():Input.action_release(action)
 intro_finished.emit()
 var tree=get_tree()
 if tree.change_scene_to_packed(packed)!=OK:note.text="Unable to open menu. Please restart Ancient Nest.";return
 overlay.menu_requested=true
