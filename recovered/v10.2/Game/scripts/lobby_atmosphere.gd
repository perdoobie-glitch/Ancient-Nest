class_name NestLobbyAtmosphere
extends Control
## Small translucent waterfall veils and drifting motes; no lights or physics.
var moving=true
var timer=0.0
var time=0.0
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 for x in [.14,.79]:
  var water=ColorRect.new();water.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(water)
  water.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);water.anchor_left=x;water.anchor_right=x+.065;water.anchor_top=.08;water.anchor_bottom=.84
  var material=ShaderMaterial.new();material.shader=load("res://assets/lobby_water.gdshader");water.material=material
func set_enabled(value: bool) -> void:
 moving=value;visible=value;set_process(value)
func _process(delta: float) -> void:
 time+=delta;timer+=delta
 if timer>=1.0/30.0:timer=0;queue_redraw()
func _draw() -> void:
 if not moving:return
 for i in range(18):
  var x=fposmod(float(i)*.173+sin(time*.06+i)*.018,1.0)*size.x
  var y=fposmod(float(i)*.217-time*(.008+float(i%3)*.002),1.0)*size.y
  draw_circle(Vector2(x,y),1.0+float(i%2),Color(.77,.71,.46,.13+.07*sin(time+i)))
