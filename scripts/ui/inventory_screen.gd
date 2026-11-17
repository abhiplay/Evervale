class_name InventoryScreen
extends Control
## The inventory: what Amelia carries, from the save. The title and the close cross sit at the top, the category tabs
## under them. The items of the chosen tab fill a grid on the left, and the detail panel on the right shows the selected
## item: its picture, name, category and words. A box offers Open Box, which puts what is inside into the inventory. A
## letter offers Read and a photo offers View, which show it in the viewer. It opens from the Inventory button, the I key
## or the discovery popup, and closes with the cross, Esc or I. While it is open, gameplay does not take movement or E.

## The tabs across the top, in order. "all" shows every item; the others show the items whose category in data/items.json
## is that id. The tag is the category's name on the detail panel.
const CATEGORIES := [
	{"id": "all", "tab": "All", "tag": ""},
	{"id": "key", "tab": "Key Items", "tag": "Key Item"},
	{"id": "documents", "tab": "Documents", "tag": "Document"},
	{"id": "clues", "tab": "Clues", "tag": "Clue"},
	{"id": "personal", "tab": "Personal", "tag": "Personal Item"},
]
const SIZE := Vector2(800, 490)
const TITLE_SIZE := Vector2(290, 75)
const TAB_HEIGHT := 36.0
const GRID_COLUMNS := 5
const GRID_MIN_SLOTS := 20
const CELL_SIZE := Vector2(76, 70)
const CELL_GAP := 10
const MUTED := Color(0.86, 0.8, 0.68)
const PANEL_FILL := Color(0.165, 0.114, 0.082, 0.97)
const PANEL_EDGE := Color("#c9a25a")

var _panel: Control
var _tabs := {}
var _grid: GridContainer
var _slots: Array = []
var _detail: Control
var _detail_nodes: Array = []
var _glow: TextureRect
var _picture: TextureRect
var _name: Label
var _tag: Panel
var _tag_words: Label
var _description: Label
var _empty_words: Label
var _open: ChoiceButton
var _read: ChoiceButton
var _items: Array = []
var _category := "all"
var _selected := ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(shade))

	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -SIZE.x / 2.0
	_panel.offset_top = -SIZE.y / 2.0
	_panel.offset_right = SIZE.x / 2.0
	_panel.offset_bottom = SIZE.y / 2.0
	add_child(_panel)
	var edge := Panel.new()
	edge.add_theme_stylebox_override("panel", _panel_style())
	_panel.add_child(UiKit.fill(edge))

	_build_title()
	_build_tabs()
	_build_grid()
	_build_detail()
	HudEvents.inventory_changed.connect(_on_inventory_changed)
	_refresh_tabs()
	_select(-1)


## The screen covers the whole viewport. It is sized from the viewport, because anchors alone left it at zero size under the
## screens layer, and the panel was then centred on the top-left corner.
func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func show_inventory() -> void:
	refresh()
	visible = true
	HudEvents.screen_open = true
	var tab: ChoiceButton = _tabs[_category]
	tab.focus_button.call_deferred()


func hide_inventory() -> void:
	visible = false
	HudEvents.screen_open = false


## Lists the items of the chosen tab from the save and fills the grid with them. The selected item stays selected if it is
## still listed; otherwise the first item is selected.
func refresh() -> void:
	var inventory: Dictionary = SaveSystem.state.inventory
	_items = []
	for item_id in inventory:
		if int(inventory[item_id]) > 0 and _in_category(item_id):
			_items.append(item_id)
	_build_slots(inventory)
	var keep := _items.find(_selected)
	_select(keep if keep >= 0 else (0 if not _items.is_empty() else -1))


## Selects the item at this index of the chosen tab, and shows it on the detail panel. An index with no item clears the
## selection and shows the prompt to select one.
func _select(index: int) -> void:
	_selected = _items[index] if index >= 0 and index < _items.size() else ""
	for i in _slots.size():
		_slots[i].is_selected = i == index and _selected != ""
	var has_item := _selected != ""
	var item := UiData.item(_selected)
	for node in _detail_nodes:
		node.visible = has_item
	_empty_words.visible = not has_item
	_open.visible = has_item and item.has("contents") and not SaveSystem.state.opened_items.get(_selected, false)
	_read.visible = has_item and item.has("view")
	if has_item:
		_read.set_text("View" if _is_photo(item) else "Read")
		_picture.texture = _texture_of(_selected)
		_name.text = item.get("name", _selected)
		var tag := _tag_text(item.get("category", ""))
		_tag.visible = tag != ""
		_tag_words.text = tag
		_description.text = item.get("description", "")


## Opens a box, which puts what is inside into the inventory, or reads a letter or a photo through the viewer. Either way
## the inventory closes first.
func _on_choice(value: String) -> void:
	if _selected == "":
		return
	if value == "open":
		hide_inventory()
		HudEvents.item_open_requested.emit(_selected)
	elif value == "read":
		hide_inventory()
		HudEvents.item_view_requested.emit(_selected)


func _set_category(category_id: String) -> void:
	_category = category_id
	_refresh_tabs()
	refresh()


func _refresh_tabs() -> void:
	for id in _tabs:
		_tabs[id].is_chosen = id == _category


func _on_inventory_changed() -> void:
	if visible:
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var inventory_key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I
	if event.is_action_pressed("ui_cancel") or inventory_key:
		get_viewport().set_input_as_handled()
		hide_inventory()


