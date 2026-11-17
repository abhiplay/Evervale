class_name HouseInspection
extends Node
## Amelia's look around the house, for the scene it is added to. Once Evelyn has left, each area says its lines the
## first time Amelia walks into it. When every area has been seen the task is done. The loose board in the north room
## opens only once the task is done and the plank's "requires" condition holds (back from the café, see MissionTracker),
## so the box is found in the evening, in story order. Then E at the board finds the box, shows the "New Discovery" popup, and offers Open Box or Leave.
## Opening the box puts what is inside into the inventory, and the first time it is open in the house, Amelia and Oliver
## talk about it (BoxTalk). Areas and words are in data/home_events.json. The objective and the prompt are shown by the
## HUD, through HudEvents.

const DATA_PATH := "res://data/home_events.json"
const HIGHLIGHT_COLOUR := Color("#e8c77a")
## A floating question mark over each place not yet looked at: its radius, how far it sits below the place's top edge, how
## far it bobs, and the size of the mark.
const MARKER_RADIUS := 15.0
const MARKER_TOP := 24.0
const MARKER_BOB := 8.0
const MARKER_FONT := 22

var _host: Node2D
var _data: Dictionary
var _busy := false
var _prompt_on := false
var _highlight: Node2D
## The question mark over each place not yet looked at, by the place's id. Only this scene's places have one.
var _markers := {}
## The task the objective and the marks were last drawn for, so a change made elsewhere (the opening) is picked up.
var _shown_task := ""
var _popup: DiscoveryPopup
## The talk about the box, once it has started (see BoxTalk). Null until then.
var box_talk: BoxTalk = null


func _init(host: Node2D) -> void:
	_host = host
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


func _ready() -> void:
	var viewers := CanvasLayer.new()
	viewers.layer = 20
	add_child(viewers)
	_popup = DiscoveryPopup.new()
	viewers.add_child(_popup)
	HudEvents.item_opened.connect(_on_item_opened)
	var plank: Dictionary = _data.plank
	if plank.scene == _host.SCENE_ID:
		_highlight = Node2D.new()
		_highlight.z_index = 3
		_highlight.visible = false
		_highlight.draw.connect(_draw_highlight)
		_host.add_child(_highlight)
		_highlight.queue_redraw()
		var pulse := _highlight.create_tween().set_loops()
		pulse.tween_property(_highlight, "modulate:a", 0.55, 0.9)
		pulse.tween_property(_highlight, "modulate:a", 1.0, 0.9)
	_refresh()
	if _talk_pending():
		_talk_when_ready()


## The box can be opened from the inventory as well, so the objective is read again when it has been, and the talk starts
## when it is pending here.
func _on_item_opened(_item_id: String) -> void:
	_refresh()
	if _talk_pending():
		_talk_when_ready()


func _box_opened() -> bool:
	return SaveSystem.state.opened_items.get("hidden_box", false)


## The talk plays once, after the box is open. It is only on the ground floor, where the front door is: the upstairs
## bedroom has this script too.
func _talk_pending() -> bool:
	var done: bool = _state().get("box_talk_done", false)
	return _host.SCENE_ID == "home_floor1" and _box_opened() and not done


## Amelia and Oliver talk about the box. Nothing else in the house runs until it has ended.
func _start_box_talk() -> void:
	_busy = true
	box_talk = BoxTalk.new()
	await box_talk.play(_host)
	# With the box talk over, the house is settled: the ground floor fades into its furnished picture.
	if _host.has_method("settle_with_fade"):
		_host.scripted = true
		await _host.settle_with_fade()
		_host.scripted = false
	_busy = false


## The talk waits until nothing else is running here, then starts if it is still pending. When examine has opened the box,
## examine starts the talk itself, so by the time this waiting ends the talk has played and is no longer pending.
func _talk_when_ready() -> void:
	await _host.get_tree().process_frame
	while is_instance_valid(_host) and not _idle():
		await _host.get_tree().process_frame
	if is_instance_valid(_host) and _talk_pending():
		await _start_box_talk()


func _idle() -> bool:
	return not _busy and not _host.scripted and not _host.transitioning and not _host.scene_dialogue.is_open


