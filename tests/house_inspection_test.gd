extends SceneTree
## Checks: once Evelyn has left, walking into each area of the house says its line once, and the task is done
## only when all eleven areas (both floors) have been seen. Until then the loose board says it is not time yet.
## Once the task is done, the board opens the box, and what is inside goes into the inventory. Run:
## Godot --headless --path . -s res://tests/house_inspection_test.gd

var failures: Array[String] = []
var _data: Dictionary


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _rect(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])


## A spot in the rectangle where Amelia's whole feet collision fits, so physics does not push her out of the area.
func _free_spot(scene, rect: Rect2) -> Vector2:
	var space = scene.get_world_2d().direct_space_state
	var feet: CollisionShape2D = null
	for child in scene.player.get_children():
		if child is CollisionShape2D:
			feet = child
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = feet.shape
	query.collide_with_bodies = true
	query.exclude = [scene.player.get_rid()]
	for y in range(int(rect.position.y), int(rect.end.y), 8):
		for x in range(int(rect.position.x), int(rect.end.x), 8):
			query.transform = Transform2D(feet.rotation, Vector2(x, y) + feet.position)
			if space.intersect_shape(query, 1).is_empty():
				return Vector2(x, y)
	return Vector2.INF


func _inspection(scene) -> Node:
	for child in scene.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/house_inspection.gd":
			return child
	return null


## Runs the scene for up to a number of frames. Closes any open line, and any item viewer a scene has opened (the player
## would close it), and stops once `until` is true.
func _pump(scene, insp, until: Callable, frames: int) -> bool:
	for i in frames:
		if scene.scene_dialogue.is_open:
			scene.scene_dialogue.advance()
		if root.get_node("/root/HudEvents").screen_open:
			root.get_node("/root/Hud").viewer.close()
		await process_frame
		if until.call():
			return true
	return false


