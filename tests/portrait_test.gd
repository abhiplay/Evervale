extends SceneTree
## Checks: Amelia's lines show her portrait with the expression each line asks for, her mouth moves
## while a line is new, and a speaker without portrait art (Evelyn) gets no portrait.
## Run: Godot --headless --path . -s res://tests/portrait_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var box = SceneDialogue.new()
	root.add_child(box)
	for i in 3:
		await process_frame

	print("Amelia")
	box.say("Amelia", [{"text": "Thank you, Evelyn.", "emotion": "smile"}, "Second line."])
	check(box._portrait.visible, "Amelia's portrait shows while she speaks")
	check(box._portrait.texture != null, "the portrait has an image")
	check(box._portrait.texture.resource_path.get_file() == "talk_02.png", "her talking expression shows when the line first appears")
	for i in 1500:
		await process_frame
		if box._talk_left <= 0.0:
			break
	check(box._portrait.texture.resource_path.get_file() == "smile.png", "the expression stays on after the mouth stops")
	box.advance()
	check(box._text_label.text == "Second line.", "the next line replaces the first")
	box.advance()
	check(not box.is_open, "the box closes after its last line")
	check(not box._portrait.visible, "the portrait hides when the box closes")

	print("Evelyn and a speaker with no art")
	box.say("Evelyn", ["Hello."])
	check(box._portrait.visible, "Evelyn has a portrait")
	box.advance()
	box.say("Charlie", ["Woof."])
	check(box._speaker_label.text == "Charlie", "the speaker's name shows")
	check(not box._portrait.visible, "a speaker with no portrait art shows no portrait")
	box.advance()

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
