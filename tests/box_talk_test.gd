extends SceneTree
## Checks: the talk between Amelia and Oliver after the hidden box is opened. Its data is whole: every speaker has portraits,
## every emotion has a picture, every item shown has a view, every item in the box is shown, and the talk ends on Amelia's
## decision to sleep on it, without sending her to Evelyn (her secret waits for later missions). A pending talk plays once, in order, and waits while an item viewer is open. It also
## starts when the box is opened from the inventory on the ground floor, and it does not start upstairs. A box that is not
## opened plays nothing. Frame limits only, no timers. Run:
## Godot --headless --path . -s res://tests/box_talk_test.gd

const DATA_PATH := "res://data/box_talk.json"
const ITEMS_PATH := "res://data/items.json"
const EVENTS_PATH := "res://data/home_events.json"
const OLIVER_ANIMATIONS := "res://data/oliver_animations.json"
const HOUSE := "res://scenes/HomeFloor1.tscn"
const BEDROOM := "res://scenes/BedroomUpstairs.tscn"
const MAX_FRAMES := 6000
## Frames an item viewer is held open by the test before it is closed, so the talk has to wait on it.
const HOLD_FRAMES := 30

var failures: Array[String] = []
var _indices: Array = []
var _early: Array = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _rect(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])


## A spot in the rectangle that no wall or furniture covers, found by asking the physics world.
func _free_spot(scene, rect: Rect2) -> Vector2:
	var space = scene.get_world_2d().direct_space_state
	for y in range(int(rect.position.y), int(rect.end.y), 8):
		for x in range(int(rect.position.x), int(rect.end.x), 8):
			var query := PhysicsPointQueryParameters2D.new()
			query.position = Vector2(x, y)
			query.collide_with_bodies = true
			query.exclude = [scene.player.get_rid()]
			if space.intersect_point(query).is_empty():
				return Vector2(x, y)
	return Vector2.INF


func _inspection(scene) -> Node:
	for child in scene.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/house_inspection.gd":
			return child
	return null


## True when Oliver, a walker with his own sheets, is on the scene.
func _has_oliver(scene: Node) -> bool:
	for child in scene.find_children("*", "", true, false):
		var walker := child.get_node_or_null("Walker")
		if walker is CharacterSprite and walker.animations_path == OLIVER_ANIMATIONS:
			return true
	return false


## Loads a scene and lets it settle for a few frames.
func _load_scene(path: String) -> Node2D:
	var scene: Node2D = load(path).instantiate()
	root.add_child(scene)
	for i in 3:
		await process_frame
	return scene


func _leave(scene: Node) -> void:
	scene.get_parent().remove_child(scene)
	scene.free()


## Waits up to a number of frames for the condition. True when it holds.
func _until(frames: int, condition: Callable) -> bool:
	for i in frames:
		if condition.call():
			return true
		await process_frame
	return condition.call()


## True while a screen, the item viewer, is open (HudEvents.screen_open).
func _screen_open() -> bool:
	return root.get_node("/root/HudEvents").screen_open


## Records each step the talk starts, and any that starts while an item viewer is open.
func _record(talk) -> void:
	_indices = []
	_early = []
	talk.step_started.connect(_on_step)


func _on_step(index: int) -> void:
	_indices.append(index)
	if _screen_open():
		_early.append(index)


