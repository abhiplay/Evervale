extends SceneTree
## Saves a picture of the Town Square with the character behind the tree, to check the walk-behind. Run without --headless:
## Godot --path . -s res://tests/town_tree_walk_behind_screenshot.gd

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	save.state = save.new_game_state()
	var square = load("res://scenes/TownSquare.tscn").instantiate()
	root.add_child(square)
	current_scene = square
	for i in 3:
		await process_frame
	# Behind the tree: above its base (its base is at y 720), inside its footprint on the picture.
	square.player.position = Vector2(1030, 650)
	square.scripted = true
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/town_behind_tree.png")
	print("saved town tree walk-behind")
	quit(0)
