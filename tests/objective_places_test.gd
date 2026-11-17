extends SceneTree
## Checks: every house place has its own label; while the look around is on, the objective lists one row per place and ticks
## only the places seen; the panel grows to fit the rows; and the rows go once the look around is done. Frame limits only. Run:
## Godot --headless --path . -s res://tests/objective_places_test.gd

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


## How many of the objective's place rows are ticked. Each row holds its box first, and the box holds its tick second.
func _ticked(panel) -> int:
	var count := 0
	for row in panel._places.get_children():
		var tick: Control = row.get_child(0).get_child(1)
		if tick.visible:
			count += 1
	return count


func _initialize() -> void:
	await process_frame
	var events: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EVENTS))
	var seen_labels := {}
	var labels_ok := true
	for area in events.areas:
		var label: String = area.get("label", "")
		if label == "" or seen_labels.has(label):
			labels_ok = false
		seen_labels[label] = true
	check(labels_ok, "every house place has its own non-empty label")

	var save = root.get_node("/root/SaveSystem")
	var hud = root.get_node("/root/Hud")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "active"
	save.state.world_state["house_seen"] = ["living_room"]
	var house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	for i in 3:
		await process_frame
	var insp = _inspection(house)
	check(insp != null, "the house has its look around")
	var places: Array = insp._places()
	check(places.size() == events.areas.size(), "the look around lists every place (%d)" % places.size())
	var living: Dictionary = {}
	var kitchen: Dictionary = {}
	for place in places:
		if place.label == "Living room":
			living = place
		if place.label == "Kitchen":
			kitchen = place
	check(living.get("seen", false) and not kitchen.get("seen", true), "the place looked at is seen, and the others are not")

	var panel = hud.objective_panel
	check(panel._places.get_child_count() == events.areas.size(), "the objective shows one row per place")
	check(_ticked(panel) == 1, "only the place looked at is ticked")
	check(panel._places.get_child(0).get_child(1).text == "Living room", "the first row is named for its place")
	check(panel.custom_minimum_size.y > panel.MIN_HEIGHT, "the panel grows to fit its rows")

	print("Each place is ticked once it has been seen")
	save.state.world_state["house_seen"] = ["living_room", "kitchen"]
	insp._refresh()
	await process_frame
	check(_ticked(panel) == 2, "a second place seen gets a second tick")

	print("The rows go once the look around is done or before it starts")
	save.state.world_state["house_task"] = "done"
	insp._refresh()
	await process_frame
	check(panel._places.get_child_count() == 0 and not panel._places.visible, "no rows once the look around is done")
	save.state.world_state["house_task"] = ""
	insp._refresh()
	await process_frame
	check(insp._places().is_empty(), "no places before the look around starts")

	house.get_parent().remove_child(house)
	house.free()
	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
