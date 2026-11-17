extends SceneTree
## Saves a zoomed-out picture of the whole town square. Run without --headless:
## Godot --path . -s res://tests/town_overview_screenshot.gd

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	save.state = save.new_game_state()
	var town = load("res://scenes/TownSquare.tscn").instantiate()
	root.add_child(town)
	current_scene = town
	for i in 3:
		await process_frame
	# The player stands in the middle of the room, so the camera (which follows her) shows the room; the camera zooms out to fit it.
	town.player.position = Vector2(835, 470)
	town.scripted = true
	town.camera.position_smoothing_enabled = false
	town.camera.limit_left = -100000
	town.camera.limit_right = 100000
	town.camera.limit_top = -100000
	town.camera.limit_bottom = 100000
	town.camera.zoom = Vector2(0.56, 0.56)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/town_overview.png")
	print("saved overview")
	quit(0)
