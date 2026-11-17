class_name InteractionPrompt
extends Control
## The contextual prompt at the bottom centre: a key and what it does, such as "E  Enter House". It only shows
## when something can be done, and fades in and out.

const SIZE := Vector2(340, 52)

@export var prompt_text := "":
	set(value):
		prompt_text = value
		_apply()
@export var key_text := "E":
	set(value):
		key_text = value
		_apply()

var _keycap: Control
var _label: Label
var _tween: Tween


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := UiKit.picture(UiKit.texture(UiAssets.FRAME_WIDE))
	add_child(UiKit.fill(frame))
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(content))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(row)
	row.offset_left = 66
	row.offset_right = -66
	content.add_child(row)
	_keycap = UiKit.keycap(key_text, 30.0)
	row.add_child(_keycap)
	_label = UiKit.label(24)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)
	visible = false
	_apply()


func _apply() -> void:
	if _label == null:
		return
	UiKit.set_keycap_text(_keycap, key_text)
	_label.text = prompt_text
	# A long prompt takes a smaller word size, so it stays inside the bar.
	_label.add_theme_font_size_override("font_size", 24 if prompt_text.length() <= 14 else 18)
	_fade(prompt_text != "")


func _fade(show_it: bool) -> void:
	if show_it and visible and modulate.a >= 1.0:
		return
	if not show_it and not visible:
		return
	if _tween:
		_tween.kill()
	if show_it and not visible:
		visible = true
		modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0 if show_it else 0.0, 0.2)
	if not show_it:
		_tween.tween_callback(func(): visible = false)
