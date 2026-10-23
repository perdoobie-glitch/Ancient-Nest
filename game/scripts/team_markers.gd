class_name NestTeamMarkers
extends Control
var game: Node3D
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE; z_index=2
func _process(_delta: float) -> void: queue_redraw()
func marker_positions() -> Array[Vector2]:
	var result: Array[Vector2]=[]
	if not is_instance_valid(game) or not game.running or game.finished or game.mode==1 or game.context not in ["playing","chat"]: return result
	var viewer=game.player
	if not is_instance_valid(viewer) or viewer.camera==null: return result
	for actor in game.actors:
		if actor==viewer or not actor.alive or actor.faction!=viewer.faction: continue
		var head=actor.global_position+Vector3.UP*(1.9 if actor.crouched else 2.5)*NestActor.SIZE # above the scaled head
		if game.get_viewport().get_camera_3d().is_position_behind(head): continue
		var point=get_global_transform_with_canvas().affine_inverse()*game.get_viewport().get_camera_3d().unproject_position(head)
		if Rect2(Vector2(12,16),size-Vector2(24,32)).has_point(point): result.append(point)
	return result
func _draw() -> void:
	draw_nu_spots()
	# A HUD marker deliberately has no world-depth test, so allies remain marked
	# behind walls. Free-for-all, enemies, self and eliminated actors are excluded.
	for point in marker_positions():
		var triangle=PackedVector2Array([point+Vector2(-8,-13),point+Vector2(8,-13),point])
		draw_colored_polygon(triangle,Color("7cf4b7"))
		draw_polyline(PackedVector2Array([triangle[0],triangle[1],triangle[2],triangle[0]]),Color("102b22"),2.5,true)

func draw_nu_spots() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player) or game.context!="playing":return
	var camera=game.get_viewport().get_camera_3d()
	if camera==null:return
	for id in game.nu.visible_enemy_ids(game.player):
		var actor=game.actor_by_id(id)
		if actor==null:continue
		var head=actor.global_position+Vector3.UP*2.6*NestActor.SIZE
		if camera.is_position_behind(head):continue
		var point=get_global_transform_with_canvas().affine_inverse()*camera.unproject_position(head)
		if not Rect2(Vector2(5,5),size-Vector2(10,10)).has_point(point):continue
		draw_arc(point,9,0,TAU,24,Color("ff5656"),2,true)
		draw_string(ThemeDB.fallback_font,point+Vector2(13,5),"NU · "+actor.username,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ff9090"))
