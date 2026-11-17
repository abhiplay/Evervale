extends SceneTree
## Saves a screenshot of one scene as it starts, for a visual check. Run without --headless:
## Godot --path . -s res://tests/scene_screenshot.gd -- SceneName

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var scene_name := args[0] if args.size() > 0 else "ExteriorHome"
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	if OS.get_cmdline_user_args().has("house"):
		save.state.world_state["opening_stage"] = "done"
		save.state.world_state["house_task"] = "active"
	root.get_node("/root/HudEvents").inventory_changed.emit()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var scene: Node = load("res://scenes/%s.tscn" % scene_name).instantiate()
	root.add_child(scene)
	current_scene = scene
	# Let the scene draw before an option opens the viewer, so the viewer's backdrop copies the room and not an empty screen.
	for i in 60:
		await process_frame
	if OS.get_cmdline_user_args().has("door"):
		scene.player.position = Vector2(748, 420)
	if OS.get_cmdline_user_args().has("inventory"):
		save.add_item("hidden_box", 1)
		var inventory = root.get_node("/root/Hud").inventory
		inventory.show_inventory()
		for category_id in ["key", "documents", "clues", "personal"]:
			if OS.get_cmdline_user_args().has(category_id):
				inventory._set_category(category_id)
		if OS.get_cmdline_user_args().has("box"):
			inventory._select(inventory._items.find("hidden_box"))
	if OS.get_cmdline_user_args().has("objective"):
		root.get_node("/root/HudEvents").objective_changed.emit("Look around the house", "10 of 11 places checked.", false)
	if OS.get_cmdline_user_args().has("letter"):
		var letter: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))["letter_arthur"]
		root.get_node("/root/Hud").viewer.show_item(letter["view"][0])
	if OS.get_cmdline_user_args().has("letterdetail"):
		save.add_item("letter_arthur", 1)
		save.add_item("photo_box", 1)
		var inv = root.get_node("/root/Hud").inventory
		inv.show_inventory()
		inv._set_category("documents")
		inv._select(inv._items.find("letter_arthur"))
	if OS.get_cmdline_user_args().has("photo") or OS.get_cmdline_user_args().has("photoback"):
		var photo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))["photo_box"]
		root.get_node("/root/Hud").viewer.show_item(photo["view"][0])
		if OS.get_cmdline_user_args().has("photoback"):
			root.get_node("/root/Hud").viewer.turn_over()
	if OS.get_cmdline_user_args().has("photodetail"):
		save.add_item("photo_box", 1)
		var photo_inv = root.get_node("/root/Hud").inventory
		photo_inv.show_inventory()
		photo_inv._set_category("personal")
		photo_inv._select(photo_inv._items.find("photo_box"))
	for i in 90:
		await process_frame
	var label := "_".join(args) if args.size() > 0 else "ExteriorHome"
	var out := OUT_DIR + "/" + label + ".png"
	root.get_texture().get_image().save_png(out)
	print("saved " + out)
	quit(0)
