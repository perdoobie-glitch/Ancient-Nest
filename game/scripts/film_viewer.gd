extends Control
class ViewMask extends Control:
	var area=Rect2()
	func _draw():
		draw_rect(Rect2(0,0,size.x,area.position.y),Color.BLACK)
		draw_rect(Rect2(0,area.end.y,size.x,maxf(0,size.y-area.end.y)),Color.BLACK)
		draw_rect(Rect2(0,area.position.y,area.position.x,area.size.y),Color.BLACK)
		draw_rect(Rect2(area.end.x,area.position.y,maxf(0,size.x-area.end.x),area.size.y),Color.BLACK)
var game
var film={}
var timestamp=0.0
var speed=1.0
var paused=true
var selected=""
var camera: Camera3D
var actors={}
var label_view: Label
var timeline: HSlider
var picker: OptionButton
var panel: VBoxContainer
var worker: Thread
var worker_kind=""
var closing=false
var source=""
var preferences={}
var updating=false
var previous_time=0.0
var view_mask
var recorded_fov=90.0
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);process_priority=-100
	theme=game.screen.theme
	view_mask=ViewMask.new();view_mask.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(view_mask);view_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);view_mask.hide()
	preferences=game.prefs.values.duplicate(true)
	panel=VBoxContainer.new();add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_theme_constant_override("separation",8)
	var margin=MarginContainer.new();margin.add_theme_constant_override("margin_left",24);margin.add_theme_constant_override("margin_right",24);panel.add_child(margin)
	var head=HBoxContainer.new();margin.add_child(head);head.add_child(game.button("Back",close))
	label_view=game.label("FILMS · 29 samples/second · Interactive reconstructions",18);head.add_child(label_view)
	label_view.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label_view.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	library()
func library():
	var list=VBoxContainer.new();list.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(list)
	list.add_child(game.button("Open exported film…",func():file_dialog(false)))
	var dir=DirAccess.open(NestFilmArchive.ROOT)
	if dir!=null:
		var names=dir.get_files();names.reverse()
		for name in names:
			if name.get_extension()!="nestfilm" or not NestFilmArchive.valid_id(name.get_basename()):continue
			var filename=NestFilmArchive.ROOT+"/"+name
			var date=Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(filename))
			list.add_child(game.button(date+" · "+name.substr(0,8),load_film.bind(filename)))
	list.add_child(game.label("Films and temporary perspective tracks: 7 days, 2 GiB total.\nPlayer-submitted tracks are not trusted evidence of honest play.",14))
func file_dialog(save: bool):
	var dialog=FileDialog.new();dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.use_native_dialog=true
	dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE;dialog.filters=PackedStringArray(["*.nestfilm ; Ancient Nest film"]);add_child(dialog)
	dialog.file_selected.connect(func(filename):
		if save:
			if worker!=null:return
			worker_kind="export";worker=Thread.new();worker.start(copy_film.bind(source,filename));label_view.text="Exporting film asynchronously…"
		else:load_film(filename))
	dialog.popup_centered_ratio(.8)
static func copy_film(from: String, to: String) -> Dictionary:
	if ProjectSettings.globalize_path(from).to_lower()==ProjectSettings.globalize_path(to).to_lower():return {"exported":to}
	return {"error":"Export failed"} if DirAccess.copy_absolute(from,to)!=OK else {"exported":to}
func load_film(filename: String):
	if worker!=null:return
	if game.running or (game.network_active and not game.film_retaining_transport):label_view.text="Leave the current match/lobby before opening a film";return
	source=filename;worker_kind="load";worker=Thread.new();worker.start(NestFilmArchive.read.bind(filename));label_view.text="Loading film asynchronously…"
func _process(delta):
	if worker!=null and not worker.is_alive():
		var result=worker.wait_to_finish();worker=null
		if closing:queue_free();return
		if result.has("error"):label_view.text=result.error
		elif worker_kind=="load":open_film(result)
		else:label_view.text="Export complete · "+str(result.exported)
	if film.is_empty() or closing:return
	var from=timestamp;var was_paused=paused
	if not paused:
		timestamp=clampf(timestamp+delta*speed,0,float(film.metadata.get("duration",0)))
		if timestamp<=0 or timestamp>=float(film.metadata.get("duration",0)):paused=true
	if selected.is_empty() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var direction=Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		camera.position+=camera.basis*direction.limit_length()*delta*15
	apply_time()
	if not was_paused and speed>0 and not selected.is_empty():
		for event in NestFilmArchive.events_between(film.events.get(selected,[]),from,timestamp):
			if event.t>from and event.t<=timestamp and event.get("kind","")=="sound":game.audio.play_sound(str(event.get("data",{}).get("id","")).substr(0,128),event.get("data",{}).get("pos",Vector3.ZERO),{"spatial":bool(event.get("data",{}).get("spatial",true))})
