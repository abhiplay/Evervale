extends SceneTree
## Checks: the hidden path from the cave to the temple stairs stays shut until the flag is set,
## and once it is set the cave walks into the temple and the stairs lead back down.
## Run: Godot --headless --path . -s res://tests/stairs_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func walk_to(node, target: Vector2) -> void:
	node.player.position = target
	node._physics_process(0.0)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.pending_spawn = "from_entrance"
	var cave = load("res://scenes/CaveInterior.tscn").instantiate()
	root.add_child(cave)
	for i in 3:
		await process_frame
	cave.set_physics_process(false)

	print("Before the event")
	walk_to(cave, Vector2(330, 715))
	check(not cave.transitioning, "the hidden path does not open before the event")
	cave.get_parent().remove_child(cave)
	cave.free()

	print("After the event")
	save.state.world_state["temple_stairs_open"] = true
	cave = load("res://scenes/CaveInterior.tscn").instantiate()
	root.add_child(cave)
	for i in 3:
		await process_frame
	cave.set_physics_process(false)
	walk_to(cave, Vector2(330, 715))
	check(cave.transitioning, "after the event, walking up the hidden path goes to the temple")
	cave.get_parent().remove_child(cave)
	cave.free()
	save.state.world_state.erase("temple_stairs_open")

	print("Temple stairs")
	save.state.world_state["temple_stairs_open"] = true
	var temple = load("res://scenes/TempleInterior.tscn").instantiate()
	root.add_child(temple)
	for i in 3:
		await process_frame
	var ids := []
	for opening in temple.exits:
		ids.append(opening.id)
	check("temple_stairs" in ids, "the temple has its stairs once the flag is set")
	temple.get_parent().remove_child(temple)
	temple.free()
	save.state.world_state.erase("temple_stairs_open")
	temple = load("res://scenes/TempleInterior.tscn").instantiate()
	root.add_child(temple)
	for i in 3:
		await process_frame
	ids = []
	for opening in temple.exits:
		ids.append(opening.id)
	check(not ("temple_stairs" in ids), "the stairs are not in the temple before the event")
	temple.get_parent().remove_child(temple)
	temple.free()

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
