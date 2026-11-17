extends Node
## Loads the story data from res://data and checks that every ID reference
## resolves (missions, characters, clues, cutscenes, locations).

const DATA_DIR := "res://data/"
## The kinds of mission condition MissionTracker understands (see scripts/mission_tracker.gd).
const CONDITION_KINDS := ["mission_complete", "flag", "talked_to", "visited", "opened", "cutscene", "clue"]

var characters: Dictionary = {}
var locations: Dictionary = {}
var cutscenes: Dictionary = {}
var clues: Dictionary = {}
var missions: Dictionary = {}


func _ready() -> void:
	characters = _load_by_id("characters.json", "characters")
	locations = _load_by_id("locations.json", "locations")
	cutscenes = _load_by_id("cutscenes.json", "cutscenes")
	clues = _load_by_id("clues.json", "clues")
	missions = _load_by_id("missions.json", "missions", "mission_id")

	var errors := validate()
	for error in errors:
		push_error("[GameData] " + error)
	if errors.is_empty():
		print("[GameData] Loaded %d characters, %d locations, %d cutscenes, %d clues, %d missions." % [
			characters.size(), locations.size(), cutscenes.size(), clues.size(), missions.size()])


func _load_by_id(file_name: String, key: String, id_field: String = "id") -> Dictionary:
	var result: Dictionary = {}
	var text := FileAccess.get_file_as_string(DATA_DIR + file_name)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has(key):
		push_error("[GameData] %s is missing the '%s' list." % [file_name, key])
		return result
	for entry in parsed[key]:
		var id: String = entry.get(id_field, "")
		if id == "":
			push_error("[GameData] An entry in %s has no %s." % [file_name, id_field])
		elif result.has(id):
			push_error("[GameData] Duplicate ID '%s' in %s." % [id, file_name])
		else:
			result[id] = entry
	return result


## Returns a list of human-readable problems. An empty list means the data is consistent.
func validate() -> Array[String]:
	var errors: Array[String] = []
	for id in missions:
		var m: Dictionary = missions[id]
		if not characters.has(m.get("starting_character", "")):
			errors.append("%s: unknown starting_character '%s'" % [id, m.get("starting_character", "")])
		var place = m.get("starting_location")
		if place != null and not locations.has(place):
			errors.append("%s: unknown starting_location '%s'" % [id, place])
		for cutscene_id in m.get("cutscene_ids", []):
			if not cutscenes.has(cutscene_id):
				errors.append("%s: unknown cutscene '%s'" % [id, cutscene_id])
		for condition in m.get("availability_conditions", []):
			if condition.begins_with("mission_complete:"):
				var target: String = condition.trim_prefix("mission_complete:")
				if not missions.has(target):
					errors.append("%s: availability refers to unknown mission '%s'" % [id, target])
		var all_conditions: Array = m.get("availability_conditions", []) + m.get("completion_conditions", [])
		for step in m.get("objective_steps", []):
			all_conditions.append(step.get("until", ""))
		for condition in all_conditions:
			if not CONDITION_KINDS.has(str(condition).get_slice(":", 0)):
				errors.append("%s: unknown kind of condition '%s'" % [id, condition])
		for condition in m.get("completion_conditions", []):
			if condition.begins_with("cutscene:") and not cutscenes.has(condition.trim_prefix("cutscene:")):
				errors.append("%s: completion refers to unknown cutscene '%s'" % [id, condition])
			if condition.begins_with("clue:") and not clues.has(condition.trim_prefix("clue:")):
				errors.append("%s: completion refers to unknown clue '%s'" % [id, condition])
	for id in clues:
		var c: Dictionary = clues[id]
		for character_id in c.get("related_characters", []):
			if not characters.has(character_id):
				errors.append("%s: unknown related character '%s'" % [id, character_id])
		for clue_id in c.get("related_clues", []):
			if not clues.has(clue_id):
				errors.append("%s: unknown related clue '%s'" % [id, clue_id])
	for id in cutscenes:
		for character_id in cutscenes[id].get("characters", []):
			if not characters.has(character_id):
				errors.append("%s: unknown character '%s'" % [id, character_id])
	return errors
