extends SceneTree
## Checks: the courtyard door leads into the ground floor, the character can walk from the
## door into the hall and the kitchen, and the front door goes back out to the courtyard.
## Run: Godot --headless --path . -s res://tests/home_floor1_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.pending_spawn = "from_exterior"
	var home = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(home)
	for i in 3:
		await process_frame
	home.set_physics_process(false)
	check(home.player.position.is_equal_approx(Vector2(725, 880)), "arriving from the courtyard appears at the front door, inside")

	print("Walking the floor")
	home.player.position = Vector2(725, 880)
	for i in 120:
		home.move_player(Vector2(0, -1), 0.0)
		await process_frame
	check(home.player.position.y < 760, "the hall is walkable upward from the front door")
	home.player.position = Vector2(1100, 700)
	for i in 60:
		home.move_player(Vector2(-1, 0), 0.0)
		await process_frame
	check(home.player.position.x < 1040, "the kitchen opens into the hall")

	print("Leaving by the front door")
	home.player.position = Vector2(725, 900)
	for i in 60:
		home.move_player(Vector2(0, 1), 0.0)
		await process_frame
		home._physics_process(0.0)
		if home.transitioning:
			break
	check(home.transitioning, "walking out of the front door goes back to the courtyard")
	check(save.state.pending_spawn == "from_home", "the courtyard is entered at the house door")
	home.get_parent().remove_child(home)
	home.free()

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
