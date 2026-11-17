extends SceneTree
## Checks: the forest's left path leads to the cave entrance, and the cave's right path leads
## back to the forest. Run: Godot --headless --path . -s res://tests/area_link_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.pending_spawn = "from_map"
	var forest = load("res://scenes/Forest.tscn").instantiate()
	root.add_child(forest)
	for i in 3:
		await process_frame

	print("Forest to the cave")
	forest.set_physics_process(false)  # the test drives the steps itself
	forest.player.position = Vector2(60, 405)
	for i in 60:
		forest.move_player(Vector2(-1, 0), 0.0)
		forest._physics_process(0.0)  # the game checks the exits every step
		await physics_frame
		if forest.transitioning:
			break
	check(forest.transitioning, "walking left out of the forest starts the move to the cave")
	check(forest.EXITS[0].scene == "res://scenes/CaveEntrance.tscn", "the left path leads to the cave entrance")
	forest.get_parent().remove_child(forest)
	forest.free()
	save.state.pending_spawn = "from_forest"

	var cave = load("res://scenes/CaveEntrance.tscn").instantiate()
	root.add_child(cave)
	for i in 3:
		await process_frame
	check(cave.player.position.is_equal_approx(cave.SPAWN_DEFAULT), "arriving from the forest appears at the right-hand path")
	check(not cave.transitioning, "arriving does not send the player straight back")
	check(cave.GATE_RECT.size == Vector2.ZERO, "the cave has no gate to the map")
	check(save.state.current_location == "forest", "the cave counts as near the forest on the map")

	print("Cave back to the forest")
	cave.player.position = Vector2(1640, 425)
	cave._physics_process(0.0)
	check(not cave.transitioning, "the path just before the right edge does not leave the cave")
	cave.player.position = Vector2(1660, 425)
	cave._physics_process(0.0)
	check(cave.transitioning, "walking off the right-hand path starts the move back to the forest")
	cave.get_parent().remove_child(cave)
	cave.free()

	print("Into the Hollow Cave")
	var mouth = load("res://scenes/CaveEntrance.tscn").instantiate()
	root.add_child(mouth)
	for i in 3:
		await process_frame
	mouth.set_physics_process(false)
	mouth.player.position = Vector2(220, 420)
	for i in 60:
		mouth.move_player(Vector2(0, -1), 0.0)
		await physics_frame
	mouth._physics_process(0.0)
	check(mouth.transitioning, "walking into the cave mouth goes inside")
	check(mouth.EXITS[1].scene == "res://scenes/CaveInterior.tscn", "the mouth leads to the cave interior")
	mouth.get_parent().remove_child(mouth)
	mouth.free()
	save.state.pending_spawn = "from_entrance"

	var inside = load("res://scenes/CaveInterior.tscn").instantiate()
	root.add_child(inside)
	for i in 3:
		await process_frame
	inside.set_physics_process(false)
	check(inside.player.position.is_equal_approx(inside.SPAWNS["from_entrance"]), "arriving from the entrance appears by the pool")
	inside.player.position = Vector2(335, 840)
	inside._physics_process(0.0)
	check(inside.transitioning, "the way out of the cave interior leads back to the entrance")
	inside.get_parent().remove_child(inside)
	inside.free()

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
