extends SceneTree
## Saves a picture of the settled upstairs bedroom with the radio on the wall, left of the bedside table, so its place can be
## checked. Run without --headless: Godot --path . -s res://tests/radio_bedroom_screenshot.gd

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
	var bedroom = load("res://scenes/BedroomUpstairs.tscn").instantiate()
	root.add_child(bedroom)
	current_scene = bedroom
	for i in 3:
		await process_frame
	# Just in front of the radio, outside the bedside table, so Amelia does not walk onto anything.
	bedroom.player.position = Vector2(390, 430)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/radio_bedroom.png")
	print("saved radio_bedroom.png")
	quit(0)
