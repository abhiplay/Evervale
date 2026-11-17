extends SceneTree
## Saves two pictures of the destination marker: on the world map, marking the Town Square (Meet the neighbours), and in the
## Town Square, marking the café's door (A warm welcome). Run without --headless:
## Godot --path . -s res://tests/destination_marker_screenshot.gd

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	# Meet the neighbours: Amelia has not met Henry yet, so the objective is the Town Square.
	save.state = save.new_game_state()
	save.state.completed_missions = ["M01"]
	save.state.current_location = "home"
	var town_map = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(town_map)
	current_scene = town_map
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/destination_town_on_map.png")
	town_map.get_parent().remove_child(town_map)
	town_map.free()

	# A warm welcome: Henry has been met, so the objective is the café, marked at its door in the Town Square.
	save.state = save.new_game_state()
	save.state.completed_missions = ["M01", "M02"]
	save.state.world_state["talked_to"] = ["henry_collins"]
	save.state.pending_spawn = "from_map"
	var town = load("res://scenes/TownSquare.tscn").instantiate()
	root.add_child(town)
	current_scene = town
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/destination_cafe_door.png")
	print("saved destination pictures")
	quit(0)
