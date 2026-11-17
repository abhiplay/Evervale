extends SceneTree
## Checks: Evelyn's walk has all eight directions, each with eight frames, and her sprite plays the
## right direction. Run: Godot --headless --path . -s res://tests/evelyn_walk_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var sprite := CharacterSprite.new()
	sprite.animations_path = "res://data/evelyn_animations.json"
	root.add_child(sprite)
	for i in 3:
		await process_frame

	print("Evelyn")
	var names := ["walk_south", "walk_north", "walk_east", "walk_south_east", "walk_south_west",
		"walk_north_east", "walk_north_west", "walk_west"]
	for n in names:
		check(sprite.sprite_frames.has_animation(n), "%s exists" % n)
		if sprite.sprite_frames.has_animation(n):
			check(sprite.sprite_frames.get_frame_count(n) == 8, "%s has eight frames" % n)
	sprite.update_movement(Vector2(0, 1))
	check(sprite.animation == "walk_south", "walking down plays walk_south")
	sprite.update_movement(Vector2(-1, -1).normalized())
	check(sprite.animation == "walk_north_west", "walking up-left plays walk_north_west")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
