extends SceneTree
## Checks the people of the town (data/people.json, ScenePeople): Henry and Rose are drawn in the Town Square, Henry
## leaves the square for his café once First Steps is done, every person stands on open floor and is about Amelia's
## height, and Evelyn's welcome at the florist is said with her portrait, counts as meeting her and keeps her secret.
## Run: Godot --headless --path . -s res://tests/people_test.gd

var failures: Array[String] = []
var save


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	save = root.get_node("/root/SaveSystem")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/people.json"))

	print("Data")
	var ids_ok := true
	for person in data.people:
		if not root.get_node("/root/GameData").characters.has(person.id):
			ids_ok = false
	check(ids_ok, "every person is a character from characters.json")
	var evelyn_text := ""
	for person in data.people:
		if person.id == "evelyn_hale":
			evelyn_text = JSON.stringify(person.lines).to_lower()
	var guarded := true
	for word in ["radio", "arthur", "father", "dad", "box"]:
		if evelyn_text.contains(word):
			guarded = false
	check(guarded, "Evelyn's welcome keeps her secret (no radio, Arthur or father)")

	print("Town Square before First Steps")
	_new_state(["M01"])
	save.state.pending_spawn = "from_map"
	var town = await _open("res://scenes/TownSquare.tscn")
	check((town.find_child("Person_henry_collins", true, false) != null) and (town.find_child("Person_rose_west", true, false) != null), "Henry and Rose are drawn in the square")
	_check_on_floor(town)
	_check_height(town, "Person_rose_west")
	var ids: Array = []
	for item in town.interactables:
		ids.append(item.id)
	check(ids.has("henry_collins") and ids.has("rose_west") and ids.has("noticeboard"), "Henry, Rose and the noticeboard can be talked to")
	_close(town)

	print("Town Square after First Steps")
	_new_state(["M01", "M02"])
	town = await _open("res://scenes/TownSquare.tscn")
	check(not (town.find_child("Person_henry_collins", true, false) != null), "Henry has gone back to his café")
	check((town.find_child("Person_rose_west", true, false) != null), "Rose is still at the florist's door")
	_close(town)

	print("Café")
	var cafe = await _open("res://scenes/Cafe.tscn")
	check((cafe.find_child("Person_henry_collins", true, false) != null), "Henry is in his café")
	_check_on_floor(cafe)
	_check_height(cafe, "Person_henry_collins")
	_close(cafe)
	_new_state(["M01"])
	cafe = await _open("res://scenes/Cafe.tscn")
	check(not (cafe.find_child("Person_henry_collins", true, false) != null), "before First Steps, Henry is not in the café yet")
	_close(cafe)

	print("Florist")
	_new_state(["M01", "M02", "M03"])
	var shop = await _open("res://scenes/Florist.tscn")
	shop.player.position = Vector2(1070, 485)
	shop._update_nearby()
	check(shop.nearby.get("id", "") == "evelyn_hale", "standing by Evelyn offers to talk")
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	shop._unhandled_input(event)
	check(shop.scene_dialogue.is_open and shop.scene_dialogue._speaker_label.text == "Evelyn", "Evelyn speaks with her name and portrait")
	check(save.state.world_state.get("talked_to", []).has("evelyn_hale"), "talking to Evelyn counts as meeting her")
	_close(shop)

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _check_on_floor(scene) -> void:
	var space = scene.get_world_2d().direct_space_state
	for child in scene.find_children("*", "", true, false):
		if not child.name.begins_with("Person_"):
			continue
		var query := PhysicsPointQueryParameters2D.new()
		query.position = child.position
		query.collide_with_bodies = true
		query.exclude = [scene.player.get_rid()]
		check(space.intersect_point(query).is_empty(), "%s stands on open floor" % child.name.trim_prefix("Person_"))


func _check_height(scene, node_name: String) -> void:
	var figure: Node2D = scene.find_child(node_name, true, false)
	var height: float = 78.0 * figure.scale.y
	var amelia: float = 667.0 * scene.PLAYER_SCALE
	check(height > amelia * 0.8 and height < amelia * 1.1, "%s is about Amelia's height (%d vs %d)" % [node_name.trim_prefix("Person_"), height, amelia])


func _new_state(completed: Array) -> void:
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	save.state.completed_missions = completed.duplicate()


func _open(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	for i in 3:
		await process_frame
	return scene


func _close(scene: Node) -> void:
	scene.get_parent().remove_child(scene)
	scene.free()
