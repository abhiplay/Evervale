class_name NotificationSystem
extends Control
## A short notice above the prompt, such as "Coming soon". It fades in, holds for a moment, and fades out. A new
## notice replaces the one showing.

const SIZE := Vector2(300, 46)
const HOLD_SECONDS := 2.4

var _label: Label
var _tween: Tween


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := BasePanel.new()
	frame.setup(UiAssets.PANEL_SMALL, 28, 26)
	add_child(UiKit.fill(frame))
	_label = UiKit.label(16, UiKit.GOLD_LIT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(UiKit.fill(_label))
	visible = false


func show_text(text: String) -> void:
	_label.text = text
	if _tween:
		_tween.kill()
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.25)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	_tween.tween_callback(func(): visible = false)
