class_name DestinationMarker
extends Node2D
## The destination marker: a floating label over the way in to where the protagonist must go next. A green pin glows under
## the name, and the marker bobs gently. It follows the current objective (the "destination" of its step in
## data/missions.json, named and placed in data/destinations.json), so it appears when an objective needs a place, moves
## when the next one does, and goes when the place is reached. Scenes add one each; a world-map marker is placed on the
## place's zone, and an interior marker at its door, or at the scene's gate when only the world map leads there.

const DESTINATIONS_DATA := "res://data/destinations.json"
const PIN_COLOUR := Color("#7fe36a")
const PIN_GLOW := Color(0.5, 1.0, 0.4, 0.35)
const LABEL_COLOUR := Color("#f5efdc")
const OUTLINE_COLOUR := Color(0.04, 0.03, 0.02, 0.95)
const PLATE_COLOUR := Color(0.06, 0.05, 0.04, 0.55)
const FONT_SIZE := 22
## The label sits this far above the way in, and the pin's glow pulses.
const LABEL_HEIGHT := 64.0
const BOB := 6.0
const BOB_SECONDS := 1.3
const PULSE_SECONDS := 1.6

var _host: Node2D
var _on_map := false
var _label := ""
var _base := Vector2.ZERO
var _bob: Tween
var _time := 0.0


func _init(host: Node2D, on_map: bool) -> void:
	_host = host
	_on_map = on_map
	name = "DestinationMarker"
	z_index = 20
	visible = false


func _ready() -> void:
	HudEvents.objective_changed.connect(_on_objective_changed)
	HudEvents.objective_cleared.connect(refresh)
	refresh()


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


func _on_objective_changed(_title: String, _description: String, _complete: bool) -> void:
	refresh()


## Shows the marker at the way in to the current objective's destination, or hides it when there is none to show here.
func refresh() -> void:
	var destination := String(MissionTracker.current_step().get("destination", ""))
	var place := DestinationMarker.resolve(_host, _on_map, destination)
	if place.is_empty():
		visible = false
		if _bob:
			_bob.kill()
		return
	_label = place.label
	if _base != place.position or not visible:
		_base = place.position
		position = _base
		_start_bobbing()
	visible = true
	queue_redraw()


## Where the marker goes for a destination from this host, and its label: {position, label}. Empty when the destination is
## reached here, or there is no way in to show from this scene. Static, so it can be checked without a scene running.
static func resolve(host: Node2D, on_map: bool, destination: String) -> Dictionary:
	var entry: Dictionary = _destinations().get(destination, {})
	if entry.is_empty():
		return {}
	var scene_id := str(host.get("SCENE_ID")) if host.get("SCENE_ID") != null else ""
	if scene_id in entry.get("reached_in", []):
		return {}
	if on_map:
		if not entry.has("world"):
			return {}
		var zone = GameData.locations.get(entry.world, {}).get("zone", null)
		if zone == null:
			return {}
		return {"position": Vector2(zone[0] + zone[2] / 2.0, zone[1]), "label": entry.name}
	var entrance = _inside_entrance(host, entry, scene_id)
	if entrance != null:
		return {"position": entrance, "label": entry.name}
	if entry.has("world") and host.get("GATE_RECT") != null and host.GATE_RECT.size != Vector2.ZERO:
		var gate: Rect2 = host.GATE_RECT
		return {"position": Vector2(gate.position.x + gate.size.x / 2.0, gate.position.y), "label": entry.name}
	return {}


## The way in from this scene to the destination's building: its door, or the exit to its scene. Empty when there is none.
static func _inside_entrance(host: Node2D, entry: Dictionary, scene_id: String) -> Variant:
	if entry.get("entrance_scene", "") != scene_id:
		return null
	if entry.get("door", false) and host.get("HAS_DOOR") == true:
		return host.ENTER_POSITION
	var exits: Array = host.get("EXITS") if host.get("EXITS") != null else []
	for exit in exits:
		if exit.get("scene", "") == entry.get("exit_scene", "__none__"):
			var rect: Rect2 = exit.rect
			return Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y)
	return null


static func _destinations() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DESTINATIONS_DATA))


func _start_bobbing() -> void:
	if _bob:
		_bob.kill()
	_bob = create_tween().set_loops()
	_bob.tween_property(self, "position", _base + Vector2(0, -BOB), BOB_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(self, "position", _base, BOB_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * TAU / PULSE_SECONDS)
	# The pin: a soft glow, the green capsule standing on the way in, and a small dot where it stands.
	draw_circle(Vector2(0, -30), 22.0 + 4.0 * pulse, Color(PIN_GLOW, PIN_GLOW.a * (0.6 + 0.4 * pulse)))
	draw_circle(Vector2(0, -44), 7.0, PIN_COLOUR)
	draw_circle(Vector2(0, -16), 7.0, PIN_COLOUR)
	draw_rect(Rect2(-7, -44, 14, 28), PIN_COLOUR)
	draw_rect(Rect2(-2.5, -41, 3, 20), Color(1, 1, 1, 0.45))
	draw_circle(Vector2.ZERO, 3.5, OUTLINE_COLOUR)
	# The name, on a dark plate with an outline, so it reads over any background.
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(_label, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE).x
	var plate := Rect2(-width / 2.0 - 12.0, -LABEL_HEIGHT - FONT_SIZE, width + 24.0, FONT_SIZE + 14.0)
	draw_rect(plate, PLATE_COLOUR)
	var baseline := Vector2(-width / 2.0 - 0.0, -LABEL_HEIGHT + 4.0)
	draw_string_outline(font, baseline, _label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, OUTLINE_COLOUR)
	draw_string(font, baseline, _label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, LABEL_COLOUR)
