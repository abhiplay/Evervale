extends SceneTree
## Checks: the video fades in from black and out to black with a long, eased fade, so its loop joins without a cut; the ambient
## sound is quiet; the dust motes and the floor mist are there and stay on the picture; and the menu is still there. Frame
## limits only. Run: Godot --headless --path . -s res://tests/start_screen_motion_test.gd

## The script is loaded by path, not named, because a headless test cannot compile a script that uses the save autoload.
const SCREEN_SCRIPT := "res://scripts/start_screen.gd"
const SCREEN_SCENE := "res://scenes/StartScreen.tscn"

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var screen_script = load(SCREEN_SCRIPT)
	var constants: Dictionary = screen_script.get_script_constant_map()

	print("The fade")
	var length := 8.0
	var fade: float = constants["FADE_SECONDS"]
	check(screen_script.fade_for(0.0, length) == 1.0, "the video starts fully black")
	check(is_equal_approx(screen_script.fade_for(fade * 0.5, length), 0.5), "halfway through its fade-in the video is half black")
	check(screen_script.fade_for(length * 0.5, length) == 0.0, "the middle of the video is not faded")
	check(is_equal_approx(screen_script.fade_for(length - fade * 0.5, length), 0.5), "halfway through its fade-out the video is half black")
	check(screen_script.fade_for(length, length) == 1.0, "the video ends fully black")
	check(screen_script.fade_for(fade * 0.25, length) > screen_script.fade_for(fade * 0.5, length) and screen_script.fade_for(fade * 0.25, length) < 1.0, "the fade-in falls steadily, not in one cut")
	check(screen_script.fade_for(length - 0.05, length) > 0.9 and screen_script.fade_for(0.05, length) > 0.9, "just before the loop and just after it the video is nearly black, so the loop joins without a cut")
	check(screen_script.fade_for(1.0, 0.0) == 0.0, "with no length known, nothing is faded")

	print("The ambient sound")
	var screen = load(SCREEN_SCENE).instantiate()
	root.add_child(screen)
	current_scene = screen
	for i in 3:
		await process_frame
	check(screen._video.get_stream_length() > 0.0, "the video's length is known to the fade (%.2f s)" % screen._video.get_stream_length())
	var volume: float = constants["AMBIENT_VOLUME"]
	check(is_equal_approx(screen._ambient.volume_linear, volume), "the ambient sound plays at its set volume (%.2f)" % volume)
	check(volume <= 0.25, "the ambient sound is quiet (at most a quarter of full volume)")
	check(screen._ambient.stream.loop, "the ambient sound loops")

	print("The dust motes and the mist")
	var count: int = constants["PARTICLE_COUNT"]
	check(screen._motes.size() == count, "there are %d dust motes" % count)
	var bands: int = constants["FOG_BANDS"]
	check(screen._fog_blobs.size() == bands, "there are %d mist bands" % bands)
	var mist_on_floor := true
	for blob in screen._fog_blobs:
		if blob.y < 0.75:
			mist_on_floor = false
	check(mist_on_floor, "every mist band lies along the floor of the picture")
	for i in 240:
		await process_frame
	var all_inside := true
	for mote in screen._motes:
		if mote.pos.x < 0.0 or mote.pos.x > 1.0 or mote.pos.y < -0.05 or mote.pos.y > 1.1:
			all_inside = false
	check(all_inside, "after a few seconds every mote is still over the picture")

	print("The logo")
	screen._layout()
	var logo: Rect2 = screen._logo_rect
	check(screen._logo_texture != null, "the logo is on the title screen")
	check(logo.position.y >= 16.0, "the logo keeps room above it (%.0f px from the top)" % logo.position.y)
	check(absf((logo.position.x + logo.size.x / 2.0) - screen.size.x / 2.0) < 1.0, "the logo is centred across the top")
	check(logo.end.y < screen.size.y * 0.5, "the logo stays in the top half of the screen")
	check(screen.get_children().all(func(c): return not (c is TextureRect)), "the logo is drawn by the screen, so the fog and dust can pass in front of it")

	print("The menu")
	var buttons: Dictionary = constants["BUTTONS"]
	check(screen._buttons.size() == buttons.size(), "all %d menu buttons are still there" % buttons.size())

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
