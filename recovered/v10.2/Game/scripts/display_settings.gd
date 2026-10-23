class_name NestDisplaySettings
extends RefCounted
const KEYS=["fullscreen","resolution_width","resolution_height","aspect_ratio","exclusive_fullscreen","render_scale"]
const ASPECT_LABELS=["Auto · fit display","4:3","16:10","16:9","21:9 · ultrawide","32:9 · super ultrawide"]
const ASPECTS=[Vector2i.ZERO,Vector2i(4,3),Vector2i(16,10),Vector2i(16,9),Vector2i(21,9),Vector2i(32,9)]
const RESOLUTIONS=[Vector2i(800,600),Vector2i(1024,768),Vector2i(1280,720),Vector2i(1280,800),Vector2i(1280,960),Vector2i(1280,540),Vector2i(1280,360),Vector2i(1366,768),Vector2i(1440,900),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(1920,1200),Vector2i(2560,1080),Vector2i(2560,1440),Vector2i(3440,1440),Vector2i(3840,1080),Vector2i(3840,1600),Vector2i(3840,2160),Vector2i(5120,1440)]
static var last_values: Dictionary={}
static func changed(a: Dictionary,b: Dictionary) -> bool:
 for key in KEYS:
  if a.get(key)!=b.get(key):return true
 return false
static func logical_size(aspect: int) -> Vector2i:
 if aspect==0:return Vector2i(1440,900)
 var ratio=ASPECTS[clampi(aspect,1,ASPECTS.size()-1)]
 var height=maxi(900,ceili(1440.0*ratio.y/ratio.x))
 return Vector2i(roundi(float(height)*ratio.x/ratio.y),height)
static func fit_window(wanted: Vector2i, usable: Vector2i) -> Vector2i:
 var available=Vector2i(maxi(640,usable.x-16),maxi(360,usable.y-48))
 var scale=minf(1.0,minf(float(available.x)/wanted.x,float(available.y)/wanted.y))
 return Vector2i(maxi(640,roundi(wanted.x*scale)),maxi(360,roundi(wanted.y*scale)))
static func apply_layout(window: Window, aspect: int) -> void:
 window.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 window.content_scale_size=logical_size(aspect)
 window.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND if aspect==0 else Window.CONTENT_SCALE_ASPECT_KEEP
static func apply(values: Dictionary) -> void:
 var tree=Engine.get_main_loop() as SceneTree
 if tree==null:return
 var window=tree.root;apply_layout(window,0 if bool(values.fullscreen) else int(values.aspect_ratio));window.min_size=Vector2i(640,360)
 if DisplayServer.get_name()!="headless":
  var old_full=bool(last_values.get("fullscreen",not values.fullscreen))
  var desired_mode=DisplayServer.WINDOW_MODE_WINDOWED
  if values.fullscreen:desired_mode=DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if values.get("exclusive_fullscreen",false) else DisplayServer.WINDOW_MODE_FULLSCREEN
  if DisplayServer.window_get_mode()!=desired_mode:
   DisplayServer.window_set_mode(desired_mode)
  if not values.fullscreen and (last_values.is_empty() or old_full or values.resolution_width!=last_values.get("resolution_width") or values.resolution_height!=last_values.get("resolution_height")):
   if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_WINDOWED:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
   var screen=DisplayServer.window_get_current_screen();var rect=DisplayServer.screen_get_usable_rect(screen)
   var size=fit_window(Vector2i(values.resolution_width,values.resolution_height),rect.size)
   DisplayServer.window_set_size(size);DisplayServer.window_set_position(rect.position+(rect.size-size)/2)
 if values.fullscreen:
  var screen_size=DisplayServer.screen_get_size()
  window.scaling_3d_scale=clampf(minf(float(values.resolution_width)/maxi(1,screen_size.x),float(values.resolution_height)/maxi(1,screen_size.y))*float(values.get("render_scale",1.0)),0.25,1.0)
 else:window.scaling_3d_scale=float(values.get("render_scale",1.0))
 last_values=values.duplicate(true)

static func is_fullscreen_shortcut(event: InputEvent) -> bool:
 return event is InputEventKey and event.pressed and not event.echo and (event.keycode==KEY_F11 or (event.keycode==KEY_ENTER and event.alt_pressed))
