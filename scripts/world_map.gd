extends Node2D
## Evervale, the town map. The character walks the roads (and the Town plaza and
## the beach). Each place has a zone on the road or open ground in front of it: walking
## into a zone goes to that place's scene, or says it is not built yet.

const MAP_PATH := "res://assets/map/town_map.webp"
const COLLISION_DATA := "res://data/world_map_collision.json"
const MAP_SIZE := Vector2(1673, 940)
const SPEED := 180.0
const MAP_CHARACTER_SCALE := 0.07

var player: CharacterBody2D
var sprite: CharacterSprite
var camera: Camera2D
var zones: Array[Dictionary] = []
## The place the player arrived in. It stays off until the player steps out of it.
var locked_zone := ""
## Where the character was last frame, to tell which side a zone was entered from.
var last_position := Vector2.ZERO
var message_label: Label
var message_time := 0.0
var transitioning := false
var fade: ColorRect
## Click or tap to walk (ClickWalker). A click on a place walks to its entrance on the road and goes in.
var click_walker: ClickWalker
## How near a click must be to a place's entrance to count as a click on that place, in map pixels.
const PLACE_CLICK_RANGE := 160.0


func _ready() -> void:
	_setup_input()
	_build_map()
	_build_fog()
	_build_solids()
	_build_zones()
	_build_player()
	_build_ui()
	_arrive_at(SaveSystem.state.current_location)
	SaveSystem.save_game()
	MissionTracker.update()


func _setup_input() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


func _build_map() -> void:
	if has_meta("static_scene"):
		return  # the map picture is a node in the static scene
	var picture := Sprite2D.new()
	picture.texture = load(MAP_PATH)
	picture.centered = false
	picture.z_index = -10
	add_child(picture)


## Two layers of the same soft fog, scrolling at different speeds and directions, over the map.
const FOG_LAYERS := [
	{"velocity": Vector2(10, 4), "alpha": 1.0},
	{"velocity": Vector2(-6, 7), "alpha": 0.6},
]
var fog_layers: Array[Dictionary] = []


func _build_fog() -> void:
	var texture: Texture2D = load("res://assets/map/fog.png")
	for layer in FOG_LAYERS:
		var fog := Sprite2D.new()
		fog.texture = texture
		fog.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		fog.centered = false
		fog.region_enabled = true
		fog.region_rect = Rect2(Vector2.ZERO, MAP_SIZE)
		fog.modulate.a = layer.alpha
		fog.z_index = 7
		add_child(fog)
		fog_layers.append({"node": fog, "velocity": layer.velocity})


func _process(delta: float) -> void:
	for layer in fog_layers:
		var fog: Sprite2D = layer.node
		fog.region_rect.position += layer.velocity * delta


func _build_solids() -> void:
	if has_meta("static_scene"):
		return  # the solids are nodes in the static scene
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(COLLISION_DATA))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[WorldMap] Could not read %s" % COLLISION_DATA)
		return
	for solid in parsed.solids:
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


func _build_zones() -> void:
	for location in GameData.locations.values():
		if location.get("zone") == null:
			continue
		zones.append({"id": location.id, "name": location.name, "zone": location.zone,
			"scene": location.get("scene", ""), "entry": location.get("entry", ""),
			"arrive": location.get("arrive", null)})


func _zone_centre(zone: Dictionary) -> Vector2:
	var z: Array = zone.zone
	return Vector2(z[0] + z[2] / 2.0, z[1] + z[3] / 2.0)


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
	sprite.character_scale = MAP_CHARACTER_SCALE
	player.add_child(sprite)
	add_child(player)
	click_walker = ClickWalker.new(player, Rect2(Vector2.ZERO, MAP_SIZE))
	add_child(click_walker)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(MAP_SIZE.x)
	camera.limit_bottom = int(MAP_SIZE.y)
	player.add_child(camera)
	camera.make_current()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "Evervale"
	title.position = Vector2(12, 8)
	title.add_theme_font_size_override("font_size", 18)
	layer.add_child(title)
	message_label = Label.new()
	message_label.position = Vector2(12, 500)
	message_label.visible = false
	message_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(message_label)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0.0
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	if DEBUG_JUMP:
		_build_jump_menu(layer)


## TESTING ONLY: a dropdown that jumps straight to any scene. Set DEBUG_JUMP to false to hide it.
const DEBUG_JUMP := true
const JUMP_TARGETS := [
	["Town square", "res://scenes/TownSquare.tscn"],
	["Bookstore", "res://scenes/Bookstore.tscn"],
	["Café", "res://scenes/Cafe.tscn"],
	["Florist", "res://scenes/Florist.tscn"],
	["Home courtyard", "res://scenes/ExteriorHome.tscn"],
	["Home ground floor", "res://scenes/HomeFloor1.tscn"],
	["Upstairs bedroom", "res://scenes/BedroomUpstairs.tscn"],
	["Temple courtyard", "res://scenes/TempleCourtyard.tscn"],
	["Temple interior", "res://scenes/TempleInterior.tscn"],
	["Forest", "res://scenes/Forest.tscn"],
	["Cave entrance", "res://scenes/CaveEntrance.tscn"],
	["Cave interior", "res://scenes/CaveInterior.tscn"],
	["World map", "res://scenes/WorldMap.tscn"],
]
var jump_menu: OptionButton


