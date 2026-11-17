extends SceneTree
## Saves a picture of the "New Discovery" chat over the ground floor: the found item floats in the middle, the place is
## dimmed behind it, and the words and the choice sit in the dialogue box. Run without --headless:
## Godot --path . -s res://tests/discovery_chat_screenshot.gd

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "done"
	save.state.world_state["box_talk_done"] = true
	save.state.cutscenes_viewed.append("CS-003")
	var house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	for i in 3:
		await process_frame
	house.set_physics_process(false)
	var items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	var inspection = null
	for child in house.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("house_inspection.gd"):
			inspection = child
	inspection._popup.show_discovery(items["hidden_box"])
	# Past the fade in and the moment the item is shown, so the choice is up.
	for i in 150:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/discovery_chat.png")
	print("saved discovery_chat.png")
	quit(0)
