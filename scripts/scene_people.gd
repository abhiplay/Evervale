class_name ScenePeople
extends Node
## The people of a scene (data/people.json): each is drawn (a stand-in figure until their art exists) and added to the
## host's interactables, so E talks to them. Talking counts as meeting the character and sets the person's flag, both
## through talked_to() below, which the scene's own talk handling calls. Every location scene adds one (exterior_home).

const DATA_PATH := "res://data/people.json"
## How tall a stand-in figure is drawn, unscaled (PlaceholderPerson: body, head and a little above).
const PLACEHOLDER_HEIGHT := 78.0
## The player's picture height at scale 1 (her walk frames are 667 pixels tall).
const PLAYER_FRAME_HEIGHT := 667.0

var _host: Node2D
## The figures drawn, by character id.
var figures := {}


func _init(host: Node2D) -> void:
	_host = host


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	for person in data.people:
		if person.scene != _host.SCENE_ID or not _present(person):
			continue
		var spot := Vector2(person.pos[0], person.pos[1])
		if person.get("look", "placeholder") == "placeholder":
			var figure := PlaceholderPerson.new(person.name, Color(person.colour))
			figure.name = "Person_" + person.id
			figure.position = spot
			# A little shorter than Amelia, whatever scale this scene draws her at.
			var height: float = PLAYER_FRAME_HEIGHT * _host.PLAYER_SCALE * 0.95
			figure.scale = Vector2.ONE * (height / PLACEHOLDER_HEIGHT)
			_host.add_figure(figure)
			figures[person.id] = figure
		var item := {"id": person.id, "pos": spot, "label": person.label, "lines": person.lines, "character": person.id,
			"speaker": person.get("speaker", "")}
		if person.has("flag"):
			item["flag"] = person.flag
		_host.interactables.append(item)


## Whether the person is here now: show_if holds (or there is none) and hide_if does not.
func _present(person: Dictionary) -> bool:
	if person.has("show_if") and not MissionTracker.condition_met(person.show_if):
		return false
	if person.has("hide_if") and MissionTracker.condition_met(person.hide_if):
		return false
	return true


## Remembers talking to an interactable: its flag, if it has one, and meeting its character, then updates the missions.
static func talked_to(item: Dictionary) -> void:
	if item.has("flag"):
		SaveSystem.state.world_state[item.flag] = true
	if item.has("character"):
		MissionTracker.note_talked_to(item.character)
	else:
		MissionTracker.update()
