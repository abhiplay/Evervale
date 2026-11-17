class_name HorizontalButton
extends Control
## A wide button with laurel ends: an optional icon, the label and an optional key. The frame is the same for every
## button. Only the words, the icon and the key change. Pressing it emits `activated` with its action.

signal activated(action: String)

const SIZE := Vector2(280, 47)

@export var label_text := "":
	set(value):
		label_text = value
		_apply()
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_apply()
@export var key_binding := "":
	set(value):
		key_binding = value
		_apply()
@export var is_enabled := true:
	set(value):
		is_enabled = value
		_apply()
@export var is_selected := false:
	set(value):
		is_selected = value
		_apply()
@export var button_action := ""

var _frame: TextureRect
var _content: Control
var _row: HBoxContainer
var _icon: TextureRect
var _label: Label
var _keycap: Control
var _button: Button
var _hovered := false


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = UiKit.picture(UiKit.texture(UiAssets.FRAME_BUTTON))
	add_child(UiKit.fill(_frame))
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(_content))
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 8)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(_row)
	_row.offset_left = 66
	_row.offset_right = -66
	_content.add_child(_row)
	_icon = UiKit.picture(null)
	_icon.custom_minimum_size = Vector2(26, 26)
	_row.add_child(_icon)
	_label = UiKit.label(18)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(_label)
	_keycap = UiKit.keycap("")
	_row.add_child(_keycap)
	_button = UiKit.hit_area()
	add_child(_button)
	_button.pressed.connect(func(): activated.emit(button_action))
	_button.mouse_entered.connect(func(): _set_hovered(true))
	_button.mouse_exited.connect(func(): _set_hovered(false))
	_button.button_down.connect(func(): _content.position = Vector2(0, 2))
	_button.button_up.connect(func(): _content.position = Vector2.ZERO)
	_apply()


func _apply() -> void:
	if _frame == null:
		return
	_label.text = label_text
	_icon.texture = icon_texture
	_icon.visible = icon_texture != null
	_keycap.visible = key_binding != ""
	UiKit.set_keycap_text(_keycap, key_binding)
	_button.disabled = not is_enabled
	modulate.a = 1.0 if is_enabled else UiKit.DISABLED_ALPHA
	_refresh_frame()


func _set_hovered(value: bool) -> void:
	_hovered = value
	_refresh_frame()


func _refresh_frame() -> void:
	if is_selected:
		_frame.modulate = UiKit.TINT_SELECTED
	elif _hovered and is_enabled:
		_frame.modulate = UiKit.TINT_HOVER
	else:
		_frame.modulate = UiKit.TINT_NORMAL
