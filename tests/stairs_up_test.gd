extends SceneTree
## Checks: the stairs on the ground floor lead up to the bedroom, the bedroom's stairs lead back
## down, and the bedroom's floor can be walked. Run:
## Godot --headless --path . -s res://tests/stairs_up_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.pending_spawn = "from_exterior"
	var floor1 = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(floor1)
	for i in 3:
		await process_frame
	floor1.set_physics_process(false)
	floor1.player.position = Vector2(975, 620)
	floor1._physics_process(0.0)
	check(not floor1.transitioning, "standing at the foot of the stairs does not go up by itself")
	floor1.player.position = Vector2(1040, 520)  # the foot of the stairs in the first-visit picture
	floor1._physics_process(0.0)
	check(floor1.transitioning, "walking onto the stairs goes up to the bedroom")
	check(save.state.pending_spawn == "from_stairs", "the bedroom is entered at its stairs")
	floor1.get_parent().remove_child(floor1)
	floor1.free()
	save.state.pending_spawn = "from_stairs"

	var bedroom = load("res://scenes/BedroomUpstairs.tscn").instantiate()
	root.add_child(bedroom)
	for i in 3:
		await process_frame
	bedroom.set_physics_process(false)
	check(bedroom.player.position.is_equal_approx(Vector2(300, 780)), "arriving from the stairs appears by the stairs down")
	bedroom.player.position = Vector2(300, 780)
	for i in 60:
		bedroom.move_player(Vector2(0.5, -0.5).normalized(), 0.0)
		await process_frame
	check(bedroom.player.position.y < 780 and bedroom.player.position.x > 300, "the bedroom floor can be walked")
	bedroom.player.position = Vector2(285, 990)
	bedroom._physics_process(0.0)
	check(bedroom.transitioning, "walking to the stairs down goes back to the ground floor")
	bedroom.get_parent().remove_child(bedroom)
	bedroom.free()

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
