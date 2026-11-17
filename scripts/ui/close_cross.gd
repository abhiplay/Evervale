class_name CloseCross
extends Control
## A close button: a gold medallion with a cross drawn on it. The cross lights up under the mouse and when the button
## has keyboard focus. Pressing it emits `pressed`. The inventory and the item viewer both close with it.

signal pressed

const SIZE := Vector2(34, 34)

var _mark: Control
var _button: Button
var _hovered := false
var _focused := false


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(UiKit.picture(UiKit.texture(UiAssets.BADGE))))
	_mark = Control.new()
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.draw.connect(_draw_mark)
	add_child(UiKit.fill(_mark))
	_button = UiKit.hit_area()
	_button.pressed.connect(func(): pressed.emit())
	_button.mouse_entered.connect(_set_hovered.bind(true))
	_button.mouse_exited.connect(_set_hovered.bind(false))
	_button.focus_entered.connect(_set_focused.bind(true))
	_button.focus_exited.connect(_set_focused.bind(false))
	add_child(_button)


## Gives the cross the keyboard focus, so Enter or E presses it.
func focus_button() -> void:
	_button.grab_focus()


func _set_hovered(on: bool) -> void:
	_hovered = on
	_mark.queue_redraw()


func _set_focused(on: bool) -> void:
	_focused = on
	_mark.queue_redraw()


func _draw_mark() -> void:
	var colour: Color = UiKit.GOLD_LIT if _hovered or _focused else UiKit.CREAM
	var box := _mark.size
	var inset := box * 0.34
	_mark.draw_line(inset, box - inset, colour, 3.0, true)
	_mark.draw_line(Vector2(box.x - inset.x, inset.y), Vector2(inset.x, box.y - inset.y), colour, 3.0, true)
