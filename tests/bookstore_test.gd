extends SceneTree
## Checks: the bookstore door in the Town square opens the bookstore, the bookstore floor can be
## walked, and its front door leads back to the Town square. Run:
## Godot --headless --path . -s res://tests/bookstore_test.gd

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
	town.player.position = Vector2(333, 540)
	town._physics_process(0.0)
	check(not town.transitioning, "standing in front of the bookstore does not go in by itself")
	town.player.position = Vector2(333, 474)
	town._physics_process(0.0)
	check(town.transitioning, "walking into the bookstore door goes inside")
	check(save.state.pending_spawn == "from_town", "the bookstore is entered from the town")
	town.get_parent().remove_child(town)
	town.free()
	save.state.pending_spawn = "from_town"

	var shop = load("res://scenes/Bookstore.tscn").instantiate()
	root.add_child(shop)
	for i in 3:
		await process_frame
	shop.set_physics_process(false)
	check(shop.player.position.is_equal_approx(Vector2(838, 740)), "arriving from the town appears inside the front")
	shop.player.position = Vector2(838, 740)
	for i in 60:
		shop.move_player(Vector2(-1, -0.4).normalized(), 0.0)
		await process_frame
	check(shop.player.position.x < 830 and shop.player.position.y < 735, "the bookstore floor can be walked")
	shop.player.position = Vector2(838, 830)
	shop._physics_process(0.0)
	check(shop.transitioning, "walking out of the front door goes back to the town")
	check(save.state.pending_spawn == "from_bookstore", "the town is entered at the bookstore door")
	shop.get_parent().remove_child(shop)
	shop.free()

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
