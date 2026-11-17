class_name OpeningSequence
extends Node
## The opening of the game, in two parts. In the front yard, Evelyn welcomes Amelia and Oliver, and
## they all walk to the door. Inside the house, Amelia says a few things about it, notices the radio
## and asks Evelyn about it. The world_state flag "opening_stage" keeps the place across the scene
## change: "pending" (front yard still to play), "inside" (walk inside still to play), "done".

## Oliver's art is drawn smaller than Amelia's, so this scale makes him 1.10 times Amelia's height.
const OLIVER_SIZE := 1.30


## Part one, in the front yard (ExteriorHome). Ends by walking through the front door.
func front_yard(host: Node2D) -> void:
	host.scripted = true
	# Evelyn is already waiting at the front door. Amelia and Oliver walk up to her.
	var evelyn := _walker(host, "res://data/evelyn_animations.json")
	evelyn.position = Vector2(730, 430)
	host.add_figure(evelyn)
	var oliver := _walker(host, "res://data/oliver_animations.json", OLIVER_SIZE)
	oliver.position = Vector2(990, 700)
	host.add_figure(oliver)
	await _walk_together(host, [
		[host.player, Vector2(690, 480)],
		[oliver, Vector2(775, 490)],
	], 2.0)
	SceneWalkers.face_each_other(host, host.player, evelyn)
	SceneWalkers.face_point(host, oliver, evelyn.position)
	await host.scene_dialogue.say("Evelyn", [
		{"text": "Welcome to Evervale! You must be Amelia and Oliver.", "emotion": "smile"},
		{"text": "This is your house now.", "emotion": "smile"},
	])
	await host.scene_dialogue.say("Amelia", [{"text": "Thank you, Evelyn. It's lovely to meet you.", "emotion": "smile"}])
	await host.scene_dialogue.say("Oliver", [{"text": "We can't wait to see inside.", "emotion": "happy"}])
	await host.scene_dialogue.say("Evelyn", [{"text": "Then come in. I'll show you around.", "emotion": "smile"}])
	# Evelyn leads the way to her spot by the door first, then Amelia and Oliver walk up to the door beside her.
	var door: Vector2 = host.ENTER_POSITION
	await _walk_together(host, [[evelyn, door + Vector2(-30, 0)]], 1.2)
	await _walk_together(host, [
		[host.player, door],
		[oliver, door + Vector2(30, 0)],
	], 2.2)
	SaveSystem.state.world_state["opening_stage"] = "inside"
	host._go_to(host.ENTER_HOME_SCENE, host.ENTER_HOME_SPAWN)


## Part two, inside the house (HomeFloor1), once they have walked in.
func inside(host: Node2D) -> void:
	host.scripted = true
	var evelyn := _walker(host, "res://data/evelyn_animations.json")
	evelyn.position = Vector2(700, 790)
	host.add_figure(evelyn)
	var oliver := _walker(host, "res://data/oliver_animations.json", OLIVER_SIZE)
	oliver.position = Vector2(770, 800)
	host.add_figure(oliver)
	# They face each other from the first line: Amelia to Evelyn and Oliver, and the two of them to her.
	SceneWalkers.face_each_other(host, host.player, evelyn)
	SceneWalkers.face_point(host, oliver, host.player.position)
	await host.scene_dialogue.say("Amelia", [
		{"text": "This is even better inside. Look at the light through those windows.", "emotion": "happy"},
		{"text": "There's plenty of room to draw, and the kitchen is lovely.", "emotion": "smile"},
	])
	await host.scene_dialogue.say("Amelia", [{"text": "Oh, there's a radio on the table. Evelyn, whose is that?", "emotion": "surprised"}])
	await host.scene_dialogue.say("Evelyn", [{"text": "I honestly don't know whose it is. It's been here all along.", "emotion": "neutral"}])
	# Evelyn tells Amelia to explore, then leaves through the front door. Amelia's look around the house starts.
	await host.scene_dialogue.say("Evelyn", [
		{"text": "Explore the area while you're here. Take your time.", "emotion": "smile"},
		{"text": "If you need any help, find me in town, at the florist shop.", "emotion": "smile"},
	])
	# Evelyn walks round Amelia, who stands in the middle of the room, and out through the door. Oliver walks out with her,
	# since he is out unpacking; he comes back for the box talk.
	await _walk_together(host, [[evelyn, Vector2(670, 880)]], 1.2)
	await _walk_together(host, [[evelyn, Vector2(725, 935)], [oliver, Vector2(790, 935)]], 1.2)
	evelyn.queue_free()
	oliver.queue_free()
	SaveSystem.state.world_state["house_task"] = "active"
	await host.scene_dialogue.say("Amelia", [{"text": "I'll start by looking around the house, every corner of it.", "emotion": "smile"}])
	# Evelyn placed the radio herself; she says she doesn't know for now. The later reveal checks this flag.
	SaveSystem.state.world_state["evelyn_radio_denied"] = true
	SaveSystem.state.world_state["opening_stage"] = "done"
	SaveSystem.save_game()
	host.scripted = false


func _walk(host: Node2D, node: Node2D, target: Vector2, seconds: float) -> void:
	await _walk_together(host, [[node, target]], seconds)


## Walks each node to its target at the same time, and waits until they have all arrived (see SceneWalkers).
func _walk_together(host: Node2D, moves: Array, seconds: float) -> void:
	await SceneWalkers.walk_together(host, moves, seconds)


## A figure with its own walk sheets (Oliver), built like the player's sprite.
func _walker(host: Node2D, animations: String, size: float = 1.0) -> Node2D:
	return SceneWalkers.walker(host, animations, size)
