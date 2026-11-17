class_name FloorMap
extends Control
## The indoor map, opened from the Map button inside a building. The building's rooms are drawn as boxes on a plan, the room the
## protagonist is in has a pin, and the doors and stairs between rooms are drawn where they are. A locked room is drawn red
## and a link into one is red too. Closes with the Map button again, or Escape. While it is open, the game takes no movement.
## The plan comes from FloorPlan (data/floor_plans.json).

const PLAN_SIZE := Vector2(560, 340)
const BACKDROP := Color(0.03, 0.025, 0.02, 0.9)
const ROOM_FILL := Color(0.2, 0.14, 0.09, 0.95)
const ROOM_EDGE := Color("#8a6d3b")
const GOLD := Color("#e8c77a")
const TEXT := Color("#f3e3c3")
const LOCKED_FILL := Color(0.4, 0.07, 0.07, 0.95)
const LOCKED_EDGE := Color("#ff5a5a")
const DOOR_OPEN := Color("#4fc3c0")
const DOOR_LOCKED := Color("#d64545")
const DOOR_SIZE := 16.0
const PULSE_SECONDS := 1.6

var _plan: Dictionary = {}
var _current := ""
var _scale := 1.0
var _origin := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


## Opens the map of a plan, with the room the protagonist is in (its id) marked with the pin.
func show_plan(plan: Dictionary, room_id: String) -> void:
	_plan = plan
	_current = room_id
	# Covers the whole screen: a CanvasLayer is not a Control, so the size is set rather than left to the anchors.
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_layout()
	visible = true
	HudEvents.screen_open = true
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	HudEvents.screen_open = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## The plan is scaled to fill most of the screen, and centred.
func _layout() -> void:
	var view := get_viewport_rect().size
	_scale = minf(view.x * 0.84 / PLAN_SIZE.x, view.y * 0.7 / PLAN_SIZE.y)
	_origin = (view - PLAN_SIZE * _scale) / 2.0 + Vector2(0, 18)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	var font := UiKit.font()
	var title := String(_plan.get("name", ""))
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 26).x
	draw_string(font, Vector2(size.x / 2.0 - title_width / 2.0, _origin.y - 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, GOLD)
	var rooms := {}
	for room in _plan.get("rooms", []):
		rooms[room.id] = room
	for room in _plan.get("rooms", []):
		_draw_room(room, font)
	for link in _plan.get("links", []):
		_draw_link(link, rooms, font)
	var hint := "Press Map or Escape to close"
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
	draw_string(font, Vector2(size.x / 2.0 - hint_width / 2.0, size.y - 22), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)


func _draw_room(room: Dictionary, font: Font) -> void:
	var box: Array = room.box
	var rect := Rect2(_origin + Vector2(box[0], box[1]) * _scale, Vector2(box[2], box[3]) * _scale)
	var locked: bool = room.get("locked", false)
	var is_here: bool = room.id == _current
	draw_rect(rect, LOCKED_FILL if locked else ROOM_FILL)
	draw_rect(rect, LOCKED_EDGE if locked else ROOM_EDGE, false, 2.0)
	if is_here:
		var pulse := 0.5 + 0.5 * sin(_time * TAU / PULSE_SECONDS)
		draw_rect(rect.grow(4.0), Color(GOLD, 0.25 + 0.25 * pulse), false, 4.0)
		draw_rect(rect.grow(-3.0), GOLD, false, 2.0)
	draw_string(font, rect.position + Vector2(12, 26), String(room.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24, 18, TEXT)
	if locked:
		var word := "Locked"
		var word_width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
		draw_string(font, rect.get_center() + Vector2(-word_width / 2.0, 6), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, LOCKED_EDGE)
	elif is_here:
		_draw_pin(rect.get_center() + Vector2(0, 14))


## The pin marks the room the protagonist is in: a gold drop with a dark centre.
func _draw_pin(tip: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-10, -20), tip + Vector2(10, -20), tip + Vector2(0, 0)]), GOLD)
	draw_circle(tip + Vector2(0, -26), 10.0, GOLD)
	draw_circle(tip + Vector2(0, -26), 4.0, Color(0.1, 0.07, 0.04))


## A door is a small square on the plan; stairs are a square with steps. Either is red when it leads into a locked room.
func _draw_link(link: Dictionary, rooms: Dictionary, font: Font) -> void:
	var at: Array = link.at
	var centre := _origin + Vector2(at[0], at[1]) * _scale
	var target: String = link.get("to", "outside")
	var blocked: bool = rooms.has(target) and rooms[target].get("locked", false)
	var colour := DOOR_LOCKED if blocked else DOOR_OPEN
	var square := Rect2(centre - Vector2(DOOR_SIZE, DOOR_SIZE) / 2.0, Vector2(DOOR_SIZE, DOOR_SIZE))
	draw_rect(square, colour)
	draw_rect(square, Color(0.05, 0.04, 0.03), false, 2.0)
	if link.get("kind", "") == "stairs":
		for step in 3:
			var y := centre.y - 4.0 + step * 4.0
			draw_line(Vector2(centre.x - 5, y), Vector2(centre.x + 5, y), Color(0.05, 0.04, 0.03), 1.5)
	var label := String(link.get("label", ""))
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
	draw_string(font, centre + Vector2(-width / 2.0, DOOR_SIZE + 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, colour if blocked else TEXT)
