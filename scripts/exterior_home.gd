extends Node2D
## A walled front courtyard: the reference picture is the ground, and the solid objects are
## listed in a collision data file. The home and the temple use this script. A courtyard
## subclass changes the picture, the collisions, the door and the gate.
## E at the door goes inside; walking into the gate goes to the world map.

const TiledMapLoader = preload("res://scripts/tiled_map_loader.gd")
var PICTURE_PATH := "res://assets/environments/home_exterior.png"
var COLLISION_DATA := "res://data/exterior_home_collision.json"
## The area's Tiled map (res://data/maps/*.json). When set, it supplies the picture, solids,
## furniture, exits, spawns and door, and the values above are not used.
@export var MAP_DATA := ""
var COLLISION_RECTS: Array = []
var IMAGE_SIZE := Vector2(1629, 965)
var PLAYER_SPEED := 180.0
var PLAYER_SCALE := 0.16
var INTERACT_RADIUS := 70.0
## Where the character appears: the default, and by arrival ID.
var SPAWN_DEFAULT := Vector2(748, 470)
var SPAWN_FROM_HOME := Vector2(748, 470)
## Just inside the gate, when arriving from the town map.
var SPAWN_FROM_MAP := Vector2(748, 815)
var SPAWNS := {}
## Walking into this rectangle goes to the world map. An empty rectangle means no gate.
var GATE_RECT := Rect2(672, 840, 166, 60)
## Other ways out of this picture: each {"rect", "scene", "spawn"}, used like the gate.
## An exit with a "requires" flag stays shut until that flag is set in world_state.
var EXITS: Array = []
## The door: where the prompt appears, its label, and the scene it leads to.
var ENTER_POSITION := Vector2(748, 380)
var ENTER_LABEL := "Enter House"
var ENTER_HOME_SCENE := "res://scenes/HomeFloor1.tscn"
var ENTER_HOME_SPAWN := "from_exterior"
## Places without a door (the forest) turn this off.
var HAS_DOOR := true
## Our place name on the map, and the scene ID used for the previous-room record.
var MAP_PLACE := "home"
var SCENE_ID := "exterior_home"
## Furniture that the character walks behind: each rectangle is drawn in front of her while her
## feet are above its bottom edge. Taken from the picture, so it looks the same as the room.
var OCCLUDERS: Array = []
## Cut-out props placed on the floor, each {"image", "pos"} with pos as the top-left corner.
var PROPS: Array = []
var occluder_sprites: Array = []
## A depth-sorted scene (a static picture with furniture in it) draws the character and each piece of furniture together,
## by the height of their base lines. The character walks behind anything whose base is lower on the picture than her feet.
var DEPTH_SORTED := true
var _depth_root: Node2D

var player: CharacterBody2D
var sprite: CharacterSprite
var camera: Camera2D
var _prompt_text := ""
var fade: ColorRect
var nearby: Dictionary = {}
var transitioning := false
var interactables: Array = []
var scene_dialogue: SceneDialogue
## True while a scripted scene (the opening) has the character: no walking and no interaction.
var scripted := false
## Click or tap to walk (ClickWalker): made with the player.
var click_walker: ClickWalker


func _ready() -> void:
	if MAP_DATA != "":
		_apply_map(TiledMapLoader.load_map(MAP_DATA))
	if SPAWNS.is_empty():
		SPAWNS = {
			"from_home": SPAWN_FROM_HOME,
			"from_hallway": SPAWN_FROM_HOME,
			"from_map": SPAWN_FROM_MAP,
		}
	interactables = [{"id": "enter", "pos": ENTER_POSITION, "label": ENTER_LABEL}] if HAS_DOOR else []
	_setup_input()
	if DEPTH_SORTED:
		_depth_root = Node2D.new()
		_depth_root.y_sort_enabled = true
		add_child(_depth_root)
	_build_ground()
	_build_collisions()
	_build_player()
	_build_ui()
	_start_opening()
	SaveSystem.state.current_location = MAP_PLACE
	MissionTracker.note_visit(SCENE_ID)
	SaveSystem.save_game()
	HudEvents.location_changed.emit(UiData.location_name(MAP_PLACE), UiData.chapter_title())
	# The people of this scene (data/people.json).
	add_child(ScenePeople.new(self))
	# The destination of the current objective, when this scene is on the way to it.
	add_child(DestinationMarker.new(self, false))
	# Walking into a place can complete a mission (the café), and the objective follows the mission that is on now.
	MissionTracker.update()


