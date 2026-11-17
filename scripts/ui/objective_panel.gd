class_name ObjectivePanel
extends Control
## The current objective, under the place: a gold heading, a box that ticks when the objective is complete, the title, a short
## description, and one row per place to look at in the house, each ticked once it has been seen. It has no frame, so it reads
## as text on the room. It fades in and out, and the place's chevron folds it away.

const WIDTH := 218.0
## Tall enough for the heading, the title and its description. The panel grows to fit its place rows.
const MIN_HEIGHT := 64.0
## Where the text starts inside the place's block, so the heading lines up under the place's name.
const LEFT := 35.0
const BOX_SIZE := 14.0
const PLACE_BOX_SIZE := 11.0
const HEADING_COLOUR := Color("#ecc442")
const BOX_COLOUR := Color("#ecb63c")
const TITLE_COLOUR := Color("#ece2d4")
const DESCRIPTION_COLOUR := Color("#cdbfb2")

var objective_title := ""
var objective_description := ""
var completion_status := false
## Whether the objective may show. The chevron under the place turns it off and on.
var expanded := true

var _content: Control
var _column: VBoxContainer
var _title: Label
var _description: Label
var _tick: TextureRect
var _places: VBoxContainer
var _tween: Tween
var _active := false


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, MIN_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(_content))
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 14)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(_column)
	_column.offset_left = LEFT
	_column.offset_right = 0
	_content.add_child(_column)
	var heading := UiKit.label(13, HEADING_COLOUR)
	heading.add_theme_font_override("font", UiKit.bold_font())
	heading.text = "Current Objective"
	_column.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(row)
	# The box sits level with the title, not with the description under it.
	var tick_holder := MarginContainer.new()
	tick_holder.add_theme_constant_override("margin_top", 2)
	tick_holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tick_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tick_holder)
	var box := _make_box(BOX_SIZE)
	tick_holder.add_child(box)
	_tick = _make_tick()
	box.add_child(_tick)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 6)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	_title = UiKit.label(15, TITLE_COLOUR)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_title)
	_description = UiKit.label(12, DESCRIPTION_COLOUR)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_description)
	# The places to look at, under the description and lined up with the title.
	_places = VBoxContainer.new()
	_places.add_theme_constant_override("separation", 6)
	_places.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_places.visible = false
	text.add_child(_places)
	visible = false
	_apply()


## Shows an objective, or updates the one showing.
func show_objective(title: String, description: String, complete: bool) -> void:
	objective_title = title
	objective_description = description
	completion_status = complete
	_active = true
	_apply()
	if expanded and (not visible or modulate.a < 1.0):
		_fade_in()


func hide_objective() -> void:
	_active = false
	_fade_out()


## Shows one row per place, each ticked when it has been seen. An empty list leaves no rows.
func show_places(places: Array) -> void:
	for child in _places.get_children():
		_places.remove_child(child)
		child.queue_free()
	for place in places:
		_places.add_child(_place_row(place.label, place.seen))
	_places.visible = not places.is_empty()
	_fit()


## Folds the objective away, or opens it again. The place's chevron calls this.
func set_expanded(shown: bool) -> void:
	expanded = shown
	if shown and _active:
		_fade_in()
	else:
		_fade_out()


func _apply() -> void:
	if _title == null:
		return
	_title.text = objective_title
	_description.text = objective_description
	_description.visible = objective_description != ""
	_tick.visible = completion_status
	_fit()


## The panel is at least its minimum height, and taller when its rows need the room, so nothing spills past it.
func _fit() -> void:
	custom_minimum_size = Vector2(WIDTH, maxf(MIN_HEIGHT, _column.get_combined_minimum_size().y))


## One place: a small box, ticked once it has been seen, and the place's name beside it.
func _place_row(place_name: String, seen: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := _make_box(PLACE_BOX_SIZE)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(box)
	var tick := _make_tick()
	tick.visible = seen
	box.add_child(tick)
	var label := UiKit.label(12, TITLE_COLOUR if seen else DESCRIPTION_COLOUR)
	label.text = place_name
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return row


## An open square, as in the reference: the room shows through it. The tick is added on top by the caller.
func _make_box(size: float) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(size, size)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outline := StyleBoxFlat.new()
	outline.draw_center = false
	outline.border_color = BOX_COLOUR
	outline.set_border_width_all(2)
	outline.set_corner_radius_all(3)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", outline)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(UiKit.fill(frame))
	return box


## The tick inside a box: a small diamond, centred in the box.
func _make_tick() -> TextureRect:
	var tick := UiKit.picture(UiKit.texture(UiAssets.DIAMOND), true)
	tick.anchor_left = 0.25
	tick.anchor_top = 0.25
	tick.anchor_right = 0.75
	tick.anchor_bottom = 0.75
	return tick


func _fade_in() -> void:
	if _tween:
		_tween.kill()
	visible = true
	modulate.a = 0.0
	_content.position = Vector2(0, 6)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.3)
	_tween.tween_property(_content, "position", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _fade_out() -> void:
	if not visible:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(func(): visible = false)
