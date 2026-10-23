class_name NestSoundPool
extends Node

# Reusable world/interface voices. Limits are supplied by the audio manifest.
var max_voices: int
var voices: Array[Node] = []
var serial: int = 0

func configure(config: Dictionary) -> void:
	stop_all()
	max_voices = int(config.max_voices)
	while voices.size() > max_voices:
		voices.pop_back().queue_free()

func acquire(sound_id: String, spatial: bool, per_sound_limit: int, attached: Node=null, limit_group: String="") -> Node:
	var active: Array[Node] = []
	for voice in voices:
		if voice.get_meta("sound_id", "") == sound_id and (limit_group.is_empty() or voice.get_meta("limit_group","")==limit_group):
			active.append(voice)
	if active.size() >= per_sound_limit:
		active.sort_custom(func(a, b): return a.get_meta("serial") < b.get_meta("serial"))
		release(active[0])
	var selected: Node
	for voice in voices:
		if attached==null and voice.get_parent()==self and not voice.has_meta("sound_id") and (voice is AudioStreamPlayer3D) == spatial:
			selected = voice
			break
	if selected == null and voices.size() >= max_voices:
		# Recycle the oldest voice, replacing its player type if necessary.
		var oldest = voices[0]
		for voice in voices:
			if (oldest.get_meta("protected",false) and not voice.get_meta("protected",false)) or (voice.get_meta("protected",false)==oldest.get_meta("protected",false) and int(voice.get_meta("serial", -1)) < int(oldest.get_meta("serial", -1))):
				oldest = voice
		release(oldest)
		if is_instance_valid(oldest) and not oldest.is_queued_for_deletion() and attached==null and oldest.get_parent()==self and (oldest is AudioStreamPlayer3D) == spatial:
			selected = oldest
		else:
			voices.erase(oldest)
			oldest.queue_free()
	if selected == null:
		selected = AudioStreamPlayer3D.new() if spatial else AudioStreamPlayer.new()
		(attached if attached!=null else self).add_child(selected)
		voices.append(selected)
		selected.finished.connect(release.bind(selected))
		selected.tree_exited.connect(func(): voices.erase(selected))
	serial += 1
	selected.set_meta("sound_id", sound_id)
	selected.set_meta("limit_group",limit_group)
	selected.set_meta("serial", serial)
	return selected

func release(voice: Node) -> void:
	if not is_instance_valid(voice):
		return
	voice.stop()
	voice.stream = null
	if voice.has_meta("sound_id"):
		voice.remove_meta("sound_id")
	if voice.get_parent()!=self:
		voices.erase(voice); voice.queue_free()
	for tag in ["group","base_gain","protected","limit_group"]:
		if voice.has_meta(tag): voice.remove_meta(tag)

func stop_sound(sound_id: String) -> void:
	for voice in voices.duplicate():
		if voice.get_meta("sound_id", "") == sound_id:
			release(voice)

func stop_all() -> void:
	for voice in voices.duplicate():
		release(voice)

func active_count(sound_id: String = "") -> int:
	var count = 0
	for voice in voices:
		if voice.has_meta("sound_id") and (sound_id.is_empty() or voice.get_meta("sound_id") == sound_id):
			count += 1
	return count

func _exit_tree() -> void:
	stop_all()
