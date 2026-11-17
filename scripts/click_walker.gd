class_name ClickWalker
extends Node2D
## Click (or tap) to walk: Amelia finds her own way to the clicked spot, around walls and furniture, and a ring marks
## where she is going. When the click was on something she can use (a person, an object, the loose board), she uses it
## when she gets there, as if E had been pressed. Arrow keys or WASD take over at once and cancel the walk.
##
## The way is found on a grid of CELL pixels over the scene. A cell is free when the character's feet collision fits
## there without touching any solid; the grid is made the first time it is needed, and again after the scene's solids
## change (invalidate). Paths are straightened where the way between two points is clear.

const CELL := 8
## How close counts as reaching a point on the path, in pixels.
const ARRIVE := 6.0
## Giving up after this long without moving (something in the way that the grid did not know about, like a figure).
const STUCK_SECONDS := 0.5
const MARKER_COLOUR := Color("#e8c77a")

var _body: CharacterBody2D
var _area: Rect2
var _grid: AStarGrid2D
var _cols := 0
var _rows := 0
var _path: Array[Vector2] = []
var _interact_on_arrival := false
var _stuck_time := 0.0
var _last_position := Vector2.INF
var _marker_time := 0.0


## body is the character that walks; area is the scene's picture rectangle, which the grid covers.
func _init(body: CharacterBody2D, area: Rect2) -> void:
	_body = body
	_area = area
	z_index = 50
	visible = false


## True while Amelia is on her way somewhere.
func is_walking() -> bool:
	return not _path.is_empty()


## The scene's solids changed (the house was settled): the grid is made again next time.
func invalidate() -> void:
	_grid = null


## Sets off for the target. via, when given, is passed through first (the road in front of a place on the map).
## Returns false when there is no way there.
func go_to(target: Vector2, interact_on_arrival: bool = false, via: Vector2 = Vector2.INF) -> bool:
	var goals: Array[Vector2] = []
	if via != Vector2.INF:
		goals.append(via)
	goals.append(target)
	_path = route(_body.position, goals)
	if _path.is_empty() and _body.position.distance_to(target) > ARRIVE:
		return false
	_interact_on_arrival = interact_on_arrival
	_stuck_time = 0.0
	_last_position = _body.position
	position = target
	_marker_time = 0.0
	visible = true
	queue_redraw()
	return not _path.is_empty()


## The way from one spot through each goal in turn, as straight-line points (the start left out), without walking it.
## Scripted scenes use it to walk figures round the furniture (Night217). Empty when there is no way.
func route(from: Vector2, goals: Array[Vector2]) -> Array[Vector2]:
	_ensure_grid()
	var start := _nearest_free(_cell_of(from))
	if start.x < 0:
		return []
	var points: Array[Vector2] = [from]
	var at := start
	for goal in goals:
		var end := _nearest_free(_cell_of(goal))
		if end.x < 0:
			return []
		var ids: Array[Vector2i] = _grid.get_id_path(at, end)
		if ids.is_empty() and at != end:
			return []
		for id in ids:
			points.append(_centre(id))
		at = end
	# The last point is the target itself when the feet fit there, not just the centre of its cell.
	if points.size() > 1 and _fits(goals[goals.size() - 1]):
		points[points.size() - 1] = goals[goals.size() - 1]
	return _straightened(points)


## True when the walking character's feet fit at this spot without touching a solid.
func fits(spot: Vector2) -> bool:
	return _fits(spot)


func cancel() -> void:
	_path.clear()
	_interact_on_arrival = false
	visible = false


## The direction to walk this frame, or ZERO when not walking. Call once per physics frame. On arrival it presses E for
## the scene when the click was on something.
func steer(delta: float) -> Vector2:
	if _path.is_empty():
		return Vector2.ZERO
	while not _path.is_empty() and _body.position.distance_to(_path[0]) <= ARRIVE:
		_path.remove_at(0)
	if _path.is_empty():
		_arrive()
		return Vector2.ZERO
	if _body.position.distance_to(_last_position) < 0.5:
		_stuck_time += delta
		if _stuck_time >= STUCK_SECONDS:
			_path.clear()
			_arrive()
			return Vector2.ZERO
	else:
		_stuck_time = 0.0
	_last_position = _body.position
	return (_path[0] - _body.position).normalized()


