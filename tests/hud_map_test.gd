extends SceneTree
## Checks the Map button in the HUD: inside a building it opens that building's plan, pressed again it closes, and outside
## (the courtyard) it opens nothing and keeps the notice. Run: Godot --headless --path . -s res://tests/hud_map_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	var events = root.get_node("/root/HudEvents")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "done"
	save.state.world_state["box_talk_done"] = true
	save.state.cutscenes_viewed.append("CS-003")

	print("Inside the house")
	var house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	# The game's HUD is the autoload /root/Hud; the map is tested on it, not on a second copy.
	var hud = root.get_node("/root/Hud")
	for i in 3:
		await process_frame
	events.screen_requested.emit("map")
	await process_frame
	check(hud.floor_map.visible and events.screen_open, "the Map button opens the house's plan, and the game takes no movement")
	events.screen_requested.emit("map")
	await process_frame
	check(not hud.floor_map.visible and not events.screen_open, "the Map button closes the plan again")
	hud.floor_map.show_plan(load("res://scripts/floor_plan.gd").for_scene("home_floor1"), "ground_floor")
	hud.floor_map.close()
	root.remove_child(house)
	house.free()
	await process_frame

	print("Outside, in the courtyard")
	var courtyard = load("res://scenes/ExteriorHome.tscn").instantiate()
	root.add_child(courtyard)
	current_scene = courtyard
	hud = root.get_node("/root/Hud")
	for i in 3:
		await process_frame
	events.screen_requested.emit("map")
	await process_frame
	check(not hud.floor_map.visible and not events.screen_open, "outdoors there is no plan, so the Map button opens nothing")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
