class_name NestManCannon
extends Area3D
var destination: Vector3
var flight_seconds: float = 2.8
var horizontal_drag_compensation: float = .5
var recent: Dictionary = {}
func _ready() -> void:
	collision_layer=0; collision_mask=2
	var shape=CollisionShape3D.new(); var cylinder=CylinderShape3D.new(); cylinder.radius=1.15; cylinder.height=.7; shape.shape=cylinder; shape.position.y=.35; add_child(shape)
	body_entered.connect(launch)
func launch(body: Node3D) -> void:
	if not visible or not body is NestActor or not body.alive: return
	if body.game.is_client() and not body.local_player: return
	var key=body.get_instance_id()
	if body.game.now<float(recent.get(key,-INF)): return
	recent[key]=body.game.now+4
	var target=get_parent().to_global(destination)
	var travel=target-body.global_position
	# Existing replicated external momentum carries the launch; gravity and
	# collision remain active, and the player keeps normal mouse aiming.
	var impulse=travel/flight_seconds
	impulse.y+=.5*body.tuning.gravity*flight_seconds+.65
	var horizontal=Vector3(travel.x,0,travel.z)
	impulse+=horizontal.normalized()*(flight_seconds*horizontal_drag_compensation)
	body.controlled=Vector3(0,impulse.y,0); body.external=Vector3(impulse.x,0,impulse.z)
	body.cannon_takeoff=true
	body.global_position.y+=.12; body.velocity=impulse
	body.game.audio.play_sound("man_cannon_launch",global_position)