func _physics_process(_delta: float) -> void:
	# The look around can start in another script (the opening), so the objective and the marks follow the task here too.
	if _task() != _shown_task:
		_refresh()
	if _busy or _host.scripted or _host.transitioning or _host.scene_dialogue.is_open:
		_set_examine(false)
		return
	var task := _task()
	if task == "":
		_set_examine(false)
		return
	var here: Vector2 = _host.player.position
	if task == "active":
		for area in _data.areas:
			if area.scene == _host.SCENE_ID and not _seen().has(area.id) and _rect(area.rect).has_point(here):
				_visit(area)
				return
	var plank: Dictionary = _data.plank
	var at_board: bool = plank.scene == _host.SCENE_ID and not _box_opened() and _rect(plank.rect).has_point(here)
	_set_examine(at_board)


func _unhandled_input(event: InputEvent) -> void:
	if _prompt_on and not _busy and not HudEvents.screen_open and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		examine_plank()


## Says the area's lines. The area counts as seen only once they have finished, so a line cut short by closing the
## game is said again next time.
func _visit(area: Dictionary) -> void:
	_busy = true
	await _host.scene_dialogue.say("Amelia", area.lines)
	_seen().append(area.id)
	var finished := _seen_all()
	if finished:
		_state()["house_task"] = "done"
	SaveSystem.save_game()
	_refresh()
	if finished:
		await _host.scene_dialogue.say("Amelia", _data.done_lines)
	_busy = false


## E at the loose board. Before the look-around is done, Amelia says it is not time yet; after it, until she is back from
## town, she says she will look later. Once the board is ready, the box is found and the New Discovery popup asks whether
## to open it now or leave it in the inventory.
func examine_plank() -> void:
	var plank: Dictionary = _data.plank
	_busy = true
	_set_examine(false)
	if _task() != "done" or not _board_ready():
		await _host.scene_dialogue.say("Amelia", plank.waiting_lines if _task() != "done" else plank.later_lines)
		_busy = false
		return
	_host.scripted = true
	var first_time: bool = not _state().get("house_plank_found", false)
	if first_time:
		await _host.scene_dialogue.say("Amelia", plank.found_lines)
	_popup.show_discovery(UiData.item(plank.item_id))
	var choice: String = await _popup.choice_made
	if first_time:
		SaveSystem.add_item(plank.item_id)
		_state()["house_plank_found"] = true
	if choice == "open":
		HudEvents.item_open_requested.emit(plank.item_id)
	SaveSystem.save_game()
	_refresh()
	if _talk_pending():
		await _start_box_talk()
	_host.scripted = false
	_busy = false


## A click on the loose board, once it can be examined, walks Amelia to it and examines it (exterior_home.click_target).
## null for any other click.
func click_target(point: Vector2):
	var plank: Dictionary = _data.plank
	if plank.scene != _host.SCENE_ID or _box_opened() or _task() == "":
		return null
	var rect := _rect(plank.rect)
	return rect.get_center() if rect.has_point(point) else null


## Shows the examine prompt and the highlight on the board while Amelia stands on it.
func _set_examine(on: bool) -> void:
	if _highlight:
		_highlight.visible = on
	if on == _prompt_on:
		return
	_prompt_on = on
	HudEvents.interaction_changed.emit(_data.plank.examine_label if on else "")


## Tells the HUD what the objective is now. The objective follows the story's missions (MissionTracker): during the look
## around it is M01's count of places checked. Updating also completes any mission this change finished.
func _refresh() -> void:
	_shown_task = _task()
	MissionTracker.update()
	HudEvents.places_changed.emit(_places())
	_sync_markers()


## The places to look at while the look around is on: each with its label, and whether Amelia has looked at it. Before it
## starts, and once it is done, there are none.
func _places() -> Array:
	var places: Array = []
	if _task() != "active":
		return places
	for area in _data.areas:
		places.append({"label": area.label, "seen": _seen().has(area.id)})
	return places



