class_name NestControlPolicy
extends RefCounted
static var defaults: Dictionary={}
static func settings() -> Dictionary:
	if defaults.is_empty():defaults=JSON.parse_string(FileAccess.get_file_as_string("res://data/network_defaults.json"))
	return defaults
static func retry_delay(attempt: int, random_value: float=.5, retry_after: float=0) -> float:
	return maxf(retry_after,minf(float(settings().retry_cap_seconds),pow(2,mini(8,maxi(0,attempt))))*(.5+.5*clampf(random_value,0,1)))
