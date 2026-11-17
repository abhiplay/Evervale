extends SceneTree
## Saves pictures of the bookstore reading corner with the character behind the armchair and in front of it, to check the
## walk-behind. Run without --headless: Godot --path . -s res://tests/reading_corner_screenshot.gd

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	save.state = save.new_game_state()
	var shop = load("res://scenes/Bookstore.tscn").instantiate()
	root.add_child(shop)
	current_scene = shop
	for i in 3:
		await process_frame
	shop.scripted = true
	# Behind the armchair: feet above its seat edge, so the chair covers her.
	shop.player.position = Vector2(320, 240)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/reading_corner_behind_chair.png")
	# In front of the armchair on the rug: feet below its seat edge, so she is drawn over it.
	shop.player.position = Vector2(320, 330)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/reading_corner_front_chair.png")
	print("saved reading corner pictures")
	quit(0)
