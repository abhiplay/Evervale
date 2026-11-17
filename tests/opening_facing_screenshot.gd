extends SceneTree
## Saves pictures of the opening talks, for a visual check that the people in each talk face each other: the first line in
## the front yard, and the first line inside the house. Run without --headless:
## Godot --path . -s res://tests/opening_facing_screenshot.gd

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"
const MAX_FRAMES := 3000


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "pending"
	var yard = load("res://scenes/ExteriorHome.tscn").instantiate()
	root.add_child(yard)
	current_scene = yard
	var yard_line: bool = await _until(MAX_FRAMES, func(): return yard.scene_dialogue.is_open)
	if not yard_line:
		print("The front-yard talk did not start")
		quit(1)
		return
	for i in 30:
		await process_frame
	_save("opening_1_front_yard.png")
	root.remove_child(yard)
	yard.free()

	save.state.world_state["opening_stage"] = "inside"
	var house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	var house_line: bool = await _until(MAX_FRAMES, func(): return house.scene_dialogue.is_open and house.scene_dialogue._text_label.text.begins_with("This is even better"))
	if not house_line:
		print("The house talk did not start")
		quit(1)
		return
	for i in 30:
		await process_frame
	_save("opening_2_house.png")
	print("The opening talks were saved")
	quit(0)


func _save(file_name: String) -> void:
	var out := OUT_DIR + "/" + file_name
	root.get_texture().get_image().save_png(out)
	print("saved " + out)


## Waits up to a number of frames for the condition, and says nothing meanwhile. True when it holds.
func _until(frames: int, condition: Callable) -> bool:
	for i in frames:
		if condition.call():
			return true
		await process_frame
	return condition.call()
