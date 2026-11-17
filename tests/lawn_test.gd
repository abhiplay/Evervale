extends SceneTree
## Checks: the player walks freely across the courtyard lawn, and cannot walk off the edge of
## the courtyard. Run on its own: Godot --headless --path . -s res://tests/lawn_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	var scene = load("res://scenes/ExteriorHome.tscn").instantiate()
	root.add_child(scene)
	for i in 3:
		await process_frame

	scene.player.position = Vector2(420, 600)
	for i in 60:
		scene.move_player(Vector2(1, 0.4).normalized(), 1.0 / 60.0)
		await process_frame
	check(scene.player.position.x > 480 and scene.player.position.y > 620, "player walks freely across the lawn")

	print("The courtyard edge")
	scene.player.position = Vector2(300, 700)
	for i in 240:
		scene.move_player(Vector2(-1, 0), 1.0 / 60.0)
		await process_frame
	check(scene.player.position.x > 5, "the courtyard's left edge stops the player")
	scene.player.position = Vector2(600, 880)
	for i in 240:
		scene.move_player(Vector2(0, 1), 1.0 / 60.0)
		await process_frame
	check(scene.player.position.y < 940, "the bottom edge stops the player, except at the gate")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
