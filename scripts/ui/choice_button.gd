class_name ChoiceButton
extends Control
## A wide button for a choice, a tab or a command. It is drawn with the discovery frames: the glowing frame while it is
## chosen or has focus, the dark frame otherwise. An optional icon sits at its left and lights up with the frame. Pressing
## it emits `pressed_choice` with its choice; gaining focus emits `focused_choice`. Call setup() before adding it to the tree.

signal pressed_choice(choice: String)
signal focused_choice(choice: String)

const SIZE := Vector2(230, 48)
const ICON_BOX := 28.0
const ICON_INSET := 12.0
const ICON_LIT := Color(1.25, 1.12, 0.9)
const ICON_DIM := Color(0.82, 0.78, 0.7)

var choice := ""
## The choice in effect, such as the chosen tab. It keeps the glowing frame when the button has no focus.
var is_chosen := false:
	set(value):
		is_chosen = value
		_refresh_look()

var _dark: TextureRect
var _glow: TextureRect
var _icon: TextureRect
var _words: Label
var _button: Button
var _focused := false


func setup(text: String, value: String, icon_path: String = "", font_size: int = 20) -> void:
	choice = value
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark = UiKit.picture(UiKit.texture(UiAssets.BUTTON_DARK))
	add_child(UiKit.fill(_dark))
	_glow = UiKit.picture(UiKit.texture(UiAssets.BUTTON_GLOW))
	add_child(UiKit.fill(_glow))
	if icon_path != "":
		_icon = UiKit.picture(UiKit.texture(icon_path))
		_icon.anchor_top = 0.5
		_icon.anchor_bottom = 0.5
		_icon.offset_left = ICON_INSET
		_icon.offset_right = ICON_INSET + ICON_BOX
		_icon.offset_top = -ICON_BOX / 2.0
		_icon.offset_bottom = ICON_BOX / 2.0
		add_child(_icon)
	_words = UiKit.label(font_size, UiKit.CREAM)
	_words.text = text
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.fill(_words)
	if _icon != null:
		_words.offset_left = ICON_INSET + ICON_BOX + 6.0
	add_child(_words)
	_button = UiKit.hit_area()
	add_child(_button)
	_button.pressed.connect(func(): pressed_choice.emit(choice))
	_button.focus_entered.connect(_on_focus_entered)
	_button.focus_exited.connect(_on_focus_exited)
	_button.mouse_entered.connect(func(): _button.grab_focus())
	_refresh_look()


func focus_button() -> void:
	_button.grab_focus()


## Changes the words on the button, such as Read to View. Does nothing before setup() has made the words.
func set_text(text: String) -> void:
	if _words != null:
		_words.text = text


func _refresh_look() -> void:
	if _glow == null:
		return
	var lit := is_chosen or _focused
	_glow.visible = lit
	_dark.visible = not lit
	if _icon != null:
		_icon.modulate = ICON_LIT if lit else ICON_DIM


func _on_focus_entered() -> void:
	_focused = true
	_refresh_look()
	focused_choice.emit(choice)


func _on_focus_exited() -> void:
	_focused = false
	_refresh_look()
