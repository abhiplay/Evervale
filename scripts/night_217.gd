class_name Night217
extends RefCounted
## Mission 5, "2:17 AM" (data/night_217.json). Once the box talk is over, the bed upstairs offers Sleep. Sleeping fades to
## black and shows the time; Amelia wakes in the dark bedroom to static and goes down to the ground floor, where the
## radio delivers the warning transmission. Oliver comes down after it. Then it is morning: radio_217_heard is saved,
## which completes Mission 5, and the end of Act I is shown. The world_state flag night_217_stage keeps the place across
## the change of floor: "downstairs" (the ground floor part still to play), "done".
## It plays once: the bed only offers Sleep before radio_217_heard is set.

const DATA_PATH := "res://data/night_217.json"
const STATIC_SOUND := "res://assets/audio/radio_static.wav"
const NIGHT_TINT := Color(0.32, 0.36, 0.55)
const OLIVER_ANIMATIONS := "res://data/oliver_animations.json"
const HEARD_FLAG := "radio_217_heard"


## True when Amelia can go to bed for the night: the box talk is over and the radio has not spoken yet.
static func sleep_available() -> bool:
	var world: Dictionary = SaveSystem.state.world_state
	return world.get("box_talk_done", false) == true and world.get(HEARD_FLAG, false) != true


## True when the ground floor part should play as the scene opens.
static func downstairs_pending() -> bool:
	return SaveSystem.state.world_state.get("night_217_stage", "") == "downstairs"


static func _data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


## Upstairs: Amelia goes to bed, the time shows, she wakes to static, and goes down the stairs.
func bedroom(host: Node2D) -> void:
	var data := _data()
	host.scripted = true
	await host.scene_dialogue.say("Amelia", data.bed_lines)
	var card := _caption(host, data.caption)
	await _fade(host, 1.0, 0.8)
	card.visible = true
	await host.get_tree().create_timer(2.0).timeout
	card.visible = false
	_tint(host)
	var radio := _static_player(host)
	radio.volume_db = -22.0
	await _fade(host, 0.0, 0.8)
	for step in data.wake:
		await host.scene_dialogue.say(step.say, step.lines)
	SaveSystem.state.world_state["night_217_stage"] = "downstairs"
	SaveSystem.save_game()
	host._go_to("res://scenes/HomeFloor1.tscn", "from_bedroom")


## Downstairs: the radio speaks, Oliver comes down, and morning comes.
func downstairs(host: Node2D) -> void:
	var data := _data()
	host.scripted = true
	_tint(host)
	var radio_prop: Node2D = host.get_node_or_null("RadioProp")
	var glow: Tween = null
	if radio_prop:
		glow = radio_prop.create_tween().set_loops()
		glow.tween_property(radio_prop, "modulate", Color(2.2, 1.8, 1.2), 0.5)
		glow.tween_property(radio_prop, "modulate", Color(1.4, 1.2, 1.0), 0.5)
	var sound := _static_player(host)
	sound.volume_db = -14.0
	var to: Array = data.amelia_walks_to
	await SceneWalkers.walk_together(host, [[host.player, Vector2(to[0], to[1])]], 2.4)
	if radio_prop:
		SceneWalkers.face_point(host, host.player, radio_prop.position)
	var oliver: Node2D = null
	for step in data.downstairs:
		if step.get("oliver", false):
			if glow:
				glow.kill()
				radio_prop.modulate = Color.WHITE
			sound.stop()
			oliver = SceneWalkers.walker(host, OLIVER_ANIMATIONS, OpeningSequence.OLIVER_SIZE)
			var enters: Array = data.oliver_enters_at
			oliver.position = Vector2(enters[0], enters[1])
			host.add_child(oliver)
			await SceneWalkers.walk_together(host, [[oliver, host.player.position + Vector2(70, -10)]], 2.0)
			SceneWalkers.face_each_other(host, host.player, oliver)
			continue
		if step.get("static", false):
			sound.volume_db = -6.0
		await host.scene_dialogue.say(step.say, step.lines)
		if step.get("static", false):
			sound.volume_db = -14.0
	# Morning.
	await _fade(host, 1.0, 1.0)
	if oliver:
		oliver.queue_free()
	sound.queue_free()
	_untint(host)
	var world: Dictionary = SaveSystem.state.world_state
	world[HEARD_FLAG] = true
	world["night_217_stage"] = "done"
	SaveSystem.state.day = int(SaveSystem.state.get("day", 1)) + 1
	SaveSystem.save_game()
	MissionTracker.update()
	await _end_card(host, data.end_card)
	await _fade(host, 0.0, 1.0)
	host.scripted = false


## A dark blue night over the whole scene.
func _tint(host: Node2D) -> void:
	var night := host.get_node_or_null("NightTint") as CanvasModulate
	if night == null:
		night = CanvasModulate.new()
		night.name = "NightTint"
		host.add_child(night)
	night.color = NIGHT_TINT


func _untint(host: Node2D) -> void:
	var night := host.get_node_or_null("NightTint")
	if night:
		night.queue_free()


func _static_player(host: Node2D) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "RadioStatic"
	var stream: AudioStreamWAV = load(STATIC_SOUND)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	player.stream = stream
	host.add_child(player)
	player.play()
	return player


## Fades the scene's own fade rectangle to alpha over the given time.
func _fade(host: Node2D, alpha: float, seconds: float) -> void:
	var tween: Tween = host.create_tween()
	tween.tween_property(host.fade, "modulate:a", alpha, seconds)
	await tween.finished


## The time, in large letters in the middle of the black screen. Hidden until shown.
func _caption(host: Node2D, text: String) -> Label:
	var layer := CanvasLayer.new()
	layer.layer = 30
	host.add_child(layer)
	var label := Label.new()
	label.name = "NightCaption"
	label.text = text
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color("#e8c77a"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.visible = false
	layer.add_child(label)
	return label


## "End of Act I" over the black screen for a few seconds.
func _end_card(host: Node2D, card: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.name = "EndCard"
	host.add_child(layer)
	var view := host.get_viewport().get_visible_rect().size
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size = view
	layer.add_child(box)
	for entry in [[card.title, 44, Color("#e8c77a")], [card.subtitle, 24, Color("#f3e3c3")], [card.note, 16, Color("#c9b79a")]]:
		var label := Label.new()
		label.text = entry[0]
		label.add_theme_font_size_override("font_size", entry[1])
		label.add_theme_color_override("font_color", entry[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
	await host.get_tree().create_timer(4.0).timeout
	layer.queue_free()
