extends SceneTree
## Checks: one tap on the dialogue box moves on one line, not two. A touch also arrives as an emulated mouse
## click, and both used to move the box on. A real mouse click moves on one line too.
## Run: Godot --headless --path . -s res://tests/dialogue_touch_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var box := SceneDialogue.new()
	root.add_child(box)
	for i in 3:
		await process_frame
	box.say("", ["One.", "Two.", "Three.", "Four."])
	for i in 3:
		await process_frame
	# say() moves the box to the bottom of the screen, so the tap point is worked out after that.
	var centre := box.global_position + box.size / 2.0

	print("One tap, sent as Godot sends it: an emulated mouse click, then the touch")
	var emulated := InputEventMouseButton.new()
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.position = centre
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = centre
	box._gui_input(emulated)
	box._gui_input(touch)
	check(box._text_label.text == "Two.", "one tap moves on one line, not two")

	print("One real mouse click")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = centre
	click.device = 0
	box._gui_input(click)
	check(box._text_label.text == "Three.", "one real mouse click moves on one line")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