func open_film(data: Dictionary):
	if data.get("metadata",{}).is_empty() or data.get("frames",[]).is_empty():label_view.text="Film has no main timeline";return
	if not data.metadata.get("config",{}).get("game_type",{}) is Dictionary:label_view.text="Invalid film rules";return
	film=data;game.replay_active=true;game.replay_state={}
	if not game.film_retaining_transport:game.close_connection()
	game.clear_screen();game.current_screen="film";game.results_shown=true
	for child in panel.get_children():
		if child.get_index()>0:child.queue_free()
	var rules=GameTypeSettings.new();rules.apply_network_dict(data.metadata.config.game_type);game.apply_game_type_settings(rules);game.ensure_selected_map()
	game.running=true;game.context="playing";game.finished=false;game.get_viewport().disable_3d=false;game.audio.stop_all()
	game.match_session=int(data.metadata.config.get("session",0));game.team_characters.assign(game.MATCHUPS[clampi(int(data.metadata.config.get("matchup",0)),0,3)])
	for who in data.metadata.roster:
		var member=data.metadata.roster[who]
		if not member is Dictionary:continue
		var actor=NestActor.new();actor.game=game;actor.net_id=int(member.id);actor.faction=clampi(int(member.team),0,1);actor.character_choice=clampi(int(member.character),0,1);actor.username=str(member.name).substr(0,64)
		game.add_child(actor);game.actors.append(actor);actor.process_mode=Node.PROCESS_MODE_DISABLED;actor.collision_layer=0;actors[who]=actor
	camera=Camera3D.new();camera.near=.04;game.add_child(camera);camera.current=true;camera.position=Vector3(-30,20,30);camera.look_at(Vector3.ZERO)
	var bar=HBoxContainer.new();panel.add_child(bar)
	bar.add_child(game.button("Previous player",cycle.bind(-1)));bar.add_child(game.button("Next player",cycle.bind(1)))
	picker=OptionButton.new();picker.custom_minimum_size=Vector2(240,42);bar.add_child(picker);picker.add_item("Free Camera")
	for who in actors:
		var member=film.metadata.roster[who];picker.add_item(str(member.name)+" · Team "+str(int(member.team)+1))
	picker.item_selected.connect(func(index):select("" if index==0 else str(actors.keys()[index-1])))
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(spacer)
	var bottom=HBoxContainer.new();panel.add_child(bottom)
	for rate in [-2,-1,1,2]:bottom.add_child(game.button(str(rate)+"×",set_speed.bind(float(rate))))
	bottom.add_child(game.button("Pause / Play",func():paused=not paused))
	bottom.add_child(game.button("◀ Frame",step.bind(-1)));bottom.add_child(game.button("Frame ▶",step.bind(1)))
	bottom.add_child(game.button("Export…",func():file_dialog(true)))
	panel.add_child(game.label("Interactive reconstruction · player-submitted tracks are untrusted · first-person mouse aim is locked",12))
	timeline=HSlider.new();timeline.min_value=0;timeline.max_value=float(data.metadata.get("duration",0));timeline.step=.001;panel.add_child(timeline)
	timeline.value_changed.connect(func(value):if not updating:seek(value))
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;selected="";timestamp=0;paused=true;apply_time()
func select(who: String):
	if not who.is_empty() and not actors.has(who):return
	selected=who
	if is_instance_valid(picker):picker.select(0 if who.is_empty() else actors.keys().find(who)+1)
	game.audio.stop_all();apply_time() # Deliberately preserve time, rate and pause.
func cycle(direction: int):
	if actors.is_empty():return
	var keys=actors.keys();var index=keys.find(selected)
	select(str(keys[posmod(index+direction,keys.size())]))
func set_speed(rate: float):speed=rate;paused=false
func seek(time: float):
	if film.is_empty():return
	timestamp=clampf(time,0,float(film.metadata.get("duration",0)));game.audio.stop_all();game.clear_effects();apply_time()
func step(direction: int):paused=true;seek(timestamp+float(direction)/29)
func input(event: InputEvent) -> bool:
	if film.is_empty():return false
	if get_viewport().gui_get_focus_owner() is LineEdit:return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==int(game.prefs.keys.film_previous):cycle(-1)
		elif event.physical_keycode==int(game.prefs.keys.film_next):cycle(1)
		elif event.keycode==KEY_SPACE:paused=not paused
		elif event.keycode==KEY_LEFT:step(-1)
		elif event.keycode==KEY_RIGHT:step(1)
		else:return false
		return true
	if selected.is_empty() and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotation.y-=event.relative.x*.003;camera.rotation.x=clampf(camera.rotation.x-event.relative.y*.003,-1.55,1.55)
		return true
	return false
