class_name TempleCourtyard
extends "res://scripts/exterior_home.gd"
## The temple's front courtyard. Same behaviour as the home courtyard, with its own picture,
## collisions, door and gate. The door leads into the temple interior.


func _init() -> void:
	PICTURE_PATH = "res://assets/environments/temple_courtyard.webp"
	COLLISION_DATA = "res://data/temple_courtyard_collision.json"
	IMAGE_SIZE = Vector2(1672, 940)
	SPAWN_DEFAULT = Vector2(840, 520)
	SPAWN_FROM_MAP = Vector2(842, 735)
	SPAWNS = {
		"from_temple_interior": Vector2(840, 390),
		"from_map": Vector2(842, 735),
	}
	GATE_RECT = Rect2(775, 805, 135, 45)
	ENTER_POSITION = Vector2(840, 370)
	ENTER_LABEL = "Enter the temple"
	ENTER_HOME_SCENE = "res://scenes/TempleInterior.tscn"
	ENTER_HOME_SPAWN = "from_courtyard"
	MAP_PLACE = "temple"
	SCENE_ID = "temple_courtyard"
