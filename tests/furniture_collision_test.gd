extends SceneTree
## Checks: in the bookstore, the character cannot walk into any piece of furniture's solid from the front. The solids are read
## from the scene file, where they can be moved in the editor. The character stops at the solid's near edge, with her collider
## just touching it. Frame limits only. Run:
## Godot --headless --path . -s res://tests/furniture_collision_test.gd

## The collider at the feet reaches 12 px above the feet, so the feet stop 12 px below the solid's bottom edge.
const FEET_REACH := 12.0

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


## The rectangle a solid body covers in the room, from its position, its shape's offset and its size.
func _solid_rect(body: Node2D) -> Rect2:
	for child in body.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var size: Vector2 = child.shape.size
			var centre: Vector2 = body.position + child.position
			return Rect2(centre - size / 2.0, size)
	return Rect2()


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

	print("Walking into each piece's solid from the front")
	var pieces := []
	for child in shop.get_children():
		if child is StaticBody2D and String(child.name).begins_with("Solid_") and String(child.name).ends_with("_base"):
			pieces.append(child)
	check(pieces.size() == 7, "the room has its seven furniture solids (%d)" % pieces.size())
	for body in pieces:
		var rect := _solid_rect(body)
		shop.player.position = Vector2(rect.get_center().x, rect.end.y + 90)
		for i in 180:
			shop.move_player(Vector2(0, -1), 0.0)
			await physics_frame
		var expected := rect.end.y + FEET_REACH
		check(absf(shop.player.position.y - expected) <= 2.0, "%s stops her at its near edge (feet %.0f, expected %.0f)" % [body.name, shop.player.position.y, expected])
		shop.move_player(Vector2.ZERO, 0.0)

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
