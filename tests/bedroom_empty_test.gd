extends SceneTree
## The first scene's bedroom is empty while Amelia looks around the house: the picture has no furniture, and only the
## walls are solid. Once the look around is done, the furnished room comes back. Run:
## Godot --headless --path . -s res://tests/bedroom_empty_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


## How many solids the room has (each solid is a body with one rectangle).
func _count_bodies(room: Node) -> int:
	var count := 0
	for child in room.get_children():
		if child is StaticBody2D:
			count += 1
	return count


## True when a point lies inside one of the room's solids.
func _solid_at(room: Node, point: Vector2) -> bool:
	for body in room.get_children():
		if body is StaticBody2D:
			for shape in body.get_children():
				if shape is CollisionShape2D and shape.shape is RectangleShape2D:
					var rect := Rect2(body.position + shape.position - shape.shape.size / 2.0, shape.shape.size)
					if rect.has_point(point):
						return true
	return false


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.start_new_game()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "active"
	var empty: Texture2D = load("res://assets/environments/bedroom_upstairs_empty.webp")

	print("While the look around is active")
	var room = load("res://scenes/BedroomUpstairs.tscn").instantiate()
	root.add_child(room)
	await process_frame
	check(room.get_node("Sprite_0").texture == empty, "the picture is the empty room")
	check(room.has_node("WalkMaskSolids") and _count_bodies(room) == 1, "the empty room's walk mask is its only solid")
	check(not _solid_at(room, Vector2(510, 380)), "the left nightstand's place is open floor")
	check(not _solid_at(room, Vector2(330, 600)), "the dresser's place is open floor")
	check(not _solid_at(room, Vector2(720, 800)), "the bed's place is open floor")
	check(not _solid_at(room, Vector2(1200, 600)), "the wardrobe's place is open floor")
	check(not _solid_at(room, Vector2(290, 1000)), "the stairs opening is open")
	check(_solid_at(room, Vector2(700, 200)), "the back wall is solid")
	check(_solid_at(room, Vector2(1290, 600)), "the right wall is solid")
	check(_solid_at(room, Vector2(700, 1000)), "the front wall is solid")
	room.queue_free()
	await process_frame

	print("After the look around, still empty until they have settled in")
	save.state.world_state["house_task"] = "done"
	room = load("res://scenes/BedroomUpstairs.tscn").instantiate()
	root.add_child(room)
	await process_frame
	check(room.get_node("Sprite_0").texture == empty, "before the Our New Home talk, the room is still empty")
	room.queue_free()
	await process_frame

	print("The furnished room comes back after the Our New Home talk")
	save.state.cutscenes_viewed.append("CS-003")
	room = load("res://scenes/BedroomUpstairs.tscn").instantiate()
	root.add_child(room)
	await process_frame
	check(room.get_node("Sprite_0").texture != empty, "the furnished picture is back")
	check(room.has_node("WalkMaskSolids") and _count_bodies(room) == 1, "the furnished room's walk mask is its only solid")
	check(_solid_at(room, Vector2(510, 380)), "the left nightstand is solid again")
	room.queue_free()
	await process_frame

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
