class_name DiscoveryPopup
extends Control
## The "New Discovery" popup. It first shows the item found, with its picture and words, for a moment. Then it offers
## the choice: Open Box, or Leave it where it is. Built from the discovery art in assets/ui/hud/Discovery. The title
## and the words are drawn here, so none of them is baked into a picture.

signal choice_made(choice: String)

const SIZE := Vector2(340, 370)
const CHOICE_DELAY := 1.5
const INVENTORY_KEY := KEY_I
const MUTED := Color(0.86, 0.8, 0.68)

## 0 hidden, 2 showing the item, 3 waiting for the choice.
var _stage := 0
var _choice := "open"
var _content: Control
var _icon: TextureRect
var _name: Label
var _description: Label
var _hint: HBoxContainer
var _choices: VBoxContainer
var _buttons := {}
var _fade: Tween
## The nodes of the reading step: the item, its words and the hint. The choice step hides them.
var _reading_nodes: Array = []


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_content = UiKit.fill(Control.new())
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_content.add_child(UiKit.fill(UiKit.picture(UiKit.texture(UiAssets.DISCOVERY_FRAME))))
	var glow := UiKit.picture(UiKit.texture(UiAssets.DISCOVERY_GLOW))
	_place(glow, Rect2(20, 50, 300, 150))
	_content.add_child(glow)
	_icon = UiKit.picture(null)
	_place(_icon, Rect2(60, 72, 220, 160))
	_content.add_child(_icon)

	var title := UiKit.label(24, UiKit.GOLD)
	title.text = "New Discovery"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(title, Rect2(0, 26, 340, 30))
	_content.add_child(title)
	_name = UiKit.label(22, UiKit.CREAM)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_name, Rect2(0, 232, 340, 30))
	_content.add_child(_name)
	_description = UiKit.label(14, MUTED)
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_description, Rect2(40, 262, 260, 44))
	_content.add_child(_description)
	var divider := DecorativeDivider.new()
	_place(divider, Rect2(40, 312, 260, 12))
	_content.add_child(divider)

	_hint = HBoxContainer.new()
	_hint.alignment = BoxContainer.ALIGNMENT_CENTER
	_hint.add_theme_constant_override("separation", 8)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(UiKit.keycap("I", 26.0))
	var hint_words := UiKit.label(16, UiKit.CREAM)
	hint_words.text = "View in Inventory"
	_hint.add_child(hint_words)
	_place(_hint, Rect2(0, 326, 340, 30))
	_content.add_child(_hint)

	_choices = VBoxContainer.new()
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 12)
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choices.add_child(_make_choice("Open Box", "open"))
	_choices.add_child(_make_choice("Leave", "leave"))
	_place(_choices, Rect2(0, 128, 340, 130))
	_choices.visible = false
	_content.add_child(_choices)
	_reading_nodes = [glow, _icon, _name, _description, divider, _hint]


## Shows the item found, then, after a moment, the choice. `item` is an entry of data/items.json.
func show_discovery(item: Dictionary) -> void:
	_name.text = item.get("name", "")
	_description.text = item.get("description", "")
	var icon_path: String = item.get("icon", "")
	_icon.texture = UiKit.texture(icon_path) if ResourceLoader.exists(icon_path) else null
	_set_reading(true)
	_stage = 2
	_center()
	visible = true
	modulate.a = 0.0
	_content.position = Vector2(0, 8)
	if _fade:
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(self, "modulate:a", 1.0, 0.3)
	_fade.tween_property(_content, "position", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var timer := create_tween()
	timer.tween_interval(CHOICE_DELAY)
	timer.tween_callback(_show_choices)


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


func _center() -> void:
	position = (get_viewport_rect().size - SIZE) / 2.0


func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size
