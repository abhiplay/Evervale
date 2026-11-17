extends SceneTree
## Checks the story's missions (MissionTracker, data/missions.json): M01 to M05 complete in order from what the game saves,
## progress made early counts once the missions before it are done, a mission with no completion conditions never completes,
## and the HUD objective follows the mission that is on, in the yard, in the house after the box talk, in the Town square
## and in the café. Run: Godot --headless --path . -s res://tests/mission_tracker_test.gd

var failures: Array[String] = []
var notices: Array[String] = []
var save
var hud
## The tracker script, loaded once the autoloads it reads exist (a test script compiles before them).
var tracker


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	save = root.get_node("/root/SaveSystem")
	hud = root.get_node("/root/Hud")
	tracker = load("res://scripts/mission_tracker.gd")
	var data = root.get_node("/root/GameData")
	root.get_node("/root/HudEvents").notification_requested.connect(func(text: String): notices.append(text))
	check(save.save_path == save.TEST_SAVE_PATH, "the test saves to the test file, not the player's save")

	print("Mission data")
	check(data.validate().is_empty(), "the story data has no broken references or unknown conditions")
	for id in ["M01", "M02", "M03", "M04", "M05"]:
		var mission: Dictionary = data.missions[id]
		check(not mission.completion_conditions.is_empty() and not mission.get("objective_steps", []).is_empty(),
			"%s has completion conditions and objective steps" % id)

	print("A new game")
	_new_state()
	save.state.world_state["opening_stage"] = "pending"
	tracker.update()
	check(tracker.active_mission() == "M01", "a new game starts on M01")
	check(not hud.objective_panel.visible, "no objective shows while the opening plays")

	print("Moving in")
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "active"
	tracker.update()
	check(not save.state.completed_missions.has("M01"), "M01 waits for the look around")
	check(_title() == "Look around the house", "away from the house, the objective still asks to look around")
	save.state.world_state["house_task"] = "done"
	tracker.update()
	check(not save.state.completed_missions.has("M01"), "M01 waits for the pets after the look around")
	check(_title() == "Say hello to Coco", "the objective asks to meet Coco")
	tracker.note_talked_to("coco")
	check(_title() == "Say hello to Charlie", "then Charlie")
	tracker.note_talked_to("charlie")
	check(_title() == "Our new home", "then the talk with Oliver")
	check(not save.state.completed_missions.has("M01"), "M01 waits for the Our New Home talk")
	save.state.cutscenes_viewed.append("CS-003")
	tracker.update()
	check(save.state.completed_missions.has("M01"), "the look around, the pets and the talk complete M01")
	check(tracker.active_mission() == "M02", "M02 comes next")
	check(save.state.active_missions == ["M02"], "the save names the mission that is on")
	check(_title() == "Meet the neighbours", "the objective moves on to the town")
	check(notices.has("Completed: A New Beginning"), "a notice says M01 is complete")

	print("Town and café")
	tracker.note_talked_to("noticeboard")
	check(not save.state.world_state.get("talked_to", []).has("noticeboard"), "the noticeboard is not a person met")
	tracker.note_talked_to("rose_west")
	check(not save.state.completed_missions.has("M02"), "meeting Rose alone does not finish First Steps")
	tracker.note_talked_to("henry_collins")
	check(save.state.completed_missions.has("M02"), "meeting Henry completes M02")
	check(_title() == "A warm welcome", "the objective moves on to the café")
	tracker.note_visit("cafe")
	tracker.update()
	check(not save.state.completed_missions.has("M03"), "M03 waits for Henry's welcome in the café")
	check(_description() == "Say hello to Henry at the counter.", "the objective asks to talk to Henry inside")
	save.state.world_state["cafe_welcome_done"] = true
	tracker.update()
	check(save.state.completed_missions.has("M03"), "Henry's welcome in the café completes M03")
	check(_title() == "The loose board", "the objective moves on to the loose board")

	print("The hidden box")
	save.state.world_state["house_plank_found"] = true
	tracker.update()
	check(_description() == "Open the box you found. It's in your inventory.", "once found, the objective asks to open the box")
	save.state.opened_items["hidden_box"] = true
	tracker.update()
	check(_description() == "Go home and show Oliver what was inside.", "once open, the objective asks to show Oliver")
	check(not save.state.completed_missions.has("M04"), "M04 waits for the talk with Oliver")
	save.state.world_state["box_talk_done"] = true
	tracker.update()
	check(save.state.completed_missions.has("M04"), "the talk with Oliver completes M04")
	check(tracker.active_mission() == "M05", "M05 comes next")
	check(_title() == "Settle in for the night", "the objective moves on to the night")
	check(not save.state.completed_missions.has("M05"), "M05 waits for the 2:17 radio")

	print("A mission with no ending yet")
	save.state.completed_missions.append("M05")
	tracker.update()
	check(not save.state.completed_missions.has("M06"), "a mission without completion conditions never completes on its own")
	check(tracker.active_mission() == "M06", "it is still the mission that is on")

	print("Progress made early")
	_new_state()
	for flag in ["house_plank_found", "box_talk_done"]:
		save.state.world_state[flag] = true
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "done"
	_moved_in()
	save.state.opened_items["hidden_box"] = true
	tracker.update()
	check(save.state.completed_missions == ["M01"], "the box found early does not skip the town and the café")
	tracker.note_talked_to("henry_collins")
	tracker.note_visit("cafe")
	save.state.world_state["cafe_welcome_done"] = true
	tracker.update()
	check(save.state.completed_missions == ["M01", "M02", "M03", "M04"], "it counts as soon as the café welcome is done")
	check(tracker.active_mission() == "M05", "and the story moves on to the night")

	print("In the house after the box talk")
	_new_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "done"
	_moved_in()
	save.state.world_state["house_plank_found"] = true
	save.state.world_state["box_talk_done"] = true
	save.state.opened_items["hidden_box"] = true
	var house = await _open("res://scenes/HomeFloor1.tscn")
	check(_title() == "Meet the neighbours", "before the town, the house points to the town, not to the open box")
	_close(house)
	save.state.world_state["talked_to"] = ["coco", "charlie", "henry_collins"]
	save.state.world_state["visited_scenes"] = ["cafe"]
	save.state.world_state["cafe_welcome_done"] = true
	house = await _open("res://scenes/HomeFloor1.tscn")
	check(save.state.completed_missions.has("M04"), "walking into the house completes what was already done")
	check(_title() == "Settle in for the night", "after the town, the café and the box, the house shows the night")
	_close(house)

	print("Town square")
	_new_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "done"
	_moved_in()
	save.state.pending_spawn = "from_map"
	var town = await _open("res://scenes/TownSquare.tscn")
	town.set_physics_process(false)
	var old_label := false
	for label in town.find_children("*", "Label", true, false):
		if label.text.begins_with("Journal:"):
			old_label = true
	check(not old_label, "the old journal label is gone")
	check(_title() == "Meet the neighbours", "arriving in town shows the town objective")
	town.player.position = Vector2(760, 560)
	town._update_nearby()
	town._interact(town.nearby)
	check(save.state.completed_missions.has("M02"), "talking to Henry completes M02")
	check(_title() == "A warm welcome", "and the objective moves on to the café")
	_close(town)

	print("Café")
	var cafe = await _open("res://scenes/Cafe.tscn")
	check(not save.state.completed_missions.has("M03"), "walking in alone does not complete M03")
	check((cafe.find_child("Person_henry_collins", true, false) != null), "Henry is in his café once First Steps is done")
	cafe.player.position = Vector2(1120, 460)
	cafe._update_nearby()
	check(cafe.nearby.get("id", "") == "henry_collins", "standing by Henry offers to talk")
	cafe._unhandled_input(_interact_event())
	check(cafe.scene_dialogue.is_open, "Henry says his welcome")
	check(save.state.completed_missions.has("M03"), "Henry's welcome completes M03")
	check(_title() == "The loose board", "the objective moves on to the loose board")
	_close(cafe)

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


## The rest of M01 after the look around: both pets met and the Our New Home talk seen.
func _moved_in() -> void:
	save.state.world_state["talked_to"] = ["coco", "charlie"]
	save.state.cutscenes_viewed.append("CS-003")


func _interact_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	return event


func _new_state() -> void:
	save.state = save.new_game_state()
	notices.clear()


func _title() -> String:
	return hud.objective_panel.objective_title if hud.objective_panel.visible else ""


func _description() -> String:
	return hud.objective_panel.objective_description


func _open(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	for i in 5:
		await process_frame
	return scene


func _close(scene: Node) -> void:
	scene.get_parent().remove_child(scene)
	scene.free()
