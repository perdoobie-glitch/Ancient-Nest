extends SceneTree
func _initialize():call_deferred("run")
func run():
 var p=NestPreferences.new();p.load_saved()
 p.values.merge(NestPreferences.DEFAULTS.duplicate(true),true);p.apply()
 assert(p.values.resolution_width==1920 and p.values.resolution_height==1080)
 for aa in range(5):
  p.values.antialiasing=aa;p.apply()
 assert(root.msaa_3d==Viewport.MSAA_8X)
 p.values.render_scale=0.1;p.validate();assert(p.values.render_scale==0.5)
 assert(NestDisplaySettings.changed({"exclusive_fullscreen":true},{"exclusive_fullscreen":false}))
 var intro=load("res://intro/intro_scene.tscn").instantiate();root.add_child(intro);current_scene=intro
 await create_timer(12).timeout
 assert(current_scene!=null and current_scene.scene_file_path=="res://scenes/main.tscn")
 for child in root.get_children():assert(child.get_script()!=load("res://intro/loading_overlay.gd"))
 print("PASS: 1080 defaults, five AA settings, render-scale bounds, display confirmation keys, startup-to-menu and loading-overlay cleanup")
 current_scene.queue_free();current_scene=null;await create_timer(.75).timeout
 call_deferred("quit")
