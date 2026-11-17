extends SceneTree
## Checks: the café door in the Town square opens the café, the café floor can be walked, and its
## front door leads back to the Town square. Run: Godot --headless --path . -s res://tests/cafe_test.gd

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
	var town = load("res://scenes/TownSquare.tscn").instantiate()
	root.add_child(town)
	for i in 3:
		await process_frame
	town.set_physics_process(false)
	town.player.position = Vector2(652, 474)
	town._physics_process(0.0)
	check(town.transitioning, "walking into the café door goes inside")
	check(save.state.pending_spawn == "from_town", "the café is entered from the town")
	town.get_parent().remove_child(town)
	town.free()
	save.state.pending_spawn = "from_town"

	var cafe = load("res://scenes/Cafe.tscn").instantiate()
	root.add_child(cafe)
	for i in 3:
		await process_frame
	cafe.set_physics_process(false)
	check(cafe.player.position.is_equal_approx(Vector2(835, 740)), "arriving from the town appears inside the front")
	cafe.player.position = Vector2(835, 740)
	for i in 60:
		cafe.move_player(Vector2(-1, -0.4).normalized(), 0.0)
		await process_frame
	check(cafe.player.position.x < 830 and cafe.player.position.y < 735, "the café floor can be walked")
	cafe.player.position = Vector2(835, 840)
	cafe._physics_process(0.0)
	check(cafe.transitioning, "walking out of the front door goes back to the town")
	check(save.state.pending_spawn == "from_cafe", "the town is entered at the café door")
	cafe.get_parent().remove_child(cafe)
	cafe.free()

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
