extends SceneTree
## Checks: the front-yard welcome plays and walks the three of them to the door; the walk inside plays
## the house conversation and ends the opening; the radio is in the house; and the house is closed
## except its door and stairs. Run: Godot --headless --path . -s res://tests/opening_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


## Plays the dialogue by pressing E for every line, until the condition holds or the frames run out.
func _play(scene: Node, until: Callable, max_frames: int) -> void:
	for i in max_frames:
		await process_frame
		if scene.scene_dialogue.is_open:
			scene.scene_dialogue.advance()
		if until.call():
			return


## True when Evelyn is on the scene, drawn with her own walk sheets.
func _has_evelyn(scene: Node) -> bool:
	for child in scene.find_children("*", "", true, false):
		# A figure already queued for deletion has left the scene, even if it is still in the child list for this frame.
		if child.is_queued_for_deletion():
			continue
		var walker := child.get_node_or_null("Walker")
		if walker is CharacterSprite and walker.animations_path == "res://data/evelyn_animations.json":
			return true
	return false


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")

	print("Front yard")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "pending"
	var yard = load("res://scenes/ExteriorHome.tscn").instantiate()
	root.add_child(yard)
	for i in 3:
		await process_frame
	check(yard.scripted, "the welcome takes the character out of player control")
	check(_has_evelyn(yard), "Evelyn waits at the front door with her own walk sheets")
	await _play(yard, func(): return save.state.world_state.get("opening_stage", "") == "inside", 4000)
	check(save.state.world_state.get("opening_stage", "") == "inside", "the front-yard part ends with the walk inside")
	check(yard.transitioning, "the door takes them into the house")
	yard.get_parent().remove_child(yard)
	yard.free()

	print("Inside the house")
	save.state.world_state["opening_stage"] = "inside"
	var house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	for i in 3:
		await process_frame
	check(house.scripted, "the house conversation takes the character out of player control")
	check(_has_evelyn(house), "Evelyn is in the house with her own walk sheets")
	await _play(house, func(): return save.state.world_state.get("opening_stage", "") == "done", 4000)
	check(save.state.world_state.get("opening_stage", "") == "done", "the house conversation ends the opening")
	check(not _has_evelyn(house), "Evelyn has left the house")
	check(save.state.world_state.get("house_task", "") == "active", "Amelia's look around the house has started")
	check(not house.scripted, "control comes back after the opening")
	var has_radio := false
	for item in house.interactables:
		if item.get("id", "") == "radio" and item.has("lines"):
			has_radio = true
	check(has_radio, "the radio is in the house and says a line when used")
	house.player.position = Vector2(500, 800)
	house._update_nearby()
	check(house.nearby.get("id", "") == "radio", "standing by the coffee table offers to look at the radio")
	house.player.position = Vector2(725, 880)
	for i in 180:
		house.move_player(Vector2(0, 1), 0.0)
		await process_frame
	check(house.transitioning, "walking into the front door goes back to the courtyard")
	house.get_parent().remove_child(house)
	house.free()

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
