class_name Bookstore
extends "res://scripts/exterior_home.gd"
## The bookstore. The door at the front goes back out to the Town square. The room is laid out in scenes/Bookstore.tscn, so it
## can be seen and edited in the 2D tab: the picture, the furniture (nodes marked "furniture"), the solids (StaticBody2D nodes)
## and the spawn and exit markers. The shelves, the counter and the display cabinets are solid; the rugs and the floor are walkable.


func _init() -> void:
	IMAGE_SIZE = Vector2(1670, 942)
	SPAWN_DEFAULT = Vector2(838, 740)
	SPAWNS = {
		"from_town": Vector2(838, 740),
	}
	GATE_RECT = Rect2(0, 0, 0, 0)
	EXITS = [
		{"rect": Rect2(740, 800, 195, 70), "scene": "res://scenes/TownSquare.tscn", "spawn": "from_bookstore"},
	]
	HAS_DOOR = false
	DEPTH_SORTED = true
	MAP_PLACE = "town_square"
	SCENE_ID = "bookstore"


## The room is in the scene file. The furniture in it is moved into the group sorted with the character, by its base line,
## and each piece gets a soft shadow on the floor under its base.
func _build_ground() -> void:
	super._build_ground()
	var furniture: Array = []
	for child in get_children():
		if child.has_meta("furniture"):
			furniture.append(child)
	for piece in furniture:
		var base: Vector2 = piece.position
		remove_child(piece)
		_depth_root.add_child(piece)
		var shadow := Sprite2D.new()
		shadow.texture = _shadow_texture()
		shadow.scale = Vector2(1.5, 0.45)
		shadow.position = base
		shadow.modulate = Color(0, 0, 0, 0.5)
		shadow.z_index = -1
		_depth_root.add_child(shadow)
