extends SceneTree
## Saves pictures of the box talk, for a visual check: Oliver walking in, the first line, the letter, the photo, and the pocket watch,
## the key and the doll.
## Run without --headless: Godot --path . -s res://tests/box_talk_screenshot.gd

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"
const MAX_FRAMES := 3000

var _progress := {"step": -1}


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	var events: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/home_events.json"))
	var talk_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/box_talk.json"))
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "done"
	save.state.world_state["house_plank_found"] = true
	save.state.opened_items["hidden_box"] = true
	save.state.world_state["box_talk_done"] = false
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	for i in 3:
		await process_frame
	var insp = _inspection(house)
	# Amelia stands at the loose board, where the box is opened.
	var board := Rect2(events.plank.rect[0], events.plank.rect[1], events.plank.rect[2], events.plank.rect[3])
	house.player.position = _free_spot(house, board)

	var started: bool = await _until(MAX_FRAMES, func(): return insp.box_talk != null)
	if not started:
		print("The talk did not start")
		quit(1)
		return
	var talk = insp.box_talk
	talk.step_started.connect(_on_step_started)

	# About 150 frames after the talk starts, Oliver is walking in.
	for i in 150:
		await process_frame
	_save("boxtalk_1_walk.png")

	# The first line, once it has settled on screen. Nothing is advanced here.
	var line_showing: bool = await _until(MAX_FRAMES, func(): return _progress.step == 0 and house.scene_dialogue.is_open)
	if not line_showing:
		print("The first line did not show")
		quit(1)
		return
	for i in 40:
		await process_frame
	_save("boxtalk_2_line.png")

	# The letter, once the viewer shows it.
	var letter_step: int = _show_step(talk_data, "letter_arthur")
	var letter_up: bool = await _advance_until(house, MAX_FRAMES, func(): return _progress.step == letter_step and _screen_open())
	if not letter_up:
		print("The letter did not open")
		quit(1)
		return
	for i in 30:
		await process_frame
	_save("boxtalk_3_letter.png")
	root.get_node("/root/Hud").viewer.close()

	# The photo, once the viewer shows it.
	var photo_step: int = _show_step(talk_data, "photo_box")
	var photo_up: bool = await _advance_until(house, MAX_FRAMES, func(): return _progress.step == photo_step and _screen_open())
	if not photo_up:
		print("The photo did not open")
		quit(1)
		return
	for i in 30:
		await process_frame
	_save("boxtalk_4_photo.png")
	root.get_node("/root/Hud").viewer.close()

	# The pocket watch, the key and the doll, each in the viewer as the talk shows it.
	for entry in [[_show_step(talk_data, "pocket_watch"), "boxtalk_5_pocket_watch.png"], [_show_step(talk_data, "key_strange"), "boxtalk_6_key.png"], [_show_step(talk_data, "doll_rag"), "boxtalk_7_doll.png"]]:
		var step: int = entry[0]
		var item_up: bool = await _advance_until(house, MAX_FRAMES, func(): return _progress.step == step and _screen_open())
		if not item_up:
			print("The item at step %d did not open" % step)
			quit(1)
			return
		for i in 30:
			await process_frame
		_save(entry[1])
		root.get_node("/root/Hud").viewer.close()

	# Let the talk finish, so the house is left as the player would leave it.
	var finished: bool = await _advance_until(house, MAX_FRAMES, func(): return save.state.world_state.get("box_talk_done", false))
	if not finished:
		print("The talk did not finish")
		quit(1)
		return
	print("The talk finished")
	quit(0)


func _on_step_started(index: int) -> void:
	_progress.step = index


## The index of the step that shows an item in the talk, or -1 when no step does.
func _show_step(data: Dictionary, item_id: String) -> int:
	var steps: Array = data.steps
	for index in steps.size():
		if steps[index].get("show", "") == item_id:
			return index
	return -1


func _save(file_name: String) -> void:
	var out := OUT_DIR + "/" + file_name
	root.get_texture().get_image().save_png(out)
	print("saved " + out)


func _inspection(scene) -> Node:
	for child in scene.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/house_inspection.gd":
			return child
	return null


## True while a screen, the item viewer, is open (HudEvents.screen_open).
func _screen_open() -> bool:
	return root.get_node("/root/HudEvents").screen_open


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


## Waits up to a number of frames for the condition, and says nothing meanwhile. True when it holds.
func _until(frames: int, condition: Callable) -> bool:
	for i in frames:
		if condition.call():
			return true
		await process_frame
	return condition.call()


## Waits up to a number of frames for the condition, closing each line of the talk as the player would. True when it holds.
func _advance_until(scene, frames: int, condition: Callable) -> bool:
	for i in frames:
		if scene.scene_dialogue.is_open:
			scene.scene_dialogue.advance()
		if condition.call():
			return true
		await process_frame
	return condition.call()
