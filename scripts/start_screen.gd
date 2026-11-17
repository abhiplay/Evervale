class_name StartScreen
extends Control
## The title screen. A looping video of the scene is the background, with a looping ambient sound, and the picture of
## Evervale is kept behind it for when the video cannot play. The menu is drawn here in code. Each
## button is a plate with its own icon and label, drawn over the picture's own buttons. Invisible Buttons
## sit on the plates, so the mouse, touch and keyboard all work. New Game starts a new save (asking first
## when there is one). Continue and Load Game resume the one save slot. Quit closes the game. Settings,
## Gallery and Credits are not built yet.

const ART := "res://assets/ui/start_screen.webp"
const ART_SIZE := Vector2(1672, 941)
## The background video, in Theora (Godot plays .ogv), with no sound of its own. It loops.
const VIDEO := "res://assets/video/start_loop.ogv"
## The ambient sound that plays on this screen, looped. It stops when the screen is left.
const AMBIENT := "res://assets/audio/start_ambient.ogg"
## The ambient sound's volume, as a share of its full level.
const AMBIENT_VOLUME := 0.2
## The video fades in from black at its start and out to black at its end, so the loop joins without a cut. The fade is
## long and eased, so it lingers and feels slow rather than a cut. In seconds.
const FADE_SECONDS := 2.5
## The Evervale logo, at the top centre of the screen, with room above it.
const LOGO := "res://assets/ui/evervale_logo.webp"
## How far the logo sits below the top edge, as a share of the window height, and how big it may be.
const LOGO_TOP_SHARE := 0.05
const LOGO_MAX_WIDTH_SHARE := 0.42
const LOGO_MAX_HEIGHT_SHARE := 0.28
## Dust motes that drift over the video and under the menu.
const PARTICLE_COUNT := 48
## Soft mist bands that drift along the floor of the picture, over the video and under the menu.
const FOG_BANDS := 7
const GAME_SCENE := "res://scenes/ExteriorHome.tscn"
const GOLD := Color("#e8c77a")
const GOLD_LIT := Color("#fff1c9")
const CREAM := Color("#f3e3c3")
## Solid, so the picture's own buttons do not show through the plates.
const PLATE := Color(0.08, 0.055, 0.045)
const PLATE_LIT := Color(0.14, 0.095, 0.065)
const EDGE := Color(0.58, 0.44, 0.24)

## Where the picture's own buttons sit, in picture pixels (x, y, width, height), top to bottom. The drawn
## plates cover these, with a little room to spare.
const BUTTONS := {
	"new_game": Rect2(1297, 347, 323, 67),
	"continue": Rect2(1297, 421, 323, 60),
	"load_game": Rect2(1297, 487, 323, 61),
	"settings": Rect2(1297, 552, 323, 60),
	"gallery": Rect2(1297, 618, 323, 58),
	"credits": Rect2(1297, 681, 323, 59),
	"quit": Rect2(1297, 746, 323, 58),
}
const LABELS := {
	"new_game": "New Game",
	"continue": "Continue",
	"load_game": "Load Game",
	"settings": "Settings",
	"gallery": "Gallery",
	"credits": "Credits",
	"quit": "Quit",
}
## How far each plate reaches beyond the picture's button, in picture pixels (sideways, up and down).
const PLATE_GROW := Vector2(6, 3)
## Buttons that need a save. They are dimmed until there is one.
const NEEDS_SAVE := ["continue", "load_game"]

var _art: Texture2D
var _font: SystemFont
var _buttons := {}
var _confirm: PanelContainer
var _notice: Label
var _notice_tween: Tween
var _video: VideoStreamPlayer
var _ambient: AudioStreamPlayer
## The dust motes: each has a place (as a share of the picture), a drift, a size and a twinkle phase.
var _motes: Array = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()
## The logo is drawn by this screen, between the video and the fog and dust, so the mist and the motes pass in front of it.
var _logo_texture: Texture2D
var _logo_rect := Rect2()
## The mist bands along the floor: each has a place, a size, a drift and an opacity. They share one soft texture.
var _fog_blobs: Array = []
var _fog_texture: Texture2D


