extends SceneTree
## Saves a screenshot of the home exterior. Run without --headless.

const OUT := "C:/Users/USER37/AppData/Local/Temp/claude/C--Users-USER37-Downloads-Game/3c3f3f77-722b-4e35-9585-baac277c40f4/scratchpad/evervale_exterior.png"


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	var exterior = load("res://scenes/ExteriorHome.tscn").instantiate()
	root.add_child(exterior)
	for i in 90:
		await process_frame
	root.get_texture().get_image().save_png(OUT)
	print("saved " + OUT)
	quit(0)
