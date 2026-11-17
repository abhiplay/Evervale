extends SceneTree
## Saves a picture of the objective with its place rows, three places seen, for a visual check of the layout. Run without
## --headless: Godot --path . -s res://tests/objective_places_screenshot.gd

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "active"
	save.state.world_state["house_seen"] = ["living_room", "kitchen", "staircase"]
	var house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	for i in 60:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/objective_places.png")
	print("saved " + OUT_DIR + "/objective_places.png")
	quit(0)
