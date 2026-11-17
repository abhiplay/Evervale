extends SceneTree
## Saves pictures of the bookstore with the character behind the lower display table and in front of it, to check the walk-behind.
## Run without --headless: Godot --path . -s res://tests/bookstore_walk_behind_screenshot.gd

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
	# Behind the lower display table: above its base, so the table covers her legs.
	shop.player.position = Vector2(818, 548)
	shop.scripted = true
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/bookstore_behind_table.png")
	# In front of the table: below its base.
	shop.player.position = Vector2(818, 660)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/bookstore_front_table.png")
	print("saved walk-behind pictures")
	quit(0)
