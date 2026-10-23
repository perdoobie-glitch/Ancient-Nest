class_name NestTuning
extends Resource
# Units are meters and seconds. Balance values are provisional unless noted.
@export_group("Movement")
@export var ground_speed: float = 5.94
@export var crouch_speed: float = 2.97
@export var ground_acceleration: float = 45.0
@export var ground_braking: float = 40.0
@export var air_acceleration: float = 6.0
@export var air_projection_cap: float = 0.7425
@export var air_speed_cap: float = 8.91
@export var gravity: float = 9.361750225500
@export var jump_speed: float = 6.917293239963 # Preserves prior apex with 15% stronger gravity at 60 Hz
@export var carry_multiplier: float = 0.80 # confirmed
@export_group("Extraction — confirmed")
@export var round_seconds: float = 180.0
@export var drill_seconds: float = 45.0
@export var load_seconds: float = 5.0
@export var switch_seconds: float = 1.0
@export var startup_seconds: float = 2.0
@export var score_limit: int = 50
@export var respawn_seconds: float = 3.0
@export var role_switch_rounds: int = 3
@export var pickup_delay: float = 30.0
@export var pickup_interval: float = 120.0
@export_group("Extraction — prototype choices")
@export var plant_seconds: float = 3.0
@export var defuse_seconds: float = 6.0
@export var bomb_fuse: float = 15.0
@export var bag_stock: int = 3
@export var retain_drill_work: bool = true
@export var round_break: float = 5.0
@export_group("Protection — proposed")
@export var shield_capacity: float = 100.0
@export var health_capacity: float = 100.0
@export var armor_capacity: float = 100.0
@export var shield_delay: float = 5.0
@export var shield_rate: float = 50.0
@export var radar_range: float = 25.0
@export var spot_memory: float = 4.0
@export var friendly_fire: bool = false
@export_group("Unconfirmed power pickup defaults")
@export var overshield_capacity: float = 100.0
@export var overshield_duration: float = 60.0
@export var pickup_ammo_topup: int = 4
@export var pickup_time_topup: float = 30.0
@export var pickup_stack_cap: float = 120.0
