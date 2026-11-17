class_name ItemViewer
extends Control
## Shows an item over the room, floating on a blurred view of the room, until its close cross is pressed, Esc is pressed,
## or E is pressed after a moment. A picture (a letter) shows whole, scaled to fit the screen. A text letter shows its words
## in a scrolling column. A photo shows its front, and turns over to its back by a tap, a drag or R.
## A photo whose picture is not added yet says "Photo to come."

signal closed

## E cannot close the item in its first moments, so the press that opened it does not close it again.
const MIN_SECONDS := 0.8
## The space kept clear above and below a picture, so a letter never touches the top or bottom of the screen.
const FIT_MARGIN := 24.0
## The width of a text letter, and the height of its view.
const TEXT_WIDTH := 480.0
const TEXT_HEIGHT := 340.0
## The room for "Photo to come.", which stands where the photo will be.
const PLACEHOLDER_HEIGHT := 40.0
## A photo is 3:2, like the photos themselves.
const PHOTO_BOX := Vector2(576, 384)
## A turn takes this long.
const TURN_SECONDS := 0.35
## A press must move this far before it counts as a drag and not a tap.
const DRAG_START_PX := 8.0
## How far a drag must move to turn a photo from its front to its back.
const DRAG_RANGE_PX := 300.0
## A press that moves less than this is a tap, even when it has dragged a little on the way.
const TAP_SLOP_PX := 20.0
const TURN_KEY := KEY_R
## The gap between the close cross and the top right corner of the screen.
const CLOSE_MARGIN := 18.0

## True while a photo shows its back. The face swaps when the photo is edge-on, where the change cannot be seen.
var showing_back := false

var _backdrop_picture: TextureRect
var _tint: ColorRect
var _title: Label
var _close: CloseCross
var _scroll: ScrollContainer
var _picture: TextureRect
var _body: Label
var _photo_holder: Control
var _photo_picture: TextureRect
var _turn_row: CenterContainer
var _turn_button: ChoiceButton
var _front_face: Texture2D
var _back_face: Texture2D
var _angle := 0.0
var _turn_tween: Tween
var _pressing := false
var _dragging := false
var _press_x := 0.0
var _press_angle := 0.0
var _open_for := 0.0
## True while the viewer shows an image, a letter. Such a letter is fitted to the screen again when the screen changes size.
var _shows_image := false


func _ready() -> void:
	_fit()
	get_viewport().size_changed.connect(_fit)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_backdrop()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.name = "column"
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	_build_column(column)
	_close = CloseCross.new()
	_close.anchor_left = 1.0
	_close.anchor_right = 1.0
	_close.anchor_top = 0.0
	_close.anchor_bottom = 0.0
	_close.offset_left = -(CLOSE_MARGIN + CloseCross.SIZE.x)
	_close.offset_right = -CLOSE_MARGIN
	_close.offset_top = CLOSE_MARGIN
	_close.offset_bottom = CLOSE_MARGIN + CloseCross.SIZE.y
	_close.pressed.connect(close)
	add_child(_close)


## The room behind the viewer: a copy of the screen taken as the viewer opens (see _capture_backdrop), under a dark tint.
## Both sit first in the viewer, so everything else in it is drawn over them.
func _build_backdrop() -> void:
	_backdrop_picture = TextureRect.new()
	_backdrop_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_backdrop_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop_picture)
	_tint = ColorRect.new()
	_tint.color = Color(0.03, 0.02, 0.015, 0.92)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_tint)


