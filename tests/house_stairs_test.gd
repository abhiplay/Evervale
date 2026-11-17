extends SceneTree
## Checks: walking into the stairs says the stairs' line before the stairs take Amelia to the other floor, from whichever
## side she comes. The line counts the place as checked, so the look around cannot stall on it. Each walk presses a
## direction until the floor changes, then checks the stairs' area was seen. Run:
## Godot --headless --path . -s res://tests/house_stairs_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	print("Ground floor, walking east along the stairs from the west")
	await _walk("res://scenes/HomeFloor1.tscn", Vector2(940, 500), "move_right", "staircase")
	print("Ground floor, walking north from the corridor")
	await _walk("res://scenes/HomeFloor1.tscn", Vector2(1040, 640), "move_up", "staircase")
	print("Upstairs, walking south down the bedroom stairs")
	await _walk("res://scenes/BedroomUpstairs.tscn", Vector2(300, 780), "move_down", "bedroom_stairs")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _walk(path: String, start: Vector2, action: String, area_id: String) -> void:
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "active"
	save.state.world_state["house_seen"] = []
	var scene = load(path).instantiate()
	root.add_child(scene)
	for i in 3:
		await process_frame
	scene.player.position = start
	for i in 3:
		await process_frame
	Input.action_press(action)
	var frames := 0
	while not scene.transitioning and frames < 600:
		if scene.scene_dialogue.is_open:
			scene.scene_dialogue.advance()
		await process_frame
		frames += 1
	Input.action_release(action)
	check(scene.transitioning, "the stairs take her to the other floor")
	check(save.state.world_state.get("house_seen", []).has(area_id), "%s is seen before the stairs take her" % area_id)
	root.remove_child(scene)
	scene.free()
	await process_frame
