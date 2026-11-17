extends SceneTree
## Checks: a line too long for the text box is split into pages that each fit it in two lines, and joined back the pages give
## every word of the line in order. The quick slots hide while a talk is on screen, and the box says when it opens and closes.
## Frame limits only. Run:
## Godot --headless --path . -s res://tests/dialogue_pages_test.gd

const BOX_TALK := "res://data/box_talk.json"
const HOME_EVENTS := "res://data/home_events.json"
## The opening sequence's lines, which are written in its script rather than in data.
const OPENING_LINES := [
	"Welcome to Evervale! You must be Amelia and Oliver.",
	"This is your house now.",
	"Thank you, Evelyn. It's lovely to meet you.",
	"We can't wait to see inside.",
	"Then come in. I'll show you around.",
	"This is even better inside. Look at the light through those windows.",
	"There's plenty of room to draw, and the kitchen is lovely.",
	"Oh, there's a radio on the table. Evelyn, whose is that?",
	"I honestly don't know whose it is. It's been here all along.",
	"Explore the area while you're here. Take your time.",
	"If you need any help, find me in town, at the florist shop.",
	"I'll start by looking around the house, every corner of it.",
]

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


## Every line the game shows in a dialogue box, from the data and from the opening sequence.
func _all_texts() -> Array:
	var texts: Array = []
	var talk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BOX_TALK))
	for step in talk.steps:
		if step.has("lines"):
			for line in step.lines:
				texts.append(line.text)
	var events: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HOME_EVENTS))
	for area in events.areas:
		texts.append_array(area.lines)
	texts.append_array(events.done_lines)
	texts.append_array(events.plank.waiting_lines)
	texts.append_array(events.plank.found_lines)
	texts.append_array(OPENING_LINES)
	return texts


## How many lines the text takes in a label of the text box's size. Measured in a label of its own, on screen.
func _line_count(text: String) -> int:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	label.size = Vector2(
		SceneDialogue.TEXT_RECT.size.x * SceneDialogue.WIDTH,
		SceneDialogue.TEXT_RECT.size.y * SceneDialogue.WIDTH * SceneDialogue.ART_SIZE.y / SceneDialogue.ART_SIZE.x)
	label.text = text
	root.add_child(label)
	await process_frame
	var count := label.get_line_count()
	root.remove_child(label)
	label.free()
	return count


func _initialize() -> void:
	await process_frame
	var dialogue := SceneDialogue.new()
	root.add_child(dialogue)
	await process_frame
	await process_frame
	var hud = root.get_node("/root/Hud")
	var hud_events = root.get_node("/root/HudEvents")

	print("Long lines are paged to fit the box")
	var all_fit := true
	var words_kept := true
	var longest := ""
	for text in _all_texts():
		var pages: Array = dialogue.pages_for(text)
		for page in pages:
			var lines: int = await _line_count(page)
			if lines > SceneDialogue.MAX_LINES:
				all_fit = false
				print("       too tall (%d lines): %s" % [lines, page])
		var joined := " ".join(PackedStringArray(pages))
		if joined.split(" ", false) != String(text).split(" ", false):
			words_kept = false
		if String(text).length() > longest.length():
			longest = text
	check(all_fit, "every page of every line fits the text box in two lines")
	check(words_kept, "the pages, joined back, give every word of each line in order")
	check(dialogue.pages_for(longest).size() >= 2, "the longest line is shown on more than one page")
	var unpaged: int = await _line_count(longest)
	check(unpaged > SceneDialogue.MAX_LINES, "measured unpaged, the longest line takes more than two lines (%d): the check can fail" % unpaged)
	check(dialogue.pages_for("Hello there.") == ["Hello there."], "a short line stays on one page")

	print("The quick slots leave the screen while a talk is up")
	hud_events.dialogue_changed.emit(true)
	await process_frame
	check(not hud.quick_slots.visible, "the quick slots hide when a talk box opens")
	hud_events.dialogue_changed.emit(false)
	await process_frame
	check(hud.quick_slots.visible, "the quick slots come back when the talk box closes")

	print("The box says when it opens and closes, and shows each page in turn")
	var changes: Array = []
	dialogue.talk_changed.connect(func(is_open: bool): changes.append(is_open))
	dialogue.say("Amelia", [{"text": "Hello there.", "emotion": "neutral"}])
	check(changes == [true] and dialogue.is_open, "the box says it has opened")
	dialogue.advance()
	check(changes == [true, false] and not dialogue.is_open, "the box says it has closed")

	var expected: Array = dialogue.pages_for(longest)
	var shown: Array = []
	dialogue.say("Oliver", [{"text": longest, "emotion": "thinking"}])
	shown.append(dialogue._text_label.text)
	while dialogue.is_open:
		dialogue.advance()
		if dialogue.is_open:
			shown.append(dialogue._text_label.text)
	check(shown == expected, "each page of the longest line is shown in turn, then the box closes")
	check(changes == [true, false, true, false], "the box announces the long line's opening and closing once each")

	dialogue.queue_free()
	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
