extends NestMatchmaking
## Protocol test client: load the world but deliberately withhold its ready packet.
## Same RPC declaration/table as production; only the application readiness differs.
@rpc("authority","call_remote","reliable")
func prepare(config: Dictionary,members: Dictionary,revision: int,rejoining: bool) -> void:
 if not active or local_slot==0:return
 epoch=revision;phase="rejoining" if rejoining else "loading";public_state.members=members
 game.begin_network_match(config,members)
 game.clear_held_input();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 changed()
