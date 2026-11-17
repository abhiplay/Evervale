extends SceneTree
## Plays the bookstore: walks many routes with the real physics and reports every place the
## character stops moving while still far from the next waypoint.

func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.pending_spawn = "from_town"
	var shop = load("res://scenes/Bookstore.tscn").instantiate()
	root.add_child(shop)
	for i in 3:
		await physics_frame
	shop.set_physics_process(false)
	var routes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/routes.json"))
	var stuck := {}
	for route in routes:
		shop.player.position = Vector2(838, 740)
		for p in 2:
			await physics_frame
		for wp in route:
			var target := Vector2(wp[0], wp[1])
			var last: Vector2 = shop.player.position
			var still := 0
			for i in 150:
				var d: Vector2 = target - shop.player.position
				if d.length() < 4.0:
					break
				shop.move_player(d.normalized(), 0.0)
				await physics_frame
				if shop.player.position.distance_to(last) < 0.05:
					still += 1
				else:
					still = 0
				last = shop.player.position
				if still > 20:
					var key := "%d,%d" % [round(shop.player.position.x / 10) * 10, round(shop.player.position.y / 10) * 10]
					stuck[key] = stuck.get(key, 0) + 1
					break
	print("STUCK_SPOTS ", JSON.stringify(stuck))
	quit(0)
