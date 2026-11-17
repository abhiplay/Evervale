class_name Florist
extends "res://scripts/exterior_home.gd"
## The florist shop. The door at the front goes back out to the Town square. The picture, the
## furniture, its shadows and the solid walls and furniture are nodes in Florist.tscn, so they show in
## the 2D tab. Each piece of furniture also has a hidden occluder there, which this script links so
## the piece is drawn over the character when she is behind it.


## Evelyn is in the shop, standing where the shop has room for her, so Amelia can find her there.
func _ready() -> void:
	super._ready()
	var evelyn := SceneWalkers.walker(self, "res://data/evelyn_animations.json")
	evelyn.position = Vector2(1070, 425)
	add_figure(evelyn)


func _init() -> void:
	IMAGE_SIZE = Vector2(1670, 941)
	SPAWN_DEFAULT = Vector2(838, 740)
	SPAWNS = {
		"from_town": Vector2(838, 740),
	}
	GATE_RECT = Rect2(0, 0, 0, 0)
	EXITS = [
		{"rect": Rect2(740, 800, 195, 70), "scene": "res://scenes/TownSquare.tscn", "spawn": "from_florist"},
	]
	# The shop is drawn large, so the character is drawn larger here to match the furniture.
	PLAYER_SCALE = 0.2
	HAS_DOOR = false
	MAP_PLACE = "town_square"
	SCENE_ID = "florist"


## The scene already holds the picture, the furniture and its shadows, so only the occluders are linked.
func _build_ground() -> void:
	_register_occluders()


## The solid walls and furniture are nodes in the scene.
func _build_collisions() -> void:
	pass


## Each hidden occluder in the scene is handed to the base script, which shows it over the character
## when she is behind it.
func _register_occluders() -> void:
	for child in get_children():
		if not child.has_meta("rect"):
			continue
		var rect: Rect2 = child.get_meta("rect")
		child.visible = false
		occluder_sprites.append({
			"node": child,
			"rect": rect,
			"origin": Vector2.ZERO,
			"cutout": true,
		})