func _ready() -> void:
	_art = load(ART)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Cinzel", "Georgia", "Times New Roman", "serif"])
	_build_buttons()
	_build_confirm()
	_build_notice()
	_build_media()
	_build_motes()
	_build_fog()
	_build_logo()
	resized.connect(_layout)
	_layout()
	_buttons["new_game"].grab_focus.call_deferred()


func _build_buttons() -> void:
	var no_box := StyleBoxEmpty.new()
	for key in BUTTONS:
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		for style in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(style, no_box)
		button.disabled = key in NEEDS_SAVE and not SaveSystem.has_save()
		button.pressed.connect(_on_pressed.bind(key))
		for signal_name in ["focus_entered", "focus_exited", "mouse_entered", "mouse_exited"]:
			button.connect(signal_name, queue_redraw)
		add_child(button)
		_buttons[key] = button


func _build_confirm() -> void:
	_confirm = PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.09, 0.06, 0.05, 0.96)
	frame.border_color = GOLD
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(10)
	frame.set_content_margin_all(18)
	_confirm.add_theme_stylebox_override("panel", frame)
	_confirm.set_anchors_preset(Control.PRESET_CENTER)
	_confirm.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm.grow_vertical = Control.GROW_DIRECTION_BOTH
	_confirm.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_confirm.add_child(column)
	var question := Label.new()
	question.text = "Start a new game? Your saved progress will be replaced."
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.custom_minimum_size = Vector2(320, 0)
	question.add_theme_color_override("font_color", CREAM)
	column.add_child(question)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var start := Button.new()
	start.text = "Start new game"
	start.pressed.connect(_start_new_game)
	row.add_child(start)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_hide_confirm)
	row.add_child(cancel)
	add_child(_confirm)


func _build_notice() -> void:
	_notice = Label.new()
	_notice.visible = false
	_notice.add_theme_font_size_override("font_size", 18)
	_notice.add_theme_color_override("font_color", CREAM)
	_notice.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_notice.add_theme_constant_override("shadow_offset_x", 1)
	_notice.add_theme_constant_override("shadow_offset_y", 1)
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notice)


## The looping video and the looping ambient sound. The video is not drawn by itself: _draw shows its frames in the
## picture's place, under the menu, so the menu stays on top.
func _build_media() -> void:
	_video = VideoStreamPlayer.new()
	_video.stream = load(VIDEO)
	_video.loop = true
	_video.visible = false
	add_child(_video)
	_video.play()
	var sound: AudioStreamOggVorbis = load(AMBIENT)
	sound.loop = true
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = sound
	_ambient.volume_linear = AMBIENT_VOLUME
	add_child(_ambient)
	_ambient.play()


func _build_motes() -> void:
	_rng.randomize()
	for i in PARTICLE_COUNT:
		_motes.append(_new_mote(_rng, true))


## A mote with a random place, drifting slowly upward. When `anywhere` is false it starts at the bottom edge instead.
func _new_mote(rng: RandomNumberGenerator, anywhere: bool) -> Dictionary:
	var y := rng.randf() if anywhere else 1.0 + rng.randf() * 0.05
	return {
		"pos": Vector2(rng.randf(), y),
		"drift": Vector2(rng.randf_range(-0.004, 0.004), rng.randf_range(-0.03, -0.012)),
		"size": rng.randf_range(2.0, 3.8),
		"phase": rng.randf() * TAU,
	}


## How opaque the black over the video is, from 0 (none) to 1 (fully black), at a point in the video. It is black at the
## very start and the very end, so the loop goes black and comes back without a cut. `length` is the video's length.
static func fade_for(position: float, length: float) -> float:
	if length <= 0.0:
		return 0.0
	var fade := minf(FADE_SECONDS, length * 0.5)
	if position < fade:
		return 1.0 - _ease_in_out(position / fade)
	if position > length - fade:
		return _ease_in_out((position - (length - fade)) / fade)
	return 0.0


