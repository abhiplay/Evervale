extends SceneTree
## Headless checks for the temple interior: the character cannot enter any solid object, and
## the front opening leads back to the courtyard. Run:
## Godot --headless --path . -s res://tests/temple_interior_test.gd

var failures: Array[String] = []
var solids: Array[Rect2] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/temple_interior.json"))
	for s in data.solids:
		var r: Array = s.rect
		solids.append(Rect2(r[0], r[1], r[2], r[3]))

	save.state.pending_spawn = "from_courtyard"
	save.state.previous_room = "temple_courtyard"
	var room = load("res://scenes/TempleInterior.tscn").instantiate()
	room.change_scenes = false
	root.add_child(room)
	for i in 3:
		await process_frame

	print("Solid objects")
	var blocked := 0
	var tested := 0
	for solid in solids:
		var start := _free_start(solid)
		if start == Vector2.INF:
			continue
		tested += 1
		room.player.position = start
		await process_frame
		for i in 120:
			room.move_player((solid.get_center() - room.player.position).normalized())
			await process_frame
		if not _overlaps(room.player.position):
			blocked += 1
	check(tested > 0 and blocked == tested, "the player never enters a solid object (%d of %d pushes stopped)" % [blocked, tested])

	print("Front opening")
	room.player.position = Vector2(725, 920)
	room._update_prompts()
	check(room.nearby_exit.get("id", "") == "temple_interior_to_courtyard", "the way out is offered at the front opening")
	room._go_through(room.nearby_exit)
	check(save.state.pending_spawn == "from_temple_interior" and save.state.current_room == "temple_courtyard",
		"going out returns to the temple courtyard")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _overlaps(feet: Vector2) -> bool:
	var body := Rect2(feet.x - 9, feet.y - 12, 18, 12).grow(-0.5)
	for solid in solids:
		if body.intersects(solid):
			return true
	return false


func _free_start(solid: Rect2) -> Vector2:
	var c := solid.get_center()
	var reach := maxf(solid.size.x, solid.size.y) / 2.0 + 40.0
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var p: Vector2 = c + dir * reach
		if not _overlaps(p) and p.x > 0 and p.y > 0 and p.x < 1448 and p.y < 1086:
			return p
	return Vector2.INF
