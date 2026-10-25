class_name NestPreferences
extends RefCounted
const PATH = "user://preferences.cfg"
const DEFAULTS = {"campaign_dialogue":0.85,"campaign_music":0.65,"campaign_effects":0.8,"record_films":true, "allow_host":true, "username":"Player", "sensitivity": 2.0, "aim_sensitivity": 1.0, "nu_sensitivity": 2.0, "nu_flight_assist": true, "zoom_feel_tweak": 1.0, "hover_sensitivity_multiplier": 0.7125, "invert_y": false, "fov": 90.0, "vsync": true, "graphics_quality": 0, "shadows": true, "fullscreen": true, "resolution_width":1920, "resolution_height":1080, "exclusive_fullscreen":false, "render_scale":1.0, "antialiasing":0, "aspect_ratio":0, "fps_limit": 120, "master": 0.65, "effects": 0.8, "hud_scale": 1.0, "hud_opacity": 0.95, "radar": true, "crosshair": true, "crosshair_color": 2, "crosshair_size": 7.0, "crosshair_gap": 3.0, "dynamic_crosshair": true, "chat": true, "naki_radar_size": 170.0, "annu_radar_size": 170.0, "naki_radar_corner": 0, "annu_radar_corner": 1, "radar_background_opacity": 0.65, "radar_sweep": false, "radar_colorblind": false}
const KEYS = {"flashlight":KEY_T,"sprint":KEY_SHIFT,"film_previous":KEY_PAGEUP,"film_next":KEY_PAGEDOWN, "forward": KEY_W, "backward": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE, "crouch": KEY_CTRL, "reload": KEY_R, "zoom": KEY_Z, "interact": KEY_E, "melee": KEY_F, "grenade": KEY_G, "grenade_type": KEY_B, "nu_boost": KEY_SHIFT, "nu": KEY_Q, "sword": KEY_3, "scoreboard": KEY_TAB, "pause": KEY_ESCAPE, "chat": KEY_ENTER, "connections": KEY_O, "switch_weapon": KEY_C, "primary_weapon": KEY_1, "secondary_weapon": KEY_2}
var values: Dictionary = DEFAULTS.duplicate(true)
var keys: Dictionary = KEYS.duplicate(true)
var audio_buses: Array = []
func load_saved() -> void:
	audio_buses=JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_manifest.json")).buses
	for bus in audio_buses:
		if bus.slider.key!="master": values[bus.slider.key]=1.0
	var cfg = ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in DEFAULTS:
			var v = cfg.get_value("personal", k, DEFAULTS[k])
			if typeof(v) == typeof(DEFAULTS[k]): values[k] = v
		for k in KEYS:
			var v = cfg.get_value("bindings", k, KEYS[k])
			if v is int and v > 0 and v < (1 << 25): keys[k] = v
		for bus in audio_buses:
			if bus.slider.key!="master": values[bus.slider.key]=cfg.get_value("personal",bus.slider.key,1.0)
		# Schema 1 used radians-per-pixel/100. Preserve the player's old turn distance
		# when displaying it in the menu sensitivity units (0.022 degrees per count).
		if int(cfg.get_value("meta","schema",1))<2: values.sensitivity=rad_to_deg(values.sensitivity*.01)/.022
		# Apply the additional 5% reduction once to existing saved hover settings.
		# Defaults already include it, so missing keys must not be scaled again.
		if int(cfg.get_value("meta","schema",1))<3 and cfg.has_section_key("personal","hover_sensitivity_multiplier"):
			values.hover_sensitivity_multiplier*=0.95
		if int(cfg.get_value("meta","schema",1))<5 and keys.grenade_type==KEY_Q:keys.grenade_type=KEY_B
		if int(cfg.get_value("meta","schema",1))<6 and keys.switch_weapon==KEY_1:
			for candidate in [KEY_C,KEY_BACKSLASH,KEY_BRACKETRIGHT,KEY_END]:
				if not keys.values().has(candidate):keys.switch_weapon=candidate;break
	validate()
	apply()
