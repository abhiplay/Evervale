extends SceneTree
## Checks: in the house, Evelyn is drawn the same height as Amelia, and Oliver a little taller than Amelia.
## Run: Godot --headless --path . -s res://tests/character_size_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


## The height a figure takes up on screen: its drawn pixels, times its scale.
func _drawn_height(sprite: CharacterSprite) -> float:
	var frame: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	var drawn := frame.get_image().get_used_rect()
	return drawn.size.y * sprite.scale.y


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	var house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	# Loaded at run time, because the opening script uses the SaveSystem autoload.
	var opening_script: GDScript = load("res://scripts/opening_sequence.gd")
	var oliver_size: float = opening_script.get_script_constant_map()["OLIVER_SIZE"]
	var opening = opening_script.new()
	var evelyn: Node2D = opening._walker(house, "res://data/evelyn_animations.json")
	var oliver: Node2D = opening._walker(house, "res://data/oliver_animations.json", oliver_size)
	root.add_child(evelyn)
	root.add_child(oliver)
	for i in 3:
		await process_frame

	print("Heights in the house")
	var amelia_h := _drawn_height(house.sprite)
	var evelyn_h := _drawn_height(evelyn.get_node("Walker"))
	var oliver_h := _drawn_height(oliver.get_node("Walker"))
	print("  Amelia %.1f px (scale %.3f), Evelyn %.1f px (scale %.3f), Oliver %.1f px (scale %.3f)" % [
		amelia_h, house.sprite.scale.y, evelyn_h, evelyn.get_node("Walker").scale.y, oliver_h, oliver.get_node("Walker").scale.y])
	check(absf(evelyn_h - amelia_h) <= amelia_h * 0.02, "Evelyn is the same height as Amelia")
	var oliver_ratio := oliver_h / amelia_h
	check(oliver_ratio >= 1.05 and oliver_ratio <= 1.20, "Oliver is a little taller than Amelia, 5 to 20 percent")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
