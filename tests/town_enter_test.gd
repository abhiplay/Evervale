extends SceneTree
## Checks: the character can walk from the road into the Town square, and the map opens the
## Town Square when they do. Run: Godot --headless --path . -s res://tests/town_enter_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.current_location = "home"
	var map = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	for i in 3:
		await process_frame
	map.set_physics_process(false)
	map.locked_zone = ""
	map.player.position = Vector2(790, 745)
	var entered := false
	for i in 240:
		map.move_player(Vector2(0, -1))
		map._check_zones(0.0)
		await process_frame
		if map.transitioning:
			entered = true
			break
	check(entered, "walking up from the road into the Town square opens it")
	check(save.state.current_location == "town_square", "the saved place is the Town square")
	map.get_parent().remove_child(map)
	map.free()

	print("Leaving the Town")
	save.state.current_location = "town_square"
	var back = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(back)
	for i in 3:
		await process_frame
	back.set_physics_process(false)
	check(back.player.position.is_equal_approx(Vector2(802, 740)), "leaving the Town puts the character on the road")
	check(back.locked_zone == "" or back.locked_zone == "town_square", "the road is outside the Town zone")
	back.get_parent().remove_child(back)
	back.free()

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
