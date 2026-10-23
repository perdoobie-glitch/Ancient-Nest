class_name NestReticle
extends Control
var game: Node3D
var scope_mask: ColorRect
var scope_material: ShaderMaterial
var enemy_hover: bool=false
var hover_head: bool=false
const SNIPER_RING_SCALE: float=.225
const SNIPER_GOLD: Color=Color("e4c57e")
const SNIPER_BLACK: Color=Color(.015,.012,.008,.98)
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	scope_mask=ColorRect.new(); scope_mask.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scope_material=ShaderMaterial.new(); scope_material.shader=load("res://assets/scope_mask.gdshader")
	scope_mask.material=scope_material; scope_mask.z_index=-1; add_child(scope_mask); scope_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_mask.visible=false
func _process(_delta: float) -> void:
	if not is_instance_valid(game): return
	var scoped=is_instance_valid(game.player) and game.player.scoped_overlay() and game.context=="playing"
	scope_mask.visible=scoped
	if scoped: scope_material.set_shader_parameter("viewport_size",size)
	var previous=enemy_hover; enemy_hover=false; hover_head=false
	if is_instance_valid(game.player) and game.player.alive and game.context=="playing":
		var actor=game.player
		var range_m=float(NestWeaponCatalog.for_kind(actor.weapons[actor.slot].kind).get("reticle_red_range_m",0))
		if range_m>0:
			var origin=actor.camera.global_position
			var contact=game.trace(origin,origin+actor.aim_direction()*range_m,5,actor.ray_exclusions())
			if not contact.is_empty() and contact.collider is Area3D and contact.collider.has_meta("actor"):
				var target=contact.collider.get_meta("actor")
				enemy_hover=target.alive and target!=actor and (target.faction!=actor.faction or game.mode==1) and target.cloak_deadline<=game.now
				hover_head=enemy_hover and contact.collider.get_meta("region")=="head"
	if enemy_hover and not previous: game.audio.play_sound("reticle_red_on")
	elif previous and not enemy_hover and game.damage_rules.reticle_red_off_sound: game.audio.play_sound("reticle_red_off")
	queue_redraw()
func stroke(a: Vector2, b: Vector2, color: Color, width: float=1.5) -> void:
	draw_line(a,b,Color(0.025,.035,.04,.96),width+2,true)
	draw_line(a,b,color,width,true)