func _arrive() -> void:
	visible = false
	if _interact_on_arrival:
		_interact_on_arrival = false
		var press := InputEventAction.new()
		press.action = "interact"
		press.pressed = true
		Input.parse_input_event(press)
		var release := InputEventAction.new()
		release.action = "interact"
		release.pressed = false
		Input.parse_input_event(release)


func _process(delta: float) -> void:
	if visible:
		_marker_time += delta
		queue_redraw()


## A gold ring at the destination that pulses gently, with a dot in the middle.
func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_marker_time * 5.0)
	draw_arc(Vector2.ZERO, 10.0 + 3.0 * pulse, 0.0, TAU, 32, Color(MARKER_COLOUR, 0.9 - 0.4 * pulse), 2.5)
	draw_circle(Vector2.ZERO, 2.5, Color(MARKER_COLOUR, 0.9))


# ---------------------------------------------------------------- the grid

func _ensure_grid() -> void:
	if _grid != null:
		return
	_cols = ceili(_area.size.x / CELL)
	_rows = ceili(_area.size.y / CELL)
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, _cols, _rows)
	_grid.cell_size = Vector2(CELL, CELL)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	var query := _feet_query()
	var space := _body.get_world_2d().direct_space_state
	var feet := _feet()
	for row in _rows:
		for col in _cols:
			query.transform = Transform2D(feet.rotation, _centre(Vector2i(col, row)) + feet.position)
			if not space.intersect_shape(query, 1).is_empty():
				_grid.set_point_solid(Vector2i(col, row), true)


func _feet() -> CollisionShape2D:
	for child in _body.get_children():
		if child is CollisionShape2D:
			return child
	return null


func _feet_query() -> PhysicsShapeQueryParameters2D:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _feet().shape
	query.collide_with_bodies = true
	query.exclude = [_body.get_rid()]
	return query


## True when the feet fit at this exact spot.
func _fits(spot: Vector2) -> bool:
	if not _area.has_point(spot):
		return false
	var query := _feet_query()
	query.transform = Transform2D(_feet().rotation, spot + _feet().position)
	return _body.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _cell_of(spot: Vector2) -> Vector2i:
	var local := spot - _area.position
	return Vector2i(clampi(int(local.x / CELL), 0, _cols - 1), clampi(int(local.y / CELL), 0, _rows - 1))


func _centre(cell: Vector2i) -> Vector2:
	return _area.position + Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)


## The free cell nearest the given one, searched in growing squares. (-1, -1) when none is near.
func _nearest_free(cell: Vector2i) -> Vector2i:
	for radius in 40:
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := cell + Vector2i(dx, dy)
				if c.x < 0 or c.y < 0 or c.x >= _cols or c.y >= _rows or _grid.is_point_solid(c):
					continue
				var d := Vector2(dx, dy).length()
				if d < best_d:
					best_d = d
					best = c
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## Drops the points in between wherever the straight line from the last kept point is clear of solid cells, so she
## walks in straight lines instead of grid steps.
func _straightened(points: Array[Vector2]) -> Array[Vector2]:
	if points.size() <= 2:
		return points.slice(1)
	var result: Array[Vector2] = [points[0]]
	var anchor := points[0]
	for i in range(1, points.size() - 1):
		if not _clear(anchor, points[i + 1]):
			result.append(points[i])
			anchor = points[i]
	result.append(points[points.size() - 1])
	# The first point is where she starts; she is already there.
	result.remove_at(0)
	return result


func _clear(a: Vector2, b: Vector2) -> bool:
	var steps := ceili(a.distance_to(b) / (CELL * 0.5))
	for s in range(steps + 1):
		var c := _cell_of(a.lerp(b, s / float(maxi(steps, 1))))
		if _grid.is_point_solid(c):
			return false
	return true
