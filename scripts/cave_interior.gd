class_name CaveInterior
extends "res://scripts/exterior_home.gd"
## Inside the Hollow Cave. The floor paths are walkable; the way out is at the bottom left.


func _init() -> void:
	PICTURE_PATH = "res://assets/environments/cave_interior.webp"
	COLLISION_DATA = "res://data/cave_interior_collision.json"
	IMAGE_SIZE = Vector2(1670, 941)
	SPAWN_DEFAULT = Vector2(400, 840)
	SPAWNS = {
		"from_entrance": Vector2(1290, 765),
		"from_temple_stairs": Vector2(330, 660),
	}
	GATE_RECT = Rect2(0, 0, 0, 0)
	EXITS = [
		{"rect": Rect2(300, 820, 70, 45), "scene": "res://scenes/CaveEntrance.tscn", "spawn": "from_interior"},
		# The hidden path up to the temple's stairs. It stays shut until the temple_stairs_open flag is set.
		{"rect": Rect2(318, 696, 46, 36), "scene": "res://scenes/TempleInterior.tscn", "spawn": "from_cave_stairs", "requires": "temple_stairs_open"},
	]
	HAS_DOOR = false
	MAP_PLACE = "forest"
	SCENE_ID = "cave_interior"