## A smooth curve from 0 to 1, slow at both ends, so the fade starts and ends gently.
static func _ease_in_out(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## The fade now, while the video plays. Nothing to fade when the video is not playing.
func _fade_alpha() -> float:
	if _video == null or not _video.is_playing():
		return 0.0
	return fade_for(_video.stream_position, _video.get_stream_length())


## The frame to show behind the menu: the video's current frame while it plays, otherwise the still picture.
func _frame() -> Texture2D:
	if _video and _video.get_video_texture() != null:
		return _video.get_video_texture()
	return _art


func _process(delta: float) -> void:
	# The video and the motes change every frame, so the screen is drawn again each frame.
	_time += delta
	for mote in _motes:
		mote.pos += mote.drift * delta
		mote.pos.x = wrapf(mote.pos.x, 0.0, 1.0)
		if mote.pos.y < -0.02:
			mote.merge(_new_mote(_rng, false), true)
	queue_redraw()


## The dust motes over the picture, under the menu. Each twinkles, and they all fade out with the video's black.
## The logo, blended into the picture: it fades with the video, has a soft dark shadow that lifts it off the forest, and a faint
## warm glow around its edge.
func _draw_logo(share: float) -> void:
	if _logo_texture == null or share <= 0.0:
		return
	var shadow := Rect2(_logo_rect.position + Vector2(0, 5), _logo_rect.size)
	draw_texture_rect(_logo_texture, shadow.grow(3.0), false, Color(0, 0, 0, 0.5 * share))
	draw_texture_rect(_logo_texture, _logo_rect.grow(5.0), false, Color(1.0, 0.8, 0.5, 0.14 * share))
	draw_texture_rect(_logo_texture, _logo_rect, false, Color(1, 1, 1, share))


func _build_fog() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 128
	_fog_texture = texture
	for i in FOG_BANDS:
		_fog_blobs.append({
			"x": _rng.randf(),
			"y": _rng.randf_range(0.78, 0.98),
			"width": _rng.randf_range(0.35, 0.6),
			"height": _rng.randf_range(0.14, 0.24),
			"drift": _rng.randf_range(0.012, 0.03) * (1.0 if _rng.randf() > 0.5 else -1.0),
			"alpha": _rng.randf_range(0.22, 0.34),
		})


## The mist along the floor. Each band drifts sideways, and wraps just beyond the picture's edges so it never pops.
func _draw_fog(art: Rect2, visible_share: float) -> void:
	for blob in _fog_blobs:
		var x: float = wrapf(blob.x + blob.drift * _time, -0.3, 1.3)
		var size := Vector2(blob.width * art.size.x, blob.height * art.size.y)
		var centre := art.position + Vector2(x * art.size.x, blob.y * art.size.y)
		draw_texture_rect(_fog_texture, Rect2(centre - size * 0.5, size), false, Color(0.78, 0.82, 0.9, blob.alpha * visible_share))


func _draw_motes(art: Rect2, k: float, visible_share: float) -> void:
	for mote in _motes:
		var at := art.position + Vector2(mote.pos.x * art.size.x, mote.pos.y * art.size.y)
		var twinkle := 0.5 + 0.5 * sin(_time * 1.3 + mote.phase)
		var alpha: float = (0.25 + 0.45 * twinkle) * visible_share
		draw_circle(at, mote.size * k * 3.0, Color(1.0, 0.85, 0.55, alpha * 0.16))
		draw_circle(at, mote.size * k, Color(1.0, 0.93, 0.75, alpha))


## The picture fills the window and keeps its shape. A window narrower than the picture shows its right
## side, where the menu is.
func _art_rect() -> Rect2:
	var scale := maxf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	var drawn := ART_SIZE * scale
	return Rect2(Vector2(size.x - drawn.x, (size.y - drawn.y) / 2.0), drawn)


## A rectangle of the picture, converted to window coordinates.
func _to_window(src: Rect2, art: Rect2) -> Rect2:
	var scale := art.size.x / ART_SIZE.x
	return Rect2(art.position + src.position * scale, src.size * scale)


## The window rectangle of a button's plate. The invisible Button has the same rectangle.
func _plate(key: String, art: Rect2) -> Rect2:
	return _to_window(BUTTONS[key].grow_individual(PLATE_GROW.x, PLATE_GROW.y, PLATE_GROW.x, PLATE_GROW.y), art)


## The logo picture, added above the background and the menu's plates have no room at the top centre, so it sits clear.
func _build_logo() -> void:
	_logo_texture = load(LOGO)


## The logo at the top centre, as large as its share of the window allows, keeping its shape.
func _place_logo() -> void:
	if _logo_texture == null:
		return
	var aspect: float = _logo_texture.get_width() / float(_logo_texture.get_height())
	var width := minf(size.x * LOGO_MAX_WIDTH_SHARE, size.y * LOGO_MAX_HEIGHT_SHARE * aspect)
	var height := width / aspect
	_logo_rect = Rect2(Vector2((size.x - width) / 2.0, size.y * LOGO_TOP_SHARE), Vector2(width, height))


func _layout() -> void:
	_place_logo()
	var art := _art_rect()
	for key in BUTTONS:
		var rect := _plate(key, art)
		_buttons[key].position = rect.position
		_buttons[key].size = rect.size
	queue_redraw()


func _draw() -> void:
	if _art == null:
		return
	var art := _art_rect()
	draw_texture_rect(_frame(), art, false)
	var k := art.size.x / ART_SIZE.x
	var fade := _fade_alpha()
	if fade > 0.0:
		draw_rect(art, Color(0, 0, 0, fade))
	_draw_logo(1.0 - fade)
	_draw_fog(art, 1.0 - fade)
	_draw_motes(art, k, 1.0 - fade)
	for key in BUTTONS:
		_draw_button(key, _plate(key, art), k)


func _draw_button(key: String, rect: Rect2, k: float) -> void:
	var button: Button = _buttons[key]
	var enabled := not button.disabled
	var lit := enabled and (button.has_focus() or button.is_hovered())
	var fill := PLATE_LIT if lit else PLATE
	var edge := GOLD if lit else EDGE
	var ink := GOLD_LIT if lit else CREAM
	if not enabled:
		edge = Color(EDGE, 0.4)
		ink = Color(CREAM, 0.38)
	if lit:
		draw_rect(rect.grow(3.0 * k), Color(GOLD, 0.7), false, maxf(1.0, 2.0 * k))
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(maxi(2, roundi(2.0 * k)))
	style.set_corner_radius_all(roundi(8.0 * k))
	draw_style_box(style, rect)
	_draw_ornaments(rect, edge, k)
	var icon_size := rect.size.y * 0.5
	var icon_centre := Vector2(rect.position.x + rect.size.x * 0.13, rect.get_center().y)
	_draw_icon(key, icon_centre, icon_size, ink, fill, k)
	var font_size := roundi(rect.size.y * 0.5)
	var text_left := rect.position.x + rect.size.x * 0.25
	var text_width := rect.size.x * 0.69
	var baseline := Vector2(text_left, rect.get_center().y + font_size * 0.36)
	draw_string(_font, baseline, LABELS[key], HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, ink)


## A small point on each side of a plate, like the picture's ornaments.
func _draw_ornaments(rect: Rect2, color: Color, k: float) -> void:
	var mid := rect.get_center().y
	var reach := 11.0 * k
	var spread := 5.0 * k
	for side in [-1.0, 1.0]:
		var x := rect.position.x if side < 0.0 else rect.end.x
		var points := PackedVector2Array([
			Vector2(x, mid - spread),
			Vector2(x + side * reach, mid),
			Vector2(x, mid + spread),
		])
		draw_colored_polygon(points, color)


func _draw_icon(key: String, c: Vector2, s: float, color: Color, plate: Color, k: float) -> void:
	var w := maxf(1.5, 2.2 * k)
	match key:
		"new_game":
			_icon_feather(c, s, color, w)
		"continue":
			_icon_folder(c, s, color)
		"load_game":
			_icon_download(c, s, color, w)
		"settings":
			_icon_gear(c, s, color, plate)
		"gallery":
			_icon_picture(c, s, color, w)
		"credits":
			_icon_people(c, s, color, w)
		"quit":
			_icon_power(c, s, color, w)


func _icon_feather(c: Vector2, s: float, color: Color, w: float) -> void:
	var half_length := s * 0.5
	var half_width := s * 0.2
	var points := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		points.append(c + Vector2(cos(t) * half_length, sin(t) * half_width).rotated(-PI / 4.0))
	draw_colored_polygon(points, color)
	var vein := Color(0, 0, 0, 0.35)
	draw_line(c + Vector2(-half_length * 0.85, 0).rotated(-PI / 4.0), c + Vector2(half_length * 0.85, 0).rotated(-PI / 4.0), vein, w)


func _icon_folder(c: Vector2, s: float, color: Color) -> void:
	draw_rect(Rect2(c.x - s * 0.5, c.y - s * 0.36, s * 0.42, s * 0.2), color, true)
	draw_rect(Rect2(c.x - s * 0.5, c.y - s * 0.2, s, s * 0.56), color, true)


func _icon_download(c: Vector2, s: float, color: Color, w: float) -> void:
	draw_line(c + Vector2(0, -s * 0.45), c + Vector2(0, s * 0.1), color, w * 1.4)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.25, -s * 0.05),
		c + Vector2(s * 0.25, -s * 0.05),
		c + Vector2(0, s * 0.22),
	]), color)
	draw_polyline(PackedVector2Array([
		c + Vector2(-s * 0.45, s * 0.08),
		c + Vector2(-s * 0.45, s * 0.42),
		c + Vector2(s * 0.45, s * 0.42),
		c + Vector2(s * 0.45, s * 0.08),
	]), color, w * 1.4)


