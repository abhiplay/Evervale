extends SceneTree
## Saves a picture of the New Discovery popup over the house, for a visual check. Run without --headless:
## Godot --path . -s res://tests/popup_screenshot.gd

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "done"
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	await create_timer(1.0).timeout
	var inspection = null
	for child in house.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/house_inspection.gd":
			inspection = child
	# The same item as data/items.json, so the picture matches what the game shows.
	inspection._popup.show_discovery({
		"name": "Hidden Box",
		"description": "A strange, handcrafted box concealed beneath the floorboards.",
		"icon": "res://assets/ui/hud/Icons/hidden_box.png",
	})
	await create_timer(2.4).timeout
	var out := OUT_DIR + "/popup_choice.png"
	root.get_texture().get_image().save_png(out)
	print("saved " + out)
	quit(0)
