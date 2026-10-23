class_name NestWeapon
extends Resource
@export var title: String = "Automatic Rifle"
@export var kind: String = "rifle"
@export var automatic: bool = true
@export var damage: float = 20.0
@export var precision: bool = false
@export var speed: float = 0.0
@export var interval: float = 0.10
@export_range(0.0,15.0,0.005) var spread_half_angle_deg: float = 0.0
# Legacy resource/test alias; one canonical cone value.
@export var spread_degrees: float:
	get:return spread_half_angle_deg
	set(value):spread_half_angle_deg=value
@export var magazine: int = 32
@export var reserve: int = 160
@export var reload_seconds: float = 2.0
@export var pellets: int = 1
@export var max_range: float = 150.0
@export var explosive: bool = false

@export var shot_sounds: Array[AudioStream] = []
@export var distant_sound: AudioStream
@export var reload_sound: AudioStream
@export var dry_fire_sound: AudioStream
@export var shot_volume_db: float = -7.0
@export_range(0.0,0.1) var pitch_variation: float = 0.04
@export_range(0.0,1.0) var tracer_opacity: float = 0.10
@export_range(1,20) var tracer_every_n_shots: int = 1

@export var plasma: bool = false
@export var plasma_color: Color = Color("ffcf42")