## Gives each place of this scene that has not been looked at yet a floating question mark, while the look around is on, and
## takes it away once the place has been seen or the look around is over.
func _sync_markers() -> void:
	var active := _task() == "active"
	for area in _data.areas:
		if area.scene != _host.SCENE_ID:
			continue
		var wanted: bool = active and not _seen().has(area.id)
		if wanted and not _markers.has(area.id):
			_markers[area.id] = _add_marker(area)
		elif not wanted and _markers.has(area.id):
			var marker: Node2D = _markers[area.id]
			_markers.erase(area.id)
			_remove_marker(marker)
	# Once the board can be opened, it keeps its mark until the box has been taken out from under it.
	var plank: Dictionary = _data.plank
	var board_wanted: bool = _task() == "done" and _board_ready() and not _box_opened() and plank.scene == _host.SCENE_ID
	if board_wanted and not _markers.has("plank"):
		_markers["plank"] = _add_marker({"id": "plank", "rect": plank.rect})
	elif not board_wanted and _markers.has("plank"):
		var board: Node2D = _markers["plank"]
		_markers.erase("plank")
		_remove_marker(board)


## Takes a mark away together with the sparkle that goes with it.
func _remove_marker(marker: Node2D) -> void:
	if marker.has_meta("glint"):
		marker.get_meta("glint").queue_free()
	marker.queue_free()


## A question mark in a gold ring, floating just inside the place's top edge, bobbing gently up and down.
func _add_marker(area: Dictionary) -> Node2D:
	var rect := _rect(area.rect)
	var marker := Node2D.new()
	marker.name = "Marker_" + area.id
	# Above the furniture and the player, so the mark is never hidden behind them.
	marker.z_index = 20
	var base := Vector2(rect.get_center().x, rect.position.y + MARKER_TOP)
	marker.position = base
	marker.draw.connect(_draw_marker.bind(marker))
	_host.add_child(marker)
	marker.queue_redraw()
	# The sparkle sits on the place itself, not on the bobbing mark, so it flickers where the thing is.
	var glint := Glint.new()
	glint.position = rect.get_center()
	_host.add_child(glint)
	marker.set_meta("glint", glint)
	var bob := marker.create_tween().set_loops()
	bob.tween_property(marker, "position", base + Vector2(0, -MARKER_BOB), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(marker, "position", base, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return marker


func _draw_marker(marker: Node2D) -> void:
	marker.draw_circle(Vector2.ZERO, MARKER_RADIUS, Color(0.12, 0.08, 0.05, 0.8))
	marker.draw_arc(Vector2.ZERO, MARKER_RADIUS, 0.0, TAU, 32, HIGHLIGHT_COLOUR, 2.0)
	var font := ThemeDB.fallback_font
	marker.draw_string(font, Vector2(-MARKER_RADIUS, MARKER_FONT * 0.36), "?", HORIZONTAL_ALIGNMENT_CENTER, MARKER_RADIUS * 2.0, MARKER_FONT, HIGHLIGHT_COLOUR)


## A soft gold bloom along the loose board, drawn as a band turned to the board's angle, so it follows the planks.
func _draw_highlight() -> void:
	var glow: Dictionary = _data.plank.glow
	var centre := Vector2(glow.centre[0], glow.centre[1])
	var half := Vector2(glow.half[0], glow.half[1])
	var angle: float = glow.angle
	for i in 4:
		var grow := 4.0 + i * 5.0
		var band := _rotated_rect(centre, half + Vector2(grow, grow * 0.5), angle)
		_highlight.draw_colored_polygon(band, Color(HIGHLIGHT_COLOUR, 0.2 - i * 0.04))
	var outline := _rotated_rect(centre, half, angle)
	outline.append(outline[0])
	_highlight.draw_polyline(outline, HIGHLIGHT_COLOUR, 2.0)


func _rotated_rect(centre: Vector2, half: Vector2, angle: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		corners.append(centre + corner.rotated(angle))
	return corners


func _state() -> Dictionary:
	return SaveSystem.state.world_state


func _task() -> String:
	return _state().get("house_task", "")


## True when the plank's "requires" condition holds (or it has none), so the box can be found now.
func _board_ready() -> bool:
	var requires: String = _data.plank.get("requires", "")
	return requires == "" or MissionTracker.condition_met(requires)


func _seen() -> Array:
	var state := _state()
	if not state.has("house_seen"):
		state["house_seen"] = []
	return state["house_seen"]


func _seen_all() -> bool:
	for area in _data.areas:
		if not _seen().has(area.id):
			return false
	return true


func _rect(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])
