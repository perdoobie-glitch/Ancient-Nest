class_name NestAnnouncer
extends Node
var manager: NestAudioManager
var rules: Dictionary
var lines: Dictionary = {}
var queue: Array[Dictionary] = []
var current: String = ""
var current_priority: int = -1
var current_voices: Array[Node] = []
var last_spoken: Dictionary = {}
var clock: float = 0
var lead: int = -2
var countdown_seen: Dictionary = {}
var round_seen: int = -1
var kill_history: Dictionary = {}
var streaks: Dictionary = {}
var previous_killers: Dictionary = {}
var first_blood: bool = false

func _ready() -> void:
	for line in JSON.parse_string(FileAccess.get_file_as_string("res://data/announcer_lines.json")).lines: lines[line.id]=line
func say(id: String) -> bool:
	if not lines.has(id): return false
	var line: Dictionary=lines[id]
	if clock-float(last_spoken.get(id,-INF))<maxf(float(line.cooldown),float(rules.announcer_duplicate_seconds)): return false
	last_spoken[id]=clock
	if current.is_empty() or int(line.priority)>current_priority:
		manager.stop_group("announcer"); current=""; current_voices.clear(); _start(line)
	else:
		queue.append(line)
		queue.sort_custom(func(a,b): return int(a.priority)>int(b.priority))
		if queue.size()>int(rules.announcer_max_queue): queue.resize(int(rules.announcer_max_queue))
	return true
func _start(line: Dictionary) -> void:
	current=line.id; current_priority=int(line.priority)
	current_voices=manager.play_sound(line.sound_id,Vector3.ZERO,{"spatial":false,"group":"announcer","protected":true})
	if current_voices.is_empty(): current=""; current_priority=-1
func _process(delta: float) -> void:
	clock+=delta
	if not current.is_empty():
		var playing=false
		for voice in current_voices:
			if is_instance_valid(voice) and voice.playing and voice.get_meta("group","")=="announcer": playing=true
		if not playing: current=""; current_priority=-1; current_voices.clear()
	if current.is_empty() and not queue.is_empty(): _start(queue.pop_front())
func reset() -> void:
	manager.stop_group("announcer"); current=""; queue.clear(); current_voices.clear(); last_spoken.clear()
	lead=-2; countdown_seen.clear(); round_seen=-1; kill_history.clear(); streaks.clear(); previous_killers.clear(); first_blood=false
func tick(game) -> void:
	if not game.running or game.finished or game.is_client(): return
	if round_seen!=game.round_number:
		round_seen=game.round_number; countdown_seen.clear()
	var seconds=ceili(game.deadline-game.now) if is_finite(game.deadline) else -1
	var cue_id="match_one_minute" if seconds==60 else "match_30_seconds" if seconds==30 else "countdown_"+str(seconds) if seconds>=1 and seconds<=10 else ""
	if not cue_id.is_empty() and not countdown_seen.has(cue_id):
		countdown_seen[cue_id]=true; game.announce(cue_id)
	var new_lead=-1 if game.scores[0]==game.scores[1] else 0 if game.scores[0]>game.scores[1] else 1
	if new_lead!=lead:
		if lead!=-2:
			for actor in game.actors:
				if actor.remote_peer>0 or actor.local_player:
					var id="lead_tied" if new_lead==-1 else ("lead_taken" if game.mode==1 else "team_lead_taken") if actor.faction==new_lead else ("lead_lost" if game.mode==1 else "team_lead_lost")
					game.announce(id,actor)
		lead=new_lead
func record_death(game, victim) -> void:
	if game.is_client():return
	var id=victim.net_id if game.network_active else victim.get_instance_id()
	streaks.erase(id)
func forget_player(id: int) -> void:
	streaks.erase(id);kill_history.erase(id);previous_killers.erase(id)
func record_kill(game, killer, victim, reason: String) -> void:
	if game.is_client():return
	if killer==victim:return
	if game.mode!=1 and killer.faction==victim.faction:
		game.announce("betrayal",killer)
		return
	var id=killer.net_id if game.network_active else killer.get_instance_id()
	var victim_id=victim.net_id if game.network_active else victim.get_instance_id()
	var history: Array=kill_history.get(id,[])
	history=history.filter(func(at): return game.now-float(at)<=float(rules.medal_window_seconds))
	history.append(game.now); kill_history[id]=history
	streaks[id]=int(streaks.get(id,0))+1; streaks[victim_id]=0
	var cue_id=str(rules.kill_medals.get(str(history.size()),""))
	if not cue_id.is_empty(): game.announce(cue_id,killer)
	var spree=str(rules.streak_medals.get(str(streaks[id]),""))
	if not spree.is_empty(): game.announce(spree,killer)
	if not first_blood: first_blood=true; game.announce("first_blood",killer)
	if reason=="headshot": game.announce("headshot",killer)
	elif reason=="melee": game.announce("melee_kill",killer)
	elif reason=="explosion" and victim.last_damage_weapon in ["frag_grenade","plasma_grenade"]: game.announce("grenade_kill",killer)
	elif victim.last_damage_weapon=="sniper": game.announce("sniper_kill",killer)
	if game.mode!=1 and killer.faction==victim.faction: game.announce("betrayal",killer)
	if rules.revenge_enabled and previous_killers.get(id,-1)==victim_id: game.announce("revenge",killer)
	previous_killers[victim_id]=id
func _exit_tree() -> void:
	if manager!=null: manager.stop_group("announcer")
