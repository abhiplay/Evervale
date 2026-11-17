class_name HomePets
extends Node
## Coco and Charlie on the ground floor, once Evelyn has left (data/home_pets.json). Each pet is a picture with no
## collision and an interactable on the host: E says its line and counts as meeting it (MissionTracker). Once the look
## around is done and both pets have been met, Amelia and Oliver have their "Our New Home" talk (CS-003), once.

const DATA_PATH := "res://data/home_pets.json"
const CUTSCENE := "CS-003"
const DONE_FLAG := "our_new_home_done"

var _host: Node2D
var _data: Dictionary
var _shown := false
var _busy := false
## The pet pictures, by pet id, once they are shown.
var pets := {}


func _init(host: Node2D) -> void:
	_host = host
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


func _physics_process(_delta: float) -> void:
	var world: Dictionary = SaveSystem.state.world_state
	if not _shown and world.get("opening_stage", "") == "done":
		_show_pets()
	if talk_pending() and not _busy and not _host.scripted and not _host.transitioning \
			and not _host.scene_dialogue.is_open and not HudEvents.screen_open:
		_play_talk()


## True when the "Our New Home" talk should play: the look around is done, both pets are met, and it has not played.
func talk_pending() -> bool:
	var world: Dictionary = SaveSystem.state.world_state
	if world.get("house_task", "") != "done" or world.get(DONE_FLAG, false) or SaveSystem.state.cutscenes_viewed.has(CUTSCENE):
		return false
	for pet in _data.pets:
		if not MissionTracker.condition_met("talked_to:" + pet.id):
			return false
	return true


func _show_pets() -> void:
	_shown = true
	for pet in _data.pets:
		var node: Node2D = _coco_sprite(pet) if pet.has("sheet") else _placeholder(pet)
		node.name = "Pet_" + pet.id
		# Just under the player (5), so Amelia is drawn over a pet she walks past.
		node.z_index = 4
		_host.add_figure(node)
		pets[pet.id] = node
		_host.interactables.append({"id": pet.id, "pos": Vector2.ZERO, "label": pet.label, "lines": pet.lines, "character": pet.id})
	place_pets()


## Puts each pet at its spot: its settled spot once the house is settled (HomeFloor1.settled), otherwise its first one.
## The pet's interactable moves with it.
func place_pets() -> void:
	var house_settled: bool = _host.get("settled") == true
	for pet in _data.pets:
		if not pets.has(pet.id):
			continue
		var spot: Array = pet.settled_pos if house_settled and pet.has("settled_pos") else pet.pos
		pets[pet.id].position = Vector2(spot[0], spot[1])
		for item in _host.interactables:
			if item.id == pet.id:
				item.pos = pets[pet.id].position


## Coco sitting, cycling through her idle sheet. Her feet are at her position.
func _coco_sprite(pet: Dictionary) -> Node2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(pet.sheet)
	sprite.hframes = pet.frames[0]
	sprite.vframes = pet.frames[1]
	sprite.scale = Vector2(pet.scale, pet.scale)
	sprite.centered = true
	sprite.offset = Vector2(0, -sprite.texture.get_height() / float(pet.frames[1]) / 2.0)
	var frame_count: int = pet.frames[0] * pet.frames[1]
	var tween := sprite.create_tween().set_loops()
	tween.tween_method(func(f: float): sprite.frame = int(f) % frame_count, 0.0, float(frame_count), frame_count / float(pet.fps))
	return sprite


## A stand-in for a pet with no art yet: a dark dog shape lying down, with its name above.
func _placeholder(pet: Dictionary) -> Node2D:
	var node := Node2D.new()
	# Drawn at twice its size, so a Labrador comes up to about Amelia's knees.
	node.scale = Vector2(2.0, 2.0)
	node.draw.connect(_draw_placeholder.bind(node, pet))
	node.queue_redraw()
	return node


func _draw_placeholder(node: Node2D, pet: Dictionary) -> void:
	var colour := Color(pet.placeholder_colour)
	# Body (a flattened circle), head, ear and tail.
	node.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	node.draw_circle(Vector2(0, -40), 26, colour)
	node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	node.draw_circle(Vector2(26, -26), 13, colour)
	node.draw_circle(Vector2(33, -36), 5, colour.lightened(0.15))
	node.draw_line(Vector2(-24, -18), Vector2(-40, -26), colour, 5.0)
	node.draw_string(ThemeDB.fallback_font, Vector2(-40, -48), pet.name, HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color.WHITE)


func _play_talk() -> void:
	_busy = true
	var talk := BoxTalk.new()
	await talk.play(_host, _data.our_new_home, DONE_FLAG, CUTSCENE)
	_busy = false
