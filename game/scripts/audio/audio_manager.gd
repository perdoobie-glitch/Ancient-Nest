class_name NestAudioManager
extends Node

# Manifest-driven single entry point for gameplay audio.
const MANIFEST_PATH = "res://data/audio_manifest.json"
signal placeholder_requested(sound_id: String, reason: String)
signal sound_started(sound_id: String, file_path: String, voice: Node)

var manifest: Dictionary = {}
var pool: NestSoundPool
var rng = RandomNumberGenerator.new()
var stream_cache: Dictionary = {}
var last_variants: Dictionary = {}
var variant_bags: Dictionary = {}
var reported_missing: Dictionary = {}
var pending: Array[Dictionary] = []
var weapon_entries: Dictionary = {}
var ready_for_audio: bool = false
var playback_enabled: bool = true

func _ready() -> void:
	rng.randomize()
	load_manifest()

func load_manifest(path: String = MANIFEST_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return false
	return configure(parser.data)

func configure(data: Dictionary) -> bool:
	# Invalid data must not leave partially configured or unbounded playback.
	if not data.has("defaults") or not data.has("sounds") or not data.has("buses"):
		return false
	var defaults = data.defaults
	for field in ["max_voices", "max_pending", "voice_limit", "volume_db", "pitch_range", "spatial", "max_distance", "unit_size", "attenuation_filter_cutoff_hz", "attenuation_filter_db", "doppler_tracking", "far_distance", "sound_speed"]:
		if not defaults.has(field):
			return false
	if int(defaults.max_voices) < 1 or int(defaults.voice_limit) < 1 or int(defaults.max_pending) < 1 or float(defaults.sound_speed) <= 0:
		return false
	for bus in data.buses:
		if AudioServer.get_bus_index(bus.name) < 0:
			return false
	stop_all()
	manifest = data.duplicate(true)
	if manifest.has("master_limiter") and AudioServer.get_bus_effect_count(0)>0:
		var limiter=AudioServer.get_bus_effect(0,0)
		for key in manifest.master_limiter: limiter.set(key,manifest.master_limiter[key])
	stream_cache.clear()
	last_variants.clear()
	variant_bags.clear()
	weapon_entries.clear()
	reported_missing.clear()
	if pool == null:
		pool = NestSoundPool.new()
		add_child(pool)
	pool.configure(manifest.defaults)
	if playback_enabled and manifest.defaults.get("preload",false):
		for entry in manifest.sounds.values():
			for file in entry.get("files",[]):
				if ResourceLoader.exists(file): stream_cache[file]=load(file)
	ready_for_audio = true
	return true

func play_sound(sound_id: String, position: Vector3 = Vector3.ZERO, options: Dictionary={}) -> Array[Node]:
	return _play(sound_id, position, false, options)

func _play(sound_id: String, position: Vector3, distance_resolved: bool, options: Dictionary={}) -> Array[Node]:
	var result: Array[Node] = []
	if not ready_for_audio or not manifest.sounds.has(sound_id):
		_note_missing(sound_id, "Sound ID is not declared in audio_manifest.json")
		return result
	var entry: Dictionary = manifest.defaults.duplicate(true)
	entry.merge(manifest.sounds[sound_id], true)
	if options.has("spatial"): entry.spatial=options.spatial
	if entry.get("placeholder", false):
		_note_missing(sound_id, entry.get("reason", "Recording is pending"))
		return result
	var listener = get_viewport().get_camera_3d()
	if listener!=null and entry.has("listener_max_distance") and listener.global_position.distance_to(position)>float(entry.listener_max_distance): return result
	if entry.spatial and listener != null and not distance_resolved and entry.has("far_sound"):
		var distance = listener.global_position.distance_to(position)
		if distance >= float(entry.far_distance):
			if entry.get("delay_far", false):
				if pending.size() < int(manifest.defaults.max_pending):
					pending.append({"id": entry.far_sound, "position": position, "remaining": distance / float(entry.sound_speed),"options":options})
				return result
			return _play(entry.far_sound, position, true,options)
	if entry.has("layers"):
		# All layers come from data; a shot can combine crack, action and tail.
		for layer in entry.layers:
			result.append_array(_play(str(layer), position, true,options))
		return result
	var files: Array = entry.get("files", [])
	if files.is_empty():
		_note_missing(sound_id, "No recordings supplied for this sound ID")
		return result
	var index = choose_variant(sound_id, files.size())
	var path = str(files[index])
	if not playback_enabled:
		sound_started.emit(sound_id,path,null)
		return result
	if not stream_cache.has(path):
		if not ResourceLoader.exists(path):
			_note_missing(sound_id, "Missing declared recording: " + path)
			return result
		var stream = load(path)
		if not stream is AudioStream:
			_note_missing(sound_id, "Declared recording is not an AudioStream: " + path)
			return result
		stream_cache[path] = stream
	var voice = pool.acquire(sound_id, bool(entry.spatial), int(entry.voice_limit),options.get("attach_to"),String(options.get("limit_group","")))
	voice.stream = stream_cache[path]
	if entry.get("loop",false) and voice.stream is AudioStreamOggVorbis:
		voice.stream=voice.stream.duplicate(); voice.stream.loop=true
	voice.bus = entry.bus
	voice.set_meta("group",str(options.get("group","")))
	voice.set_meta("protected",bool(options.get("protected",false)))
	voice.set_meta("base_gain",float(entry.volume_db))
	voice.volume_db = float(entry.volume_db)+float(options.get("gain_db",0.0))
	voice.pitch_scale = rng.randf_range(float(entry.pitch_range[0]), float(entry.pitch_range[1]))*float(options.get("pitch_scale",1.0))
	if voice is AudioStreamPlayer3D:
		voice.global_position = position
		voice.max_distance = float(entry.max_distance)
		voice.unit_size = float(entry.unit_size)
		voice.attenuation_filter_cutoff_hz = float(entry.attenuation_filter_cutoff_hz)
		voice.attenuation_filter_db = float(entry.attenuation_filter_db)
		voice.doppler_tracking = int(options.get("doppler_tracking",entry.doppler_tracking))
	voice.play()
	sound_started.emit(sound_id, path, voice)
	result.append(voice)
	return result

func choose_variant(sound_id: String, count: int) -> int:
	if count <= 1:
		last_variants[sound_id] = 0
		return 0
	var previous = int(last_variants.get(sound_id, -1))
	var bag: Array=variant_bags.get(sound_id,[])
	if bag.is_empty():
		for index in range(count): bag.append(index)
		for index in range(count-1,0,-1):
			var other=rng.randi_range(0,index); var swap=bag[index]; bag[index]=bag[other]; bag[other]=swap
		if bag[-1]==previous:
			var swap=bag[0]; bag[0]=bag[-1]; bag[-1]=swap
	var selected: int=bag.pop_back(); variant_bags[sound_id]=bag
	last_variants[sound_id] = selected
	return selected

func _note_missing(sound_id: String, reason: String) -> void:
	if reported_missing.has(sound_id):
		return
	reported_missing[sound_id] = reason
	placeholder_requested.emit(sound_id, reason)

func _process(delta: float) -> void:
	for index in range(pending.size() - 1, -1, -1):
		pending[index].remaining -= delta
		if pending[index].remaining <= 0:
			var event = pending[index]
			pending.remove_at(index)
			_play(event.id, event.position, true,event.get("options",{}))

func set_voice_gain(voice: Node, gain_db: float) -> void:
	if is_instance_valid(voice): voice.volume_db=float(voice.get_meta("base_gain"))+gain_db
func stop_group(tag: String) -> void:
	if pool!=null:
		for voice in pool.voices.duplicate():
			if voice.get_meta("group","")==tag: pool.release(voice)
	for index in range(pending.size()-1,-1,-1):
		if pending[index].get("options",{}).get("group","")==tag: pending.remove_at(index)
func stop_group_prefix(prefix: String) -> void:
	if pool!=null:
		for voice in pool.voices.duplicate():
			if str(voice.get_meta("group","")).begins_with(prefix): pool.release(voice)

func set_bus_volume(bus_name: String, linear_volume: float) -> bool:
	if not ready_for_audio:
		return false
	for bus in manifest.buses:
		if bus.name == bus_name:
			var index = AudioServer.get_bus_index(bus_name)
			if index < 0:
				return false
			var volume = clampf(linear_volume, float(bus.slider.min), float(bus.slider.max))
			AudioServer.set_bus_mute(index, volume <= 0)
			if volume > 0:
				AudioServer.set_bus_volume_db(index, linear_to_db(volume))
			return true
	return false

func stop_sound(sound_id: String) -> void:
	_stop_event(sound_id, {})

func _stop_event(sound_id: String, visited: Dictionary) -> void:
	if visited.has(sound_id):
		return
	visited[sound_id] = true
	if pool != null:
		pool.stop_sound(sound_id)
	for index in range(pending.size() - 1, -1, -1):
		if pending[index].id == sound_id:
			pending.remove_at(index)
	var entry: Dictionary = manifest.get("sounds", {}).get(sound_id, {})
	for layer in entry.get("layers", []):
		_stop_event(str(layer), visited)
	if entry.has("far_sound"):
		_stop_event(str(entry.far_sound), visited)

func stop_all() -> void:
	pending.clear()
	if pool != null:
		pool.stop_all()

func _exit_tree() -> void:
	stop_all()

func prepare_weapon(profile: NestWeapon) -> String:
	var key="weapon_profile_"+str(profile.get_instance_id())
	if weapon_entries.has(key):return key
	weapon_entries[key]=true
	var files=[]
	for stream in profile.shot_sounds:
		if stream==null:continue
		files.append(stream.resource_path);stream_cache[stream.resource_path]=stream
	for stream in [profile.distant_sound,profile.reload_sound,profile.dry_fire_sound]:
		if stream!=null:stream_cache[stream.resource_path]=stream
	var bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "SFX_Weapons"
	manifest.sounds[key]={"files":files,"bus":bus,"volume_db":profile.shot_volume_db,"pitch_range":[1-profile.pitch_variation,1+profile.pitch_variation],"voice_limit":6,"far_distance":40,"spatial":true}
	if profile.distant_sound!=null:
		manifest.sounds[key]["far_sound"]=key+"_distant"
		manifest.sounds[key+"_distant"]={"files":[profile.distant_sound.resource_path],"bus":bus,"volume_db":profile.shot_volume_db-7,"voice_limit":6,"pitch_range":[.97,1.03],"spatial":true}
	for suffix in ["reload","dry"]:
		var stream=profile.reload_sound if suffix=="reload" else profile.dry_fire_sound
		if stream!=null:manifest.sounds[key+"_"+suffix]={"files":[stream.resource_path],"bus":bus,"volume_db":-24,"spatial":true}
	return key
func play_weapon(profile: NestWeapon, position: Vector3, local_shooter: bool, group: String, suffix: String="") -> Array[Node]:
	var key=prepare_weapon(profile)
	return play_sound(key+("_"+suffix if not suffix.is_empty() else ""),position,{"spatial":not local_shooter,"group":group,"limit_group":group})
