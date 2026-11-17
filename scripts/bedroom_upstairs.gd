class_name BedroomUpstairs
extends "res://scripts/exterior_home.gd"
## The upstairs bedroom, reached by the stairs from the ground floor. The stairs down are at the
## bottom left of the room, through the opening in the floor. Until Amelia and Oliver have settled in (their
## "Our New Home" talk, CS-003), the room is still empty: its furniture is taken out and only the walls stay.

## The empty room's picture, for the look around. The room's collision comes from its walk masks (WalkMask): the
## empty room's walls, or the furnished room's walls and furniture.
const EMPTY_PICTURE := "res://assets/environments/bedroom_upstairs_empty.webp"
const EMPTY_MASK := "res://data/walkmasks/bedroom_upstairs_empty.png"
const FURNISHED_MASK := "res://data/walkmasks/bedroom_upstairs_furnished.png"
## Once the house is settled, the radio moves here from the ground floor: on the floor against the wall, left of the
## bedside table. Its size matches the rooms' scale.
const RADIO_PROP := "res://assets/environments/furniture/radio_prop.png"
const RADIO_POSITION := Vector2(385, 335)
const RADIO_SCALE := 0.6


func _init() -> void:
	PICTURE_PATH = "res://assets/environments/bedroom_upstairs.webp"
	COLLISION_DATA = "res://data/bedroom_upstairs_collision.json"
	IMAGE_SIZE = Vector2(1448, 1086)
	SPAWN_DEFAULT = Vector2(300, 780)
	SPAWNS = {
		"from_stairs": Vector2(300, 780),
	}
	GATE_RECT = Rect2(0, 0, 0, 0)
	EXITS = [
		{"rect": Rect2(215, 930, 135, 110), "scene": "res://scenes/HomeFloor1.tscn", "spawn": "from_bedroom"},
	]
	# The rooms are drawn large, so the character is drawn larger here to match them.
	PLAYER_SCALE = 0.24
	OCCLUDERS = [
		Rect2(560, 290, 320, 460), Rect2(465, 330, 105, 110), Rect2(870, 330, 105, 110),
		Rect2(1150, 355, 115, 560), Rect2(190, 200, 100, 470), Rect2(290, 515, 65, 95),
		Rect2(1120, 180, 135, 155), Rect2(520, 880, 405, 55),
	]
	HAS_DOOR = false
	MAP_PLACE = "home"
	SCENE_ID = "bedroom_upstairs"


func _ready() -> void:
	super()
	if not SaveSystem.state.cutscenes_viewed.has(HomePets.CUTSCENE):
		_empty_the_room()
	else:
		WalkMask.apply(self, FURNISHED_MASK)
		if HomeFloor1.is_settled_now():
			_place_radio()
	# Amelia's look around the house, once Evelyn has left.
	add_child(HouseInspection.new(self))
	# The bed, once the box talk is over: Sleep starts the night (Mission 5, Night217).
	if Night217.sleep_available():
		interactables.append({"id": "bed", "pos": Vector2(720, 790), "label": "Sleep", "action": "sleep"})


## The radio on the bedroom wall. Using it says a line, and after the night of 2:17 it is silent.
func _place_radio() -> void:
	var radio := Sprite2D.new()
	radio.name = "RadioProp"
	radio.texture = load(RADIO_PROP)
	radio.position = RADIO_POSITION
	radio.scale = Vector2(RADIO_SCALE, RADIO_SCALE)
	# Above the picture, under the characters.
	radio.z_index = -5
	add_child(radio)
	var lines := ["An old radio sits on the floor by the wall."]
	if SaveSystem.state.world_state.get(Night217.HEARD_FLAG, false):
		lines = Night217._data().radio_silent
	interactables.append({"id": "radio", "pos": RADIO_POSITION + Vector2(0, 40), "label": "Look", "lines": lines})


func _do_action(action: String) -> void:
	if action == "sleep" and Night217.sleep_available():
		# Kept on the scene while it plays, so the sequence is not freed between its frames.
		set_meta("night_217", Night217.new())
		get_meta("night_217").bedroom(self)


## Takes the furniture out of the room until they have settled in: the empty picture replaces the furnished one,
## the furniture's solids go, and the walls of the empty room take their place.
func _empty_the_room() -> void:
	var furnished: Texture2D = $Sprite_0.texture
	var empty: Texture2D = load(EMPTY_PICTURE)
	for child in get_children():
		if child is Sprite2D and child.texture == furnished:
			child.texture = empty
	# The furniture's pieces are no longer drawn over Amelia, since there is no furniture to walk behind.
	occluder_sprites = []
	WalkMask.apply(self, EMPTY_MASK)
