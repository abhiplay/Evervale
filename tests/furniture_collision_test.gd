extends SceneTree
## Checks: in the bookstore, the character cannot walk into any piece of furniture from the front. Each piece's solid base is
## as wide as the piece's drawn base, so there is no gap at its corners. Frame limits only. Run:
## Godot --headless --path . -s res://tests/furniture_collision_test.gd

const DATA := "res://data/bookstore_interior_collision.json"
const FURNITURE_IDS := ["reading_corner_base", "trailing_shelf_left_base", "trailing_shelf_right_base", "display_table_top_base", "display_table_bottom_base", "reading_table_left_base", "reading_table_right_base"]

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
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var rects := {}
	for solid in data.solids:
		rects[solid.id] = Rect2(solid.rect[0], solid.rect[1], solid.rect[2], solid.rect[3])

	print("Walking into each piece from the front")
	for id in FURNITURE_IDS:
		var rect: Rect2 = rects[id]
		var bottom := rect.end.y
		var start := Vector2(rect.get_center().x, bottom + 90)
		shop.player.position = start
		for i in 180:
			shop.move_player(Vector2(0, -1), 0.0)
			await physics_frame
		# The feet (the player's origin) must stop at the piece's base line, never above it.
		check(shop.player.position.y >= bottom - 1.0, "%s stops the character at its base (feet at %.0f, base at %.0f)" % [id, shop.player.position.y, bottom])
		shop.move_player(Vector2.ZERO, 0.0)

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
