extends SceneTree
## Checks: the reading corner's rug is floor that the character walks over (never drawn over her), and the armchair,
## lamp, side table and plant are depth-sorted by their own base lines, so she is drawn over the armchair from the front
## and behind it from the back. Run: Godot --headless --path . -s res://tests/reading_corner_depth_test.gd

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
	current_scene = shop
	for i in 3:
		await process_frame
	shop.set_physics_process(false)

	print("The rug is floor, the furniture is sorted")
	var rug: Sprite2D = shop.find_child("Reading_rug", true, false)
	check(rug.z_index < 0 and not rug.has_meta("furniture"), "the rug is floor under the character")
	var depth_root: Node2D = shop._depth_root
	check(rug.get_parent() == shop, "the rug is not in the depth-sorted group")
	var pieces := ["Reading_chair", "Reading_lamp", "Reading_table", "Reading_plant"]
	for piece_name in pieces:
		var piece: Node2D = shop.find_child(piece_name, true, false)
		check(piece != null and piece.get_parent() == depth_root, "%s is depth-sorted with the character" % piece_name)
	var chair: Node2D = shop.find_child("Reading_chair", true, false)
	check(absf(chair.position.y - 290.4) < 0.5, "the armchair's base is its seat edge (%.1f)" % chair.position.y)

	print("The character walks over the rug in front of the armchair")
	shop.player.position = Vector2(320, 420)
	for i in 120:
		shop.move_player(Vector2(0, -1), 0.0)
		await physics_frame
	check(shop.player.position.y > 295 and shop.player.position.y < 310, "she stops on the rug in front of the armchair (feet %.0f)" % shop.player.position.y)
	check(shop.player.position.y > chair.position.y, "from there she is in front of the armchair, so it is drawn under her")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
