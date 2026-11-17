extends SceneTree
## Checks: the bookstore floor can be walked from behind the left shelf run down to the floor
## in front of it. Run: Godot --headless --path . -s res://tests/behind_shelf_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	var shop = load("res://scenes/Bookstore.tscn").instantiate()
	root.add_child(shop)
	for i in 3:
		await process_frame
	shop.set_physics_process(false)
	shop.player.position = Vector2(400, 200)
	for i in 240:
		shop.move_player(Vector2(0, 1), 0.0)
		await physics_frame
	check(shop.player.position.y > 380, "walking down from behind the shelf reaches the floor in front of it")
	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