func _setup_input() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_E, KEY_ENTER],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


func _build_ground() -> void:
	if has_meta("static_scene"):
		_register_occluders()
		return
	var texture: Texture2D = load(PICTURE_PATH)
	var picture := Sprite2D.new()
	picture.texture = texture
	picture.centered = false
	picture.z_index = -10
	add_child(picture)
	# Props stand on the floor: drawn above the picture, under the character.
	for prop in PROPS:
		var prop_texture: Texture2D = load(prop.image)
		# A soft shadow on the floor under the prop, like the shadows drawn into the picture.
		var shadow := Sprite2D.new()
		shadow.texture = _shadow_texture()
		shadow.scale = Vector2(prop_texture.get_width() * 0.0045, prop_texture.get_height() * 0.0040)
		shadow.position = Vector2(prop.pos[0] + prop_texture.get_width() / 2.0, prop.pos[1] + prop_texture.get_height() * 0.62)
		shadow.modulate = Color(0, 0, 0, 0.5)
		shadow.z_index = -1
		add_child(shadow)
		var sprite := Sprite2D.new()
		sprite.texture = prop_texture
		sprite.centered = false
		sprite.position = Vector2(prop.pos[0], prop.pos[1])
		sprite.z_index = 0
		add_child(sprite)
	# Each piece of furniture is a copy of its own part of the picture, drawn above the character.
	for entry in OCCLUDERS:
		# An entry is a Rect2 of the picture, or {"rect", "image"} for a cut-out with its own
		# transparent background (such as a lamp), so no picture background shows around it.
		var rect: Rect2 = entry if entry is Rect2 else entry.rect
		var piece := Sprite2D.new()
		var origin := rect.position
		if entry is Rect2:
			piece.texture = texture
			piece.region_enabled = true
		else:
			piece.texture = load(entry.image)
			origin = Vector2.ZERO
		piece.centered = false
		if DEPTH_SORTED:
			# Sorted by its base line (the bottom of its rectangle), so the character walks behind it when she is above it.
			if entry is Rect2:
				piece.region_rect = rect
			piece.position = Vector2(rect.position.x, rect.end.y)
			piece.offset = Vector2(0, -rect.size.y)
			piece.z_index = 0
			piece.visible = true
			_depth_root.add_child(piece)
		else:
			piece.position = rect.position
			piece.z_index = 6
			piece.visible = false
			add_child(piece)
		occluder_sprites.append({"node": piece, "rect": rect, "origin": origin, "cutout": not (entry is Rect2)})


## Takes the area's picture, solids, furniture, exits, spawns and door from its Tiled map.
func _apply_map(map: Dictionary) -> void:
	if map.is_empty():
		return  # TiledMapLoader has already reported the error.
	PICTURE_PATH = map.picture
	IMAGE_SIZE = map.image_size
	COLLISION_RECTS = map.solids
	OCCLUDERS = map.occluders
	EXITS = map.exits
	GATE_RECT = map.gate
	SPAWNS = map.spawns
	if map.spawns.has("default"):
		SPAWN_DEFAULT = map.spawns["default"]
	HAS_DOOR = not map.door.is_empty()
	if HAS_DOOR:
		ENTER_POSITION = map.door.pos
		ENTER_LABEL = map.door.label
		ENTER_HOME_SCENE = map.door.scene
		ENTER_HOME_SPAWN = map.door.spawn


func _build_collisions() -> void:
	if has_meta("static_scene"):
		return
	var rects: Array = COLLISION_RECTS
	if MAP_DATA == "":
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(COLLISION_DATA))
		if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("solids"):
			push_error("[Courtyard] Could not read %s" % COLLISION_DATA)
			return
		for solid in parsed.solids:
			var r: Array = solid.rect
			rects.append(Rect2(r[0], r[1], r[2], r[3]))
	for rect in rects:
		var size: Vector2 = rect.size
		var body := StaticBody2D.new()
		body.position = rect.position + size / 2
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = size
		shape.shape = rect_shape
		body.add_child(shape)
		add_child(body)


