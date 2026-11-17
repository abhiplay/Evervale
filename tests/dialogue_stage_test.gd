extends SceneTree
## Checks the full-screen dialogue (SceneDialogue's stage, DialogueStage): Amelia's own remarks while exploring stay in the
## small box, while a conversation (someone else speaking, or any line in a scripted scene) plays on the stage with the
## room close up behind it, the speaker large on their side (Amelia right, others left), and the HUD out of the way. The
## stage stays up between speakers of one conversation, goes down when it ends, takes the night's tint, knows the zone
## Amelia stands in, and Hide and Skip work. Frame limits only. Run: Godot --headless --path . -s res://tests/dialogue_stage_test.gd

var failures: Array[String] = []
var save
var hud


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	save = root.get_node("/root/SaveSystem")
	hud = root.get_node("/root/Hud")
	var events = root.get_node("/root/HudEvents")
	save.state = save.new_game_state()
	var world: Dictionary = save.state.world_state
	world["opening_stage"] = "done"
	world["house_task"] = "done"
	world["talked_to"] = ["coco", "charlie"]
	save.state.cutscenes_viewed = ["CS-003"]
	var house = load("res://scenes/HomeFloor1.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	await _frames(5)
	var talk = house.scene_dialogue
	var stage = talk.stage

	print("Amelia's own remark while exploring")
	talk.say("Amelia", ["The kitchen is spotless."])
	await _frames(3)
	check(not talk.stage_mode and not stage.visible, "stays in the small box")
	talk.advance()
	await _frames(3)

	print("Someone else speaking")
	talk.say("Oliver", [{"text": "Amelia? What was that noise?", "emotion": "surprised"}])
	await _frames(20)
	check(talk.stage_mode and stage.visible, "plays on the stage")
	check(stage.backdrop.texture != null, "the room is behind them")
	check(stage.figure.visible and stage.side == "left", "Oliver stands large on the left")
	check(stage.figure.position.y + stage.figure.size.y >= house.get_viewport().get_visible_rect().size.y - 1.0, "his picture's bottom edge sits on the screen's bottom edge")
	check(events.dialogue_stage, "the HUD is told a conversation is on")
	check(not hud._corners.visible, "the HUD steps aside")
	check(talk._speaker_label.text == "Oliver" and talk._text_label.text.contains("noise"), "his name and his line show")

	print("The next speaker of the same conversation")
	house.scripted = true
	talk.advance()
	var stayed := true
	for i in 6:
		if not stage.visible:
			stayed = false
		await process_frame
	talk.say("Amelia", [{"text": "The radio. It switched itself on.", "emotion": "scared"}])
	await _frames(3)
	check(stayed and stage.visible, "the stage stays up between speakers, with no flicker")
	check(stage.figure.visible and stage.side == "right", "Amelia stands on the right")

	print("Night")
	var night := CanvasModulate.new()
	night.name = "NightTint"
	night.color = Color(0.3, 0.35, 0.5)
	house.add_child(night)
	await _frames(2)
	check(stage.backdrop.self_modulate.is_equal_approx(night.color), "the room behind them takes the night's tint")
	night.queue_free()

	print("Hide and Skip")
	talk._hide_words()
	check(not talk._text_label.visible and not stage.figure.visible, "Hide shows the room alone")
	talk.advance()
	check(talk.is_open and talk._text_label.visible, "the next tap brings the words back without moving on")
	talk.advance()
	await _frames(2)
	talk.say("Oliver", ["One.", "Two.", "Three.", "Four."])
	talk._skip_talk()
	var skipped := false
	for i in 120:
		if not talk.is_open:
			skipped = true
			break
		await process_frame
	check(skipped, "Skip runs through the rest of the lines")

	print("The conversation ends")
	house.scripted = false
	# The stage fades out over a quarter of a second, so this waits in real time, not frames.
	var down := false
	for i in 20:
		if not stage.visible:
			down = true
			break
		await create_timer(0.1).timeout
	check(down, "the stage goes down once the scene is no longer scripted")
	check(not events.dialogue_stage, "and the HUD comes back")
	await _frames(2)
	check(hud._corners.visible, "the HUD is shown again")

	print("Zones")
	house.player.position = Vector2(1100, 760)
	stage._host = house
	check(stage._zone("home_floor1") == "kitchen", "standing in the kitchen, the zone is the kitchen")
	check(stage._painting() == null, "with no painting listed yet, the room's own picture is used")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
