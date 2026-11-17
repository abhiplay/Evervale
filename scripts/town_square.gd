class_name TownSquare
extends "res://scripts/exterior_home.gd"
## The Town square: the town courtyard in front of the bookshop, the café and the florist.
## The square is laid out in scenes/TownSquare.tscn, so it can be seen and edited in the 2D tab: the picture, the street
## props (nodes marked "furniture"), the solids (StaticBody2D nodes) and the spawn and exit markers. The shop doors walk
## into their shops. Henry (until First Steps is done; then he is in his café) and Rose are here (data/people.json), the
## Town banner is one of the street props, and the kerb at the bottom goes back to the world map. Talking to a resident
## is remembered (MissionTracker), so meeting Henry completes First Steps.

var dialogue_open := false
var dialogue_panel: Control
var dialogue_label: Label
var dialogue_lines: Array[String] = []

## The dialogue box artwork (assets/ui/dialogue_box.png) and where things sit on it.
const DIALOGUE_ART := "res://assets/ui/dialogue_box.png"
const DIALOGUE_ART_SIZE := Vector2(1953, 586)
const DIALOGUE_WIDTH := 740.0
const TEXT_RECT := Rect2(0.275, 0.37, 0.62, 0.45)
const BUTTON_PLAY := Vector2(1284, 537)
const BUTTON_SKIP := Vector2(1391, 537)
const BUTTON_HIDE := Vector2(1502, 537)
const BUTTON_TOUCH_SIZE := 110.0


func _init() -> void:
	IMAGE_SIZE = Vector2(1671, 941)
	SPAWN_DEFAULT = Vector2(760, 640)
	SPAWNS = {
		"from_map": Vector2(760, 640),
		"from_bookstore": Vector2(333, 500),
		"from_cafe": Vector2(652, 500),
		"from_florist": Vector2(881, 505),
	}
	# The shop doors: walking into one goes inside. The Evervale Emporium's door is not open yet (see _ready).
	EXITS = [
		{"rect": Rect2(300, 466, 66, 16), "scene": "res://scenes/Bookstore.tscn", "spawn": "from_town"},
		{"rect": Rect2(622, 466, 58, 16), "scene": "res://scenes/Cafe.tscn", "spawn": "from_town"},
		{"rect": Rect2(862, 470, 38, 16), "scene": "res://scenes/Florist.tscn", "spawn": "from_town"},
	]
	GATE_RECT = Rect2(680, 700, 140, 45)
	HAS_DOOR = false
	MAP_PLACE = "town_square"
	SCENE_ID = "town_square"


func _ready() -> void:
	# Henry and Rose come from data/people.json (ScenePeople, added by super()); the noticeboard is the square's own.
	super()
	interactables.append({"id": "noticeboard", "pos": Vector2(565, 560), "label": "Noticeboard", "lines": [
		"Lantern Festival is on next month. Volunteers are needed for the stalls.",
		"A lost cat poster, a bake sale and an old photo of the river."]})
	# The Evervale Emporium (the grocery store) is on the right of the square. Its door is not built yet, so it says so.
	interactables.append({"id": "emporium_door", "pos": Vector2(1312, 505), "label": "Evervale Emporium", "lines": [
		"The Evervale Emporium is still being stocked. Its doors open soon."]})
	_build_town_ui()

	SaveSystem.state.current_location = "town_square"
	if not ("town_square" in SaveSystem.state.discovered_locations):
		SaveSystem.state.discovered_locations.append("town_square")
	SaveSystem.save_game()


## The street props are in the scene. Each one is moved into the group sorted with the character, by its base line, and
## gets a soft shadow on the pavement under that base.
func _build_ground() -> void:
	super._build_ground()
	var props: Array = []
	for child in get_children():
		if child.has_meta("furniture"):
			props.append(child)
	for prop in props:
		var base: Vector2 = prop.position
		remove_child(prop)
		_depth_root.add_child(prop)
		var shadow := Sprite2D.new()
		shadow.texture = _shadow_texture()
		shadow.scale = Vector2(prop.texture.get_width() * 0.9 / shadow.texture.get_width(), 0.4)
		shadow.position = base
		shadow.modulate = Color(0, 0, 0, 0.45)
		shadow.z_index = -1
		_depth_root.add_child(shadow)


func _physics_process(delta: float) -> void:
	if dialogue_open:
		move_player(Vector2.ZERO, 0.0)
		_update_nearby()
		return
	super(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _handle_click(event):
		return
	if HudEvents.screen_open:
		return
	if not event.is_action_pressed("interact"):
		return
	if dialogue_open:
		_advance_dialogue()
	elif not nearby.is_empty() and not transitioning:
		_interact(nearby)


## The square's own talk box counts too: no click walking while it is open.
func _click_blocked() -> bool:
	return dialogue_open or super()


func _interact(item: Dictionary) -> void:
	_show_dialogue(item.lines)
	# People count as met (the noticeboard is not one), and their flags are set.
	ScenePeople.talked_to(item)
	SaveSystem.save_game()


# ---------------------------------------------------------------- UI

func _build_town_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_build_dialogue_box(layer)


## The dialogue box artwork at the bottom of the screen, with the text on its dark panel and
## invisible buttons over the play, skip and hide icons drawn into the artwork.
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
	dialogue_label.visible = not dialogue_label.visible
	dialogue_panel.modulate.a = 1.0 if dialogue_label.visible else 0.25


func _show_dialogue(lines: Array) -> void:
	dialogue_lines.clear()
	for line in lines:
		dialogue_lines.append(str(line))
	dialogue_open = true
	dialogue_panel.visible = true
	dialogue_label.text = dialogue_lines[0]
	dialogue_lines.remove_at(0)


func _advance_dialogue() -> void:
	if dialogue_lines.is_empty():
		dialogue_open = false
		dialogue_panel.visible = false
		return
	dialogue_label.text = dialogue_lines[0]
	dialogue_lines.remove_at(0)
