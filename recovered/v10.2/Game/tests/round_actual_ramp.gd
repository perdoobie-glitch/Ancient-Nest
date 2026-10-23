extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.lobby_network.set_process(false);game.lobby_network=null;await process_frame
 var rules=GameTypeSettings.new();rules.mode=2;rules.bots_fill_empty_slots=false;game.apply_game_type_settings(rules);game.start_game();game.clear_screen();game.current_screen="playing";game.context="playing";Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;game.input_window_focused=true;game.create_hud()
 var p=game.player;p.set_physics_process(false);p.respawn();p.global_position=Vector3(0,0,-18.7)*.85+Vector3.UP*.09;p.rotation.y=-PI;p.reset_physics_interpolation();p.set_physics_process(true)
 for i in range(8):await physics_frame
 Input.action_press("forward")
 for i in range(240):await physics_frame
 Input.action_release("forward");p.set_physics_process(false)
 print("ACTUAL ",p.global_position," ctrl ",p.controlled," velocity ",p.velocity," floor ",p.is_on_floor()," active ",p.input_active()," yaw ",p.rotation.y)
 var passed=p.global_position.y>5.7
 print("ACTUAL RAMP: 1 checks, ",0 if passed else 1," failures")
 game.stop_game();game.queue_free();await process_frame;quit(0 if passed else 1)
