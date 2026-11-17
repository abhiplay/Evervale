extends SceneTree
## Checks: the beach is a solid block with its zone on the road above it (not built yet);
## the Lighthouse zone opens the lighthouse front; the front arrives from the map, and its gate
## goes back. Run: Godot --headless --path . -s res://tests/beach_lighthouse_test.gd

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

	print("Beach")
	var map = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	for i in 3:
		await process_frame
	map.set_physics_process(false)
	map.locked_zone = ""
	map.player.position = Vector2(540, 735)
	for i in 200:
		map.move_player(Vector2(0, 1))
		await process_frame
	check(map.player.position.y < 750.0, "the beach is solid: walking south from its zone stops at the sand")

	map.player.position = Vector2(250, 728)
	map.locked_zone = ""
	for i in 200:
		map.move_player(Vector2(1, 0))
		map._check_zones(0.0)
		await process_frame
		if map.locked_zone == "beach":
			break
	check(map.locked_zone == "beach" and map.message_label.text == "Beach is not built yet.",
		"walking east along the road into the Beach zone says it is not built yet")
	map.get_parent().remove_child(map)
	map.free()

	print("Lighthouse")
	save.state.current_location = "home"
	var lit = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(lit)
	for i in 3:
		await process_frame
	lit.set_physics_process(false)
	lit.locked_zone = ""
	lit.player.position = Vector2(285, 712)
	for i in 240:
		lit.move_player(Vector2(0, 1))
		lit._check_zones(0.0)
		await process_frame
		if lit.transitioning:
			break
	check(lit.transitioning and save.state.current_location == "lighthouse",
		"walking down the path into the Lighthouse zone opens the lighthouse front")
	lit.get_parent().remove_child(lit)
	lit.free()

	print("The lighthouse front")
	save.state.pending_spawn = "from_map"
	var front = load("res://scenes/LighthouseFront.tscn").instantiate()
	root.add_child(front)
	for i in 3:
		await process_frame
	front.set_physics_process(false)
	check(front.player.position.is_equal_approx(front.SPAWN_FROM_MAP), "arriving from the map appears just inside the gate")
	check(not front.transitioning, "arriving does not send the player straight back to the map")
	for i in 60:
		front.move_player(Vector2(0, -1), 0.0)
		await process_frame
	front._physics_process(0.0)
	check(front.transitioning, "walking north through the gate goes back to the map")
	front.get_parent().remove_child(front)
	front.free()
	await create_timer(0.5).timeout
	for child in root.get_children():
		if child.name == "WorldMap":
			root.remove_child(child)
			child.free()
	current_scene = null

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
