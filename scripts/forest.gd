class_name Forest
extends "res://scripts/exterior_home.gd"
## The forest, entered from the town map. The character walks the dirt paths. The gate at the
## bottom goes back to the map, and the path to the left leads to the cave entrance. No door.


func _init() -> void:
	PICTURE_PATH = "res://assets/environments/forest.webp"
	COLLISION_DATA = "res://data/forest_collision.json"
	IMAGE_SIZE = Vector2(1672, 941)
	SPAWN_DEFAULT = Vector2(790, 850)
	SPAWN_FROM_MAP = Vector2(790, 850)
	SPAWNS = {
		"from_map": Vector2(790, 850),
		"from_cave": Vector2(80, 405),
	}
	GATE_RECT = Rect2(720, 905, 110, 36)
	EXITS = [
		{"rect": Rect2(0, 360, 50, 90), "scene": "res://scenes/CaveEntrance.tscn", "spawn": "from_forest"},
	]
	HAS_DOOR = false
	MAP_PLACE = "forest"
	SCENE_ID = "forest"
