class_name Bookstore
extends "res://scripts/exterior_home.gd"
## The bookstore. The door at the front goes back out to the Town square. The shelves, the counter and the display
## cabinets are solid; the rugs and the floor are walkable. The picture and its solids come from the data below, in the
## same way as the other scenes that are not static.


const FURNITURE_DIR := "res://assets/environments/bookstore/"
## The furniture on the floor. Each piece: its picture, the point it stands on (its base, in picture pixels), its scale, and
## where that base is in its own picture (its anchor, in its own pixels). Its solid footprint is in the collision data.
const FURNITURE := [
	{"image": "reading_corner_vintage.png", "base": Vector2(320, 352), "scale": 0.22, "anchor": Vector2(640, 1080)},
	{"image": "shelf_trailing_plant.png", "base": Vector2(540, 656), "scale": 0.30, "anchor": Vector2(513, 1467)},
	{"image": "shelf_trailing_plant.png", "base": Vector2(1100, 656), "scale": 0.30, "anchor": Vector2(513, 1467)},
	{"image": "display_table_ornate.png", "base": Vector2(820, 440), "scale": 0.23, "anchor": Vector2(768, 877)},
	{"image": "display_table_ornate.png", "base": Vector2(820, 616), "scale": 0.23, "anchor": Vector2(768, 877)},
	{"image": "reading_table_lamp_flowers.png", "base": Vector2(355, 608), "scale": 0.24, "anchor": Vector2(764, 900)},
	{"image": "reading_table_lamp_flowers.png", "base": Vector2(1310, 608), "scale": 0.24, "anchor": Vector2(764, 900)},
]


## The room, then the furniture in the sorted group with the character, each by its base line.
func _build_ground() -> void:
	super._build_ground()
	for piece in FURNITURE:
		var shadow := Sprite2D.new()
		shadow.texture = _shadow_texture()
		shadow.scale = Vector2(1.5, 0.45)
		shadow.position = piece.base
		shadow.modulate = Color(0, 0, 0, 0.5)
		shadow.z_index = -1
		_depth_root.add_child(shadow)
		var sprite := Sprite2D.new()
		sprite.texture = load(FURNITURE_DIR + piece.image)
		sprite.centered = false
		sprite.scale = Vector2.ONE * piece.scale
		sprite.offset = -piece.anchor
		sprite.position = piece.base
		_depth_root.add_child(sprite)


func _init() -> void:
	PICTURE_PATH = "res://assets/environments/bookstore/interior_warm_lit.png"
	COLLISION_DATA = "res://data/bookstore_interior_collision.json"
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
