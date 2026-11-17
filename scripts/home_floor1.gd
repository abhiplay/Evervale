class_name HomeFloor1
extends "res://scripts/exterior_home.gd"
## The ground floor of the home, one walkable picture. The front door (bottom middle) goes back
## out to the courtyard. The stairs (right) go up to the bedroom. Its picture, solids, furniture,
## exits and spawn points are in data/maps/home_floor1.json (Tiled).
##
## Once the box talk is over (Mission 4), the house is settled: the furnished picture
## (home_floor1.webp) and its solids replace the bare floor, and the radio, which the furnished
## picture does not show, sits on the coffee table as its own prop. The box talk ends with a fade
## into the settled house (settle_with_fade); a house loaded later is settled from the start.
##
## The floor's collision comes from its walk mask (WalkMask): the bare floor's, then the settled floor's.

const SETTLED_PICTURE := "res://assets/environments/home_floor1.webp"
const BARE_MASK := "res://data/walkmasks/home_floor1_bare.png"
const SETTLED_MASK := "res://data/walkmasks/home_floor1_settled.png"
const RADIO_PROP := "res://assets/environments/furniture/radio_prop.png"
const RADIO_POSITION := Vector2(480, 722)
## Where Amelia stands once the house is settled: the loose board is under the dining table now.
const SETTLED_SPOT := Vector2(725, 420)

var settled := false


func _init() -> void:
	MAP_DATA = "res://data/maps/home_floor1.json"
	# The rooms are drawn large, so the character is drawn larger here to match them.
	PLAYER_SCALE = 0.24
	MAP_PLACE = "home"
	SCENE_ID = "home_floor1"


func _ready() -> void:
	super()
	# The radio on the coffee table. Using it says a line; the opening conversation is in OpeningSequence.
	interactables.append({"id": "radio", "pos": Vector2(500, 790), "label": "Look", "lines": [
		"An old radio sits on the coffee table."]})
	# Amelia's look around the house, once Evelyn has left.
	add_child(HouseInspection.new(self))
	# Coco and Charlie, and the "Our New Home" talk once both are met.
	add_child(HomePets.new(self))
	if is_settled_now():
		settle()
	else:
		WalkMask.apply(self, BARE_MASK)
	# After the night of 2:17, the radio is quiet.
	if SaveSystem.state.world_state.get(Night217.HEARD_FLAG, false):
		for item in interactables:
			if item.id == "radio":
				item.lines = ["The radio sits silent on the coffee table. Its dial is cold."]
	# Coming down the stairs at 2:17: the radio speaks (Mission 5).
	if Night217.downstairs_pending():
		# Kept on the scene while it plays, so the sequence is not freed between its frames.
		set_meta("night_217", Night217.new())
		get_meta("night_217").downstairs.call_deferred(self)


## True once the house should be shown settled: the box talk is over.
static func is_settled_now() -> bool:
	return SaveSystem.state.world_state.get("box_talk_done", false) == true


## Fades out, settles the house, and fades back in. Used when the box talk ends.
func settle_with_fade() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.4)
	await tween.finished
	settle()
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 0.4)
	await tween.finished


## Swaps in the furnished picture, the settled walk mask and the radio prop, and moves Amelia and the pets off the new
## furniture.
func settle() -> void:
	if settled:
		return
	settled = true
	var bare: Texture2D = $Sprite_0.texture
	var furnished: Texture2D = load(SETTLED_PICTURE)
	for child in get_children():
		if child is Sprite2D and child.texture == bare:
			child.texture = furnished
	WalkMask.apply(self, SETTLED_MASK)
	# The way-finding grid was made for the bare floor's solids.
	click_walker.invalidate()
	var radio := Sprite2D.new()
	radio.name = "RadioProp"
	radio.texture = load(RADIO_PROP)
	radio.position = RADIO_POSITION
	# Above the picture, under the characters.
	radio.z_index = -5
	add_child(radio)
	for rect in settled_solids():
		if rect.grow(8).has_point(player.position):
			player.position = SETTLED_SPOT
			break
	for child in get_children():
		if child is HomePets:
			child.place_pets()


## The settled floor's solids (its walk mask), as rectangles in picture pixels.
static func settled_solids() -> Array[Rect2]:
	return WalkMask.rects(SETTLED_MASK)