## Walks Amelia into an area and lets its line play out.
func _visit(scene, insp, area: Dictionary) -> void:
	scene.player.position = _free_spot(scene, _rect(area.rect))
	await _pump(scene, insp, func(): return insp._seen().has(area.id), 30)
	await _pump(scene, insp, func(): return not insp._busy and not scene.scene_dialogue.is_open, 300)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/home_events.json"))
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"

	print("Before Evelyn leaves")
	var house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	for i in 3:
		await process_frame
	var insp = _inspection(house)
	check(insp != null, "the house has its look around")
	house.player.position = _free_spot(house, _rect(_data.areas[0].rect))
	await _pump(house, insp, func(): return false, 30)
	check(save.state.world_state.get("house_seen", []).is_empty(), "nothing is said before Evelyn leaves")
	check(not house.scene_dialogue.is_open, "no line plays before Evelyn leaves")

	print("Each area of the ground floor speaks once")
	save.state.world_state["house_task"] = "active"
	var first := true
	for area in _data.areas:
		if area.scene != house.SCENE_ID:
			continue
		check(_free_spot(house, _rect(area.rect)) != Vector2.INF, "%s has a spot to stand" % area.id)
		await _visit(house, insp, area)
		check(save.state.world_state.get("house_seen", []).has(area.id), "%s was seen" % area.id)
		if first:
			check(root.get_node("/root/Hud").objective_panel.objective_description == "1 of 11 places checked.", "the objective counts the areas seen")
			first = false
	check(save.state.world_state.get("house_task", "") == "active", "the task is not done until the upstairs is seen")

	print("Walking back in does not say a line again")
	var seen_before: int = save.state.world_state["house_seen"].size()
	house.player.position = _free_spot(house, _rect(_data.areas[0].rect))
	await _pump(house, insp, func(): return false, 30)
	check(not house.scene_dialogue.is_open, "a seen area stays quiet")
	check(save.state.world_state["house_seen"].size() == seen_before, "a seen area is not counted twice")

	print("The loose board waits until the task is done")
	var plank: Dictionary = _data.plank
	var plank_spot: Vector2 = _free_spot(house, _rect(plank.rect))
	check(plank_spot != Vector2.INF, "the loose board has a spot to stand")
	house.player.position = plank_spot
	await _pump(house, insp, func(): return false, 5)
	check(insp._prompt_on, "standing at the loose board offers to examine it")
	insp.examine_plank()
	await _pump(house, insp, func(): return not insp._busy and not house.scene_dialogue.is_open, 300)
	check(not save.state.world_state.get("house_plank_found", false), "the box stays hidden until the task is done")

	print("Upstairs")
	house.get_parent().remove_child(house)
	house.free()
	var bedroom = load("res://scenes/BedroomUpstairs.tscn").instantiate()
	root.add_child(bedroom)
	for i in 3:
		await process_frame
	var bedroom_insp = _inspection(bedroom)
	check(bedroom_insp != null, "the bedroom has its look around")
	for area in _data.areas:
		if area.scene != bedroom.SCENE_ID:
			continue
		check(_free_spot(bedroom, _rect(area.rect)) != Vector2.INF, "%s has a spot to stand" % area.id)
		await _visit(bedroom, bedroom_insp, area)
		check(save.state.world_state.get("house_seen", []).has(area.id), "%s was seen" % area.id)
	check(save.state.world_state["house_seen"].size() == _data.areas.size(), "all eleven areas have been seen")
	check(save.state.world_state.get("house_task", "") == "done", "every corner has been seen, so the task is done")

	print("The loose board opens the box")
	bedroom.get_parent().remove_child(bedroom)
	bedroom.free()
	house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	for i in 3:
		await process_frame
	insp = _inspection(house)
	house.player.position = _free_spot(house, _rect(plank.rect))
	await _pump(house, insp, func(): return false, 5)
	check(not house.has_node("Marker_plank"), "before the town, the loose board has no mark")
	insp.examine_plank()
	check(house.scene_dialogue.is_open and house.scene_dialogue._text_label.text == plank.later_lines[0], "before the town, Amelia says she will look later")
	await _pump(house, insp, func(): return not insp._busy and not house.scene_dialogue.is_open, 300)
	check(not save.state.world_state.get("house_plank_found", false), "the box stays hidden until she is back from the café")
	# Back from the town and the café (Missions 2 and 3), the board opens.
	save.state.completed_missions = ["M01", "M02", "M03"]
	house.get_parent().remove_child(house)
	house.free()
	house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	for i in 3:
		await process_frame
	insp = _inspection(house)
	check(house.has_node("Marker_plank"), "back from the café, the loose board has its mark")
	house.player.position = _free_spot(house, _rect(plank.rect))
	await _pump(house, insp, func(): return false, 5)
	insp.examine_plank()
	await _pump(house, insp, func(): return insp._popup._stage == 3, 3000)
	check(insp._popup._stage == 3, "after the popup, the choice is offered")
	insp._popup._choose("leave")
	await _pump(house, insp, func(): return not insp._busy and not house.scripted, 200)
	check(save.state.world_state.get("house_plank_found", false), "the box is found once the task is done")
	check(save.state.inventory.get("hidden_box", 0) == 1, "the box goes into the inventory")
	check(not save.state.opened_items.get("hidden_box", false), "leaving the box keeps it closed")
	await _pump(house, insp, func(): return false, 5)
	check(insp._prompt_on, "the board can be examined again to open the box")
	insp.examine_plank()
	await _pump(house, insp, func(): return insp._popup._stage == 3, 3000)
	insp._popup._choose("open")
	await _pump(house, insp, func(): return not insp._busy and not house.scripted, 4000)
	check(save.state.opened_items.get("hidden_box", false), "opening the box records it as opened")
	check(not save.state.inventory.has("hidden_box"), "the box is taken out of the inventory")
	check(save.state.inventory.get("letter_arthur", 0) == 1, "the letter goes into the inventory")
	check(save.state.inventory.get("photo_box", 0) == 1, "the photo goes into the inventory")
	check(not house.scripted, "control comes back after the box")
	check(save.state.world_state.get("box_talk_done", false), "Amelia and Oliver talk about the box, once")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
