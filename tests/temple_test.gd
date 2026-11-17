extends SceneTree
## Headless checks for the temple courtyard: collisions, the door, the gate, the arrivals,
## and the link to the temple interior and the map. Run:
## Godot --headless --path . -s res://tests/temple_test.gd

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
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/temple_courtyard_collision.json"))
	for s in parsed.solids:
		var r: Array = s.rect
		solids.append(Rect2(r[0], r[1], r[2], r[3]))

	var court = load("res://scenes/TempleCourtyard.tscn").instantiate()
	root.add_child(court)
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
		court.player.position = start
		await process_frame
		for i in 150:
			court.move_player((solid.get_center() - court.player.position).normalized(), 0.0)
			await process_frame
		if not _overlaps(court.player.position):
			blocked += 1
	check(tested > 0 and blocked == tested, "the player never enters a solid object (%d of %d pushes stopped)" % [blocked, tested])

	print("Door and gate")
	court.player.position = Vector2(840, 395)
	court._update_nearby()
	check(not court.nearby.is_empty() and court.nearby.id == "enter", "the door prompt appears from the steps")
	court.player.position = Vector2(840, 520)
	court._update_nearby()
	check(court.nearby.is_empty(), "no prompt on the path away from the door")
	court.player.position = Vector2(840, 830)
	court._physics_process(0.0)
	check(court.transitioning, "walking into the gate starts the move to the map")
	court.transitioning = false
	court.get_parent().remove_child(court)
	court.free()
	# The gate's fade ends with a scene change to the map. Let it finish, then remove the map: its shapes
	# share the physics space, so they would push the courtyard player during the arrival check.
	await create_timer(0.5).timeout
	for child in root.get_children():
		if child.name == "WorldMap":
			root.remove_child(child)
			child.free()
	current_scene = null

	print("Arrivals")
	save.state.pending_spawn = "from_map"
	var from_map = load("res://scenes/TempleCourtyard.tscn").instantiate()
	root.add_child(from_map)
	for i in 3:
		await process_frame
	check(from_map.player.position.is_equal_approx(from_map.SPAWN_FROM_MAP), "arriving from the map appears just inside the gate")
	check(not from_map.transitioning, "arriving at the gate does not send the player straight back to the map")
	from_map.get_parent().remove_child(from_map)
	from_map.free()

	save.state.pending_spawn = "from_temple_interior"
	var from_inside = load("res://scenes/TempleCourtyard.tscn").instantiate()
	root.add_child(from_inside)
	for i in 3:
		await process_frame
	check(from_inside.player.position.is_equal_approx(Vector2(840, 390)), "coming out of the temple appears on the steps")
	from_inside.get_parent().remove_child(from_inside)
	from_inside.free()

	print("Temple interior and the map")
	save.state.pending_spawn = "from_courtyard"
	save.state.previous_room = "temple_courtyard"
	var interior = load("res://scenes/TempleInterior.tscn").instantiate()
	root.add_child(interior)
	for i in 3:
		await process_frame
	check(interior.player.position.distance_to(Vector2(725, 850)) < 8.0, "entering the temple places the player at the entrance")
	interior.get_parent().remove_child(interior)
	interior.free()
	var map_data: Dictionary = {}
	var data = root.get_node("/root/GameData")
	for loc in data.locations.values():
		if loc.id == "temple":
			map_data = loc
	check(map_data.get("scene", "") == "res://scenes/TempleCourtyard.tscn", "the map's temple place opens the courtyard")

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
		if not _overlaps(p) and p.x > 0 and p.y > 0 and p.x < 1672 and p.y < 940:
			return p
	return Vector2.INF
