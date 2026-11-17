extends SceneTree
## Checks: the Town sign in the Town Square is only a sign. Standing by it offers no entry and
## no message. Run: Godot --headless --path . -s res://tests/town_entry_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	var town = load("res://scenes/TownSquare.tscn").instantiate()
	root.add_child(town)
	for i in 3:
		await process_frame
	town.player.position = Vector2(1527, 560)
	town._update_nearby()
	check(town.nearby.get("id", "") != "town_entry", "the Town sign offers no entry")
	check(not town.dialogue_open, "the Town sign opens no message")
	town.get_parent().remove_child(town)
	town.free()

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
