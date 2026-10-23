extends NestMatchmaking
## Real transport connects, but an unresponsive application never accepts registration.
@rpc("any_peer","call_remote","reliable")
func join_queue(_alias: String,_version: String,_rating: Dictionary,_resume: String="") -> void:
 pass