func _icon_gear(c: Vector2, s: float, color: Color, plate: Color) -> void:
	draw_arc(c, s * 0.3, 0.0, TAU, 32, color, s * 0.2)
	for i in 8:
		var direction := Vector2.from_angle(TAU * i / 8.0)
		draw_line(c + direction * s * 0.3, c + direction * s * 0.48, color, s * 0.2)
	draw_circle(c, s * 0.12, plate)


func _icon_picture(c: Vector2, s: float, color: Color, w: float) -> void:
	var frame := Rect2(c - Vector2(s * 0.5, s * 0.4), Vector2(s, s * 0.8))
	draw_rect(frame, color, false, w)
	draw_colored_polygon(PackedVector2Array([
		frame.position + Vector2(s * 0.1, s * 0.8),
		frame.position + Vector2(s * 0.45, s * 0.3),
		frame.position + Vector2(s * 0.7, s * 0.8),
	]), color)
	draw_circle(frame.position + Vector2(s * 0.75, s * 0.25), s * 0.08, color)


func _icon_people(c: Vector2, s: float, color: Color, w: float) -> void:
	for offset in [-0.2, 0.2]:
		draw_circle(c + Vector2(offset * s, -s * 0.16), s * 0.14, color)
		draw_arc(c + Vector2(offset * s, s * 0.5), s * 0.26, PI, TAU, 16, color, s * 0.16)