func _build_jump_menu(layer: CanvasLayer) -> void:
	jump_menu = OptionButton.new()
	jump_menu.add_item("Jump to...")
	for target in JUMP_TARGETS:
		jump_menu.add_item(target[0])
	jump_menu.position = Vector2(12, 40)
	jump_menu.size = Vector2(220, 36)
	jump_menu.item_selected.connect(_on_jump_selected)
	layer.add_child(jump_menu)


func _on_jump_selected(index: int) -> void:
	if index == 0 or transitioning:
		return
	var scene_path: String = JUMP_TARGETS[index - 1][1]
	# Leave the spawn empty so each scene uses its own default position.
	SaveSystem.state.pending_spawn = ""
	SaveSystem.save_game()
	transitioning = true
	get_tree().change_scene_to_file(scene_path)


func _arrive_at(place_id: String) -> void:
	var here: Dictionary = {}
	for zone in zones:
		if zone.id == place_id:
			here = zone
	if here.is_empty():
		here = zones[0]
	# Some places are left from their road, not their middle (the Town is left onto the road).
	player.position = _zone_centre(here) if here.arrive == null else Vector2(here.arrive[0], here.arrive[1])
	locked_zone = here.id
	SaveSystem.state.current_location = here.id


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if not transitioning and not HudEvents.screen_open:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# The keys take over from a click walk at once; otherwise a click walk steers.
		if dir != Vector2.ZERO:
			click_walker.cancel()
		elif click_walker.is_walking():
			dir = click_walker.steer(delta)
	move_player(dir)
	_check_zones(delta)


## A left click or tap on the map walks there. A click near a place walks to its entrance and in, coming from the side
## its zone is entered from.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if transitioning or HudEvents.screen_open:
		return
	get_viewport().set_input_as_handled()
	var point := get_global_mouse_position()
	var place := place_at(point)
	if place.is_empty():
		click_walker.go_to(point)
		return
	var z: Array = place.zone
	var centre := _zone_centre(place)
	var via := Vector2.INF
	if place.entry == "south":
		via = Vector2(centre.x, z[1] + z[3] + 14.0)
	click_walker.go_to(centre, false, via)


## The place whose entrance is nearest the point, within PLACE_CLICK_RANGE; empty when none is.
func place_at(point: Vector2) -> Dictionary:
	var best := {}
	var best_d := PLACE_CLICK_RANGE
	for zone in zones:
		var z: Array = zone.zone
		var rect := Rect2(z[0], z[1], z[2], z[3])
		var nearest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
		var d := point.distance_to(nearest)
		if d < best_d:
			best_d = d
			best = zone
	return best


## Moves the player with the given direction. Also used by the headless tests.
func move_player(dir: Vector2) -> void:
	player.velocity = dir * SPEED
	player.move_and_slide()
	sprite.update_movement(dir)


func _check_zones(delta: float) -> void:
	if message_label.visible:
		message_time -= delta
		if message_time <= 0.0:
			message_label.visible = false
	if transitioning:
		return
	for zone in zones:
		var z: Array = zone.zone
		var inside := Rect2(z[0], z[1], z[2], z[3]).has_point(player.position)
		if zone.id == locked_zone:
			if not inside:
				locked_zone = ""
			continue
		if inside and _entered_from_entry_side(zone):
			_enter(zone)
			return
	last_position = player.position


## A zone with an "entry" side only opens when the character comes in from that side.
func _entered_from_entry_side(zone: Dictionary) -> bool:
	if zone.entry == "":
		return true
	var z: Array = zone.zone
	var bottom: float = z[1] + z[3]
	if zone.entry == "south":
		return last_position.y >= bottom
	return true


func _enter(zone: Dictionary) -> void:
	if zone.scene == "":
		_say("%s is not built yet." % zone.name)
		# Do not repeat the message while the player stays in the zone.
		locked_zone = zone.id
		return
	transitioning = true
	SaveSystem.state.current_location = zone.id
	if zone.scene in ["res://scenes/ExteriorHome.tscn", "res://scenes/TempleCourtyard.tscn", "res://scenes/Forest.tscn", "res://scenes/LighthouseFront.tscn"]:
		SaveSystem.state.pending_spawn = "from_map"
	if not (zone.id in SaveSystem.state.discovered_locations):
		SaveSystem.state.discovered_locations.append(zone.id)
	SaveSystem.save_game()
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.25)
	await tween.finished
	get_tree().change_scene_to_file(zone.scene)


func _say(text: String) -> void:
	message_label.text = text
	message_label.visible = true
	message_time = 2.5
