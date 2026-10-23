extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.lobby_network.set_process(false);game.forge_session.start();await process_frame
 var m=game.forge_session.model
 print("V26 REGISTRY ",m.records.size()," records; ",m.originals.size()," base; markers ",m.markers.size())
 var state=m.capture();print("LAYOUT valid=",m.validate(state)," bytes=",var_to_bytes(state).size())
 for record in state.base:
  if not m.valid_record(record):print("INVALID RECORD ",record.key," ",record)
 print("NEST FORGE UI ",game.current_screen," ",game.forge_editor.editing)
 game.forge_session.stop_editing();game.close_connection();game.queue_free();await process_frame;quit()
