class_name Badge
extends Control
## A small round count badge. It hides at zero. With a count, it breathes gently to catch the eye.

const SIZE := Vector2(22, 22)

@export var count := 0:
	set(value):
		count = value
		_apply()

var _text: Label
var _tween: Tween


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(UiKit.picture(UiKit.texture(UiAssets.BADGE))))
	_text = UiKit.label(12, UiKit.GOLD_LIT)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(UiKit.fill(_text))
	_apply()


func _apply() -> void:
	if _text == null:
		return
	visible = count > 0
	_text.text = "9+" if count > 9 else str(count)
	if _tween:
		_tween.kill()
		_tween = null
	scale = Vector2.ONE
	if visible:
		_tween = create_tween().set_loops()
		_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.7).set_trans(Tween.TRANS_SINE)
		_tween.tween_property(self, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