func _build_player() -> void:
	player = CharacterBody2D.new()
	player.z_index = 0 if DEPTH_SORTED else 5
	player.add_to_group("figures")
	player.position = SPAWN_DEFAULT
	var pending: String = SaveSystem.state.pending_spawn
	if SPAWNS.has(pending):
		player.position = SPAWNS[pending]
	SaveSystem.state.pending_spawn = ""

	# A soft shadow under the feet, so she sits on the floor rather than floating over it.
	var shadow := Sprite2D.new()
	shadow.texture = _shadow_texture()
	shadow.scale = Vector2(0.9, 0.35)
	shadow.position = Vector2(0, -2)
	shadow.z_index = -1
	shadow.modulate = Color(0, 0, 0, 0.5)
	player.add_child(shadow)

	# The collision sits at the feet, so the player can walk close to walls and objects.
	player.add_child(CharacterSprite.feet_collider(PLAYER_SCALE))

	sprite = CharacterSprite.new()
	sprite.character_scale = PLAYER_SCALE
	player.add_child(sprite)
	(_depth_root if DEPTH_SORTED else self).add_child(player)
	click_walker = ClickWalker.new(player, Rect2(Vector2.ZERO, IMAGE_SIZE))
	add_child(click_walker)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(IMAGE_SIZE.x)
	camera.limit_bottom = int(IMAGE_SIZE.y)
	player.add_child(camera)
	camera.make_current()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0.0
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	scene_dialogue = SceneDialogue.new()
	layer.add_child(scene_dialogue)
	scene_dialogue.talk_changed.connect(func(is_open: bool): HudEvents.dialogue_changed.emit(is_open))


func _shadow_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


## A static scene (scripts/build_visual_scenes.py) holds each occluder as a hidden node. Each one is
## handed to the occluder logic with its rectangle and origin, and whether it is a cut-out.
func _register_occluders() -> void:
	var pieces: Array = []
	for child in get_children():
		if child.has_meta("rect"):
			pieces.append(child)
	for child in pieces:
		var rect: Rect2 = child.get_meta("rect")
		if DEPTH_SORTED:
			_place_on_base(child, rect)
			continue
		child.visible = false
		occluder_sprites.append({
			"node": child,
			"rect": rect,
			"origin": child.get_meta("origin", Vector2.ZERO),
			"cutout": child.get_meta("cutout", false),
		})


## A depth-sorted piece of furniture: moved into the sorted group, with its base line as its position, so the sort puts it in
## front of the character when its base is lower than her feet. Its picture hangs up from that base line.
func _place_on_base(piece: Node2D, rect: Rect2) -> void:
	piece.get_parent().remove_child(piece)
	_depth_root.add_child(piece)
	piece.z_index = 0
	piece.visible = true
	piece.position = Vector2(rect.position.x, rect.end.y)
	piece.offset = Vector2(0, -rect.size.y)


## Adds a character or another figure to the scene: into the sorted group, with the character, when the scene sorts its depth.
func add_figure(node: Node2D) -> void:
	if DEPTH_SORTED:
		node.z_index = 0
		_depth_root.add_child(node)
	else:
		add_child(node)


## Shows the furniture in front of the character when she is behind it.
func _update_occluders() -> void:
	if DEPTH_SORTED:
		return
	for entry in occluder_sprites:
		var rect: Rect2 = entry.rect
		var feet := player.position.y
		if entry.cutout:
			# A cut-out is only drawn when she is behind it (feet above its base). Otherwise the
			# picture already shows the furniture under her, so nothing is drawn twice.
			entry.node.visible = feet < rect.end.y and rect.grow_individual(10, 0, 10, 0).has_point(player.position)
			entry.node.z_index = 6
			continue
		var behind := feet < rect.end.y and rect.grow_individual(10, 0, 10, 0).has_point(player.position)
		# Only the part of the furniture above her feet covers her, so her feet stay visible.
		var height := clampf(feet - 4.0 - rect.position.y, 0.0, rect.size.y)
		entry.node.visible = behind and height > 0.0
		if entry.node.visible:
			if entry.cutout:
				# A cut-out is a whole piece of furniture. When she is behind it, all of it covers her,
				# feet included, because her feet are behind it too.
				entry.node.region_enabled = true
				entry.node.region_rect = Rect2(0, 0, rect.size.x, rect.size.y)
			else:
				entry.node.region_rect = Rect2(entry.origin, Vector2(rect.size.x, height))


