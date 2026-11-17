class_name BoxTalk
extends RefCounted
## The talk between Amelia and Oliver after the hidden box is opened in the house. Oliver walks in from the front door and
## stands beside Amelia. Then the steps of data/box_talk.json play in order: a say step is a line of dialogue, and a show
## step opens an item in the viewer, where the talk waits until it is closed. HouseInspection starts it. Its flag
## box_talk_done is saved at the end, so it plays once. Other Amelia and Oliver talks with the same shape use it too, with
## their own data, flag and cutscene id (HomePets plays data/our_new_home.json, CS-003).

signal step_started(index: int)

const DATA_PATH := "res://data/box_talk.json"
const OLIVER_ANIMATIONS := "res://data/oliver_animations.json"
const ROUTE_SECONDS := 2.0
const SIDE_SECONDS := 1.2


## Plays the whole talk on host, the house floor. Amelia is out of the player's control until it has ended.
## The cutscene id is added to the save's viewed cutscenes when the talk ends.
func play(host: Node2D, data_path: String = DATA_PATH, done_flag: String = "box_talk_done", cutscene_id: String = "CS-004") -> void:
	host.scripted = true
	var amelia_facing: Vector2 = host.sprite.facing
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	var oliver := SceneWalkers.walker(host, OLIVER_ANIMATIONS, OpeningSequence.OLIVER_SIZE)
	var enters: Array = data.oliver_enters_at
	oliver.position = Vector2(enters[0], enters[1])
	host.add_figure(oliver)
	for point in data.oliver_route:
		var target: Array = point
		await SceneWalkers.walk_together(host, [[oliver, Vector2(target[0], target[1])]], ROUTE_SECONDS)
	var beside := _spot_beside(host, data.oliver_beside_amelia)
	await SceneWalkers.walk_together(host, [[oliver, beside]], SIDE_SECONDS)
	SceneWalkers.face_each_other(host, host.player, oliver)
	var steps: Array = data.steps
	for index in steps.size():
		step_started.emit(index)
		var step: Dictionary = steps[index]
		if step.has("show"):
			var item_id: String = step.show
			HudEvents.item_view_requested.emit(item_id)
			while HudEvents.screen_open:
				await host.get_tree().process_frame
		else:
			var speaker: String = step.say
			var lines: Array = step.lines
			await host.scene_dialogue.say(speaker, lines)
	oliver.queue_free()
	host.sprite.face(amelia_facing)
	SaveSystem.state.world_state[done_flag] = true
	if cutscene_id != "" and not SaveSystem.state.cutscenes_viewed.has(cutscene_id):
		SaveSystem.state.cutscenes_viewed.append(cutscene_id)
	SaveSystem.save_game()
	MissionTracker.update()
	host.scripted = false


## The first of the offsets from Amelia that no wall or furniture covers. When none is free, the first offset anyway.
func _spot_beside(host: Node2D, offsets: Array) -> Vector2:
	var space := host.get_world_2d().direct_space_state
	var fallback := Vector2.ZERO
	for index in offsets.size():
		var offset: Array = offsets[index]
		var spot: Vector2 = host.player.position + Vector2(offset[0], offset[1])
		if index == 0:
			fallback = spot
		var query := PhysicsPointQueryParameters2D.new()
		query.position = spot
		query.collide_with_bodies = true
		if space.intersect_point(query).is_empty():
			return spot
	return fallback
