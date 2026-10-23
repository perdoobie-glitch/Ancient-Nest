extends Control
var game: NestMatch
var preview: bool = false
var preview_faction: int = 0
var update_accum := 0.0
var contacts: Dictionary = {}
var tactical: NestAnnuTacticalMap
var contact_character: int=-1
var sweep_phase := 0.0
const UPDATE_HZ := 25.0
const FADE_SECONDS := 0.75

func _process(delta: float) -> void:
	update_accum += delta
	sweep_phase = fmod(sweep_phase + delta, 1.5)
	if update_accum >= 1.0/UPDATE_HZ:
		update_accum=0.0
		_refresh_contacts()
	queue_redraw()

func _refresh_contacts() -> void:
	if preview or not is_instance_valid(game) or not game.running or not is_instance_valid(game.player): return
	var player=game.player
	if contact_character!=player.character:contacts.clear();contact_character=player.character
	if player.character==1:
		if tactical==null:tactical=NestAnnuTacticalMap.new(self)
		tactical.refresh();return
	for actor in game.actors:
		if actor==player or not actor.alive: continue
		var friend=actor.faction==player.faction and game.mode!=1
		var distance=actor.global_position.distance_to(player.global_position)
		var eligible=friend
		if not friend and game.game_type.radar_enabled and distance<=game.game_type.radar_range:
			eligible=not game.game_type.radar_moving_only or Vector2(actor.velocity.x,actor.velocity.z).length()>0.65
		var id=actor.get_instance_id()
		if eligible:
			contacts[id]={"actor":actor,"pos":actor.global_position,"friend":friend,"seen":game.now}
	for id in contacts.keys():
		var c=contacts[id]
		if not is_instance_valid(c.actor) or game.now-float(c.seen)>FADE_SECONDS: contacts.erase(id)

func _draw() -> void:
	if not preview and (not game.running or not is_instance_valid(game.player) or not game.game_type.radar_enabled): return
	if (preview and preview_faction==1) or (not preview and game.player.character==1):
		if tactical==null:tactical=NestAnnuTacticalMap.new(self)
		tactical.draw();return
	var center=size/2
	var radius=minf(size.x,size.y)*0.46
	var bg_alpha=0.65 if preview else float(game.prefs.values.radar_background_opacity)
	var gold=Color("e2d09a")
	draw_circle(center,radius,Color(0.025,0.035,0.04,bg_alpha))
	draw_arc(center,radius,0,TAU,72,gold,2.0,true)
	for f in [0.25,0.5,0.75]: draw_arc(center,radius*f,0,TAU,48,Color(0.8,0.8,0.7,0.18),1,true)
	if not preview and game.prefs.values.radar_sweep:
		var angle=(sweep_phase/1.5)*TAU-PI/2
		draw_line(center,center+Vector2(cos(angle),sin(angle))*radius,Color(0.9,0.82,0.55,0.25),1)
	if preview:
		draw_circle(center+Vector2(25,-30),4,Color("ef5b5b")); draw_circle(center+Vector2(-35,20),3,Color("77c8ff"))
	else:
		var player=game.player
		for id in contacts:
			var c=contacts[id]
			if not is_instance_valid(c.actor): continue
			var relative=player.global_transform.basis.inverse()*(c.pos-player.global_position)
			var offset=Vector2(relative.x,relative.z)/maxf(1.0,game.game_type.radar_range)*radius
			if offset.length()>radius-7:
				if not game.game_type.radar_edge_clamp: continue
				offset=offset.normalized()*(radius-7)
			var age=game.now-float(c.seen)
			var alpha=clampf(1.0-age/FADE_SECONDS,0.15,1.0)
			var enemy_color=Color("ff4f55")
			var team_color=Color("69c5ff")
			if game.prefs.values.radar_colorblind:
				enemy_color=Color("ffd166"); team_color=Color("67d5b5")
			var color=(team_color if c.friend else enemy_color); color.a=alpha
			var p=center+offset
			draw_circle(p,5 if not c.friend else 4,Color(0,0,0,0.75*alpha))
			if not c.friend and game.prefs.values.radar_colorblind:
				var diamond=PackedVector2Array([p+Vector2(0,-5),p+Vector2(5,0),p+Vector2(0,5),p+Vector2(-5,0)])
				draw_colored_polygon(diamond,color)
			else: draw_circle(p,4 if not c.friend else 3,color)
			var dy=float(c.pos.y-player.global_position.y)
			if absf(dy)>3.0:
				var sign=-1.0 if dy>0 else 1.0
				var tri=PackedVector2Array([p+Vector2(0,sign*8),p+Vector2(-3,sign*4),p+Vector2(3,sign*4)])
				draw_colored_polygon(tri,color)
	var pointer=PackedVector2Array([center+Vector2(0,-6),center+Vector2(-5,5),center+Vector2(5,5)])
	draw_colored_polygon(pointer,Color.WHITE)
