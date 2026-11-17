extends SceneTree
## Saves pictures of the indoor map over the house: the ground floor with the pin on the ground floor, then the pin on the
## upstairs bedroom. Run without --headless: Godot --path . -s res://tests/floor_map_screenshot.gd

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "done"
	save.state.world_state["box_talk_done"] = true
	save.state.cutscenes_viewed.append("CS-003")
	var plan_script = load("res://scripts/floor_plan.gd")
	var map_script = load("res://scripts/ui/floor_map.gd")
	var house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	for i in 3:
		await process_frame
	var layer := CanvasLayer.new()
	layer.layer = 21
	root.add_child(layer)
	var map = map_script.new()
	layer.add_child(map)
	await process_frame
	map.show_plan(plan_script.for_scene("home_floor1"), plan_script.room_id_for_scene("home_floor1"))
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/floor_map_ground.png")
	map.show_plan(plan_script.for_scene("bedroom_upstairs"), plan_script.room_id_for_scene("bedroom_upstairs"))
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/floor_map_bedroom.png")
	print("saved floor map pictures")
	quit(0)