func validate() -> void:
	values.username=normalize_username(str(values.username))
	if values.username.is_empty():values.username="Player"
	values.sensitivity = clampf(values.sensitivity, 0.1, 20.0)
	values.nu_sensitivity=clampf(values.nu_sensitivity,0.1,20.0)
	values.aim_sensitivity = clampf(values.aim_sensitivity, 0.5, 1.5)
	values.zoom_feel_tweak = clampf(values.zoom_feel_tweak, 0.5, 1.5)
	values.radar_background_opacity = clampf(values.radar_background_opacity, 0.0, 1.0)
	values.hover_sensitivity_multiplier = clampf(values.hover_sensitivity_multiplier, 0.2375, 1.0)
	values.render_scale=clampf(values.render_scale,0.5,1.0)
	values.antialiasing=clampi(values.antialiasing,0,4)
	values.graphics_quality=clampi(values.graphics_quality,0,2)
	values.fov = clampf(values.fov, 60, 110)
	values.hud_scale = clampf(values.hud_scale, 0.75, 1.35)
	values.hud_opacity = clampf(values.hud_opacity, 0.45, 1)
	values.master = clampf(values.master, 0, 1)
	values.effects = clampf(values.effects, 0, 1)
	for key in ["campaign_dialogue","campaign_music","campaign_effects"]:values[key]=clampf(float(values[key]),0,1)
	for bus in audio_buses:
		values[bus.slider.key]=clampf(values[bus.slider.key],float(bus.slider.min),float(bus.slider.max))
	values.crosshair_color=clampi(values.crosshair_color,0,3)
	values.crosshair_size=clampf(values.crosshair_size,3,14)
	values.crosshair_gap=clampf(values.crosshair_gap,0,12)
	values.resolution_width=clampi(values.resolution_width,640,7680)
	values.resolution_height=clampi(values.resolution_height,360,4320)
	values.aspect_ratio=clampi(values.aspect_ratio,0,NestDisplaySettings.ASPECTS.size()-1)
	values.fps_limit = clampi(values.fps_limit, 30, 240)
	for f in ["naki", "annu"]:
		values[f+"_radar_size"] = clampf(values[f+"_radar_size"], 130, 240)
		values[f+"_radar_corner"] = clampi(values[f+"_radar_corner"], 0, 3)
func save() -> Error:
	validate()
	var cfg = ConfigFile.new()
	cfg.set_value("meta", "schema", 6)
	for k in values: cfg.set_value("personal", k, values[k])
	for k in keys: cfg.set_value("bindings", k, keys[k])
	return cfg.save(PATH)
func light_preset() -> void:
	values.graphics_quality=0;values.shadows=false;values.antialiasing=1;values.render_scale=1.0;values.vsync=false;values.fps_limit=120
	apply()
func apply() -> void:
	Input.use_accumulated_input=false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	NestDisplaySettings.apply(values)
	NestGraphicsQuality.apply_viewport(Engine.get_main_loop().root,values)
	Engine.max_fps = values.fps_limit
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, values.master)))
	AudioServer.set_bus_mute(0,values.master<=0)
	for bus in audio_buses:
		if bus.name=="Master": continue
		var index=AudioServer.get_bus_index(bus.name)
		if index<0: continue
		var gain=float(values.get(bus.slider.key,1.0))*(float(values.effects) if str(bus.name).begins_with("SFX_") else 1.0)
		AudioServer.set_bus_mute(index,gain<=0)
		if gain>0: AudioServer.set_bus_volume_db(index,linear_to_db(gain))
	for action in KEYS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event = InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	for data in [["fire", MOUSE_BUTTON_LEFT], ["aim", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(data[0]): InputMap.add_action(data[0])
		InputMap.action_erase_events(data[0])
		var event = InputEventMouseButton.new()
		event.button_index = data[1]
		InputMap.action_add_event(data[0], event)
func key_label(action: String) -> String:
	return OS.get_keycode_string(keys.get(action, 0))

static func normalize_username(text: String) -> String:
	var result=""
	for character in text.substr(0,256).strip_edges():
		var code=character.unicode_at(0)
		if code<32 or (code>=127 and code<=159) or (code>=0x202a and code<=0x202e) or (code>=0x2066 and code<=0x2069) or (code>=0x200b and code<=0x200f) or code in [0x2028,0x2029,0xfeff] or character in ["[","]"]:continue
		result+=character
		if result.length()>=24:break
	return result.strip_edges()
