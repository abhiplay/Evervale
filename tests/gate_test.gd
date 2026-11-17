extends SceneTree
## Checks: walking into the gate starts the move to the world map, and the map shows a
## "You are here" marker at the saved place. Run: Godot --headless --path . -s res://tests/gate_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	var outside = load("res://scenes/ExteriorHome.tscn").instantiate()
	root.add_child(outside)
	for i in 3:
		await process_frame

	outside.player.position = Vector2(748, 700)
	outside._physics_process(0.0)
	check(not outside.transitioning, "the path outside the gate does not open the map")
	outside.player.position = Vector2(748, 870)
	outside._physics_process(0.0)
	check(outside.transitioning, "walking into the gate starts the move to the world map")
	check(save.state.current_location == "home", "the saved place is home when the map opens")
	outside.get_parent().remove_child(outside)
	outside.free()

	print("Arriving from the town map")
	save.state.pending_spawn = "from_map"
	var arrived = load("res://scenes/ExteriorHome.tscn").instantiate()
	root.add_child(arrived)
	for i in 3:
		await process_frame
	check(arrived.player.position.is_equal_approx(arrived.SPAWN_FROM_MAP), "arriving from the map appears just inside the gate")
	check(not arrived.transitioning, "arriving at the gate does not send the player straight back to the map")
	check(save.state.pending_spawn == "", "the gate arrival is used once")
	arrived.get_parent().remove_child(arrived)
	arrived.free()

	var map = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	for i in 3:
		await process_frame
	var home_zone: Dictionary = {}
	for zone in map.zones:
		if zone.id == "home":
			home_zone = zone
	check(not home_zone.is_empty(), "the map has a home zone")
	var z: Array = home_zone.zone
	check(map.player.position.distance_to(Vector2(z[0] + z[2] / 2.0, z[1] + z[3] / 2.0)) < 12, "the character appears at home on the map")
	check(map.locked_zone == "home", "arriving at home does not bounce straight back into the house")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
