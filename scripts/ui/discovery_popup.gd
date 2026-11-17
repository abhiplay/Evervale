class_name DiscoveryPopup
extends Control
## The "New Discovery" chat. The place where the item was found stays on screen behind it, dimmed, and the item floats in
## the middle of it, bobbing gently. Its name and words, and then the choice (Open Box, or Leave it where it is), sit in the
## dialogue box at the bottom, the same box the rest of the game talks in. The item is shown first for a moment, then the
## choice. Built from the discovery art in assets/ui/hud/Discovery and the dialogue box art in assets/ui/dialogue_box.png.

signal choice_made(choice: String)

const CHOICE_DELAY := 1.5
const INVENTORY_KEY := KEY_I
const MUTED := Color(0.86, 0.8, 0.68)
const DIALOGUE_ART := "res://assets/ui/dialogue_box.png"
const DIALOGUE_ART_SIZE := Vector2(1953, 586)
## The dialogue box is at most this wide, and never wider than the screen less a margin.
const BOX_MAX_WIDTH := 900.0
const BOX_MARGIN := 20.0
## The item floats above the middle of the scene, and bobs this far up and down.
const FLOAT_HEIGHT := 0.3
const FLOAT_SIDE := 220.0
const FLOAT_BOB := 12.0
## The captured scene behind the chat is dimmed to this.
const DIM := Color(0.42, 0.42, 0.5, 1.0)

## 0 hidden, 2 showing the item, 3 waiting for the choice.
var _stage := 0
var _choice := "open"
var _backdrop: TextureRect
var _content: Control
var _float: Control
var _glow: TextureRect
var _icon: TextureRect
var _box: Control
var _name: Label
var _description: Label
var _hint: HBoxContainer
var _choices: HBoxContainer
var _divider: DecorativeDivider
var _buttons := {}
var _fade: Tween
var _bob: Tween
## The nodes of the reading step: the item, its words and the hint. The choice step hides them.
var _reading_nodes: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_backdrop = TextureRect.new()
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.modulate = DIM
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_float = Control.new()
	_float.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_float)
	_glow = UiKit.picture(UiKit.texture(UiAssets.DISCOVERY_GLOW))
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float.add_child(_glow)
	_icon = UiKit.picture(null)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float.add_child(_icon)

	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_box)
	var art := UiKit.fill(UiKit.picture(UiKit.texture(DIALOGUE_ART)))
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(art)

	_name = UiKit.label(26, UiKit.GOLD)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_name)
	_description = UiKit.label(16, MUTED)
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_description)
	_divider = DecorativeDivider.new()
	_box.add_child(_divider)

	_hint = HBoxContainer.new()
	_hint.alignment = BoxContainer.ALIGNMENT_CENTER
	_hint.add_theme_constant_override("separation", 8)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(UiKit.keycap("I", 26.0))
	var hint_words := UiKit.label(16, UiKit.CREAM)
	hint_words.text = "View in Inventory"
	_hint.add_child(hint_words)
	_box.add_child(_hint)

	_choices = HBoxContainer.new()
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 16)
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choices.add_child(_make_choice("Open Box", "open"))
	_choices.add_child(_make_choice("Leave", "leave"))
	_box.add_child(_choices)
	_choices.visible = false
	# The item keeps floating and its name stays up while the choice is offered; the words and the hint give way to it.
	_reading_nodes = [_description, _divider, _hint]


## Shows the item found, then, after a moment, the choice. `item` is an entry of data/items.json. The place behind the
## chat is captured first, so the item floats over where it was found.
func show_discovery(item: Dictionary) -> void:
	var view := get_viewport_rect().size
	_backdrop.texture = _snapshot()
	position = Vector2.ZERO
	size = view
	_backdrop.position = Vector2.ZERO
	_backdrop.size = view
	_content.position = Vector2.ZERO
	_content.size = view
	_layout(view)
	_name.text = item.get("name", "")
	_description.text = item.get("description", "")
	var icon_path: String = item.get("icon", "")
	_icon.texture = UiKit.texture(icon_path) if ResourceLoader.exists(icon_path) else null
	_set_reading(true)
	_stage = 2
	visible = true
	modulate.a = 0.0
	_content.position = Vector2(0, 8)
	if _fade:
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(self, "modulate:a", 1.0, 0.3)
	_fade.tween_property(_content, "position", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_start_bobbing()
	var timer := create_tween()
	timer.tween_interval(CHOICE_DELAY)
	timer.tween_callback(_show_choices)


## The scene as it is on screen now, to sit dimmed behind the chat. None when the renderer gives no picture (headless).
func _snapshot() -> Texture2D:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


## The item floats above the middle of the scene, the glow turns behind it, and the dialogue box sits along the bottom.
func _layout(view: Vector2) -> void:
	var side := minf(FLOAT_SIDE, view.y * 0.33)
	var centre := Vector2(view.x / 2.0, view.y * FLOAT_HEIGHT)
	_float.position = centre - Vector2(side, side) / 2.0
	_float.size = Vector2(side, side)
	_glow.position = Vector2(-side * 0.35, -side * 0.35)
	_glow.size = Vector2(side * 1.7, side * 1.7)
	_icon.position = Vector2.ZERO
	_icon.size = Vector2(side, side)
	var width := minf(BOX_MAX_WIDTH, view.x - BOX_MARGIN * 2.0)
	var height := width * DIALOGUE_ART_SIZE.y / DIALOGUE_ART_SIZE.x
	_box.size = Vector2(width, height)
	_box.position = Vector2((view.x - width) / 2.0, view.y - height - BOX_MARGIN * 0.6)
	# Inside the box, on its banner: the name, the words, a divider, then the choice (or the hint) with the two buttons side by side.
	_place(_name, Rect2(width * 0.22, height * 0.3, width * 0.56, height * 0.12))
	_place(_description, Rect2(width * 0.22, height * 0.42, width * 0.56, height * 0.14))
	_place(_divider, Rect2(width * 0.3, height * 0.58, width * 0.4, height * 0.04))
	_place(_hint, Rect2(width * 0.22, height * 0.64, width * 0.56, height * 0.26))
	_place(_choices, Rect2(width * 0.22, height * 0.64, width * 0.56, height * 0.26))


func _start_bobbing() -> void:
	if _bob:
		_bob.kill()
	var base := _float.position
	_bob = create_tween().set_loops()
	_bob.tween_property(_float, "position", base + Vector2(0, -FLOAT_BOB), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(_float, "position", base, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _show_choices() -> void:
	if _stage != 2:
		return
	_stage = 3
	_set_reading(false)
	_buttons["open"].focus_button.call_deferred()


## The reading step shows the item and its words; the choice step shows the two choices instead.
func _set_reading(reading: bool) -> void:
	for node in _reading_nodes:
		node.visible = reading
	_choices.visible = not reading


func _choose(choice: String) -> void:
	if _stage != 3:
		return
	_stage = 0
	if _bob:
		_bob.kill()
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, 0.25)
	_fade.tween_callback(func(): visible = false)
	choice_made.emit(choice)


func _make_choice(text: String, value: String) -> ChoiceButton:
	var button := ChoiceButton.new()
	button.setup(text, value)
	button.pressed_choice.connect(_choose)
	button.focused_choice.connect(_on_focused)
	_buttons[value] = button
	return button


func _on_focused(value: String) -> void:
	_choice = value


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _stage == 0 or HudEvents.screen_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == INVENTORY_KEY:
		get_viewport().set_input_as_handled()
		HudEvents.screen_requested.emit("inventory")
	elif _stage == 3 and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_choose(_choice)


func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size
