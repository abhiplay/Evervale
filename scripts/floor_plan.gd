class_name FloorPlan
extends RefCounted
## The indoor plans (data/floor_plans.json): the rooms of each building the protagonist can open the map in, and the links
## between them. Only scenes that are a room of a plan have a map; outside, the Map button keeps its own notice.

const DATA_PATH := "res://data/floor_plans.json"


## The plan that holds the room of this scene, with its id: {id, name, rooms, links}. Empty when the scene is not indoors.
static func for_scene(scene_id: String) -> Dictionary:
	var plans: Dictionary = _data().get("plans", {})
	for plan_id in plans:
		var plan: Dictionary = plans[plan_id]
		for room in plan.get("rooms", []):
			if room.get("scene", "") == scene_id:
				var result := plan.duplicate(true)
				result["id"] = plan_id
				return result
	return {}


## True when the scene is a room of a plan, so the map opens here.
static func is_indoor(scene_id: String) -> bool:
	return not for_scene(scene_id).is_empty()


## The id of the room a scene is, within its plan. Empty when it is not a room of one.
static func room_id_for_scene(scene_id: String) -> String:
	for room in for_scene(scene_id).get("rooms", []):
		if room.get("scene", "") == scene_id:
			return room.id
	return ""


static func _data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