func _in_category(item_id: String) -> bool:
	return _category == "all" or UiData.item(item_id).get("category", "") == _category


func _tag_text(category_id: String) -> String:
	for category in CATEGORIES:
		if category["id"] == category_id:
			return category["tag"]
	return ""


## A photo is viewed rather than read, so its button says View.
func _is_photo(item: Dictionary) -> bool:
	var views: Array = item.get("view", [])
	if views.is_empty():
		return false
	var first: Dictionary = views[0]
	return String(first.get("type", "")) == "photo"


func _texture_of(item_id: String) -> Texture2D:
	var icon_path: String = UiData.item(item_id).get("icon", "")
	return UiKit.texture(icon_path) if ResourceLoader.exists(icon_path) else null


func _build_slots(inventory: Dictionary) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_slots = []
	for index in maxi(GRID_MIN_SLOTS, _items.size()):
		var slot := ItemSlot.new()
		slot.slot_size = CELL_SIZE
		slot.slot_index = index
		slot.show_plus = false
		if index < _items.size():
			var item_id: String = _items[index]
			slot.item_texture = _texture_of(item_id)
			slot.item_quantity = int(inventory[item_id])
		slot.activated.connect(_select)
		_grid.add_child(slot)
		_slots.append(slot)


func _build_title() -> void:
	var banner_at := Vector2((SIZE.x - TITLE_SIZE.x) / 2.0, 14.0)
	var banner := UiKit.picture(UiKit.texture(UiAssets.BANNER))
	_place(banner, Rect2(banner_at, TITLE_SIZE))
	_panel.add_child(banner)
	var medallion := UiKit.picture(UiKit.texture(UiAssets.ICON_INVENTORY))
	_place(medallion, Rect2(banner_at + Vector2(23, 17), Vector2(40, 40)))
	_panel.add_child(medallion)
	var title := UiKit.label(28, UiKit.GOLD)
	title.text = "Inventory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(title, Rect2(banner_at + Vector2(80, 0), Vector2(TITLE_SIZE.x - 80, TITLE_SIZE.y)))
	_panel.add_child(title)
	_add_close()


## The close cross sits at the top right of the panel, and closes the inventory.
func _add_close() -> void:
	var close := CloseCross.new()
	close.pressed.connect(hide_inventory)
	_place(close, Rect2(SIZE.x - 64, 20, CloseCross.SIZE.x, CloseCross.SIZE.y))
	_panel.add_child(close)


func _build_tabs() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(row, Rect2(30, 104, 740, TAB_HEIGHT))
	for category in CATEGORIES:
		var tab := ChoiceButton.new()
		tab.setup(category["tab"], category["id"], UiAssets.TAB_ICONS[category["id"]], 17)
		tab.custom_minimum_size = Vector2(0, TAB_HEIGHT)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed_choice.connect(_set_category)
		row.add_child(tab)
		_tabs[category["id"]] = tab
	_panel.add_child(row)


func _build_grid() -> void:
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", CELL_GAP)
	_grid.add_theme_constant_override("v_separation", CELL_GAP)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(_grid)
	_place(scroll, Rect2(30, 150, 432, 310))
	_panel.add_child(scroll)


func _build_detail() -> void:
	_detail = Control.new()
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_detail, Rect2(482, 150, 288, 310))
	_panel.add_child(_detail)
	_detail.add_child(UiKit.fill(UiKit.picture(UiKit.texture(UiAssets.DISCOVERY_FRAME))))
	_glow = UiKit.picture(UiKit.texture(UiAssets.DISCOVERY_GLOW))
	_place(_glow, Rect2(30, 14, 228, 110))
	_picture = UiKit.picture(null)
	_place(_picture, Rect2(44, 26, 200, 90))
	_name = UiKit.label(22, UiKit.CREAM)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_name, Rect2(10, 122, 268, 26))
	_tag = Panel.new()
	_tag.add_theme_stylebox_override("panel", _tag_style())
	_place(_tag, Rect2(84, 152, 120, 20))
	_tag_words = UiKit.label(13, UiKit.GOLD)
	_tag_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag.add_child(UiKit.fill(_tag_words))
	var divider := DecorativeDivider.new()
	_place(divider, Rect2(34, 180, 220, 12))
	_description = UiKit.label(13, MUTED)
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_description, Rect2(22, 196, 244, 46))
	_open = ChoiceButton.new()
	_open.setup("Open Box", "open")
	_open.custom_minimum_size = Vector2(170, 34)
	_open.pressed_choice.connect(_on_choice)
	_place(_open, Rect2(59, 248, 170, 34))
	_read = ChoiceButton.new()
	_read.setup("Read", "read")
	_read.custom_minimum_size = Vector2(170, 34)
	_read.pressed_choice.connect(_on_choice)
	_place(_read, Rect2(59, 248, 170, 34))
	_empty_words = UiKit.label(16, MUTED)
	_empty_words.text = "Select an item to view its details."
	_empty_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_empty_words, Rect2(28, 100, 232, 90))
	_detail_nodes = [_glow, _picture, _name, _tag, divider, _description]
	for node in [_glow, _picture, _name, _tag, divider, _description, _open, _read, _empty_words]:
		_detail.add_child(node)


static func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_FILL
	style.border_color = PANEL_EDGE
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 14
	return style


static func _tag_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.03, 0.9)
	style.border_color = UiKit.GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size
