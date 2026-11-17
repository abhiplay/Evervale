class_name DialogueIcon
extends Control
## The round icon on a dialogue button: a dark disc with a gold ring and a play, skip or hide glyph.

enum Kind { PLAY, SKIP, HIDE }

const GOLD := Color("#f2c14e")
const DISC := Color("#2a140a")

var kind: Kind = Kind.PLAY


func _init(icon_kind: Kind = Kind.PLAY) -> void:
	kind = icon_kind
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var centre := size / 2.0
	var radius := minf(size.x, size.y) / 2.0
	draw_circle(centre, radius, DISC)
	draw_arc(centre, radius - 2.0, 0.0, TAU, 48, GOLD, 3.0, true)
	var s := radius * 0.9
	match kind:
		Kind.PLAY:
			draw_colored_polygon(PackedVector2Array([
				centre + Vector2(-0.3, -0.5) * s, centre + Vector2(-0.3, 0.5) * s, centre + Vector2(0.5, 0.0) * s,
			]), GOLD)
		Kind.SKIP:
			draw_colored_polygon(PackedVector2Array([
				centre + Vector2(-0.6, -0.45) * s, centre + Vector2(-0.6, 0.45) * s, centre + Vector2(-0.05, 0.0) * s,
			]), GOLD)
			draw_colored_polygon(PackedVector2Array([
				centre + Vector2(-0.05, -0.45) * s, centre + Vector2(-0.05, 0.45) * s, centre + Vector2(0.5, 0.0) * s,
			]), GOLD)
			draw_rect(Rect2(centre + Vector2(0.52, -0.45) * s, Vector2(0.12, 0.9) * s), GOLD)
		Kind.HIDE:
			var eye := PackedVector2Array()
			for i in 25:
				var t := float(i) / 24.0 * TAU
				eye.append(centre + Vector2(cos(t) * 0.62, sin(t) * 0.33) * s)
			draw_polyline(eye, GOLD, 2.5, true)
			draw_circle(centre, 0.18 * s, GOLD)
			draw_line(centre + Vector2(-0.6, 0.5) * s, centre + Vector2(0.6, -0.5) * s, GOLD, 2.5, true)
