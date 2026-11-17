class_name IconButton
extends Control
## A square button: a frame, an icon in it, and an optional count badge. The frame is the same for every button.
## Only the icon, the tooltip and the count change. Pressing it emits `activated` with its action.

signal activated(action: String)

## The size of the frame picture, so it shows whole, at its own proportions.
const SIZE := Vector2(70, 61)

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_apply()
@export var label_text := "":
	set(value):
		label_text = value
		_apply()
@export var button_action := ""
@export var notification_count := 0:
	set(value):
		notification_count = value
		_apply()
@export var is_enabled := true:
	set(value):
		is_enabled = value
		_apply()
@export var is_selected := false:
	set(value):
		is_selected = value
		_apply()

var _frame: TextureRect
var _content: Control
var _icon: TextureRect
var _badge: Badge
var _label: Label
var _button: Button
var _hovered := false


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = UiKit.picture(UiKit.texture(UiAssets.FRAME_SQUARE))
	add_child(UiKit.fill(_frame))
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(_content))
	_icon = UiKit.picture(null)
	_icon.anchor_left = 0.26
	_icon.anchor_top = 0.14
	_icon.anchor_right = 0.74
	_icon.anchor_bottom = 0.6
	_content.add_child(_icon)
	_label = UiKit.label(9, UiKit.CREAM)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.anchor_left = 0.02
	_label.anchor_top = 0.64
	_label.anchor_right = 0.98
	_label.anchor_bottom = 0.92
	_content.add_child(_label)
	_badge = Badge.new()
	_badge.position = Vector2(SIZE.x - 14, -6)
	add_child(_badge)
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
	_icon.texture = icon_texture
	_icon.visible = icon_texture != null
	_label.text = label_text
	_label.visible = label_text != ""
	_badge.count = notification_count
	_button.disabled = not is_enabled
	_button.tooltip_text = tooltip_text
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
