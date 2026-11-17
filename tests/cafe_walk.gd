extends SceneTree
## Walks the café with real physics along routes and logs the trail and any stuck spot.
const ROUTES := [
	[[835, 740], [790, 600], [790, 470], [790, 335]],
	[[835, 740], [835, 600], [835, 508], [1030, 508], [1100, 470], [1100, 400]],
	[[835, 740], [790, 520], [560, 508], [560, 470], [560, 330], [560, 290], [500, 290]],
	[[835, 740], [835, 600], [835, 508], [1000, 508], [1280, 500], [1280, 420]],
	[[835, 740], [835, 600], [835, 508], [1030, 508], [1030, 620], [1280, 620], [1280, 660], [1000, 678], [835, 678], [835, 700]],
	[[835, 740], [760, 686], [560, 684], [560, 620], [400, 620], [400, 470], [370, 470]],
	[[835, 740], [835, 600], [835, 508], [1180, 508], [1180, 400]],
]

func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.pending_spawn = "from_town"
	var c = load("res://scenes/Cafe.tscn").instantiate()
	root.add_child(c)
	for i in 5:
		await physics_frame
	c.set_physics_process(false)
	var log := {"trails": [], "stuck": []}
	for r in ROUTES:
		var trail := []
		c.player.position = Vector2(r[0][0], r[0][1])
		for i in 4:
			await physics_frame
		for k in range(1, r.size()):
			var target := Vector2(r[k][0], r[k][1])
			var still := 0
			var last: Vector2 = c.player.position
			for i in 900:
				var d: Vector2 = target - c.player.position
				if d.length() < 4.0:
					break
				c.move_player(d.normalized(), 0.0)
				await physics_frame
				trail.append([c.player.position.x, c.player.position.y])
				if c.player.position.distance_to(last) < 0.05:
					still += 1
				else:
					still = 0
				last = c.player.position
				if still > 30:
					log.stuck.append([c.player.position.x, c.player.position.y, target.x, target.y])
					break
		log.trails.append(trail)
	var f := FileAccess.open("res://tests/cafe_walk.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(log))
	f.close()
	print("WALK_DONE stuck=", log.stuck.size())
	quit(0)
