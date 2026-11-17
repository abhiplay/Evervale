extends SceneTree
## Checks that the character can walk the roads of the town map: a route exists from Home to
## every place, and walking it actually reaches the place. Run:
## Godot --headless --path . -s res://tests/map_walk_test.gd

const CELL := 4.0
const BODY := Vector2(18, 12)

var failures: Array[String] = []
var solids: Array[Rect2] = []
var width := 1673
var height := 940


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_map_collision.json"))
	for s in parsed.solids:
		var r: Array = s.rect
		solids.append(Rect2(r[0], r[1], r[2], r[3]))

	var map = load("res://scenes/WorldMap.tscn").instantiate()
	map.get_node("..") if false else null
	root.add_child(map)
	for i in 3:
		await process_frame

	print("Routes from Home")
	var start: Vector2 = _nearest_free(map.player.position, 30.0)
	var reached := 0
	var total := 0
	for zone in map.zones:
		if zone.id == "home":
			continue
		total += 1
		var z: Array = zone.zone
		var target := _nearest_free_in(Rect2(z[0], z[1], z[2], z[3]))
		var path := _route(start, target)
		if path.is_empty():
			print("  ... no road route to %s" % zone.name)
			continue
		reached += 1
	check(reached == total, "every place on the map has a road route from Home (%d of %d)" % [reached, total])

	print("Walking the road to the Library")
	map.locked_zone = ""
	map.player.position = start
	var library_zone: Dictionary = {}
	for zone in map.zones:
		if zone.id == "library":
			library_zone = zone
	var lz: Array = library_zone.zone
	var target_lib := _nearest_free_in(Rect2(lz[0], lz[1], lz[2], lz[3]))
	var path_lib := _route(start, target_lib)
	var entered := ""
	for step in path_lib:
		var guard := 0
		while map.player.position.distance_to(step) > 6.0 and guard < 240:
			map.move_player((step - map.player.position).normalized())
			await process_frame
			guard += 1
		if map.locked_zone == "library":
			entered = "library"
			break
	check(entered == "library" or Rect2(lz[0], lz[1], lz[2], lz[3]).grow(4).has_point(map.player.position),
		"walking the road reaches the Library")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


## The closest standable point to p, searched outwards up to max_radius.
func _nearest_free(p: Vector2, max_radius: float) -> Vector2:
	if _free(p):
		return p
	for r in range(1, int(max_radius) + 1):
		for a in 16:
			var q := p + Vector2(cos(a * TAU / 16.0), sin(a * TAU / 16.0)) * r
			if _free(q):
				return q
	return p


## The standable point in a zone closest to its centre.
func _nearest_free_in(zone: Rect2) -> Vector2:
	var centre := zone.get_center()
	var best := centre
	var best_d := INF
	var y := zone.position.y
	while y <= zone.end.y:
		var x := zone.position.x
		while x <= zone.end.x:
			var q := Vector2(x, y)
			if _free(q) and q.distance_to(centre) < best_d:
				best = q
				best_d = q.distance_to(centre)
			x += 2.0
		y += 2.0
	return best


func _free(feet: Vector2) -> bool:
	var body := Rect2(feet.x - BODY.x / 2.0, feet.y - BODY.y, BODY.x, BODY.y).grow(-0.5)
	if body.position.x < 0 or body.position.y < 0 or body.end.x > width or body.end.y > height:
		return false
	for solid in solids:
		if body.intersects(solid):
			return false
	return true


## Breadth-first search over the walkable cells. Returns a list of feet positions.
func _route(from: Vector2, to: Vector2) -> Array:
	var cw := int(width / CELL)
	var ch := int(height / CELL)
	var start := Vector2i(int(from.x / CELL), int(from.y / CELL))
	var goal := Vector2i(int(to.x / CELL), int(to.y / CELL))
	var prev := {}
	var queue: Array[Vector2i] = [start]
	prev[start] = start
	var found := false
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == goal:
			found = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= cw or n.y >= ch or prev.has(n):
				continue
			if not _free(Vector2(n.x * CELL + CELL / 2.0, n.y * CELL + CELL / 2.0)):
				continue
			prev[n] = c
			queue.append(n)
	if not found:
		return []
	var out: Array = []
	var cur := goal
	while cur != start:
		out.append(Vector2(cur.x * CELL + CELL / 2.0, cur.y * CELL + CELL / 2.0))
		cur = prev[cur]
	out.reverse()
	return out
