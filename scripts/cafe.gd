class_name Cafe
extends "res://scripts/exterior_home.gd"
## The café. Its picture, walls, lamps, lighting and furniture covers are nodes in Cafe.tscn, so
## they show in the 2D tab; this script only links them to the character. The door at the front
## goes back out to the Town square.


func _init() -> void:
	SPAWN_DEFAULT = Vector2(835, 740)
	SPAWNS = {
		"from_town": Vector2(835, 740),
	}
	GATE_RECT = Rect2(0, 0, 0, 0)
	EXITS = [
		{"rect": Rect2(735, 800, 200, 80), "scene": "res://scenes/TownSquare.tscn", "spawn": "from_cafe"},
	]
	HAS_DOOR = false
	MAP_PLACE = "town_square"
	SCENE_ID = "cafe"


## The scene already holds the picture, the walls and the lamps, so only the furniture is linked.
func _build_ground() -> void:
	_register_furniture()


func _build_collisions() -> void:
	pass


func _build_lighting() -> void:
	pass


## Each furniture cover in the scene is handed to the base script, which draws it over the
## character when she is behind it.
func _register_furniture() -> void:
	for child in get_children():
		if not child.has_meta("rect"):
			continue
		var rect: Rect2 = child.get_meta("rect")
		child.visible = false
		occluder_sprites.append({
			"node": child,
			"rect": rect,
			"origin": child.get_meta("origin", Vector2.ZERO),
			"cutout": child.get_meta("cutout", false),
		})
