extends Node2D
## One room scene, driven by data/rooms/<room>.json. Covers the room's picture or
## floor, its solid objects, its exits (room-to-room transitions), its spawn points
## and its interactions. Scene changes use the same fade-and-switch as the rest of
## the game, through SaveSystem.

const ROOM_SCENES := {
	"exterior_home": "res://scenes/ExteriorHome.tscn",
	"temple_interior": "res://scenes/TempleInterior.tscn",
	"temple_courtyard": "res://scenes/TempleCourtyard.tscn",
	"cave_interior": "res://scenes/CaveInterior.tscn",
}
## The dialogue box artwork (assets/ui/dialogue_box.png) and where things sit on it, in
## artwork pixels: the text panel, and the centres of the play, skip and hide icons.
const DIALOGUE_ART := "res://assets/ui/dialogue_box.png"
const DIALOGUE_ART_SIZE := Vector2(1953, 586)
const DIALOGUE_WIDTH := 740.0
const TEXT_RECT := Rect2(0.275, 0.37, 0.62, 0.45)
const BUTTON_PLAY := Vector2(1284, 537)
const BUTTON_SKIP := Vector2(1391, 537)
const BUTTON_HIDE := Vector2(1502, 537)
const BUTTON_TOUCH_SIZE := 110.0
const SPEED := 180.0
const PLAYER_SCALE := 0.16
const INTERACT_RADIUS := 64.0
## How close the player must be to an exit to use it, measured from its zone.
const EXIT_MARGIN := 40.0

@export var room_id := "temple_interior"
## Set false in headless tests to check a transition without changing scene.
var change_scenes := true

var data: Dictionary
var player: CharacterBody2D
var sprite: CharacterSprite
var camera: Camera2D
var exits: Array[Dictionary] = []
var interactables: Array[Dictionary] = []
var nearby_exit: Dictionary = {}
var nearby_item: Dictionary = {}
## The exit the player arrived through. It stays off until the player steps away.
var locked_exit := ""
var transitioning := false
var dialogue_lines: Array[String] = []
var dialogue_open := false
var dialogue_panel: Control
var dialogue_label: Label
var _prompt_text := ""
var fade: ColorRect
var tv_glow: ColorRect
var lamp_light: PointLight2D
var tv_on := false
var lamp_on := false


func _ready() -> void:
	_setup_input()
	data = _load_room(room_id)
	_build_background()
	_build_solids()
	_build_exits()
	_build_interactables()
	_build_player()
	_build_ui()
	_restore_room_state()
	_apply_spawn()
	_mark_visited()


func _load_room(id: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/%s.json" % id))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[Room] Could not read the data for '%s'." % id)
		return {}
	return parsed


func _setup_input() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_E, KEY_ENTER],
		"open_map": [KEY_M],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


# ---------------------------------------------------------------- building the room

func _size() -> Vector2:
	return Vector2(data.size[0], data.size[1])


func _build_background() -> void:
	if data.has("image"):
		# A static scene (scripts/build_visual_scenes.py) already holds the picture.
		if not has_meta("static_scene"):
			var picture := Sprite2D.new()
			picture.texture = load(data.image)
			picture.centered = false
			picture.z_index = -10
			add_child(picture)
	else:
		var floor_rect := ColorRect.new()
		floor_rect.size = _size()
		floor_rect.color = Color(data.get("floor_color", "#9a6b43"))
		floor_rect.z_index = -10
		add_child(floor_rect)
	# Covers hide a part of the picture (such as the hidden stairs) until the flag is set.
	for cover in data.get("covers", []):
		if cover.has("requires") and SaveSystem.state.world_state.get(cover.requires, false):
			continue
		var patch := Sprite2D.new()
		patch.texture = load(cover.image)
		patch.centered = false
		patch.position = Vector2(cover.pos[0], cover.pos[1])
		patch.z_index = -9
		add_child(patch)


