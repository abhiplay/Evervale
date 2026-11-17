extends SceneTree
## Checks: the forest opens from the town map, the character can walk up the paths from the
## gate, and the gate at the bottom goes back to the map. Run:
## Godot --headless --path . -s res://tests/forest_test.gd

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

	check(forest.player.position.is_equal_approx(forest.SPAWN_FROM_MAP), "arriving from the map appears just inside the gate")
	check(forest.interactables.is_empty(), "the forest has no door prompt")
	check(save.state.current_location == "forest", "the saved place is the forest")
	check(forest.get_children().any(func(n): return n is StaticBody2D), "the forest has solid collisions")

	print("Walking up the path")
	for i in 60:
		forest.move_player(Vector2(0, -1), 0.0)
		await physics_frame
	check(forest.player.position.y < forest.SPAWN_FROM_MAP.y - 40, "the path goes up from the gate")
	check(not forest.transitioning, "walking up the path does not leave the forest")

	print("Going back to the map")
	forest.player.position = Vector2(790, 930)
	forest._physics_process(0.0)
	check(forest.transitioning, "walking into the gate starts the move to the world map")
	forest.get_parent().remove_child(forest)
	forest.free()

	var map = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	for i in 3:
		await process_frame
	var forest_zone: Dictionary = {}
	for zone in map.zones:
		if zone.id == "forest":
			forest_zone = zone
	check(not forest_zone.is_empty(), "the map has a forest zone")
	check(forest_zone.scene == "res://scenes/Forest.tscn", "the forest zone opens the forest scene")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
