extends SceneTree
## Checks Coco and Charlie and the "Our New Home" talk (CS-003): the pets appear on the ground floor only once Evelyn has
## left, stand on open floor and block nothing, petting one counts as meeting it, the talk waits for the look around and
## both pets, plays once in order, records CS-003 and completes M01, and its data is whole (portraits and emotions).
## Run: Godot --headless --path . -s res://tests/home_pets_test.gd

const HOUSE := "res://scenes/HomeFloor1.tscn"
const MAX_FRAMES := 6000

var failures: Array[String] = []
var save


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	save = root.get_node("/root/SaveSystem")
	var hud = root.get_node("/root/Hud")
	var pets_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/home_pets.json"))
	var talk_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pets_data.our_new_home))

	print("Talk data")
	var emotions_ok := true
	for step in talk_data.steps:
		var folder := "res://assets/portraits/%s/" % str(step.say).to_lower()
		for line in step.lines:
			if not ResourceLoader.exists(folder + line.emotion + ".png"):
				emotions_ok = false
				print("    missing " + folder + line.emotion + ".png")
	check(emotions_ok, "every line of the talk has a portrait for its emotion")
	check(talk_data.steps[-1].say == "Amelia" and str(talk_data.steps[-1].lines[0].text).contains("town"), "the talk ends with Amelia heading into town")

	print("Before Evelyn leaves")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "inside"
	var house = await _open()
	var pets = _pets(house)
	await _frames(5)
	check(pets.pets.is_empty(), "no pets while the opening plays")
	_close(house)

	print("Once Evelyn has left")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "active"
	house = await _open()
	pets = _pets(house)
	await _frames(3)
	check(pets.pets.has("coco") and pets.pets.has("charlie"), "Coco and Charlie are in the house")
	var space = house.get_world_2d().direct_space_state
	for pet in pets_data.pets:
		var query := PhysicsPointQueryParameters2D.new()
		query.position = Vector2(pet.pos[0], pet.pos[1])
		query.collide_with_bodies = true
		query.exclude = [house.player.get_rid()]
		check(space.intersect_point(query).is_empty(), "%s sits on open floor" % pet.name)
		check(pets.pets[pet.id].find_children("*", "CollisionShape2D", true, false).is_empty(), "%s has no collision, so it blocks no path" % pet.name)

	print("Petting a pet")
	house.player.position = Vector2(pets_data.pets[0].pos[0] + 20, pets_data.pets[0].pos[1])
	house._update_nearby()
	check(house.nearby.get("id", "") == "coco", "standing by Coco offers to pet her")
	house._unhandled_input(_interact_event())
	check(house.scene_dialogue.is_open, "petting Coco says her line")
	check(save.state.world_state.get("talked_to", []).has("coco"), "petting Coco counts as meeting her")
	house.scene_dialogue.advance()
	check(not pets.talk_pending(), "no talk while the look around is still on")
	_close(house)

	print("The Our New Home talk")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.world_state["house_task"] = "done"
	save.state.world_state["talked_to"] = ["coco"]
	house = await _open()
	pets = _pets(house)
	await _frames(10)
	check(not house.scripted, "no talk until Charlie is met too")
	check(hud.objective_panel.objective_title == "Say hello to Charlie", "the objective asks to meet Charlie")
	save.state.world_state["talked_to"].append("charlie")
	var started: bool = await _until(func(): return house.scripted, 300)
	check(started, "once both pets are met, the talk starts")
	var lines_seen := 0
	for i in MAX_FRAMES:
		if not house.scripted:
			break
		if house.scene_dialogue.is_open and i % 4 == 0:
			lines_seen += 1
			house.scene_dialogue.advance()
		await process_frame
	check(not house.scripted, "the talk ends")
	check(lines_seen >= talk_data.steps.size(), "every line of the talk is said")
	check(save.state.cutscenes_viewed.has("CS-003"), "the talk is recorded as CS-003")
	check(save.state.completed_missions.has("M01"), "the talk completes M01")
	check(hud.objective_panel.objective_title == "Meet the neighbours", "the objective moves on to the town")
	_close(house)

	print("It plays once")
	house = await _open()
	await _frames(30)
	check(not house.scripted, "walking back into the house does not play the talk again")
	_close(house)

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _interact_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	return event


func _pets(scene) -> Node:
	for child in scene.find_children("*", "", true, false):
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/home_pets.gd":
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