## A small copy of the screen, for the room behind the viewer. The screen is drawn again first, so the copy shows what is
## there now: an inventory that has just closed is gone from it, and the viewer is still hidden. Shrinking the copy 12 times
## and drawing it back up is what makes the blur. Null when there is no picture, as in a headless run; then only the tint shows.
func _capture_backdrop() -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return null
	RenderingServer.force_draw(false)
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return null
	image.resize(maxi(1, int(image.get_width() / 12.0)), maxi(1, int(image.get_height() / 12.0)), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


func _build_column(column: VBoxContainer) -> void:
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", UiKit.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	# A picture sits in the column rather than in the scroll, so a letter shows whole.
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The letter is drawn at about 0.375 of its file size, so it reads the smaller mipmap copies its import makes. Linear
	# filtering between those copies keeps the handwriting clean, where nearest sampling would make it jagged.
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	column.add_child(_picture)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	column.add_child(_scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("font_size", 18)
	_body.add_theme_color_override("font_color", UiKit.CREAM)
	content.add_child(_body)

	# The holder takes the taps and drags. The picture inside it turns, so it must not take them itself.
	_photo_holder = Control.new()
	_photo_holder.custom_minimum_size = PHOTO_BOX
	_photo_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_photo_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	_photo_holder.gui_input.connect(_on_photo_input)
	column.add_child(_photo_holder)
	_photo_picture = UiKit.picture(null)
	_photo_picture.pivot_offset = PHOTO_BOX / 2.0
	# The project filters textures with nearest sampling, which would alias a 1200 px photo shown at 576 px. The photo's
	# import makes mipmaps, and this filter reads the smaller copies, so the photo shrinks without shimmer.
	_photo_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_photo_holder.add_child(UiKit.fill(_photo_picture))

	_turn_row = CenterContainer.new()
	_turn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_turn_row)
	_turn_button = ChoiceButton.new()
	_turn_button.setup("Turn over", "turn")
	_turn_button.pressed_choice.connect(func(_choice: String): turn_over())
	_turn_row.add_child(_turn_button)

	_photo_holder.visible = false
	_turn_row.visible = false


## Covers the whole screen. Set by size rather than anchors, because a viewer in a canvas layer has no parent
## control to anchor to. A letter on screen is fitted again to the new size.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if visible and _shows_image:
		_fit_letter()


## Sizes a letter to the viewer: as tall as the screen, less a margin above and below, so the whole of it shows. A letter too
## wide to leave the close cross clear at each side is fitted to that width instead.
func _fit_letter() -> void:
	var fit_height := maxf(120.0, size.y - 2.0 * FIT_MARGIN)
	var fit_width := 0.0
	if _front_face != null:
		var ratio: float = float(_front_face.get_width()) / float(_front_face.get_height())
		fit_width = fit_height * ratio
		var width_limit := size.x - 2.0 * FIT_MARGIN - 2.0 * (CLOSE_MARGIN + CloseCross.SIZE.x)
		if fit_width > width_limit:
			fit_width = width_limit
			fit_height = fit_width / ratio
	_picture.custom_minimum_size = Vector2(fit_width, fit_height)


func _process(delta: float) -> void:
	if visible:
		_open_for += delta


## Shows one item: {"type": "image", "image"}, {"type": "letter", "title", "text"}, or a photo, {"type": "photo", "title",
## "front", "back"}. A photo's front falls back to "image", and its back is optional. A photo opens on its front.
func show_item(item: Dictionary) -> void:
	_stop_turn()
	if not visible:
		_backdrop_picture.texture = _capture_backdrop()
	var kind: String = String(item.get("type", ""))
	_shows_image = kind == "image"
	_front_face = _load_texture(String(item.get("front", item.get("image", ""))))
	_back_face = _load_texture(String(item.get("back", "")))
	_title.text = String(item.get("title", ""))
	_title.visible = kind != "image"
	_picture.texture = _front_face if kind == "image" else null
	_angle = 0.0
	showing_back = false
	_photo_picture.scale.x = 1.0
	_photo_picture.texture = _front_face
	_photo_holder.visible = false
	_turn_row.visible = false
	if kind == "image":
		_fit_letter()
		_picture.visible = _front_face != null
		_scroll.visible = false
		_body.visible = false
	elif kind == "photo":
		var has_front := _front_face != null
		_picture.visible = false
		_scroll.visible = not has_front
		_scroll.custom_minimum_size = Vector2(TEXT_WIDTH, PLACEHOLDER_HEIGHT)
		_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_body.text = "" if has_front else "Photo to come."
		_body.visible = not has_front
		_photo_holder.visible = has_front
		_turn_row.visible = has_back()
	else:
		_picture.visible = false
		_scroll.visible = true
		_scroll.custom_minimum_size = Vector2(TEXT_WIDTH, TEXT_HEIGHT)
		_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_body.text = String(item.get("text", ""))
		_body.visible = _body.text != ""
	_open_for = 0.0
	visible = true
	_close.focus_button.call_deferred()


## True when a photo has both its faces, so it can turn over.
func has_back() -> bool:
	return _front_face != null and _back_face != null


## Turns a photo to its other face the short way round: a half turn from the middle of the face it is on to the nearer middle
## of the other, so a photo resting off-centre never turns the long way. On a tie the turn goes forward. A turn that is under
## way, or a drag, is left alone. A press whose release never arrived is dropped first, so it cannot hold up the turn.
func turn_over() -> void:
	if _pressing and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_pressing = false
		_dragging = false
	if not has_back() or _is_turning() or _dragging:
		return
	# The middles of the other face lie at centre + PI and centre - PI. The nearer one to the angle is the short way round.
	var centre := _snap_target(_angle)
	var forward := centre + PI
	var backward := centre - PI
	var target: float = forward if absf(forward - _angle) <= absf(backward - _angle) else backward
	_turn_to(target, TURN_SECONDS)


func close() -> void:
	_stop_turn()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var turn_key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == TURN_KEY
	if turn_key and has_back():
		get_viewport().set_input_as_handled()
		turn_over()
		return
	if event.is_action_pressed("ui_cancel") or (_open_for >= MIN_SECONDS and event.is_action_pressed("interact")):
		get_viewport().set_input_as_handled()
		close()


func _load_texture(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _is_turning() -> bool:
	return _turn_tween != null and _turn_tween.is_running()


## Turns the photo to target over the given seconds. Each step may pass the photo through its edge-on angle, where the face
## swaps out of sight (see _set_angle). The turn always ends by settling the photo at its true angle.
func _turn_to(target: float, seconds: float) -> void:
	# A turn cancels a press that is still held, so the press's release cannot turn the photo again.
	_pressing = false
	_dragging = false
	if _turn_tween != null:
		_turn_tween.kill()
	_turn_tween = create_tween()
	_turn_tween.tween_method(_turn_step, _angle, target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_turn_tween.tween_callback(_settle)


func _turn_step(angle: float) -> void:
	_set_angle(angle, true)


func _settle() -> void:
	_set_angle(_angle, false)


## Ends a turn and a drag at once, for when the viewer closes or shows another item. A turn cut short is settled too, so the
## photo is never left edge-on.
func _stop_turn() -> void:
	if _is_turning():
		_turn_tween.kill()
		_settle()
	_pressing = false
	_dragging = false


## Sets the photo's angle, where 0 is the front and PI the back. The angle has no limit, so a drag turns the photo either way.
## The face swaps at each PI / 2 past the front (see _face_is_back). Inside a turn, the frame that swaps the face draws the
## photo at the crossing, edge-on, where the change cannot be seen. A drag never does that: it can rest anywhere, so its photo
## keeps its true width.
func _set_angle(angle: float, swap_edge_on: bool) -> void:
	var back := _face_is_back(angle)
	var shown := angle
	if swap_edge_on and back != _face_is_back(_angle):
		shown = _crossing(_angle, angle)
	_photo_picture.scale.x = maxf(absf(cos(shown)), 0.001)
	_angle = angle
	if back != showing_back:
		showing_back = back
		_photo_picture.texture = _back_face if back else _front_face


## True when the photo shows its back at this angle. The back runs from PI / 2 to 3 PI / 2, the front from 3 PI / 2 to
## 5 PI / 2, and so on, and the same way below zero.
func _face_is_back(a: float) -> bool:
	return posmod(int(floor((a + PI / 2.0) / PI)), 2) == 1


## The angle a released drag swings to: the middle of the face that the angle is in, 0 or PI, and so on. An angle on an edge
## goes to the face that _face_is_back gives it.
func _snap_target(a: float) -> float:
	return floorf((a + PI / 2.0) / PI) * PI


## The edge-on angle, PI / 2 plus a whole number of PI, that a turn from a0 to a1 passes through. A turn that starts edge-on
## is already at its crossing.
func _crossing(a0: float, a1: float) -> float:
	if absf(cos(a0)) < 0.000001:
		return a0
	var steps := (a0 - PI / 2.0) / PI
	var k := int(floor(steps)) + 1 if a1 > a0 else int(ceil(steps)) - 1
	return PI / 2.0 + k * PI


## Taps and drags on the photo. A tap turns it over. A drag follows the mouse in either direction, and on release the photo
## swings to its nearer face. A drag that ends within TAP_SLOP_PX of where it began counts as a tap. A press still held when
## a turn starts is cancelled by that turn, so its release does not undo it.
func _on_photo_input(event: InputEvent) -> void:
	if not has_back():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _is_turning():
				_pressing = true
				_dragging = false
				_press_x = event.position.x
				_press_angle = _angle
		elif _pressing:
			var was_drag := _dragging
			var moved := absf(event.position.x - _press_x)
			_pressing = false
			_dragging = false
			if was_drag and moved > TAP_SLOP_PX:
				var target := _snap_target(_angle)
				_turn_to(target, maxf(0.12, TURN_SECONDS * absf(target - _angle) / PI))
			else:
				_set_angle(_press_angle, false)
				turn_over()
	elif event is InputEventMouseMotion and _pressing and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var dx: float = event.position.x - _press_x
		if absf(dx) >= DRAG_START_PX:
			_dragging = true
		if _dragging:
			_set_angle(_press_angle + dx * PI / DRAG_RANGE_PX, false)