func _build_solids() -> void:
	if has_meta("static_scene"):
		return  # the solids are nodes in the static scene
	for solid in data.get("solids", []):
		var r: Array = solid.rect
		var size := Vector2(r[2], r[3])
		var body := StaticBody2D.new()
		body.position = Vector2(r[0], r[1]) + size / 2
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = size
		shape.shape = rect_shape
		body.add_child(shape)
		add_child(body)
		if data.get("draw_solids", false):
			var visual := ColorRect.new()
			visual.size = size
			visual.position = -size / 2
			visual.color = Color(data.get("solid_color", "#5b3a24"))
			body.add_child(visual)


func _build_exits() -> void:
	for opening in data.get("exits", []):
		# An exit with a "requires" flag only appears once that flag is set in the save.
		if opening.has("requires") and not SaveSystem.state.world_state.get(opening.requires, false):
			continue
		exits.append(opening)


func _build_interactables() -> void:
	for item in data.get("interactables", []):
		var pos := Vector2(item.pos[0], item.pos[1])
		var marker := ColorRect.new()
		marker.size = Vector2(16, 16)
		marker.position = pos - marker.size / 2
		marker.color = Color(0.95, 0.75, 0.35, 0.5)
		add_child(marker)
		interactables.append({
			"id": item.id,
			"pos": pos,
			"label": item.label,
			"kind": item.get("kind", "inspect"),
			"text": item.get("text", ""),
		})
	# Lights and screens get a visible effect when switched on.
	tv_glow = ColorRect.new()
	tv_glow.color = Color(0.5, 0.7, 1.0, 0.25)
	tv_glow.visible = false
	tv_glow.z_index = 3
	if data.has("tv_rect"):
		var r: Array = data.tv_rect
		tv_glow.position = Vector2(r[0], r[1])
		tv_glow.size = Vector2(r[2], r[3])
	add_child(tv_glow)
	lamp_light = PointLight2D.new()
	lamp_light.texture = _light_texture()
	lamp_light.texture_scale = 2.2
	lamp_light.energy = 0.9
	lamp_light.color = Color(1.0, 0.85, 0.6)
	lamp_light.enabled = false
	if data.has("lamp_position"):
		var p: Array = data.lamp_position
		lamp_light.position = Vector2(p[0], p[1])
	lamp_light.z_index = 4
	add_child(lamp_light)


func _light_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture


func _build_player() -> void:
	player = CharacterBody2D.new()
	player.z_index = 5
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(18, 12)
	shape.shape = rect_shape
	shape.position = Vector2(0, -6)
	player.add_child(shape)
	sprite = CharacterSprite.new()
	sprite.character_scale = PLAYER_SCALE
	player.add_child(sprite)
	add_child(player)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(data.size[0])
	camera.limit_bottom = int(data.size[1])
	player.add_child(camera)
	camera.make_current()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_build_dialogue_box(layer)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0.0
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)


# ---------------------------------------------------------------- spawning and room state

func _apply_spawn() -> void:
	var spawn_id: String = SaveSystem.state.pending_spawn
	var spawns: Dictionary = data.get("spawns", {})
	var spawn: Array = spawns.get(spawn_id, data.get("default_spawn", [data.size[0] / 2.0, data.size[1] / 2.0]))
	player.position = Vector2(spawn[0], spawn[1])
	SaveSystem.state.pending_spawn = ""
	# Do not use the exit we arrived through until the player steps away from it.
	locked_exit = ""
	var came_from: String = SaveSystem.state.previous_room
	for opening in exits:
		if opening.to_room == came_from and came_from != "":
			locked_exit = opening.id
	SaveSystem.state.current_room = room_id
	sprite.update_movement(Vector2.ZERO)


func _mark_visited() -> void:
	var visited: Array = SaveSystem.state.world_state.get("rooms_visited", [])
	if not (room_id in visited):
		visited.append(room_id)
	SaveSystem.state.world_state["rooms_visited"] = visited
	SaveSystem.save_game()


