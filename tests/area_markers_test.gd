extends SceneTree
## Checks: while the look around is on, each place of a floor that has not been looked at has a question mark over it, on that
## floor only; a place looked at loses its mark; and every mark goes once the look around is done or before it has started.
## Frame limits only. Run:
## Godot --headless --path . -s res://tests/area_markers_test.gd

const EVENTS := "res://data/home_events.json"

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _inspection(scene) -> Node:
	for child in scene.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/house_inspection.gd":
			return child
	return null


## How many question marks a scene shows.
func _marks(scene: Node) -> int:
	var count := 0
	for child in scene.get_children():
		if String(child.name).begins_with("Marker_"):
			count += 1
	return count


func _initialize() -> void:
	await process_frame
	var events: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EVENTS))
	var home_places := 0
	var upstairs_places := 0
	for area in events.areas:
		if area.scene == "home_floor1":
			home_places += 1
		elif area.scene == "bedroom_upstairs":
			upstairs_places += 1

	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "active"
	var house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	for i in 3:
		await process_frame
	check(_marks(house) == home_places, "every unvisited place on the ground floor has a question mark (%d)" % _marks(house))

	print("A place looked at loses its mark")
	save.state.world_state["house_seen"] = ["living_room"]
	var insp = _inspection(house)
	insp._refresh()
	await process_frame
	check(_marks(house) == home_places - 1, "the place looked at has no mark, and the others keep theirs")

	print("The marks go once the look around is done")
	save.state.world_state["house_task"] = "done"
	insp._refresh()
	await process_frame
	check(_marks(house) == 0, "once the look around is done, the marks go, and the board waits for the town")
	save.state.completed_missions = ["M01", "M02", "M03"]
	insp._refresh()
	await process_frame
	check(_marks(house) == 1 and house.has_node("Marker_plank"), "back from the café, only the loose board has a mark")
	house.get_parent().remove_child(house)
	house.free()

	print("The upstairs floor shows only its own places")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "active"
	var bedroom = load("res://scenes/BedroomUpstairs.tscn").instantiate()
	root.add_child(bedroom)
	for i in 3:
		await process_frame
	check(_marks(bedroom) == upstairs_places, "every unvisited upstairs place has a question mark (%d)" % _marks(bedroom))
	var only_upstairs := true
	for child in bedroom.get_children():
		if String(child.name).begins_with("Marker_") and not String(child.name).begins_with("Marker_bedroom_"):
			only_upstairs = false
	check(only_upstairs, "every mark upstairs belongs to an upstairs place")

	print("No marks before the look around starts")
	save.state.world_state["house_task"] = ""
	_inspection(bedroom)._refresh()
	await process_frame
	check(_marks(bedroom) == 0, "no marks before the look around starts")
	bedroom.get_parent().remove_child(bedroom)
	bedroom.free()

	print("The look around can start in another script, and the marks and rows follow it")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = ""
	var opened_house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(opened_house)
	for i in 3:
		await process_frame
	check(_marks(opened_house) == 0, "no marks before the look around starts")
	save.state.world_state["house_task"] = "active"
	for i in 5:
		await process_frame
	check(_marks(opened_house) == home_places, "the marks appear on their own once the look around starts")
	var hud = root.get_node("/root/Hud")
	check(hud.objective_panel._places.get_child_count() == events.areas.size(), "the place rows appear on their own too")
	opened_house.get_parent().remove_child(opened_house)
	opened_house.free()

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
