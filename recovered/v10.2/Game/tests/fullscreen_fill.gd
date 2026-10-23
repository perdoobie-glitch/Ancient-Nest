extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 checks+=1
 if ok:print("PASS: "+text)
 else:failures+=1;push_error("FAIL: "+text)
func run():
 var values=NestPreferences.DEFAULTS.duplicate(true)
 check(values.fullscreen,"New installations default to fullscreen")
 for size in [Vector2i(1920,1080),Vector2i(1920,1200),Vector2i(3440,1440),Vector2i(5120,1440)]:
  root.size=size
  for aspect in range(NestDisplaySettings.ASPECTS.size()):
   values.fullscreen=true;values.aspect_ratio=aspect;NestDisplaySettings.apply(values)
   await process_frame;await process_frame
   var logical=root.get_visible_rect().size
   check(root.content_scale_aspect==Window.CONTENT_SCALE_ASPECT_EXPAND and absf(logical.x/logical.y-float(size.x)/size.y)<.003,"Fullscreen fills %s with saved aspect %d"%[size,aspect])
 values.fullscreen=false;values.aspect_ratio=1;NestDisplaySettings.apply(values)
 await process_frame;await process_frame
 check(root.content_scale_aspect==Window.CONTENT_SCALE_ASPECT_KEEP,"Windowed fixed aspect still works")
 check(values.aspect_ratio==1,"Fullscreen does not erase preferred windowed aspect")
 var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_F11
 check(NestDisplaySettings.is_fullscreen_shortcut(key),"F11 toggles fullscreen")
 key.echo=true;check(not NestDisplaySettings.is_fullscreen_shortcut(key),"Held F11 does not toggle repeatedly")
 key.echo=false;key.pressed=false;check(not NestDisplaySettings.is_fullscreen_shortcut(key),"Key release does not toggle")
 key.pressed=true;key.keycode=KEY_ENTER;key.alt_pressed=true
 check(NestDisplaySettings.is_fullscreen_shortcut(key),"Alt+Enter toggles fullscreen")
 key.alt_pressed=false;check(not NestDisplaySettings.is_fullscreen_shortcut(key),"Normal Enter remains available to gameplay/chat")
 print("FULLSCREEN FILL: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
