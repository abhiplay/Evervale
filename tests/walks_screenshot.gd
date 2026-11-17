extends SceneTree
## Saves pictures for a visual check: the front door as the family reaches it, and Evelyn standing in the florist shop. Run
## without --headless: Godot --path . -s res://tests/walks_screenshot.gd

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"
const MAX_FRAMES := 3000


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "pending"
	var yard = load("res://scenes/ExteriorHome.tscn").instantiate()
	root.add_child(yard)
	current_scene = yard
	# Advance the talk by itself and wait for the family to be at the door, in the Evelyn line that follows their walk.
	var at_door := false
	for i in MAX_FRAMES:
		await process_frame
		if yard.scene_dialogue.is_open and yard.scene_dialogue._text_label.text.begins_with("Thank you"):
			at_door = true
			break
		if yard.scene_dialogue.is_open:
			yard.scene_dialogue.advance()
	if not at_door:
		print("The family did not reach the door talk")
		quit(1)
		return
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/walks_front_door.png")
	print("saved front door")
	root.remove_child(yard)
	yard.free()

	var shop = load("res://scenes/Florist.tscn").instantiate()
	root.add_child(shop)
	current_scene = shop
	# Amelia stands just below Evelyn, so the camera shows her.
	shop.player.position = Vector2(1000, 520)
	for i in 60:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/walks_florist.png")
	print("saved florist")
	quit(0)