func _room_states() -> Dictionary:
	return SaveSystem.state.world_state.get("room_states", {})


func _restore_room_state() -> void:
	var mine: Dictionary = _room_states().get(room_id, {})
	tv_on = mine.get("tv_on", false)
	lamp_on = mine.get("lamp_on", false)
	tv_glow.visible = tv_on
	lamp_light.enabled = lamp_on


func _save_room_state() -> void:
	var states: Dictionary = SaveSystem.state.world_state.get("room_states", {})
	states[room_id] = {"tv_on": tv_on, "lamp_on": lamp_on}
	SaveSystem.state.world_state["room_states"] = states


# ---------------------------------------------------------------- movement and prompts

func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if not (transitioning or dialogue_open or HudEvents.screen_open):
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move_player(dir)
	_update_prompts()


## Moves the player with the given direction. Also used by the headless tests.
func move_player(dir: Vector2) -> void:
	player.velocity = dir * SPEED
	player.move_and_slide()
	sprite.update_movement(dir)


func _zone_contains(zone: Array, margin: float) -> bool:
	var r := Rect2(zone[0], zone[1], zone[2], zone[3]).grow(margin)
	return r.has_point(player.position)


func _update_prompts() -> void:
	# Release the locked exit once the player has stepped clear of it.
	if locked_exit != "":
		for opening in exits:
			if opening.id == locked_exit and not _zone_contains(opening.rect, EXIT_MARGIN):
				locked_exit = ""

	nearby_exit = {}
	for opening in exits:
		if opening.id != locked_exit and _zone_contains(opening.rect, EXIT_MARGIN):
			nearby_exit = opening
			break

	nearby_item = {}
	var best := INTERACT_RADIUS
	for item in interactables:
		var d: float = player.position.distance_to(item.pos)
		if d < best:
			best = d
			nearby_item = item

	if transitioning or dialogue_open:
		_show_prompt("")
		return
	if not nearby_exit.is_empty():
		_show_prompt(nearby_exit.prompt)
	elif not nearby_item.is_empty():
		_show_prompt(_item_label(nearby_item))
	else:
		_show_prompt("")


## Tells the HUD which interaction is available here, or none ("").
func _show_prompt(text: String) -> void:
	if text != _prompt_text:
		_prompt_text = text
		HudEvents.interaction_changed.emit(text)


func _item_label(item: Dictionary) -> String:
	match item.id:
		"tv":
			return "Turn the TV off" if tv_on else "Turn the TV on"
		"floor_lamp":
			return "Switch the lamp off" if lamp_on else "Switch the lamp on"
	return item.label


# ---------------------------------------------------------------- interactions and exits

func _unhandled_input(event: InputEvent) -> void:
	if HudEvents.screen_open:
		return
	if event.is_action_pressed("open_map") and not (dialogue_open or transitioning) and change_scenes:
		get_tree().change_scene_to_file("res://scenes/WorldMap.tscn")
		return
	if not event.is_action_pressed("interact"):
		return
	if dialogue_open:
		_advance_dialogue()
	elif not nearby_exit.is_empty() and not transitioning:
		_go_through(nearby_exit)
	elif not nearby_item.is_empty() and not transitioning:
		_interact(nearby_item)


func _interact(item: Dictionary) -> void:
	match item.kind:
		"toggle_tv":
			tv_on = not tv_on
			tv_glow.visible = tv_on
			_show_dialogue(["The TV clicks on. A soft blue glow fills the room." if tv_on else "The TV clicks off."])
		"toggle_light":
			lamp_on = not lamp_on
			lamp_light.enabled = lamp_on
			_show_dialogue(["The lamp glows warmly." if lamp_on else "The lamp goes dark."])
		"sit":
			_show_dialogue([item.text])
		_:
			_show_dialogue([item.text])
	_save_room_state()
	SaveSystem.save_game()


