extends Node
const SOUNDS=[preload("res://audio/sfx/objectives/bomb_planted_alert.ogg"),preload("res://audio/sfx/objectives/bomb_defuse_start.ogg"),preload("res://audio/sfx/objectives/bomb_armed_tick.ogg")]
var game
var next_tick: float=0
var stamp: String=""
var warned_ten=false
var warned_five=false
func _ready() -> void:
 name="BombAudio"
 for i in range(SOUNDS.size()):game.audio.stream_cache[["res://audio/sfx/objectives/bomb_planted_alert.ogg","res://audio/sfx/objectives/bomb_defuse_start.ogg","res://audio/sfx/objectives/bomb_armed_tick.ogg"][i]]=SOUNDS[i]
func _process(_delta: float) -> void:
 if not game.running or game.finished or game.break_until>game.now or game.mode not in [0,game.MODE_CS]:return
 var active=-1
 for i in range(game.site_states.size()):
  if game.site_states[i].stage=="planted":active=i;break
 if active<0:stamp="";return
 var key=str(game.match_session)+":"+str(game.round_number)+":"+str(active)+":"+str(game.site_states[active].bomb_at)
 if key!=stamp:stamp=key;next_tick=game.now+.8;warned_ten=false;warned_five=false
 var remaining=float(game.site_states[active].bomb_at)-game.now
 if not game.is_client():
  if remaining<=10 and not warned_ten:warned_ten=true;game.announce("bomb_ten_seconds")
  if remaining<=5 and not warned_five:warned_five=true;game.announce("bomb_five_seconds")
 if game.now>=next_tick:
  game.audio.play_sound("bomb_armed_tick",game.arena.sites[active]+Vector3.UP*.4,{"spatial":true})
  next_tick=game.now+(.28 if remaining<3 else .6 if remaining<10 else 1.0)
