class_name HomeFloor1
extends "res://scripts/exterior_home.gd"
## The ground floor of the home, one walkable picture. The front door (bottom middle) goes back
## out to the courtyard. The stairs (right) go up to the bedroom. Its picture, solids, furniture,
## exits and spawn points are in data/maps/home_floor1.json (Tiled).
##
## Once the box talk is over (Mission 4), the house is settled: the furnished picture
## (home_floor1.webp) and its solids replace the bare floor. The radio, which the bare picture shows on the coffee table,
## moves upstairs to the bedroom wall (BedroomUpstairs) once the house is settled. The box talk ends with a fade
## into the settled house (settle_with_fade); a house loaded later is settled from the start.
##
## The floor's collision comes from its walk mask (WalkMask): the bare floor's, then the settled floor's.

const SETTLED_PICTURE := "res://assets/environments/home_floor1.webp"
const BARE_MASK := "res://data/walkmasks/home_floor1_bare.png"
const SETTLED_MASK := "res://data/walkmasks/home_floor1_settled.png"
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
	# The radio on the coffee table, until the house is settled; then it is in the bedroom. Using it says a line; the
	# opening conversation is in OpeningSequence.
	if not is_settled_now():
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


## Swaps in the furnished picture and the settled walk mask, and moves Amelia and the pets off the new
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