func apply_time():
	if film.is_empty() or not is_instance_valid(camera):return
	var pair=NestFilmArchive.sample_pair(film.frames,timestamp)
	if not pair.available:return
	game.now=timestamp;game.audio.playback_enabled=false
	apply_world(pair)
	game.replay_state={};game.hud.visible=false
	view_mask.visible=false
	for actor in actors.values():
		actor.local_player=false
		if is_instance_valid(actor.weapon_view):actor.weapon_view.visible=false
		actor.refresh_model_visibility()
	if selected.is_empty():label_view.text="Free Camera · %.3f s · %s %.0f×"%[timestamp,"Paused" if paused else "Playing",speed]
	else:
		var actor: NestActor=actors[selected];game.player=actor;actor.local_player=true
		var view_pair=NestFilmArchive.sample_pair(film.tracks.get(selected,[]),timestamp)
		var reason="";var recorded=false
		if view_pair.available:
			var view: Dictionary=view_pair.a
			if load("res://scripts/film_transfer.gd").valid_views([view]):
				recorded=true;apply_view(actor,view,view_pair)
				for event in NestFilmArchive.events_between(film.events.get(selected,[]),timestamp-.13,timestamp):
					if event.t<=timestamp and timestamp-event.t<=.13 and event.get("kind","")=="confirmed_hit":game.hit_until=maxf(game.hit_until,float(event.t)+.13)
			else:reason="Invalid local perspective track"
		else:reason=str(view_pair.reason)
		if not film.tracks.has(selected):reason="Local track missing / transfer incomplete / retention limit"
		if not recorded:
			camera.global_transform=actor.eye.global_transform;camera.fov=90
			game.replay_state={"recorded":false,"contacts":[],"hover":false}
			game.hit_until=0;game.hurt_until=0;game.messages.clear();game.local_kill_notice="";game.local_kill_notice_until=0
			if is_instance_valid(actor.weapon_view):actor.weapon_view.visible=actor.alive
		actor.camera=camera
		if actor.weapon_view==null:actor.build_view_weapon();actor.update_weapon_art()
		actor.refresh_model_visibility()
		if not is_instance_valid(game.hud_top) or game.hud_health_model!=actor.damage_model():game.create_hud()
		game.hud.visible=actor.visible and bool(game.replay_state.get("hud_visible",true));game.set_hud_preferences()
		fit_recorded_view(game.replay_state.get("viewport",size))
		label_view.text=str(film.metadata.roster[selected].name)+(" · Recorded Local Perspective" if recorded else " · Reconstructed View · "+reason)+(" · DEAD / waiting to respawn" if not actor.alive else "")+" · %.3f s"%timestamp
	game.audio.playback_enabled=DisplayServer.get_name()!="headless" and not paused and speed>0
	updating=true;timeline.set_value_no_signal(timestamp);updating=false
func apply_world(pair: Dictionary):
	var state: Array=pair.a.state;var future: Array=pair.b.state
	var m: Dictionary=state[0]
	game.round_number=int(m.get("round",1));game.scores.assign(m.get("scores",[0,0]));game.deadline=float(m.get("deadline",0));game.break_until=float(m.get("break",0));game.round_reason=str(m.get("reason",""));game.bomb_site=int(m.get("bomb_site",-1));game.kill_feed.assign(m.get("feed",[]));game.site_states.assign(m.get("sites",[]));game.flags=m.get("flags",[]).duplicate(true)
	for actor in actors.values():actor.visible=false
	for record in state[1]:
		var actor=actors.get(str(record.get("film_identity","")),game.actor_by_id(int(record.id)))
		if actor==null:continue
		actor.visible=true;actor.global_position=record.pos;actor.rotation.y=float(record.yaw);actor.eye.rotation.x=float(record.pitch)
		for next in future[1]:
			if next.id==record.id and next.life==record.life:
				actor.global_position=record.pos.lerp(next.pos,float(pair.fraction));actor.rotation.y=lerp_angle(record.yaw,next.yaw,float(pair.fraction));break
		for fields in [["alive","alive"],["life_id","life"],["health","health"],["shield","shield"],["armor","armor"],["overshield","over"],["crouched","crouch"],["air_duck","air_duck"],["velocity","velocity"],["action_state","action"],["action_until","action_until"],["respawn_at","respawn"],["kills","kills"],["deaths","deaths"],["assists","assists"],["carrying","carrying"],["bag_id","bag"]]:
			if record.has(fields[1]):actor.set(fields[0],record[fields[1]])
		actor.weapons.clear()
		for kind in record.weapons:actor.weapons.append(NestWeaponCatalog.profile(kind))
		actor.slot=clampi(int(record.slot),0,actor.weapons.size()-1);actor.ammo.assign(record.ammo);actor.reserve.assign(record.reserve);actor.grenades.assign(record.grenades)
		actor.update_visual(0)
		if is_instance_valid(actor.enemy_name_tag):actor.enemy_name_tag.visible=false
	for i in range(mini(game.site_states.size(),game.arena.deposits.size())):game.arena.set_site_visual(i,str(game.site_states[i].get("stage","sealed")),timestamp)