func _physics_process(delta: float) -> void:
	if scripted:
		click_walker.cancel()
		_update_nearby()
		_update_occluders()
		return
	var locked := scene_dialogue.is_open or HudEvents.screen_open
	var dir := Vector2.ZERO
	if not transitioning and not locked:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# The keys take over from a click walk at once; otherwise a click walk steers.
		if dir != Vector2.ZERO:
			click_walker.cancel()
		elif click_walker.is_walking():
			dir = click_walker.steer(delta)
	move_player(dir, 0.0)
	_update_nearby()
	_update_occluders()
	if locked or transitioning:
		return
	if GATE_RECT.has_point(player.position):
		_go_to("res://scenes/WorldMap.tscn", "")
		return
	for exit in EXITS:
		if exit.has("requires") and not SaveSystem.state.world_state.get(exit.requires, false):
			continue
		if exit.rect.has_point(player.position):
			_go_to(exit.scene, exit.spawn)
			return


## Moves the player with the given direction. Also used by the headless tests.
func move_player(dir: Vector2, _delta: float) -> void:
	player.velocity = dir * PLAYER_SPEED
	player.move_and_slide()
	sprite.update_movement(dir)


func _update_nearby() -> void:
	nearby = {}
	var best := INTERACT_RADIUS
	for item in interactables:
		var d: float = player.position.distance_to(item.pos)
		if d < best:
			best = d
			nearby = item
	if transitioning or scripted or scene_dialogue.is_open or nearby.is_empty():
		_show_prompt("")
	else:
		_show_prompt(nearby.label)


## Tells the HUD which interaction is available here, or none ("").
func _show_prompt(text: String) -> void:
	if text != _prompt_text:
		_prompt_text = text
		HudEvents.interaction_changed.emit(text)


## A left click or tap on the scene (not on the HUD, which takes its own clicks first) walks Amelia there. True when the
## event was such a click.
func _handle_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return false
	if _click_blocked():
		return true
	var target := click_target(get_global_mouse_position())
	click_walker.go_to(target.pos, target.interact)
	get_viewport().set_input_as_handled()
	return true


## True while a click should not walk: a scripted scene, a talk or a screen is open, or the scene is changing.
func _click_blocked() -> bool:
	return scripted or transitioning or scene_dialogue.is_open or HudEvents.screen_open


## Where a click on this point sends Amelia: {pos, interact}. A click on something she can use walks to it and uses it;
## so does a click on something a child node offers (the loose board, HouseInspection.click_target). An interactable's
## point is at its foot (a person's feet, the floor in front of the radio), and it is drawn above that, so a click counts
## anywhere from a little below the point to a figure's height above it.
func click_target(point: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for item in interactables:
		var pos: Vector2 = item.pos
		var area := Rect2(pos.x - 50.0, pos.y - 130.0, 100.0, 160.0)
		var d := point.distance_to(pos)
		if area.has_point(point) and d < best_d:
			best_d = d
			best = {"pos": pos, "interact": true}
	if not best.is_empty():
		return best
	for child in get_children():
		if child.has_method("click_target"):
			var spot = child.click_target(point)
			if spot != null:
				return {"pos": spot, "interact": true}
	return {"pos": point, "interact": false}


func _unhandled_input(event: InputEvent) -> void:
	if _handle_click(event):
		return
	if not event.is_action_pressed("interact") or transitioning or HudEvents.screen_open:
		return
	if scene_dialogue.is_open:
		scene_dialogue.advance()
	elif scripted or nearby.is_empty():
		return
	elif nearby.id == "enter":
		_go_to(ENTER_HOME_SCENE, ENTER_HOME_SPAWN)
	elif nearby.has("action"):
		_do_action(nearby.action)
	elif nearby.has("lines"):
		scene_dialogue.say(nearby.get("speaker", ""), nearby.lines)
		# A person or pet talked to counts as met, and sets its flag (MissionTracker).
		ScenePeople.talked_to(nearby)


## An interactable with an "action" instead of lines (the bed's Sleep). Scenes that have one handle it here.
func _do_action(_action: String) -> void:
	pass


## Starts the opening: the front yard for a new game, or the walk inside once it has begun.
func _start_opening() -> void:
	var stage: String = SaveSystem.state.world_state.get("opening_stage", "")
	if SCENE_ID == "exterior_home" and stage == "pending":
		var front := OpeningSequence.new()
		add_child(front)
		front.front_yard(self)
	elif SCENE_ID == "home_floor1" and stage == "inside":
		var inside := OpeningSequence.new()
		add_child(inside)
		inside.inside(self)


func _go_to(scene_path: String, spawn: String) -> void:
	transitioning = true
	SaveSystem.state.previous_room = SCENE_ID
	SaveSystem.state.pending_spawn = spawn
	SaveSystem.state.player_position = [player.position.x, player.position.y]
	SaveSystem.save_game()
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.25)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)
