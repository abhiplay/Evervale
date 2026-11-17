extends SceneTree
## Checks: the Town square opens from the map, Henry's talk completes the first step, and the florist
## door walks into the florist shop. Run: Godot --headless --path . -s res://tests/town_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.completed_missions = ["M01"]
	save.state.pending_spawn = "from_map"
	var town = load("res://scenes/TownSquare.tscn").instantiate()
	root.add_child(town)
	for i in 3:
		await process_frame
	town.set_physics_process(false)

	print("Town square")
	check(town.player.position.is_equal_approx(Vector2(760, 640)), "arriving from the map appears by the kerb")
	check(save.state.current_location == "town_square", "current location is the town square")
	check(not save.state.completed_missions.has("M02"), "First Steps is not done until Henry is met")

	print("Meeting Henry")
	town.player.position = Vector2(760, 560)
	town._update_nearby()
	check(town.nearby.get("id", "") == "henry_collins", "standing by Henry offers to talk")
	town._interact(town.nearby)
	check(save.state.completed_missions.has("M02"), "talking to Henry completes M02")
	town._advance_dialogue()
	town._advance_dialogue()
	check(not town.dialogue_open, "dialogue closes after its last line")

	print("Shop doors")
	var florist_door := false
	for exit in town.EXITS:
		if exit.scene == "res://scenes/Florist.tscn":
			florist_door = true
	check(florist_door, "the florist door walks into the florist shop")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