func _go_through(opening: Dictionary) -> void:
	# Duplicate protection: one transition at a time.
	transitioning = true
	SaveSystem.state.previous_room = room_id
	SaveSystem.state.pending_spawn = opening.to_spawn
	SaveSystem.state.current_room = opening.to_room
	_save_room_state()
	SaveSystem.save_game()
	if not change_scenes:
		transitioning = false
		return
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.25)
	await tween.finished
	get_tree().change_scene_to_file(ROOM_SCENES[opening.to_room])


## The dialogue box: the artwork at the bottom of the screen, with the text laid over its
## dark panel and invisible buttons over the play, skip and hide icons drawn into the artwork.
func _build_dialogue_box(layer: CanvasLayer) -> void:
	var view := get_viewport().get_visible_rect().size
	var scale_factor := DIALOGUE_WIDTH / DIALOGUE_ART_SIZE.x
	var box_size := DIALOGUE_ART_SIZE * scale_factor
	dialogue_panel = Control.new()
	dialogue_panel.visible = false
	dialogue_panel.size = box_size
	dialogue_panel.position = Vector2((view.x - box_size.x) / 2.0, view.y - box_size.y - 12.0)
	layer.add_child(dialogue_panel)

	var art := TextureRect.new()
	art.texture = load(DIALOGUE_ART)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = box_size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.add_child(art)

	dialogue_label = Label.new()
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_size_override("font_size", 16)
	dialogue_label.add_theme_color_override("font_color", Color("#f3e3c3"))
	dialogue_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	dialogue_label.add_theme_constant_override("shadow_offset_x", 1)
	dialogue_label.add_theme_constant_override("shadow_offset_y", 1)
	dialogue_label.position = Vector2(TEXT_RECT.position.x * box_size.x, TEXT_RECT.position.y * box_size.y)
	dialogue_label.size = Vector2(TEXT_RECT.size.x * box_size.x, TEXT_RECT.size.y * box_size.y)
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.add_child(dialogue_label)

	_add_dialogue_button(BUTTON_PLAY, scale_factor, _advance_dialogue, DialogueIcon.Kind.PLAY)
	_add_dialogue_button(BUTTON_SKIP, scale_factor, _skip_dialogue, DialogueIcon.Kind.SKIP)
	_add_dialogue_button(BUTTON_HIDE, scale_factor, _toggle_dialogue_art, DialogueIcon.Kind.HIDE)


func _add_dialogue_button(centre: Vector2, scale_factor: float, action: Callable, icon_kind: DialogueIcon.Kind) -> void:
	var button := Button.new()
	button.flat = true
	var side := BUTTON_TOUCH_SIZE * scale_factor
	button.size = Vector2(side, side)
	button.position = centre * scale_factor - Vector2(side, side) / 2.0
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	dialogue_panel.add_child(button)
	var icon := DialogueIcon.new(icon_kind)
	icon.size = Vector2(side, side)
	button.add_child(icon)


func _skip_dialogue() -> void:
	if dialogue_open:
		dialogue_lines.clear()
		_advance_dialogue()


func _toggle_dialogue_art() -> void:
	# Hides the box so the scene can be seen; the dialogue stays open and E still advances it.
	dialogue_label.visible = not dialogue_label.visible
	dialogue_panel.modulate.a = 1.0 if dialogue_label.visible else 0.25


func _show_dialogue(lines: Array) -> void:
	dialogue_lines.clear()
	for line in lines:
		dialogue_lines.append(str(line))
	dialogue_open = true
	HudEvents.dialogue_changed.emit(true)
	dialogue_panel.visible = true
	dialogue_label.text = dialogue_lines[0]
	dialogue_lines.remove_at(0)


func _advance_dialogue() -> void:
	if dialogue_lines.is_empty():
		dialogue_open = false
		dialogue_panel.visible = false
		HudEvents.dialogue_changed.emit(false)
		return
	dialogue_label.text = dialogue_lines[0]
	dialogue_lines.remove_at(0)
