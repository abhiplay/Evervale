extends SceneTree
## Checks for the Phase 1 fixes: the temple's bottom corners are closed, the interaction prompt sits on
## the character on screen, and saved progress is loaded again. Run:
## Godot --headless --path . -s res://tests/phase1_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()

	print("Temple interior corners")
	var room = load("res://scenes/TempleInterior.tscn").instantiate()
	root.add_child(room)
	for i in 3:
		await process_frame
	room.set_physics_process(false)
	room.player.position = Vector2(1250, 915)
	for i in 60:
		room.move_player(Vector2(1, 0))
		await process_frame
	check(room.player.position.x < 1300.0, "the bottom-right corner is closed: the player cannot walk out east")
	room.player.position = Vector2(170, 915)
	for i in 60:
		room.move_player(Vector2(-1, 0))
		await process_frame
	check(room.player.position.x > 145.0, "the bottom-left corner is closed: the player cannot walk out west")
	room.get_parent().remove_child(room)
	room.free()

	print("Interaction prompt")
	var home = load("res://scenes/ExteriorHome.tscn").instantiate()
	root.add_child(home)
	for i in 3:
		await process_frame
	home.set_physics_process(false)
	home.player.position = Vector2(748, 400)
	home._update_nearby()
	var hud = root.get_node("/root/Hud")
	check(hud.prompt.prompt_text == home.ENTER_LABEL, "the door prompt appears when the player is near the door")
	home.get_parent().remove_child(home)
	home.free()

	print("Saved progress")
	save.state.completed_missions = ["M01"]
	save.state.current_location = "town_square"
	check(save.save_game(), "the progress is written")
	save.state = save.new_game_state()
	check(save.load_game(), "the saved progress is read back")
	check(save.state.completed_missions == ["M01"], "the completed missions survive a reload")
	check(save.state.current_location == "town_square", "the saved location survives a reload")
	save.state = save.new_game_state()

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
