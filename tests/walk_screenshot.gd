extends SceneTree
## Saves a screenshot of the protagonist mid-walk on the home exterior. Run without --headless.

const OUT := "C:/Users/USER37/AppData/Local/Temp/claude/C--Users-USER37-Downloads-Game/3c3f3f77-722b-4e35-9585-baac277c40f4/scratchpad/evervale_walk.png"


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	var exterior = load("res://scenes/ExteriorHome.tscn").instantiate()
	root.add_child(exterior)
	exterior.player.position = Vector2(560, 560)
	for i in 40:
		exterior.move_player(Vector2(1, 0.6).normalized(), 1.0 / 60.0)
		await process_frame
	root.get_texture().get_image().save_png(OUT)
	print("saved %s (animation %s, frame %d)" % [OUT, exterior.sprite.animation, exterior.sprite.frame])
	quit(0)