func apply_view(actor: NestActor, view: Dictionary, pair: Dictionary):
	for field in NestFilmRecorder.ACTOR_FIELDS:
		if not view.actor.has(field):continue
		var value=view.actor[field]
		if typeof(value)!=typeof(actor.get(field)):continue
		if value is Array:actor.get(field).assign(value)
		else:actor.set(field,value)
	actor.slot=clampi(actor.slot,0,actor.weapons.size()-1)
	if view.get("inventory",[]) is Array and not view.get("inventory",[]).is_empty() and view.inventory.size()<=4:
		actor.weapons.clear()
		for kind in view.inventory:actor.weapons.append(NestWeaponCatalog.profile(str(kind)))
		actor.slot=clampi(actor.slot,0,actor.weapons.size()-1)
	for rendered in view.get("rendered",[]):
		var other=actors.get(str(rendered.get("identity","")),game.actor_by_id(int(rendered.id)))
		if other!=null:
			other.global_transform=rendered.xf
			if other.animation!=null and other.animation.has_animation(str(rendered.get("animation",""))):
				other.animation.play(str(rendered.animation));other.animation.seek(float(rendered.get("animation_position",0)),true)
	actor.camera=camera
	if actor.weapon_view==null:actor.build_view_weapon()
	actor.update_weapon_art()
	for weapon in actor.weapons:
		if weapon.kind!="none":game.audio.prepare_weapon(weapon)
	camera.global_transform=view.camera.interpolate_with(pair.b.camera,float(pair.fraction));recorded_fov=lerpf(view.fov,pair.b.fov,float(pair.fraction));camera.fov=recorded_fov
	apply_nodes(actor.weapon_view,view.get("weapon_nodes",[]));actor.weapon_view.visible=bool(view.get("weapon_visible",false))
	for key in view.get("preferences",{}):
		if preferences.has(key) and typeof(preferences[key])==typeof(view.preferences[key]):game.prefs.values[key]=view.preferences[key]
	game.replay_state={"recorded":true,"hud_visible":view.get("hud_visible",true),"scoreboard":view.get("scoreboard",false),"contacts":view.get("contacts",[]),"hover":bool(view.get("hover",false)),"viewport":view.get("viewport",size)}
	game.hit_until=float(view.get("hit_until",0));game.hurt_until=float(view.get("hurt_until",0));game.local_kill_notice=str(view.get("kill_notice",""));game.local_kill_notice_until=float(view.get("kill_notice_until",0));game.messages.assign(view.get("messages",[]))
func fit_recorded_view(original: Vector2):
	if original.x<=0 or original.y<=0:return
	var aspect=original.x/original.y
	var available_height=maxf(1,size.y-2*minf(120,size.y*.25))
	var extent=Vector2(minf(size.x,available_height*aspect),minf(available_height,size.x/aspect))
	view_mask.area=Rect2((size-extent)*.5,extent);view_mask.visible=true;view_mask.queue_redraw()
	game.hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);game.hud.position=view_mask.area.position;game.hud.size=original;game.hud.scale=extent/original
	camera.fov=rad_to_deg(2*atan(tan(deg_to_rad(camera.fov)*.5)*size.y/maxf(1,extent.y)))
static func apply_nodes(root: Node, poses: Array):
	for pose in poses:
		if not pose is Dictionary or not pose.get("path") is Array or pose.path.size()>16 or not pose.get("xf") is Transform3D:continue
		var node=root
		for index in pose.path:
			var children=node.get_children().filter(func(child):return not child.is_queued_for_deletion())
			if not index is int or index<0 or index>=children.size():node=null;break
			node=children[index]
		if node is Node3D and pose.xf.is_finite():node.transform=pose.xf;node.visible=bool(pose.get("visible",true))
func close():
	closing=true;hide();game.prefs.values=preferences
	if game.replay_active:
		var active_transport=game.network_active;game.network_active=false
		game.audio.stop_all();game.stop_game();game.network_active=active_transport;game.replay_active=false;game.replay_state={};game.hud.visible=false
		game.hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		game.hud.scale=Vector2.ONE
		if is_instance_valid(camera):camera.queue_free()
	game.film_viewer=null;game.show_main()
	if worker==null:queue_free()
func _exit_tree():
	if worker!=null:worker.wait_to_finish()
