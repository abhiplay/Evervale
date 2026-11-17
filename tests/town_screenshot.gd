extends SceneTree
## Saves a screenshot of the town square. Run without --headless.

const OUT := "C:/Users/USER37/AppData/Local/Temp/claude/C--Users-USER37-Downloads-Game/3c3f3f77-722b-4e35-9585-baac277c40f4/scratchpad/evervale_town.png"


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	var town = load("res://scenes/TownSquare.tscn").instantiate()
	root.add_child(town)
	for i in 120:
		await process_frame
	root.get_texture().get_image().save_png(OUT)
	print("saved " + OUT)
	quit(0)
