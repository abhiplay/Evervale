extends SceneTree
## Checks Mission 5, "2:17 AM" (Night217, data/night_217.json): the bed offers Sleep only after the box talk and only
## until the radio has spoken; sleeping plays the night through both floors (the time card, the dark bedroom, the walk to
## the radio, the static and the warning transmission, Oliver coming down); morning saves the flag, moves to day 2,
## completes Mission 5 and shows the end of Act I; and it never plays twice. Frame limits only for the dialogue.
## Run: Godot --headless --path . -s res://tests/night_217_test.gd

const MAX_FRAMES := 20000

var failures: Array[String] = []
var save
var said: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	save = root.get_node("/root/SaveSystem")
	var hud = root.get_node("/root/Hud")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/night_217.json"))

	print("Data")
	var spoken := data.duplicate()
	spoken.erase("_note")
	var all_text := JSON.stringify(spoken)
	check(data.caption == "2:17 AM", "the time card reads 2:17 AM")
	check(all_text.contains("If you're hearing this, don't trust the people who welcomed you."), "the transmission is the story bible's line")
	check(not all_text.contains("Silas"), "no line says who started the signal")
	check(ResourceLoader.exists("res://assets/audio/radio_static.wav"), "the static sound is in the assets")

	print("The bed")
	_state(false)
	var room = await _open("res://scenes/BedroomUpstairs.tscn")
	check(not _has_bed(room), "before the box talk, the bed offers nothing")
	_close(room)
	_state(true)
	room = await _open("res://scenes/BedroomUpstairs.tscn")
	check(_has_bed(room), "after the box talk, the bed offers Sleep")
	check(hud.objective_panel.objective_title == "Settle in for the night", "the objective says to settle in for the night")

	print("Upstairs at 2:17")
	room.player.position = Vector2(720, 800)
	room._update_nearby()
	check(room.nearby.get("id", "") == "bed", "standing at the foot of the bed offers Sleep")
	room._unhandled_input(_interact_event())
	var saw_caption := false
	var saw_tint := false
	var heard_static := false
	var saw_oliver := false
	for i in MAX_FRAMES:
		if save.state.world_state.get("radio_217_heard", false) and not room.scripted:
			break
		var sound = room.get_node_or_null("RadioStatic")
		if sound and sound.playing:
			heard_static = true
		for child in room.get_children():
			if child.is_in_group("figures"):
				saw_oliver = true
		if room.scene_dialogue.is_open:
			var text: String = room.scene_dialogue._text_label.text
			if said.is_empty() or said[-1] != text:
				said.append(text)
			if i % 4 == 0:
				room.scene_dialogue.advance()
		var caption = room.find_child("NightCaption", true, false)
		if caption and caption.visible:
			saw_caption = true
		if room.has_node("NightTint"):
			saw_tint = true
		await process_frame
	check(saw_caption, "the 2:17 AM card shows")
	check(saw_tint, "the bedroom is dark")
	check(heard_static, "the radio on the wall plays static")
	check(said.has("If you're hearing this, don't trust the people who welcomed you."), "the radio delivers the warning")
	check(saw_oliver, "Oliver comes over")
	check(room.player.position.distance_to(Vector2(data.amelia_walks_to[0], data.amelia_walks_to[1])) < 40, "Amelia walks to the radio")

	print("Morning")
	check(save.state.world_state.get("radio_217_heard", false), "the radio's warning is saved")
	check(save.state.world_state.get("night_217_stage", "") == "done", "the night is over")
	check(save.state.completed_missions.has("M05"), "the night completes Mission 5")
	check(int(save.state.day) == 2, "it is day 2")
	check(not room.has_node("NightTint") or room.get_node("NightTint").is_queued_for_deletion(), "the night tint is gone")
	check(not room.scripted, "Amelia can move again")
	check(hud.objective_panel.objective_title == "End of Act I", "the objective says Act I is over")
	room.player.position = Vector2(390, 400)
	room._update_nearby()
	check(room.nearby.get("id", "") == "radio" and str(room.nearby.get("lines", [""])[0]).contains("silent"), "afterwards the radio by the wall is silent")
	await _frames(20)
	check(not room.scripted, "nothing plays again")
	_close(room)
	room = await _open("res://scenes/BedroomUpstairs.tscn")
	check(not _has_bed(room), "the bed no longer offers Sleep")
	_close(room)

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _state(box_talk_done: bool) -> void:
	save.state = save.new_game_state()
	var world: Dictionary = save.state.world_state
	world["opening_stage"] = "done"
	world["house_task"] = "done"
	world["talked_to"] = ["coco", "charlie", "henry_collins"]
	world["visited_scenes"] = ["cafe"]
	world["cafe_welcome_done"] = true
	save.state.cutscenes_viewed = ["CS-003"]
	if box_talk_done:
		world["house_plank_found"] = true
		world["box_talk_done"] = true
		save.state.opened_items["hidden_box"] = true


func _has_bed(scene) -> bool:
	for item in scene.interactables:
		if item.id == "bed":
			return true
	return false


func _interact_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	return event


func _open(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	await _frames(3)
	return scene


func _close(scene: Node) -> void:
	if scene.get_parent():
		scene.get_parent().remove_child(scene)
	if current_scene == scene:
		current_scene = null
	scene.free()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
