extends SceneTree
## Saves a picture of the upstairs bedroom during the look around, with the player beside the dresser, so the sparkle on the
## dresser (a place still to be looked at) can be seen. Run without --headless: Godot --path . -s res://tests/glint_screenshot.gd

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "active"
	var bedroom = load("res://scenes/BedroomUpstairs.tscn").instantiate()
	root.add_child(bedroom)
	current_scene = bedroom
	for i in 3:
		await process_frame
	# Just in front of the dresser's area, outside it, so Amelia does not walk in and start its lines.
	bedroom.player.position = Vector2(370, 760)
	for i in 90:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/glint_dresser.png")
	print("saved glint_dresser.png")
	quit(0)
