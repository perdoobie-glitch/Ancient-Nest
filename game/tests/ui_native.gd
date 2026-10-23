extends SceneTree
var game
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok: bool, text: String):
	checks+=1
	if ok: print("PASS: "+text)
	else: failures+=1; push_error("FAIL: "+text)
func frames(count=3):
	for i in range(count): await process_frame
func key(code):
	var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e);await frames(2)
	e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=false;Input.parse_input_event(e);await frames(2)
func focus_name():
	var node=root.gui_get_focus_owner()
	return node.text if node is Button else ""
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);root.grab_focus();await frames(8)
	check(focus_name()=="Custom Lobby","Startup keyboard focus is Custom Lobby")
	await key(KEY_UP);check(focus_name()=="Quit Game","Up wraps from first to last main-menu button")
	await key(KEY_DOWN);check(focus_name()=="Custom Lobby","Down wraps from last to first main-menu button")
	await key(KEY_ENTER);check(game.current_screen=="lobby" and not game.running,"Enter opens lobby without spawning a match")
	await key(KEY_ESCAPE);check(game.current_screen=="main","Escape returns from lobby to main menu")
	game.quit_dialog();await frames();game.modal.emit_signal("canceled");await frames();check(game.current_screen=="main","Quit cancellation stays in main menu")
	var original=game.prefs.values.duplicate(true);var original_keys=game.prefs.keys.duplicate(true)
	game.open_settings("main");game.draft_keys.jump=KEY_J;game.apply_draft();await frames()
	var loaded=NestPreferences.new();loaded.load_saved()
	check(loaded.keys.jump==KEY_J and InputMap.action_get_events("jump")[0].physical_keycode==KEY_J,"Rebound jump is saved and applied to real InputMap")
	game.settings_tab="Video";game.show_settings();game.draft.fullscreen=not game.prefs.values.fullscreen;game.apply_draft();await frames()
	check(game.display_until>0 and game.modal.visible,"Display change opens the Keep/Revert confirmation")
	game.revert_display();await frames();check(game.prefs.values.fullscreen==original.fullscreen,"Revert restores the previously confirmed display mode")
	game.prefs.values=original;game.prefs.keys=original_keys;game.prefs.apply();game.prefs.save()
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
		root.size=resolution;game.show_lobby();await frames(6)
		var panel=game.screen.get_child(1)
		var rect=panel.get_global_rect();var view=game.screen.get_global_rect()
		check(view.encloses(rect),"Lobby controls stay inside the viewport at %dx%d"%[resolution.x,resolution.y])
	root.size=Vector2i(1440,900);game.show_main();await frames()
	print("RESULT: %d native UI checks, %d failures"%[checks,failures]);game.queue_free();await frames();quit(1 if failures else 0)
