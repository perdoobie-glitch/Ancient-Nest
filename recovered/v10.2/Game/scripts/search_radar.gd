class_name NestSearchRadar
extends Control
## Honest activity animation. Ring motion never represents fabricated progress.
var mm
var enabled=true
var clock=0.0
var throttle=0.0
func _process(delta: float) -> void:
 clock+=delta;throttle+=delta
 if throttle>=1.0/30.0:throttle=0;queue_redraw()
func _draw() -> void:
 if mm==null:return
 var active=mm.phase in ["queue","connecting","probing","loading","rejoining"] or mm.search_countdown_until>0
 var online=mm.hybrid.master_connected()
 if mm.phase=="queue" and not online:active=false
 var c=Vector2(size.x*.5,size.y*.5);var radius=minf(46.0,size.y*.5-8)
 var color=Color("71c992") if online else Color("dc8475")
 draw_arc(c,radius,0,TAU,64,Color(color,.22),1.0,true)
 draw_arc(c,radius*.65,0,TAU,48,Color(color,.12),1.0,true)
 draw_line(c-Vector2(radius+6,0),c+Vector2(radius+6,0),Color(color,.1),1.0,true)
 draw_line(c-Vector2(0,radius+6),c+Vector2(0,radius+6),Color(color,.1),1.0,true)
 var angle=clock*1.7 if enabled and active else -PI*.5
 if active:
  draw_arc(c,radius,angle,angle+PI*.5,28,color,2.5,true)
  draw_line(c,c+Vector2(cos(angle),sin(angle))*radius,Color(color,.4),1.0,true)
  if enabled:
   var pulse=fposmod(clock*.32,1.0);draw_arc(c,8+pulse*(radius-8),0,TAU,48,Color(color,(1-pulse)*.22),1.0,true)
 else:
  draw_arc(c,radius,-PI*.52,PI*.52,32,Color(color,.65),2.0,true)
 draw_circle(c,4.0,Color(color,.85))