func _draw() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player) or not game.player.alive: return
	var actor: NestActor=game.player
	if is_instance_valid(game.nu.local_bird):return
	var center=size*.5
	var scoped=actor.scoped_overlay() and game.context=="playing"
	var definition=NestWeaponCatalog.for_kind(actor.weapons[actor.slot].kind)
	if actor.weapons[actor.slot].kind in ["sniper","plasma_sniper"]:
		if scoped or game.prefs.values.crosshair:draw_sniper(center,actor,scoped)
		return
	if definition.get("reticle_style","")=="circle":
		if not scoped and not game.prefs.values.crosshair:return
		var color=Color(game.damage_rules.reticle_red_color) if enemy_hover else Color("ffe098")
		var ring=(game.prefs.values.crosshair_size+game.prefs.values.crosshair_gap)*.9
		draw_arc(center,ring,0,TAU,64,Color(.02,.025,.03,.9),3.5,true)
		draw_arc(center,ring,0,TAU,64,color,1.5,true)
		if scoped:
			var outer=minf(size.x,size.y)*.44;draw_arc(center,outer,0,TAU,128,Color("b8a274"),1.5,true)
			var zoom=tan(deg_to_rad(game.prefs.values.fov)*.5)/tan(deg_to_rad(actor.camera.fov)*.5)
			draw_string(ThemeDB.fallback_font,center+Vector2(outer*.62,outer*.70),"%.1f×"%zoom,HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
		return
	if scoped:
		var radius=minf(size.x,size.y)*.44
		var scope_color=Color(game.damage_rules.reticle_red_color) if enemy_hover else Color(.05,.06,.065)
		stroke(center-Vector2(radius,0),center+Vector2(radius,0),scope_color,1)
		stroke(center-Vector2(0,radius),center+Vector2(0,radius),scope_color,1)
		draw_circle(center,1.35,Color("e6eee9"))
		draw_arc(center,radius,0,TAU,128,Color("828e89"),1.5,true)
		var font=ThemeDB.fallback_font
		var zoom=tan(deg_to_rad(game.prefs.values.fov)*.5)/tan(deg_to_rad(actor.camera.fov)*.5)
		draw_string(font,center+Vector2(radius*.62,radius*.70),"%.1f×"%zoom,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("d9dfd8"))
	elif game.prefs.values.crosshair:
		var colors=[Color("8be09b"),Color("83d9ef"),Color("f2eee3"),Color("e4c57e")]
		var color=colors[game.prefs.values.crosshair_color]
		if game.prefs.values.crosshair_color==2: color=Color(game.damage_rules.reticle_normal_color)
		if enemy_hover: color=Color(game.damage_rules.reticle_red_color)
		var radius=game.prefs.values.crosshair_size+game.prefs.values.crosshair_gap
		var kind=actor.weapons[actor.slot].kind
		if kind=="shotgun":radius*=2.0
		elif kind=="rocket":radius*=1.6
		elif kind in ["burst","burst_scoped","sniper","sidearm"]:radius*=.75
		if game.prefs.values.dynamic_crosshair:
			radius+=clampf(actor.accuracy_penalty*2.0,0,8)
		# Four separated circular brackets, an open centre and a precise dot.
		for quadrant in range(4):
			var angle=float(quadrant)*PI*.5+.13
			draw_arc(center,radius,angle,angle+PI*.5-.26,20,Color(.02,.035,.05,.85),3.5,true)
			draw_arc(center,radius,angle,angle+PI*.5-.26,20,color,1.5,true)
		draw_circle(center,2.1,Color(.02,.035,.05,.85))
		draw_circle(center,1.0,color)
		if kind in ["burst","burst_scoped","sniper"]:
			for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:stroke(center+direction*(radius+2),center+direction*(radius+5),color,1.0)
		elif kind=="rocket":draw_arc(center,radius*.7,0,TAU,48,color,1,true)

func draw_sniper(center: Vector2, actor: NestActor, scoped: bool) -> void:
	# The circle is centered on the same camera ray at both zoom levels.
	var ring=maxf(1.75,(game.prefs.values.crosshair_size+game.prefs.values.crosshair_gap)*SNIPER_RING_SCALE)
	if scoped:ring=maxf(2.5,ring*1.25)
	draw_arc(center,ring,0,TAU,80,SNIPER_BLACK,4.0,true)
	draw_arc(center,ring,0,TAU,80,SNIPER_GOLD,1.5,true)
	if not scoped:return
	var radius=minf(size.x,size.y)*.44
	# Four gold/black arms stop outside the central circle, keeping its interior clear.
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		stroke(center+direction*(ring+5),center+direction*(radius-3),SNIPER_GOLD,1.0)
		stroke(center+direction*(radius+3),center+direction*(radius+14),SNIPER_GOLD,2.0)
	draw_arc(center,radius,0,TAU,160,SNIPER_BLACK,5,true)
	draw_arc(center,radius,0,TAU,160,SNIPER_GOLD,1.5,true)
	var zoom=tan(deg_to_rad(game.prefs.values.fov)*.5)/tan(deg_to_rad(actor.camera.fov)*.5)
	var label="%.1f×"%zoom
	var pos=center+Vector2(radius*.58,radius*.68)
	draw_string_outline(ThemeDB.fallback_font,pos,label,HORIZONTAL_ALIGNMENT_LEFT,-1,16,4,SNIPER_BLACK)
	draw_string(ThemeDB.fallback_font,pos,label,HORIZONTAL_ALIGNMENT_LEFT,-1,16,SNIPER_GOLD)
