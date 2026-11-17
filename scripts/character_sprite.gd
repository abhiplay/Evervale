class_name CharacterSprite
extends AnimatedSprite2D
## Amelia's walk cycle in eight directions, from the strip sheets in data/character_animations.json. The feet sit on the node's origin, so the
## player's collision (at the feet) lines up with the picture.

## The animation data for this character's sheets. Set it before the sprite enters the tree.
var animations_path := "res://data/character_animations.json"

## Direction for each 45 degree step, starting at "right" and going clockwise
## on screen (y points down). Each entry: [animation name, flip horizontally].
const DIRECTIONS := [
	["walk_east", false],        # right
	["walk_south_east", false],  # down-right
	["walk_south", false],       # down
	["walk_south_west", false],  # down-left
	["walk_west", false],        # left
	["walk_north_west", false],  # up-left
	["walk_north", false],       # up
	["walk_north_east", false],  # up-right
]

@export var character_scale := 0.085

var _feet_offset := {}
var _current_animation := ""
var _current_flip := false
## The way the figure last moved or turned, so a talk can turn it back afterwards.
var facing := Vector2.DOWN
const FEET_REFERENCE_SCALE := 0.16


## The collision at a figure's feet, sized for its scale. It grows with the sprite, so a bigger figure keeps the same gaps.
static func feet_collider(figure_scale: float) -> CollisionShape2D:
	var body_scale := figure_scale / FEET_REFERENCE_SCALE
	var shape := CollisionShape2D.new()
	# A capsule lying on its side, as wide and deep as the feet: its round ends slide along walls and round furniture
	# corners instead of catching on them.
	var capsule := CapsuleShape2D.new()
	capsule.radius = 6 * body_scale
	capsule.height = 18 * body_scale
	shape.shape = capsule
	shape.rotation = PI / 2
	shape.position = Vector2(0, -6 * body_scale)
	return shape


func _ready() -> void:
	sprite_frames = _build_frames()
	scale = Vector2.ONE * character_scale
	centered = true
	_set_direction(2, false)  # start facing the viewer


func _build_frames() -> SpriteFrames:
	var data = JSON.parse_string(FileAccess.get_file_as_string(animations_path))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var fps: float = data.fps
	for anim in data.animations:
		var name: String = anim.name
		var sheet: Texture2D = load(anim.file)
		var width: int = anim.frame_width
		var height: int = anim.frame_height
		frames.add_animation(name)
		frames.set_animation_speed(name, fps)
		frames.set_animation_loop(name, true)
		for i in anim.frames:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(i * width, 0, width, height)
			frames.add_frame(name, frame)
		# Move the picture up so the feet line is at the origin.
		_feet_offset[name] = Vector2(0, height / 2.0 - anim.anchor_y)
	return frames


## Call every physics frame with the movement direction (zero when standing still).
func update_movement(dir: Vector2) -> void:
	if dir.length() > 0.1:
		var step := posmod(roundi(dir.angle() / (PI / 4.0)), 8)
		facing = dir.normalized()
		_set_direction(step, true)
	elif is_playing():
		stop()
		frame = 0


## Turns to face a direction and stands still, as a figure does while someone talks to it.
func face(dir: Vector2) -> void:
	if dir.length() < 0.1:
		return
	facing = dir.normalized()
	_set_direction(posmod(roundi(dir.angle() / (PI / 4.0)), 8), false)
	stop()
	frame = 0


func _set_direction(step: int, moving: bool) -> void:
	var entry: Array = DIRECTIONS[step]
	var name: String = entry[0]
	var flip: bool = entry[1]
	if name != _current_animation or flip != _current_flip:
		_current_animation = name
		_current_flip = flip
		animation = name
		flip_h = flip
		offset = _feet_offset[name]
	if moving and not is_playing():
		play(name)
	elif not moving:
		frame = 0
