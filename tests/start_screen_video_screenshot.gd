extends SceneTree
## Saves two pictures of the title screen a few seconds apart, and prints whether its video is playing and moving, and whether
## its ambient sound is playing and looping. Run without --headless: Godot --path . -s res://tests/start_screen_video_screenshot.gd

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"


func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var screen = load("res://scenes/StartScreen.tscn").instantiate()
	root.add_child(screen)
	current_scene = screen
	for i in 60:
		await process_frame
	var first_position: float = screen._video.stream_position
	root.get_texture().get_image().save_png(OUT_DIR + "/start_video_1.png")
	for i in 180:
		await process_frame
	var second_position: float = screen._video.stream_position
	root.get_texture().get_image().save_png(OUT_DIR + "/start_video_2.png")
	print("video playing=%s position %.2f -> %.2f (moving=%s)" % [screen._video.is_playing(), first_position, second_position, second_position > first_position])
	print("video loop=%s" % screen._video.loop)
	print("ambient playing=%s loop=%s" % [screen._ambient.playing, screen._ambient.stream.loop])
	quit(0)
