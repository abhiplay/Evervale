class_name LocationPanel
extends Control
## The place at the top left: its icon, the place's name and its chapter, a chevron that folds the objective away, and a
## gold divider underneath. Nothing is drawn behind them, so the room shows through.

## Sent when the chevron is pressed, with whether the objective should now be shown.
signal expand_toggled(shown: bool)

## Space left of the emblem, so the block sits in the corner with room to spare.
const INSET := 10.0
const SIZE := Vector2(218, 56)
const ICON_SIZE := 42.0
const TEXT_LEFT := 60.0
const CHAPTER_COLOUR := Color("#dcc397")
## The chevron's tap area sits in the top right corner. It is larger than the chevron, so it is easy to hit.
const TAP_SIZE := 36.0
const CHEVRON_COLOUR := Color("#f8ead0")
const CHEVRON_HALF := Vector2(7, 4)
const DIVIDER_TOP := 44.0
const DIVIDER_HEIGHT := 13.0

@export var location_name := "":
	set(value):
		location_name = value
		_apply()
@export var chapter_name := "":
	set(value):
		chapter_name = value
		_apply()
@export var location_icon: Texture2D:
	set(value):
		location_icon = value
		_apply()

## Whether the objective is shown. The chevron turns it on and off.
var expanded := true

var _emblem: TextureRect
var _name: Label
var _chapter: Label
var _chevron: Control


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem = UiKit.picture(null)
	_emblem.position = Vector2(INSET, -2)
	_emblem.size = Vector2(ICON_SIZE, ICON_SIZE)
	add_child(_emblem)
	_name = UiKit.label(20, UiKit.CREAM)
	_name.position = Vector2(TEXT_LEFT, -2)
	_name.size = Vector2(SIZE.x - TEXT_LEFT - TAP_SIZE, 26)
	add_child(_name)
	_chapter = UiKit.label(11, CHAPTER_COLOUR)
	_chapter.add_theme_font_override("font", UiKit.italic_font())
	_chapter.position = Vector2(TEXT_LEFT, 22)
	_chapter.size = Vector2(SIZE.x - TEXT_LEFT, 16)
	add_child(_chapter)
	var divider := UiKit.picture(UiKit.texture(UiAssets.DIVIDER), false)
	divider.position = Vector2(INSET - 1, DIVIDER_TOP)
	divider.size = Vector2(SIZE.x - INSET - 1, DIVIDER_HEIGHT)
	add_child(divider)
	_chevron = Control.new()
	_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner(_chevron)
	_chevron.draw.connect(_draw_chevron)
	add_child(_chevron)
	var tap := UiKit.hit_area()
	_corner(tap)
	tap.pressed.connect(_toggle)
	add_child(tap)
	_apply()


## Puts a control in the top right corner, reaching a little above and beyond the block so it is easy to tap.
func _corner(node: Control) -> void:
	node.anchor_left = 1.0
	node.anchor_right = 1.0
	node.anchor_top = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = -TAP_SIZE
	node.offset_right = 14.0
	node.offset_top = -6.0
	node.offset_bottom = TAP_SIZE - 6.0


## A small caret: pointing up while the objective shows, down while it is folded away.
func _draw_chevron() -> void:
	var centre := _chevron.size / 2.0
	var lift := 1.0 if expanded else -1.0
	var points := PackedVector2Array([
		centre + Vector2(-CHEVRON_HALF.x, CHEVRON_HALF.y * lift),
		centre + Vector2(0.0, -CHEVRON_HALF.y * lift),
		centre + Vector2(CHEVRON_HALF.x, CHEVRON_HALF.y * lift),
	])
	_chevron.draw_polyline(points, CHEVRON_COLOUR, 2.4, true)


func _toggle() -> void:
	expanded = not expanded
	_chevron.queue_redraw()
	expand_toggled.emit(expanded)


func _apply() -> void:
	if _name == null:
		return
	_name.text = location_name
	_chapter.text = chapter_name
	_emblem.texture = location_icon
	_emblem.visible = location_icon != null
