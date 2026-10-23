class_name NestWaterfallAmbience
extends Node
# One preloaded looping voice, independent of weapon/effect voice budgets.
const STREAM=preload("res://audio/ambience/waterfall.ogg")
const DESERT_STREAM=preload("res://assets/savannah/desert_wind.ogg")
const BASE_GAIN=.05
const FALL_GAIN=.28
var game
var voice: AudioStreamPlayer
var gain=0.0
func _ready() -> void:
 name="WaterfallAmbience"
 voice=AudioStreamPlayer.new();voice.stream=STREAM;voice.volume_db=-80;add_child(voice)
func target_gain() -> float:
 if not is_instance_valid(game) or not game.running or game.finished or game.context!="playing" or not is_instance_valid(game.player) or not game.player.alive:return 0.0
 if game.arena.map_selection in [2,3]:return .035
 var p=game.player
 var descent=inverse_lerp(0.0,-17.5,p.global_position.y) if p.velocity.y < -1.0 and not p.is_on_floor() else 0.0
 return lerpf(BASE_GAIN,FALL_GAIN,smoothstep(0.0,1.0,clampf(descent,0.0,1.0)))
func _process(delta: float) -> void:
 var stream=DESERT_STREAM if is_instance_valid(game) and is_instance_valid(game.arena) and game.arena.map_selection in [2,3] else STREAM
 if voice.stream!=stream:voice.stop();voice.stream=stream
 var desired=target_gain()
 gain=lerpf(gain,desired,1.0-exp(-delta*5.0))
 if AudioServer.get_bus_index("SFX_Foley")>=0:voice.bus="SFX_Foley"
 if desired>0 and not voice.playing:voice.play()
 voice.volume_db=linear_to_db(maxf(gain,.0001))
 if desired==0 and gain<.00015 and voice.playing:voice.stop();gain=0

func stop_immediately() -> void:
 gain=0.0
 if is_instance_valid(voice):voice.stop()
func _exit_tree() -> void:
 stop_immediately()
 if is_instance_valid(voice):voice.stream=null