## Plays the talk as a player would: each line is advanced, and an item viewer is held open for a while and then closed.
## Returns true when the talk has ended. `seen` notes whether Oliver was in the room, and the longest a viewer was held.
func _play_talk(scene, insp, frames: int, seen: Dictionary) -> bool:
	var open_frames := 0
	for i in frames:
		if scene.scene_dialogue.is_open:
			scene.scene_dialogue.advance()
		if _screen_open():
			open_frames += 1
			seen["held"] = maxi(seen.held, open_frames)
			if open_frames > HOLD_FRAMES:
				root.get_node("/root/Hud").viewer.close()
		else:
			open_frames = 0
		await process_frame
		if _has_oliver(scene):
			seen["oliver"] = true
		if not insp._busy and not scene.scripted:
			return true
	return false


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	var events: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))
	var steps: Array = data.steps
	var box_contents: Array = items.hidden_box.contents

	print("The talk's data")
	var portraits_ok := true
	var emotions_ok := true
	var views_ok := true
	var shown_ids: Array = []
	for raw_step in steps:
		var step: Dictionary = raw_step
		if step.has("show"):
			shown_ids.append(step.show)
			var item: Dictionary = items.get(step.show, {})
			views_ok = views_ok and not item.is_empty() and not item.get("view", []).is_empty()
			continue
		var speaker: String = step.say
		if not SceneDialogue.PORTRAITS.has(speaker):
			portraits_ok = false
			continue
		var folder: String = SceneDialogue.PORTRAITS[speaker]
		for raw_line in step.lines:
			var line: Dictionary = raw_line
			if not FileAccess.file_exists(folder + line.emotion + ".png"):
				emotions_ok = false
	var shows_box := shown_ids.size() == box_contents.size()
	for id in box_contents:
		shows_box = shows_box and shown_ids.has(id)
	var last_step: Dictionary = steps[steps.size() - 1]
	var final_text := ""
	for raw_line in last_step.get("lines", []):
		var line: Dictionary = raw_line
		final_text += line.text
	var all_text := JSON.stringify(steps)
	var conclusion_ok: bool = last_step.get("say", "") == "Amelia" and final_text.contains("sleep on it") and not all_text.contains("florist")
	check(portraits_ok, "every speaker in the talk has a portrait folder")
	check(emotions_ok, "every emotion in the talk has a picture in its speaker's folder")
	check(views_ok, "every item shown in the talk exists and has a view")
	check(shows_box, "the talk shows each item in the box, and nothing else")
	check(conclusion_ok, "the talk ends on Amelia's line: they will sleep on it, and nobody is sent to the florist shop")

	print("A pending talk plays once, in order")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "done"
	save.state.world_state["house_plank_found"] = true
	save.state.opened_items["hidden_box"] = true
	save.state.world_state["box_talk_done"] = false
	var house = await _load_scene(HOUSE)
	var insp = _inspection(house)
	check(insp != null, "the house has its look around")
	# Amelia stands at the loose board, where the box is opened.
	house.player.position = _free_spot(house, _rect(events.plank.rect))
	var started := await _until(60, func(): return insp.box_talk != null)
	check(started, "the talk starts once the house loads with the box open")
	if not started:
		_finish()
		return
	# Not typed as BoxTalk: a typed name in this script would compile BoxTalk before the HudEvents autoload is known here.
	_record(insp.box_talk)
	var seen := {"oliver": false, "held": 0}
	var finished := await _play_talk(house, insp, MAX_FRAMES, seen)
	check(finished, "the talk ends within its frame limit")
	check(_indices == range(steps.size()), "the talk plays each of its steps once, in order")
	check(_early.is_empty(), "no step starts while an item viewer is open")
	check(seen.held > HOLD_FRAMES, "an item viewer stays open until it is closed, and the talk waits for it")
	check(seen.oliver, "Oliver walks into the room during the talk")
	check(save.state.world_state.get("box_talk_done", false), "the talk is marked done")
	check(not house.scripted, "control comes back after the talk")
	check(not _screen_open(), "no item viewer is left open after the talk")
	for i in 3:
		await process_frame
	check(not _has_oliver(house), "Oliver leaves the room when the talk ends")

	print("Walking back in does not play it again")
	_leave(house)
	house = await _load_scene(HOUSE)
	insp = _inspection(house)
	var again := await _until(120, func(): return insp.box_talk != null)
	check(not again, "no talk starts on the next visit")
	check(not _has_oliver(house), "Oliver is not in the room on the next visit")
	check(not house.scripted, "the house is open to Amelia on the next visit")
	check(save.state.world_state.get("box_talk_done", false), "the talk stays marked done")

	print("Opened from the inventory on the ground floor")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "done"
	save.state.world_state["house_plank_found"] = true
	save.state.inventory["hidden_box"] = 1
	save.state.world_state["box_talk_done"] = false
	_leave(house)
	house = await _load_scene(HOUSE)
	insp = _inspection(house)
	var still_shut := await _until(30, func(): return insp.box_talk != null)
	check(not still_shut, "a box still shut in the inventory starts no talk")
	root.get_node("/root/HudEvents").item_open_requested.emit("hidden_box")
	var from_inventory := await _until(60, func(): return insp.box_talk != null)
	check(from_inventory, "opening the box from the inventory starts the talk on the ground floor")
	if not from_inventory:
		_finish()
		return
	_record(insp.box_talk)
	seen = {"oliver": false, "held": 0}
	finished = await _play_talk(house, insp, MAX_FRAMES, seen)
	check(finished, "the talk from the inventory ends within its frame limit")
	check(_indices == range(steps.size()), "the talk from the inventory plays each of its steps once, in order")
	check(_early.is_empty(), "the talk from the inventory waits for each item viewer")
	var inventory: Dictionary = save.state.inventory
	var all_in := true
	for id in box_contents:
		all_in = all_in and int(inventory.get(id, 0)) > 0
	check(all_in and not inventory.has("hidden_box"), "opening the box puts all of its items in the inventory and takes the box out")

	print("Upstairs with the box open plays nothing")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "done"
	save.state.world_state["house_plank_found"] = true
	save.state.opened_items["hidden_box"] = true
	save.state.world_state["box_talk_done"] = false
	_leave(house)
	house = await _load_scene(BEDROOM)
	insp = _inspection(house)
	check(insp != null, "the bedroom has its own look around")
	var upstairs := await _until(120, func(): return insp != null and insp.box_talk != null)
	check(not upstairs, "with the box open, no talk starts upstairs")
	check(not _has_oliver(house), "Oliver does not come upstairs")
	check(not save.state.world_state.get("box_talk_done", false), "the talk stays unplayed upstairs")
	_leave(house)

	print("A box that is not opened plays nothing")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "active"
	house = await _load_scene(HOUSE)
	insp = _inspection(house)
	var unopened := await _until(120, func(): return insp.box_talk != null)
	check(not unopened, "a box that is not opened starts no talk")
	check(not _has_oliver(house), "Oliver stays out of the house without the talk")
	check(not save.state.world_state.get("box_talk_done", false), "the talk is not marked done")
	_leave(house)
	_finish()


func _finish() -> void:
	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
