extends SceneTree
## Headless checks for the walk cycle. Run: Godot --headless --path . -s res://tests/walk_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var sprite := CharacterSprite.new()
	root.add_child(sprite)
	for i in 3:
		await process_frame

	print("Eight directions")
	var cases := {
		Vector2(1, 0): ["walk_east", false],
		Vector2(1, 1): ["walk_south_east", false],
		Vector2(0, 1): ["walk_south", false],
		Vector2(-1, 1): ["walk_south_west", false],
		Vector2(-1, 0): ["walk_west", false],
		Vector2(-1, -1): ["walk_north_west", false],
		Vector2(0, -1): ["walk_north", false],
		Vector2(1, -1): ["walk_north_east", false],
	}
	for dir in cases:
		sprite.update_movement(dir.normalized())
		var expected: Array = cases[dir]
		check(sprite.animation == expected[0] and sprite.flip_h == expected[1],
			"direction %s plays %s (flip %s)" % [dir, expected[0], expected[1]])

	print("Walking and standing")
	sprite.update_movement(Vector2(0, 1))
	check(sprite.is_playing(), "walking plays the cycle")
	for i in 30:
		await process_frame
	check(sprite.frame > 0 or sprite.frame_progress > 0.0, "the frames advance while walking")
	sprite.update_movement(Vector2.ZERO)
	check(not sprite.is_playing() and sprite.frame == 0, "standing still stops on the first frame")

	print("Frames")
	var frames := sprite.sprite_frames.get_frame_count("walk_south")
	check(frames == 8, "walk_south has its eight frames (found %d)" % frames)

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
