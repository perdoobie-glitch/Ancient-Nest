extends Node3D
var game
var pack: Node3D
var marker: MeshInstance3D
func _ready() -> void:
 name="RoundBomb"
 var k=game.arena.kit
 pack=NestBombArt.create(k);add_child(pack)
 marker=k.box(self,Vector3(0,1.25,0),Vector3(.13,.13,.13),k.material(Color("ff941f")))
 marker.rotation.z=PI*.25;marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func _process(_delta: float) -> void:
 visible=game.running and game.mode==game.MODE_CS and not game.finished and game.break_until<=game.now
 marker.visible=false
 if not visible:return
 if game.cs_planted():
  global_position=game.arena.sites[game.bomb_site]+Vector3(.5,.27,.25);rotation=Vector3.ZERO
 elif game.cs_carrier!=0:
  var carrier=game.actor_by_id(game.cs_carrier)
  visible=is_instance_valid(carrier) and carrier.alive and not carrier.local_player
  if not visible:return
  var dropping=carrier.action_state=="bomb_drop"
  var t=clampf(1-(carrier.bomb_drop_at-game.now),0,1) if dropping else 0.0
  var offset=Vector3(0,1.3,.32).lerp(Vector3(.35,.9,-.4),smoothstep(0,1,t)) if dropping else Vector3(.05,1.2,-.5) if carrier.bomb_equipped else Vector3(0,1.3,.32)
  global_position=carrier.global_position+carrier.global_basis*offset;rotation=Vector3(0,carrier.rotation.y,0)
  var viewer=game.player
  if is_instance_valid(viewer):
   var friendly=viewer.faction==carrier.faction
   var clear=game.trace(viewer.eye.global_position,carrier.eye.global_position,1,viewer.ray_exclusions()).is_empty()
   var in_front=viewer.aim_direction().dot((carrier.eye.global_position-viewer.eye.global_position).normalized())>.25
   marker.visible=friendly or (carrier.bomb_equipped and clear and in_front)
   marker.position.y=.95+.05*sin(game.now*4)
 else:
  visible=game.cs_drop_position.is_finite()
  if visible:global_position=game.cs_drop_position+Vector3.UP*.10;rotation=Vector3(PI*.5,0,0)
