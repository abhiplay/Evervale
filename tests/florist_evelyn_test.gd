extends SceneTree
## Checks: Evelyn is in the florist shop, standing inside it, with her feet collision, so the shop's visitors cannot walk through
## her. Run: Godot --headless --path . -s res://tests/florist_evelyn_test.gd

const EVELYN_ANIMATIONS := "res://data/evelyn_animations.json"
const SPOT := Vector2(1070, 425)

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "done"
	var shop = load("res://scenes/Florist.tscn").instantiate()
	root.add_child(shop)
	current_scene = shop
	for i in 3:
		await process_frame

	var evelyn: Node2D = null
	for node in shop.get_tree().get_nodes_in_group("figures"):
		var walker = node.get_node_or_null("Walker")
		if walker != null and walker.animations_path == EVELYN_ANIMATIONS:
			evelyn = node
	check(evelyn != null, "Evelyn is in the florist shop")
	if evelyn != null:
		check(shop.is_ancestor_of(evelyn), "she stands in the shop itself")
		check(evelyn.position.distance_to(SPOT) < 0.5, "she stands at her spot by the shelves")
		check(SceneWalkers.feet_rect(evelyn).size.x > 0.0, "she has a feet collision")
		var rect := SceneWalkers.feet_rect(evelyn)
		check(rect.position.x > 0.0 and rect.end.x < shop.IMAGE_SIZE.x and rect.position.y > 0.0 and rect.end.y < shop.IMAGE_SIZE.y, "her spot is inside the shop picture")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
