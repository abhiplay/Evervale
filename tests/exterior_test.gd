extends SceneTree
## Headless checks for the home exterior: the player cannot enter any solid object in the scene (its own collision shapes),
## can reach the front door and the gate, and walks on the lawn.
## Run: Godot --headless --path . -s res://tests/exterior_test.gd

var failures: Array[String] = []
var solids: Array[Rect2] = []


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
	for i in 10:
		await process_frame
	solids = _scene_solids(scene)

	print("Solid objects")
	var blocked := 0
	var tested := 0
	for solid in solids:
		var target := solid.get_center()
		var start := _free_start(solid, scene)
		if start == Vector2.INF:
			print("  skipped, no free start beside it: %s" % [solid])
			continue
		tested += 1
		scene.player.position = start
		for i in 150:
			scene.move_player((target - scene.player.position).normalized(), 1.0 / 60.0)
			await process_frame
		if not _body_overlaps_any(scene.player.position):
			blocked += 1
		else:
			print("  ... penetrated at %s" % [scene.player.position])
	check(tested > 0 and blocked == tested, "player never enters a solid object (%d of %d pushes stopped)" % [blocked, tested])


	print("Front door and gate")
	scene.player.position = Vector2(748, 432)
	scene._update_nearby()
	check(not scene.nearby.is_empty() and scene.nearby.id == "enter", "the front door prompt appears from the steps")
	scene.player.position = Vector2(748, 842)
	check(scene.GATE_RECT.has_point(scene.player.position), "the gateway is on the path")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


## A start point just outside the solid, on the side that is free of other solids.
func _free_start(solid: Rect2, _scene) -> Vector2:
	var c := solid.get_center()
	var reach := maxf(solid.size.x, solid.size.y) / 2.0 + 40.0
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var p: Vector2 = c + dir * reach
		if not _body_overlaps_any(p) and p.x > 0 and p.y > 0 and p.x < 1629 and p.y < 965:
			return p
	return Vector2.INF


## The solids the player can bump into: each rectangle collision shape under a body in the scene, in world coordinates.
## Reading the scene rather than the Tiled map means the test checks the shapes the game uses after editor changes.
func _scene_solids(scene: Node) -> Array[Rect2]:
	var found: Array[Rect2] = []
	for body in scene.get_children():
		if not (body is StaticBody2D):
			continue
		for child in body.get_children():
			if child is CollisionShape2D and (child.shape is RectangleShape2D):
				var box_size: Vector2 = child.shape.size
				var centre: Vector2 = body.position + child.position
				found.append(Rect2(centre - box_size / 2.0, box_size))
	return found


func _body_overlaps_any(feet: Vector2) -> bool:
	# The player's collision box: 18 wide, 12 tall, ending at the feet.
	var body := Rect2(feet.x - 9, feet.y - 12, 18, 12).grow(-0.5)
	for solid in solids:
		if body.intersects(solid):
			return true
	return false