func _icon_power(c: Vector2, s: float, color: Color, w: float) -> void:
	draw_arc(c, s * 0.36, -PI / 2.0 + 0.45, 3.0 * PI / 2.0 - 0.45, 28, color, w * 1.6)
	draw_line(c + Vector2(0, -s * 0.42), c + Vector2(0, -s * 0.02), color, w * 1.6)


func _unhandled_input(event: InputEvent) -> void:
	if _confirm.visible and event.is_action_pressed("ui_cancel"):
		_hide_confirm()


func _on_pressed(key: String) -> void:
	match key:
		"new_game":
			if SaveSystem.has_save():
				_confirm.visible = true
			else:
				_start_new_game()
		"continue", "load_game":
			get_tree().change_scene_to_file(GAME_SCENE)
		"quit":
			get_tree().quit()
		_:
			_show_notice("Coming soon")


func _start_new_game() -> void:
	SaveSystem.start_new_game()
	get_tree().change_scene_to_file(GAME_SCENE)


func _hide_confirm() -> void:
	_confirm.visible = false
	_buttons["new_game"].grab_focus()


func _show_notice(text: String) -> void:
	_notice.text = text
	_notice.reset_size()
	_notice.position = Vector2((size.x - _notice.size.x) / 2.0, size.y - 60.0)
	_notice.modulate.a = 1.0
	_notice.visible = true
	if _notice_tween:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(2.0)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.6)
	_notice_tween.tween_callback(_notice.hide)
