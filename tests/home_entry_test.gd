extends SceneTree
## Checks: the Home zone opens only when the character comes up from the road in front of the
## gate. Walking along the road from either side does not open it. Run:
## Godot --headless --path . -s res://tests/home_entry_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func fresh_map() -> Node:
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.current_location = "town_square"
	var map = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	return map


func _initialize() -> void:
	await process_frame
	var map = fresh_map()
	for i in 3:
		await process_frame
	map.set_physics_process(false)
	map.locked_zone = ""
	map.transitioning = false

	print("Coming up from the road in front of the gate")
	map.player.position = Vector2(685, 540)
	map._check_zones(0.0)
	map.player.position = Vector2(685, 520)
	map._check_zones(0.0)
	map.player.position = Vector2(685, 500)
	map._check_zones(0.0)
	check(map.transitioning, "walking up from the road below the gate opens the home")
	map.get_parent().remove_child(map)
	map.free()

	print("Walking along the road")
	map = fresh_map()
	for i in 3:
		await process_frame
	map.set_physics_process(false)
	map.locked_zone = ""
	map.player.position = Vector2(560, 497)
	map._check_zones(0.0)
	map.player.position = Vector2(620, 497)
	map._check_zones(0.0)
	map.player.position = Vector2(700, 497)
	map._check_zones(0.0)
	map.player.position = Vector2(760, 497)
	map._check_zones(0.0)
	check(not map.transitioning, "walking along the road past the gate does not open the home")
	map.get_parent().remove_child(map)
	map.free()

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
