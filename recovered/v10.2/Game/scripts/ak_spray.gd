class_name NestAKSpray
extends RefCounted
# Original learnable rifle pattern: vertical climb, left sweep, then right.
# The first five bullets keep the previous precision. Values are angular degrees.
const RESET_SECONDS: float = 1.0
const PATTERN: Array[Vector2] = [Vector2(.02,.16),Vector2(.05,.32),Vector2(.09,.48),Vector2(.13,.64),Vector2(.17,.80),Vector2(.20,.96),Vector2(.16,1.10),Vector2(.02,1.22),Vector2(-.18,1.30),Vector2(-.40,1.37),Vector2(-.62,1.43),Vector2(-.82,1.48),Vector2(-.98,1.52),Vector2(-1.08,1.56),Vector2(-1.04,1.60),Vector2(-.90,1.64),Vector2(-.65,1.68),Vector2(-.34,1.72),Vector2(.02,1.76),Vector2(.38,1.80),Vector2(.70,1.84),Vector2(.92,1.88),Vector2(1.08,1.92),Vector2(1.16,1.96),Vector2(1.08,2.0)]
static func cone(shot: int) -> float:
	return clampf(float(shot-5)*.12,0,3.0)
static func offset(shot: int) -> Vector2:
	return Vector2.ZERO if shot<=5 else PATTERN[mini(shot-6,PATTERN.size()-1)]
static func direction(aim: Vector3, shot: int, scale: float) -> Vector3:
	var degrees=offset(shot)*scale
	var side=aim.cross(Vector3.UP).normalized()
	if side.length_squared()<.01:side=Vector3.RIGHT
	var up=side.cross(aim).normalized()
	return (aim+side*tan(deg_to_rad(degrees.x))+up*tan(deg_to_rad(degrees.y))).normalized()
