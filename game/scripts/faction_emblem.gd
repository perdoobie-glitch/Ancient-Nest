class_name NestFactionEmblem
extends Control
var annu: bool=false
const INK=Color("e3cb62")
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
 var c=size*.5;var r=minf(size.x,size.y)*.32
 if annu:
  draw_arc(c,r*.68,0,TAU,40,INK,1.5,true)
  for i in range(16):
   var a=float(i)*TAU/16;var d=Vector2(cos(a),sin(a))
   draw_line(c+d*r*.86,c+d*r*(1.28 if i%2==0 else 1.08),INK,1.3,true)
 else:
  for side in [-1,1]:
   var previous=Vector2.INF
   for i in range(6):
    var a=lerpf(.27,2.72,float(i)/5);var p=c+Vector2(sin(a)*side,cos(a))*r
    if previous!=Vector2.INF:draw_line(previous,p,INK,1,true)
    previous=p
    draw_line(p,p+Vector2(-side*.12,-.19)*r,INK,2,true)
    draw_line(p,p+Vector2(side*.19,-.02)*r,INK,2,true)
  draw_line(c+Vector2(0,r*.8),c-Vector2(0,r*.8),INK,1.5,true)
  draw_colored_polygon(PackedVector2Array([c+Vector2(0,-r),c+Vector2(-r*.15,-r*.52),c+Vector2(r*.15,-r*.52)]),INK)
