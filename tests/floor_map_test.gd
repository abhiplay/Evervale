extends SceneTree
## Checks the indoor map: each room in data/floor_plans.json is a real scene (its SCENE_ID is the scene's), every link goes
## to a room of its plan or outside, the current room is found from its scene, outdoor scenes have no plan, and the map
## opens and closes and holds the game's movement while it is open. Run: Godot --headless --path . -s res://tests/floor_map_test.gd

var failures: Array[String] = []
var PLAN
var MAP


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	# Loaded by path: the map scripts use the game's autoloads, which a -s test can only reach at run time.
	PLAN = load("res://scripts/floor_plan.gd")
	MAP = load("res://scripts/ui/floor_map.gd")
	var hud_events = root.get_node("/root/HudEvents")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/floor_plans.json"))

	print("The plans")
	var home_plan: Dictionary = PLAN.for_scene("home_floor1")
	check(home_plan.get("id", "") == "home", "the ground floor belongs to the home plan")
	check(PLAN.room_id_for_scene("bedroom_upstairs") == "bedroom", "the bedroom is the upstairs room of the home plan")
	check(PLAN.room_id_for_scene("home_floor1") == "ground_floor", "the ground floor is the home plan's ground floor room")
	check(PLAN.is_indoor("cafe") and PLAN.is_indoor("bookstore") and PLAN.is_indoor("florist"), "the café, bookshop and florist have plans")
	check(not PLAN.is_indoor("exterior_home") and not PLAN.is_indoor("town_square") and not PLAN.is_indoor("world_map"), "outdoor scenes have no plan")
	var no_locks := true
	for plan_id in data.plans:
		for room in data.plans[plan_id].rooms:
			if room.get("locked", false):
				no_locks = false
	check(no_locks, "no room is locked yet (the locks come with the tricks and events)")

	print("Every room is a real scene, and every link is to its own plan")
	for plan_id in data.plans:
		var plan: Dictionary = data.plans[plan_id]
		var room_ids: Array = []
		for room in plan.rooms:
			room_ids.append(room.id)
			var scene = load(_scene_path(room.scene)).instantiate()
			check(scene.get("SCENE_ID") == room.scene, "%s: %s is the scene %s" % [plan_id, room.id, room.scene])
			scene.free()
		for link in plan.links:
			check(link.from in room_ids and (link.to == "outside" or link.to in room_ids), "%s: a link from %s goes to a room of the plan or outside" % [plan_id, link.from])

	print("The map opens and holds the game still")
	var map = MAP.new()
	root.add_child(map)
	await process_frame
	check(not map.visible and not hud_events.screen_open, "the map is shut at first, and the game is free")
	map.show_plan(PLAN.for_scene("home_floor1"), "ground_floor")
	check(map.visible and hud_events.screen_open, "the map opens, and the game takes no movement")
	map.close()
	check(not map.visible and not hud_events.screen_open, "closing the map gives the game back its movement")
	root.remove_child(map)
	map.free()

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _scene_path(scene_id: String) -> String:
	var names := {
		"home_floor1": "HomeFloor1", "bedroom_upstairs": "BedroomUpstairs", "cafe": "Cafe",
		"bookstore": "Bookstore", "florist": "Florist",
	}
	return "res://scenes/%s.tscn" % names[scene_id]
