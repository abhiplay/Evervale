class_name MissionTracker
extends RefCounted
## The story's main missions (data/missions.json), and the HUD objective that follows them. A mission is complete once it
## is available (its availability conditions hold) and every one of its completion conditions holds. A mission with no
## completion conditions has no scripted ending yet, so it never completes on its own. Missions complete in order, so
## progress made early (the box found before the town is visited) counts as soon as the missions before it are done.
##
## Conditions, used by availability_conditions, completion_conditions and objective_steps:
##   mission_complete:<mission id>   flag:<world_state key> (true)   flag:<world_state key>=<value>
##   talked_to:<character id>        visited:<scene id>              opened:<item id>
##   cutscene:<cutscene id>          clue:<clue id>
## A mission's objective_steps are shown in order: the first step whose "until" condition does not hold yet is the
## objective. A step with an empty title hides the objective (the opening, while it plays). GameData.CONDITION_KINDS lists
## the kinds, and GameData checks the mission data against it when the game starts.


## Completes every mission whose conditions now hold, saves when one did, and shows the objective for the mission that is
## on now. Call it whenever something a condition reads has changed, and when a scene opens.
static func update() -> void:
	var completed: Array = SaveSystem.state.completed_missions
	var newly: Array[String] = []
	var changed := true
	while changed:
		changed = false
		for id in main_mission_ids():
			if not completed.has(id) and _can_complete(id):
				completed.append(id)
				newly.append(id)
				changed = true
	var current := active_mission()
	SaveSystem.state.active_missions = [] if current == "" else [current]
	if not newly.is_empty():
		SaveSystem.save_game()
		for id in newly:
			HudEvents.notification_requested.emit("Completed: " + str(GameData.missions[id].get("title", id)))
	show_objective()


## Shows the objective of the mission that is on now, or hides it when there is none to show.
static func show_objective() -> void:
	var step := current_step()
	if str(step.get("title", "")) == "":
		HudEvents.objective_cleared.emit()
	else:
		HudEvents.objective_changed.emit(step.title, _fill(str(step.get("description", ""))), false)


## Remembers that Amelia has talked to a character, then updates the missions.
static func note_talked_to(character_id: String) -> void:
	if not GameData.characters.has(character_id):
		return
	_add_unique("talked_to", character_id)
	update()


## Remembers that Amelia has been in a scene (SCENE_ID). The caller updates the missions.
static func note_visit(scene_id: String) -> void:
	if scene_id != "":
		_add_unique("visited_scenes", scene_id)


## The main missions' ids, in story order.
static func main_mission_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in GameData.missions:
		if GameData.missions[id].get("category", "") == "main":
			ids.append(id)
	return ids


## The first main mission not yet complete whose availability holds, or "" when there is none.
static func active_mission() -> String:
	var completed: Array = SaveSystem.state.completed_missions
	for id in main_mission_ids():
		if not completed.has(id):
			return id if _all_hold(GameData.missions[id].get("availability_conditions", [])) else ""
	return ""


## The objective step to show now: {title, description}. Empty when no mission is on.
static func current_step() -> Dictionary:
	var id := active_mission()
	if id == "":
		return {}
	var mission: Dictionary = GameData.missions[id]
	for step in mission.get("objective_steps", []):
		if not condition_met(str(step.get("until", ""))):
			return step
	return {"title": mission.get("title", id), "description": mission.get("short_description", "")}


static func condition_met(condition: String) -> bool:
	var kind := condition.get_slice(":", 0)
	var value := condition.substr(kind.length() + 1)
	var state: Dictionary = SaveSystem.state
	var world: Dictionary = state.world_state
	match kind:
		"mission_complete":
			return state.completed_missions.has(value)
		"flag":
			if value.contains("="):
				return str(world.get(value.get_slice("=", 0), "")) == value.get_slice("=", 1)
			return world.get(value, false) == true
		"talked_to":
			return world.get("talked_to", []).has(value)
		"visited":
			return world.get("visited_scenes", []).has(value)
		"opened":
			return state.opened_items.get(value, false) == true
		"cutscene":
			return state.cutscenes_viewed.has(value)
		"clue":
			return state.collected_clues.has(value)
	push_error("[MissionTracker] Unknown condition '%s'." % condition)
	return false


## Fills the counts an objective's description can name: {house_seen} and {house_areas}, the places of the house looked at
## so far and in all (data/home_events.json).
static func _fill(text: String) -> String:
	if not text.contains("{"):
		return text
	var events: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/home_events.json"))
	return text.format({
		"house_seen": SaveSystem.state.world_state.get("house_seen", []).size(),
		"house_areas": events.get("areas", []).size(),
	})


static func _can_complete(id: String) -> bool:
	var mission: Dictionary = GameData.missions[id]
	var conditions: Array = mission.get("completion_conditions", [])
	return not conditions.is_empty() and _all_hold(mission.get("availability_conditions", [])) and _all_hold(conditions)


static func _all_hold(conditions: Array) -> bool:
	for condition in conditions:
		if not condition_met(str(condition)):
			return false
	return true


static func _add_unique(key: String, value: String) -> void:
	var world: Dictionary = SaveSystem.state.world_state
	if not world.has(key):
		world[key] = []
	if not world[key].has(value):
		world[key].append(value)
