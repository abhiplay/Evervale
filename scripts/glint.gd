class_name Glint
extends Node2D
## A small four-point sparkle that flickers, for a place the protagonist still has to find. A soft blue bloom surrounds a
## bright core. The brightness jumps about at random, so it reads as light catching something rather than a steady glow.

const COLOUR := Color("#9fd4ff")
const RADIUS := 13.0
const RAY_LENGTH := 22.0

var _time := 0.0
var _target := 1.0
var _brightness := 1.0
var _next_jump := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	z_index = 20


func _process(delta: float) -> void:
	_time += delta
	if _time >= _next_jump:
		_target = _rng.randf_range(0.3, 1.0)
		_next_jump = _time + _rng.randf_range(0.04, 0.35)
	_brightness = lerpf(_brightness, _target, minf(1.0, delta * 14.0))
	queue_redraw()


func _draw() -> void:
	# A slow swell on top of the flicker, so the sparkle never goes fully dark.
	var swell := 0.75 + 0.25 * sin(_time * 1.7)
	var strength := _brightness * swell
	for i in 3:
		var size := RADIUS * (1.0 + i * 0.55)
		draw_circle(Vector2.ZERO, size, Color(COLOUR, 0.1 * strength / (i + 1)))
	var ray := Color(1.0, 1.0, 1.0, 0.9 * strength)
	draw_line(Vector2(-RAY_LENGTH, 0), Vector2(RAY_LENGTH, 0), ray, 1.5)
	draw_line(Vector2(0, -RAY_LENGTH), Vector2(0, RAY_LENGTH), ray, 1.5)
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 1.0, minf(1.0, strength)))
