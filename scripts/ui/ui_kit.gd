class_name UiKit
## Shared pieces the HUD components use: labels in the game's colours, pictures, invisible hit areas, a key
## cap, and the colours for hover, press and selection.

const CREAM := Color("#f3e3c3")
const GOLD := Color("#e8c77a")
const GOLD_LIT := Color("#fff1c9")
const SHADOW := Color(0, 0, 0, 0.9)
const TINT_NORMAL := Color(1, 1, 1)
const TINT_HOVER := Color(1.25, 1.15, 0.9)
const TINT_SELECTED := Color(1.4, 1.2, 0.75)
const DISABLED_ALPHA := 0.45
## The key cap, cream with a dark letter, as in the reference.
const KEYCAP_FILL := Color("#efe3c6")
const KEYCAP_EDGE := Color("#5a3a1e")
const KEYCAP_INK := Color("#2b1a0e")


static var _font: SystemFont


## The serif the reference uses for its words, from the fonts the device has.
static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Cinzel", "Georgia", "Times New Roman", "serif"])
	return _font


static var _italic: SystemFont


## The same serif in italic, for a line that reads as an aside, such as a chapter's name.
static func italic_font() -> SystemFont:
	if _italic == null:
		_italic = SystemFont.new()
		_italic.font_names = font().font_names
		_italic.font_italic = true
	return _italic


static var _bold: SystemFont


## The same serif in bold, for a heading that has to stand out from the words under it.
static func bold_font() -> SystemFont:
	if _bold == null:
		_bold = SystemFont.new()
		_bold.font_names = font().font_names
		_bold.font_weight = 700
	return _bold


static func texture(path: String) -> Texture2D:
	return load(path) as Texture2D


static func label(font_size: int, colour: Color = CREAM) -> Label:
	var text := Label.new()
	text.add_theme_font_override("font", font())
	text.add_theme_font_size_override("font_size", font_size)
	text.add_theme_color_override("font_color", colour)
	text.add_theme_color_override("font_shadow_color", SHADOW)
	text.add_theme_constant_override("shadow_offset_x", 1)
	text.add_theme_constant_override("shadow_offset_y", 1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return text


## A picture that keeps its shape, or stretches to fill when keep_aspect is false.
static func picture(picture_texture: Texture2D, keep_aspect := true) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = picture_texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep_aspect else TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func fill(node: Control) -> Control:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	return node


## An invisible button over a component. It takes the clicks, touches and keyboard presses.
static func hit_area() -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style, empty)
	fill(button)
	return button


## A small key cap showing a key, such as "E". The letter is the cap's second child.
static func keycap(key_text: String, cap_size := 26.0) -> Control:
	var cap := Panel.new()
	cap.custom_minimum_size = Vector2(cap_size, cap_size)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = KEYCAP_FILL
	style.border_color = KEYCAP_EDGE
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	cap.add_theme_stylebox_override("panel", style)
	var letter := label(roundi(cap_size * 0.7), KEYCAP_INK)
	letter.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(fill(letter))
	set_keycap_text(cap, key_text)
	return cap


static func set_keycap_text(cap: Control, key_text: String) -> void:
	(cap.get_child(0) as Label).text = key_text
