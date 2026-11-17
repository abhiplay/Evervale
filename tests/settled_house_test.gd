extends SceneTree
## Checks the settled ground floor: before the box talk is over the floor is bare (the loose board and the baked radio);
## after it, the furnished picture and its solids replace them, the pets move to their settled spots, and the radio has
## moved upstairs to the bedroom wall (see radio_bedroom_test). The box talk ends with a fade into the settled house, and Amelia is moved off the
## dining table that now stands over the loose board. Run: Godot --headless --path . -s res://tests/settled_house_test.gd

const HOUSE := "res://scenes/HomeFloor1.tscn"
const MAX_FRAMES := 8000

var failures: Array[String] = []
var save


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	save = root.get_node("/root/SaveSystem")
	var settled_picture: Texture2D = load("res://assets/environments/home_floor1.webp")
	var bare_picture: Texture2D = load("res://assets/environments/home_floor1_v2.webp")
	var solids: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/home_floor1_settled_collision.json"))
	var pets_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/home_pets.json"))

	print("Before the box talk")
	_state({"opening_stage": "done", "house_task": "done"})
	save.state.completed_missions = ["M01", "M02", "M03"]
	var house = await _open()
	check(not house.settled and house.get_node("Sprite_0").texture == bare_picture, "the floor is bare, with the loose board")
	check(not house.has_node("RadioProp"), "the radio is part of the bare picture, so there is no prop")
	check(_bodies(house) == 1 and house.has_node("WalkMaskSolids"), "the bare floor's solids come from its walk mask")
	_close(house)

	print("A house loaded after the box talk")
	_state({"opening_stage": "done", "house_task": "done", "house_plank_found": true, "box_talk_done": true})
	save.state.world_state["talked_to"] = ["coco", "charlie"]
	save.state.cutscenes_viewed.append("CS-003")
	house = await _open()
	await _frames(3)
	check(house.settled and house.get_node("Sprite_0").texture == settled_picture, "the furnished picture shows")
	check(_bodies(house) == 1 and house.has_node("WalkMaskSolids"), "the settled floor's solids come from its walk mask")
	check(_solid_at(house, Vector2(450, 850)), "the pouf is solid")
	check(not _solid_at(house, Vector2(414, 818)), "the pouf's round edge leaves its corner walkable")
	check(not house.has_node("RadioProp"), "the radio has moved upstairs, so the coffee table is bare")
	var downstairs_radio := false
	for item in house.interactables:
		if item.get("id", "") == "radio":
			downstairs_radio = true
	check(not downstairs_radio, "the radio can no longer be looked at on the ground floor")
	var pets = _pets(house)
	for pet in pets_data.pets:
		check(pets.pets[pet.id].position == Vector2(pet.settled_pos[0], pet.settled_pos[1]), "%s is at its settled spot" % pet.name)
	_close(house)

	print("The box talk ends in the settled house")
	_state({"opening_stage": "done", "house_task": "done", "house_plank_found": true, "box_talk_done": false})
	save.state.world_state["talked_to"] = ["coco", "charlie"]
	save.state.cutscenes_viewed.append("CS-003")
	save.state.completed_missions = ["M01", "M02", "M03"]
	save.state.opened_items["hidden_box"] = true
	house = await _open()
	var insp = _inspection(house)
	var events: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/home_events.json"))
	var board := Rect2(events.plank.rect[0], events.plank.rect[1], events.plank.rect[2], events.plank.rect[3])
	house.player.position = board.get_center()
	await _until(func(): return insp.box_talk != null, 600)
	for i in MAX_FRAMES:
		if save.state.world_state.get("box_talk_done", false) and not insp._busy:
			break
		if root.get_node("/root/HudEvents").screen_open and i % 20 == 0:
			root.get_node("/root/Hud").viewer.close()
		elif house.scene_dialogue.is_open and i % 4 == 0:
			house.scene_dialogue.advance()
		await process_frame
	check(save.state.world_state.get("box_talk_done", false), "the box talk ends")
	check(house.settled, "and the house is settled")
	check(not house.scripted, "Amelia can move again after the fade")
	var in_furniture := false
	for rect in house.settled_solids():
		if rect.has_point(house.player.position):
			in_furniture = true
	check(not in_furniture, "Amelia is not left standing inside the new furniture")
	_close(house)

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _state(flags: Dictionary) -> void:
	save.state = save.new_game_state()
	for key in flags:
		save.state.world_state[key] = flags[key]


func _bodies(scene) -> int:
	var count := 0
	for child in scene.get_children():
		if child is StaticBody2D and not child.is_in_group("figures") and not child.is_queued_for_deletion():
			count += 1
	return count


func _solid_at(scene, point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_bodies = true
	query.exclude = [scene.player.get_rid()]
	return not scene.get_world_2d().direct_space_state.intersect_point(query).is_empty()


func _pets(scene) -> Node:
	for child in scene.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/home_pets.gd":
			return child
	return null


func _inspection(scene) -> Node:
	for child in scene.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/house_inspection.gd":
			return child
	return null


func _open() -> Node:
	var scene: Node = load(HOUSE).instantiate()
	root.add_child(scene)
	await _frames(3)
	return scene


func _close(scene: Node) -> void:
	scene.get_parent().remove_child(scene)
	scene.free()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(condition: Callable, frames: int) -> bool:
	for i in frames:
		if condition.call():
			return true
		await process_frame
	return condition.call()
