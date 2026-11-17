class_name CaveEntrance
extends "res://scripts/exterior_home.gd"
## The Hollow Cave's entrance path, on the left of the forest. The path to the right goes back
## into the forest; walking into the cave mouth goes inside. No gate to the map and no door.


func _init() -> void:
	PICTURE_PATH = "res://assets/environments/cave_entrance.webp"
	COLLISION_DATA = "res://data/cave_entrance_collision.json"
	IMAGE_SIZE = Vector2(1671, 941)
	SPAWN_DEFAULT = Vector2(1620, 425)
	SPAWNS = {
		"from_forest": Vector2(1620, 425),
		"from_interior": Vector2(220, 420),
	}
	GATE_RECT = Rect2(0, 0, 0, 0)
	EXITS = [
		{"rect": Rect2(1652, 400, 19, 52), "scene": "res://scenes/Forest.tscn", "spawn": "from_cave"},
		{"rect": Rect2(180, 352, 60, 48), "scene": "res://scenes/CaveInterior.tscn", "spawn": "from_entrance"},
	]
	HAS_DOOR = false
	MAP_PLACE = "forest"
	SCENE_ID = "cave_entrance"
