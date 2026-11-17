class_name ItemSlot
extends Control
## A square slot for one item: a frame, the item's picture, and how many there are. An empty slot shows a faint
## plus. Pressing it emits `activated` with its slot number.

signal activated(slot_index: int)

const SIZE := Vector2(64, 56)

@export var item_texture: Texture2D:
	set(value):
		item_texture = value
		_apply()
@export var item_quantity := 0:
	set(value):
		item_quantity = value
		_apply()
@export var is_selected := false:
	set(value):
		is_selected = value
		_apply()
@export var slot_index := 0
## Whether an empty slot shows a faint plus. The inventory's grid does not.
@export var show_plus := true
## The slot's size. The inventory's grid is larger than the quick slots.
@export var slot_size := SIZE
## The key that uses this slot, shown in a key cap on its bottom edge. Empty hides it.
@export var key_hint := "":
	set(value):
		key_hint = value
		_apply()

## True when nothing is in the slot.
var is_empty: bool:
	get:
		return item_texture == null

var _frame: TextureRect
var _picture: TextureRect
var _quantity: Label
var _plus: Label
var _key: Control
var _button: Button
var _hovered := false
var _focused := false


func _ready() -> void:
	custom_minimum_size = slot_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = UiKit.picture(UiKit.texture(UiAssets.SLOT))
	add_child(UiKit.fill(_frame))
	_picture = UiKit.picture(null)
	_picture.anchor_left = 0.16
	_picture.anchor_top = 0.14
	_picture.anchor_right = 0.84
	_picture.anchor_bottom = 0.86
	add_child(_picture)
	_quantity = UiKit.label(11)
	_quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quantity.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_quantity.anchor_left = 0.4
	_quantity.anchor_top = 0.5
	_quantity.anchor_right = 0.92
	_quantity.anchor_bottom = 0.94
	add_child(_quantity)
	_plus = UiKit.label(22, UiKit.GOLD)
	_plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plus.modulate.a = 0.85
	_plus.text = "+"
	add_child(UiKit.fill(_plus))
	_key = UiKit.keycap("")
	_key.anchor_left = 0.5
	_key.anchor_right = 0.5
	_key.anchor_top = 1.0
	_key.anchor_bottom = 1.0
	_key.offset_left = -13
	_key.offset_right = 13
	_key.offset_top = -13
	_key.offset_bottom = 13
	add_child(_key)
	_button = UiKit.hit_area()
	add_child(_button)
	_button.pressed.connect(func(): activated.emit(slot_index))
	_button.mouse_entered.connect(func(): _set_hovered(true))
	_button.mouse_exited.connect(func(): _set_hovered(false))
	_button.focus_entered.connect(func(): _set_focused(true))
	_button.focus_exited.connect(func(): _set_focused(false))
	_apply()


func _apply() -> void:
	if _frame == null:
		return
	_picture.texture = item_texture
	_picture.visible = item_texture != null
	_quantity.text = str(item_quantity)
	_quantity.visible = item_texture != null and item_quantity > 1
	_plus.visible = is_empty and show_plus
	UiKit.set_keycap_text(_key, key_hint)
	_key.visible = key_hint != ""
	_refresh_frame()


func _set_focused(value: bool) -> void:
	_focused = value
	_refresh_frame()


func _set_hovered(value: bool) -> void:
	_hovered = value
	_refresh_frame()


func _refresh_frame() -> void:
	if is_selected:
		_frame.modulate = UiKit.TINT_SELECTED
	elif _hovered or _focused:
		_frame.modulate = UiKit.TINT_HOVER
	else:
		_frame.modulate = UiKit.TINT_NORMAL
