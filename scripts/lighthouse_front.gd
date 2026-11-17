class_name LighthouseFront
extends "res://scripts/exterior_home.gd"
## The open ground in front of the lighthouse, entered from the town map's Lighthouse place.
## The stone path runs from the gate at the top down to the tower. Walking into the gate goes
## back to the map.


func _init() -> void:
	PICTURE_PATH = "res://assets/environments/lighthouse_front.png"
	COLLISION_DATA = "res://data/lighthouse_front_collision.json"
	IMAGE_SIZE = Vector2(1024, 640)
	SPAWN_DEFAULT = Vector2(512, 90)
	SPAWN_FROM_MAP = Vector2(512, 90)
	SPAWNS = {
		"from_map": Vector2(512, 90),
	}
	GATE_RECT = Rect2(440, 0, 140, 24)
	HAS_DOOR = false
	MAP_PLACE = "lighthouse"
	SCENE_ID = "lighthouse_front"
