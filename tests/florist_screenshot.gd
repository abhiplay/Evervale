extends SceneTree
## Saves a screenshot of the florist shop with the character inside. Run without --headless.
## Run: Godot --path . -s res://tests/florist_screenshot.gd

const OUT := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/florist_shop.png"


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.pending_spawn = "from_town"
	var shop = load("res://scenes/Florist.tscn").instantiate()
	root.add_child(shop)
	for i in 90:
		await process_frame
	root.get_texture().get_image().save_png(OUT)
	print("saved " + OUT)
	quit(0)
