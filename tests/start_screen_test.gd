extends SceneTree
## Checks: the title screen's buttons sit over the picture's buttons, Continue and Load Game are only on when
## there is a save, every button stays inside the window at desktop and phone sizes, and a new game starts
## the opening again. Run: Godot --headless --path . -s res://tests/start_screen_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _screen() -> Control:
	var screen: Control = load("res://scenes/StartScreen.tscn").instantiate()
	root.add_child(screen)
	return screen


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	# Start with no save file, so the first checks see a new player.
	var files := DirAccess.open("user://")
	if files.file_exists(save.save_path.get_file()):
		files.remove(save.save_path.get_file())

	print("Buttons without a save")
	var screen := _screen()
	for i in 3:
		await process_frame
	var buttons: Dictionary = screen._buttons
	check(buttons.size() == 7, "seven menu buttons")
	check(not buttons["new_game"].disabled, "New Game is always on")
	check(buttons["continue"].disabled, "Continue is off without a save")
	check(buttons["load_game"].disabled, "Load Game is off without a save")
	check(not buttons["quit"].disabled, "Quit is always on")
	screen.queue_free()
	await process_frame

	print("Buttons with a save")
	save.save_game()
	screen = _screen()
	for i in 3:
		await process_frame
	buttons = screen._buttons
	check(not buttons["continue"].disabled, "Continue is on once there is a save")
	check(not buttons["load_game"].disabled, "Load Game is on once there is a save")
	check(screen._confirm.visible == false, "the New Game question is hidden at the start")
	screen._on_pressed("new_game")
	check(screen._confirm.visible, "New Game asks first when there is a save")
	screen._hide_confirm()
	check(not screen._confirm.visible, "Cancel hides the question")
	screen._on_pressed("settings")
	check(screen._notice.visible and screen._notice.text == "Coming soon", "unbuilt menu items say so")
	screen.queue_free()
	await process_frame

	print("Layout")
	screen = _screen()
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	buttons = screen._buttons
	for window in [Vector2(960, 540), Vector2(390, 844), Vector2(1920, 1080)]:
		screen.size = window
		await process_frame
		var inside := true
		for key in buttons:
			var rect: Rect2 = buttons[key].get_rect()
			if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > window.x or rect.end.y > window.y:
				inside = false
		check(inside, "every button is inside a %dx%d window" % [window.x, window.y])
	# At 960 x 540 the picture is exactly the window, so New Game sits at the picture's own place.
	screen.size = Vector2(960, 540)
	await process_frame
	var new_game: Rect2 = buttons["new_game"].get_rect()
	var scale := 960.0 / 1672.0
	var picture_centre := Vector2(1297 + 323 / 2.0, 347 + 67 / 2.0) * scale
	check(new_game.get_center().distance_to(picture_centre) < 1.0, "New Game's plate covers the picture's New Game")
	screen.queue_free()
	await process_frame

	print("New game")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.save_game()
	save.start_new_game()
	check(save.state.world_state.get("opening_stage", "") == "pending", "a new game starts the opening again")
	check(save.has_save(), "a new game is saved")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
