class_name PlaceholderPerson
extends Node2D
## A stand-in for a person who has no art yet: a coloured figure with the name above it. Replace it
## with the real sprite once the art exists.


func _init(name_text: String = "", body_colour: Color = Color("#8a7a6a")) -> void:
	display_name = name_text
	colour = body_colour
	z_index = 5
	scale = Vector2(1.9, 1.9)


var display_name := ""
var colour := Color("#8a7a6a")


func _draw() -> void:
	# The feet are at the origin: body 34 wide and 52 tall, head 13 across, name above.
	draw_rect(Rect2(-17, -52, 34, 52), colour)
	draw_circle(Vector2(0, -60), 13, Color("#f2d6b3"))
	draw_string(ThemeDB.fallback_font, Vector2(-40, -80), display_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color.WHITE)
