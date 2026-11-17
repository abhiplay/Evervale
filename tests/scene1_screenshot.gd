extends SceneTree
## Saves a picture of Scene 1 as it plays, for a visual check. Run without --headless:
## Godot --path . -s res://tests/scene1_screenshot.gd -- front_yard
## or:  Godot --path . -s res://tests/scene1_screenshot.gd -- inside

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var part := "front_yard"
	for option in ["inside", "task", "plank", "letter"]:
		if args.has(option):
			part = option
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var scene: Node
	if part == "front_yard":
		save.state.world_state["opening_stage"] = "pending"
		scene = load("res://scenes/ExteriorHome.tscn").instantiate()
	else:
		# "inside" plays the house talk; "task" is the look around with Evelyn gone; "plank" is the box.
		save.state.world_state["opening_stage"] = "inside" if part == "inside" else "done"
		save.state.world_state["house_task"] = "done" if part == "plank" else ("active" if part == "task" else "")
		scene = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	if part == "task":
		scene.player.position = Vector2(250, 650)
	if part == "plank":
		scene.player.position = Vector2(820, 340)
	if part == "letter":
		# A long placeholder letter, to check that the viewer still fits the screen.
		var layer := CanvasLayer.new()
		layer.layer = 20
		root.add_child(layer)
		var viewer = ItemViewer.new()
		layer.add_child(viewer)
		await process_frame
		var words := "Placeholder text. " .repeat(60)
		viewer.show_item({"type": "letter", "title": "A letter", "text": words})
	await create_timer(4.0).timeout
	var out := OUT_DIR + "/scene1_" + part + ".png"
	root.get_texture().get_image().save_png(out)
	print("saved " + out)
	quit(0)
