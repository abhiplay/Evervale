extends SceneTree
## Checks: every area of the house can be walked into on foot. Each floor is searched from its entry points the way
## Amelia would walk: walls and furniture stop her, and a door or the stairs is never walked through. An area nobody can
## reach would stop the look around from ever being finished. Run:
## Godot --headless --path . -s res://tests/house_reach_test.gd
## Add the word map after -- to save a picture of each floor (walkable ground in green, areas outlined) to user://.

const STEP := 4.0
const NEAREST_SEARCH := 16

var failures: Array[String] = []
var _data: Dictionary


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _rect(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/home_events.json"))
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "active"
	var want_map := OS.get_cmdline_user_args().has("map")

	print("Ground floor")
	await _check_floor("res://scenes/HomeFloor1.tscn", "home_floor1", save.state.world_state, want_map)
	print("Upstairs")
	await _check_floor("res://scenes/BedroomUpstairs.tscn", "bedroom_upstairs", save.state.world_state, want_map)
	print("Ground floor, settled (after the box talk)")
	save.state.world_state["house_task"] = "done"
	save.state.world_state["box_talk_done"] = true
	await _check_settled(save.state.world_state)

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _check_floor(path: String, scene_id: String, world: Dictionary, want_map: bool) -> void:
	var scene = load(path).instantiate()
	root.add_child(scene)
	for i in 3:
		await process_frame
	var grid := _walkable_grid(scene, world)
	var starts: Array = []
	for spawn_name in scene.SPAWNS:
		starts.append(scene.SPAWNS[spawn_name])
	var reached := _reached_from(grid, starts)
	print("  %d walkable spots, %d reached from %d entry points" % [_count(grid.free), _count(reached), starts.size()])
	for area in _data.areas:
		if area.scene != scene_id:
			continue
		var spots := _reached_spots(grid, reached, _rect(area.rect))
		check(spots > 0, "%s can be walked into on foot, rect %s" % [area.id, str(area.rect)])
	if want_map:
		_save_map(scene, grid, reached, world)
	root.remove_child(scene)
	scene.free()
	await process_frame


## The settled ground floor: the front door, the stairs, the radio, the kitchen and both pets can be reached on foot from
## where Amelia enters, and the pets do not sit on furniture.
func _check_settled(world: Dictionary) -> void:
	var scene = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(scene)
	for i in 3:
		await process_frame
	check(scene.settled, "the house is settled once the box talk is over")
	var grid := _walkable_grid(scene, world)
	var starts: Array = []
	for spawn_name in scene.SPAWNS:
		starts.append(scene.SPAWNS[spawn_name])
	var reached := _reached_from(grid, starts)
	for exit in scene.EXITS:
		check(_reached_spots(grid, reached, exit.rect.grow(24)) > 0, "the %s can be walked to" % exit.scene.get_file().get_basename())
	check(_reached_spots(grid, reached, Rect2(Vector2(500, 790) - Vector2(60, 60), Vector2(120, 120))) > 0, "the radio can be walked up to")
	check(_reached_spots(grid, reached, Rect2(985, 675, 325, 195)) > 0, "the kitchen can be walked into")
	check(_reached_spots(grid, reached, Rect2(scene.SETTLED_SPOT - Vector2(8, 8), Vector2(16, 16))) > 0, "where Amelia stands after the box talk is reachable")
	var pets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/home_pets.json"))
	for pet in pets.pets:
		var spot := Vector2(pet.settled_pos[0], pet.settled_pos[1])
		check(_reached_spots(grid, reached, Rect2(spot - Vector2(50, 50), Vector2(100, 100))) > 0, "%s can be walked up to" % pet.name)
		var on_furniture := false
		for rect in scene.settled_solids():
			if rect.has_point(spot):
				on_furniture = true
		check(not on_furniture, "%s does not sit on furniture" % pet.name)
	root.remove_child(scene)
	scene.free()
	await process_frame


## The spots Amelia's feet can stand on. A spot is walkable when her feet collision fits there without touching a wall
## or furniture, and it is not a door or the stairs.
func _walkable_grid(scene, world: Dictionary) -> Dictionary:
	var image_size: Vector2 = scene.IMAGE_SIZE
	var cols := int(ceil(image_size.x / STEP))
	var rows := int(ceil(image_size.y / STEP))
	var free := PackedByteArray()
	free.resize(cols * rows)
	var feet_collision: CollisionShape2D = null
	for child in scene.player.get_children():
		if child is CollisionShape2D:
			feet_collision = child
			break
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = feet_collision.shape
	query.collision_mask = scene.player.collision_mask
	query.exclude = [scene.player.get_rid()]
	var space: PhysicsDirectSpaceState2D = scene.get_world_2d().direct_space_state
	for row in rows:
		for col in cols:
			var feet := Vector2(col * STEP, row * STEP)
			if _through_a_door(scene, feet, world):
				continue
			query.transform = Transform2D(feet_collision.rotation, feet + feet_collision.position)
			if space.intersect_shape(query, 1).is_empty():
				free[row * cols + col] = 1
	return {"cols": cols, "rows": rows, "free": free}


func _through_a_door(scene, feet: Vector2, world: Dictionary) -> bool:
	if scene.GATE_RECT.has_point(feet):
		return true
	for exit in scene.EXITS:
		if exit.has("requires") and not world.get(exit.requires, false):
			continue
		if exit.rect.has_point(feet):
			return true
	return false


## Every walkable spot that can be reached on foot from one of the entry points.
func _reached_from(grid: Dictionary, starts: Array) -> PackedByteArray:
	var cols: int = grid.cols
	var rows: int = grid.rows
	var free: PackedByteArray = grid.free
	var reached := PackedByteArray()
	reached.resize(cols * rows)
	var queue: Array = []
	for start in starts:
		var index := _nearest_free(grid, start)
		if index >= 0 and reached[index] == 0:
			reached[index] = 1
			queue.append(index)
	var head := 0
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		var col := index % cols
		var row: int = index / cols
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next_col: int = col + offset.x
			var next_row: int = row + offset.y
			if next_col < 0 or next_row < 0 or next_col >= cols or next_row >= rows:
				continue
			var next: int = next_row * cols + next_col
			if free[next] == 1 and reached[next] == 0:
				reached[next] = 1
				queue.append(next)
	return reached


func _nearest_free(grid: Dictionary, spot: Vector2) -> int:
	var cols: int = grid.cols
	var rows: int = grid.rows
	var free: PackedByteArray = grid.free
	var centre_col := int(round(spot.x / STEP))
	var centre_row := int(round(spot.y / STEP))
	for radius in range(NEAREST_SEARCH + 1):
		for row in range(centre_row - radius, centre_row + radius + 1):
			for col in range(centre_col - radius, centre_col + radius + 1):
				if col < 0 or row < 0 or col >= cols or row >= rows:
					continue
				if free[row * cols + col] == 1:
					return row * cols + col
	return -1


## How many reached spots lie inside the area. The area counts as walked into when Amelia's feet are inside it.
func _reached_spots(grid: Dictionary, reached: PackedByteArray, rect: Rect2) -> int:
	var count := 0
	for row in range(int(rect.position.y / STEP), int(rect.end.y / STEP) + 1):
		for col in range(int(rect.position.x / STEP), int(rect.end.x / STEP) + 1):
			if col < 0 or row < 0 or col >= grid.cols or row >= grid.rows:
				continue
			var feet := Vector2(col * STEP, row * STEP)
			if rect.has_point(feet) and reached[row * grid.cols + col] == 1:
				count += 1
	return count


func _count(cells: PackedByteArray) -> int:
	var total := 0
	for cell in cells:
		total += cell
	return total


func _save_map(scene, grid: Dictionary, reached: PackedByteArray, world: Dictionary) -> void:
	var image := Image.create(grid.cols * 2, grid.rows * 2, false, Image.FORMAT_RGB8)
	for row in grid.rows:
		for col in grid.cols:
			var index: int = row * grid.cols + col
			var colour := Color(0.1, 0.08, 0.07)
			if grid.free[index] == 1:
				colour = Color(0.45, 0.85, 0.45) if reached[index] == 1 else Color(0.6, 0.6, 0.6)
			elif _through_a_door(scene, Vector2(col * STEP, row * STEP), world):
				colour = Color(0.9, 0.3, 0.3)
			image.fill_rect(Rect2i(col * 2, row * 2, 2, 2), colour)
	var pixels_per_unit := 2.0 / STEP
	for area in _data.areas:
		if area.scene != scene.SCENE_ID:
			continue
		var rect := _rect(area.rect)
		var box := Rect2i(int(rect.position.x * pixels_per_unit), int(rect.position.y * pixels_per_unit), int(rect.size.x * pixels_per_unit), int(rect.size.y * pixels_per_unit))
		var colour := Color(1, 0.85, 0.2) if _reached_spots(grid, reached, rect) > 0 else Color(1, 0, 1)
		image.fill_rect(Rect2i(box.position.x, box.position.y, box.size.x, 2), colour)
		image.fill_rect(Rect2i(box.position.x, box.end.y - 2, box.size.x, 2), colour)
		image.fill_rect(Rect2i(box.position.x, box.position.y, 2, box.size.y), colour)
		image.fill_rect(Rect2i(box.end.x - 2, box.position.y, 2, box.size.y), colour)
	var path := "user://house_reach_%s.png" % scene.SCENE_ID
	image.save_png(path)
	print("  picture saved to %s" % ProjectSettings.globalize_path(path))
