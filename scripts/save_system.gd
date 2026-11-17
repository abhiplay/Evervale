extends Node
## Saves progress to user://evervale_save.json. Fields follow
## 04_evervale_world_and_systems.md section 9. Bump SAVE_VERSION and add a
## migration in _migrate() whenever the layout changes.

const SAVE_PATH := "user://evervale_save.json"
## Headless tests save here, so a test run never overwrites the player's progress.
const TEST_SAVE_PATH := "user://evervale_test_save.json"
const SAVE_VERSION := 1

var state: Dictionary = {}
## The file this run saves to: SAVE_PATH, or TEST_SAVE_PATH while a test runs.
var save_path := SAVE_PATH


func _ready() -> void:
	if _running_a_test():
		save_path = TEST_SAVE_PATH
	if not load_game():
		state = new_game_state()
		# A brand-new game plays the opening scene once.
		state.world_state["opening_stage"] = "pending"
	# A spawn left over from the last session must not move the player on launch.
	state.pending_spawn = ""


func new_game_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"current_chapter": 1,
		"completed_missions": [],
		"active_missions": [],
		"discovered_locations": ["home"],
		"collected_clues": [],
		"character_trust": {},
		"personal_mission_progress": {},
		"story_choices": {},
		"cutscenes_viewed": [],
		"home_decorations": [],
		"pet_states": {},
		"world_state": {},
		"inventory": {"flashlight": 1},
		"opened_items": {},
		"currency": 0,
		"day": 1,
		"current_location": "home",
		"player_position": [0, 0],
		"pending_spawn": "",
		"current_room": "living_room",
		"previous_room": "",
	}


## Starts a new save: the player's progress is replaced, and the opening plays when the game opens.
func start_new_game() -> void:
	state = new_game_state()
	state.world_state["opening_stage"] = "pending"
	save_game()
	HudEvents.inventory_changed.emit()


## Adds items to the inventory, and tells the HUD.
func add_item(item_id: String, count: int = 1) -> void:
	var inventory: Dictionary = state.inventory
	inventory[item_id] = int(inventory.get(item_id, 0)) + count
	HudEvents.inventory_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveSystem] Could not write %s (error %d)." % [save_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(state, "\t"))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SaveSystem] Save file is not valid JSON; starting a new game instead.")
		return false
	state = _migrate(parsed)
	return true


func _migrate(saved: Dictionary) -> Dictionary:
	# Version 1 is the first layout, so nothing to convert yet.
	var merged := new_game_state()
	for key in saved:
		merged[key] = saved[key]
	merged["version"] = SAVE_VERSION
	# A save from before the opening scene existed has not played it yet.
	if not merged.world_state.has("opening_stage"):
		merged.world_state["opening_stage"] = "pending"
	# A save that finished the opening before the house look-around existed has no task for it yet.
	if merged.world_state.get("opening_stage", "") == "done" and not merged.world_state.has("house_task"):
		merged.world_state["house_task"] = "active"
	return merged


## True when this run is a headless test (a script under res://tests/).
func _running_a_test() -> bool:
	for arg in OS.get_cmdline_args():
		# A script given by its absolute path counts too: localize_path turns it into its res:// path.
		if ProjectSettings.localize_path(arg).begins_with("res://tests/"):
			return true
	return false
