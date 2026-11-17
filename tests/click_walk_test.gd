extends SceneTree
## Checks click to walk (ClickWalker): a click on something usable walks Amelia round the furniture to it and uses it
## (the radio on the upstairs bedroom wall once settled, Henry in the Town Square), a plain click walks to the spot, the keys cancel a walk at
## once, a click inside a solid walks to the nearest free floor, and a click on a place on the town map walks to its
## entrance and goes in. Frame limits only. Run: Godot --headless --path . -s res://tests/click_walk_test.gd

const MAX_FRAMES := 900

var failures: Array[String] = []
var save


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	save = root.get_node("/root/SaveSystem")

	print("Settled house: walk round the furniture to the radio on the bedroom wall and look at it")
	_settled_state()
	var house = await _open("res://scenes/BedroomUpstairs.tscn")
	house.player.position = Vector2(300, 780)
	var target: Dictionary = house.click_target(Vector2(385, 335))
	check(target.interact and target.pos == Vector2(385, 375), "a click on the radio targets the radio, to use it")
	check(house.click_walker.go_to(target.pos, target.interact), "there is a way to the radio")
	check(house.click_walker.visible, "a ring marks where she is going")
	var arrived: bool = await _until(func(): return not house.click_walker.is_walking(), MAX_FRAMES)
	check(arrived, "she gets there")
	await _until(func(): return house.scene_dialogue.is_open, 30)
	check(house.scene_dialogue.is_open and house.scene_dialogue._text_label.text.contains("radio"), "and looks at the radio when she arrives")
	check(not house.click_walker.visible, "the ring goes when she arrives")
	house.scene_dialogue.advance()
	await _frames(3)

	print("A plain click walks to the spot")
	var spot := Vector2(1100, 760)
	target = house.click_target(spot)
	check(not target.interact, "a click on bare floor is just a walk")
	house.click_walker.go_to(target.pos, target.interact)
	arrived = await _until(func(): return not house.click_walker.is_walking(), MAX_FRAMES)
	check(arrived and house.player.position.distance_to(spot) < 12.0, "she walks into the kitchen, to the spot clicked")

	print("The keys take over")
	house.click_walker.go_to(Vector2(725, 880))
	await _frames(5)
	Input.action_press("move_left")
	await physics_frame
	await physics_frame
	Input.action_release("move_left")
	check(not house.click_walker.is_walking(), "pressing a key cancels the walk")

	print("A click inside furniture")
	house.click_walker.go_to(Vector2(453, 854))
	arrived = await _until(func(): return not house.click_walker.is_walking(), MAX_FRAMES)
	check(arrived and house.player.position.distance_to(Vector2(453, 854)) < 80.0, "a click on the pouf walks to the floor beside it")
	_close(house)

	print("Town Square: click Henry to walk over and talk")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.completed_missions = ["M01"]
	save.state.pending_spawn = "from_map"
	var town = await _open("res://scenes/TownSquare.tscn")
	target = town.click_target(Vector2(765, 540))
	check(target.interact, "a click on Henry targets Henry")
	town.click_walker.go_to(target.pos, target.interact)
	await _until(func(): return town.dialogue_open, MAX_FRAMES)
	check(town.dialogue_open, "she walks over and talks to him")
	check(save.state.completed_missions.has("M02"), "and meeting him completes First Steps")
	_close(town)

	print("Town map: click a place to walk to its entrance and go in")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.current_location = "town_square"
	var map = await _open("res://scenes/WorldMap.tscn")
	await _frames(5)
	var home: Dictionary = {}
	for zone in map.zones:
		if zone.id == "home":
			home = zone
	var building := Vector2(home.zone[0] + home.zone[2] / 2.0, home.zone[1] - 60.0)
	check(map.place_at(building).get("id", "") == "home", "a click on the house picks Home")
	var centre: Vector2 = map._zone_centre(home)
	check(map.click_walker.go_to(centre, false, Vector2(centre.x, home.zone[1] + home.zone[3] + 14.0)), "there is a way to Home's entrance")
	var went_in: bool = await _until(func(): return map.transitioning, 2400)
	check(went_in, "she walks there and goes in")
	_close(map)

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _settled_state() -> void:
	save.state = save.new_game_state()
	var world: Dictionary = save.state.world_state
	world["opening_stage"] = "done"
	world["house_task"] = "done"
	world["talked_to"] = ["coco", "charlie", "henry_collins"]
	world["house_plank_found"] = true
	world["box_talk_done"] = true
	world["radio_217_heard"] = true
	save.state.opened_items["hidden_box"] = true
	save.state.cutscenes_viewed = ["CS-003"]
	save.state.completed_missions = ["M01", "M02", "M03", "M04", "M05"]


func _open(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(3)
	return scene


func _close(scene: Node) -> void:
	if scene.get_parent():
		scene.get_parent().remove_child(scene)
	current_scene = null
	scene.free()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _until(condition: Callable, frames: int) -> bool:
	for i in frames:
		if condition.call():
			return true
		await physics_frame
	return condition.call()
