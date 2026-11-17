class_name MainHUD
extends CanvasLayer
## The HUD for exploring: the place and the objective at the top left, the four navigation buttons at the top right,
## the quick slots at the bottom left, and the prompt and notices at the bottom centre. It also owns the inventory screen
## and the viewer that shows a letter or a photo. It listens to HudEvents, so gameplay never calls it directly. Its corners
## hide on the title screen. Autoloaded as Hud.

const TITLE_SCENE := "res://scenes/StartScreen.tscn"
const MARGIN := 14

var location: LocationPanel
var objective_panel: ObjectivePanel
var navigation: NavigationBar
var quick_slots: QuickItemSlots
var prompt: InteractionPrompt
var notifications: NotificationSystem
var inventory: InventoryScreen
var viewer: ItemViewer
var floor_map: FloorMap
var _corners: Control


func _ready() -> void:
	layer = 5
	_corners = Control.new()
	_corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(_corners))
	location = LocationPanel.new()
	objective_panel = ObjectivePanel.new()
	navigation = NavigationBar.new()
	quick_slots = QuickItemSlots.new()
	prompt = InteractionPrompt.new()
	notifications = NotificationSystem.new()

	var top_left := VBoxContainer.new()
	top_left.add_theme_constant_override("separation", 14)
	_add_region(_corners, top_left)
	top_left.add_child(_shrink_start(location))
	top_left.add_child(_shrink_start(objective_panel))
	location.expand_toggled.connect(objective_panel.set_expanded)

	var top_right := HBoxContainer.new()
	top_right.alignment = BoxContainer.ALIGNMENT_END
	_add_region(_corners, top_right)
	navigation.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_right.add_child(navigation)

	var bottom_left := VBoxContainer.new()
	bottom_left.alignment = BoxContainer.ALIGNMENT_END
	_add_region(_corners, bottom_left)
	bottom_left.add_child(_shrink_start(quick_slots))

	var bottom_centre := VBoxContainer.new()
	bottom_centre.alignment = BoxContainer.ALIGNMENT_END
	bottom_centre.add_theme_constant_override("separation", 8)
	_add_region(_corners, bottom_centre)
	notifications.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom_centre.add_child(notifications)
	prompt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom_centre.add_child(prompt)

	# The inventory and the item viewer sit above the corners, and stay usable on the title screen.
	var screens := CanvasLayer.new()
	screens.layer = 21
	add_child(screens)
	inventory = InventoryScreen.new()
	screens.add_child(inventory)
	viewer = ItemViewer.new()
	screens.add_child(viewer)
	floor_map = FloorMap.new()
	screens.add_child(floor_map)

	HudEvents.location_changed.connect(_on_location_changed)
	HudEvents.objective_changed.connect(objective_panel.show_objective)
	HudEvents.objective_cleared.connect(objective_panel.hide_objective)
	HudEvents.interaction_changed.connect(_on_interaction_changed)
	HudEvents.inventory_changed.connect(quick_slots.refresh)
	HudEvents.notification_requested.connect(notifications.show_text)
	HudEvents.screen_requested.connect(_on_screen_requested)
	HudEvents.item_open_requested.connect(_open_item)
	HudEvents.item_view_requested.connect(_view_item)
	HudEvents.dialogue_changed.connect(_on_dialogue_changed)
	HudEvents.places_changed.connect(objective_panel.show_places)
	quick_slots.slot_activated.connect(_on_slot_activated)
	quick_slots.refresh()


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	# The HUD steps aside while a conversation is on the full-screen stage.
	_corners.visible = scene != null and scene.scene_file_path != TITLE_SCENE and not HudEvents.dialogue_stage


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I):
		return
	if _corners.visible and not inventory.visible and not viewer.visible and not HudEvents.screen_open:
		get_viewport().set_input_as_handled()
		inventory.show_inventory()


## Puts a container over the whole screen, inset by the margin, so its contents sit in one corner.
func _add_region(root: Control, content: Container) -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, MARGIN)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(UiKit.fill(content))
	root.add_child(UiKit.fill(margin))


func _shrink_start(node: Control) -> Control:
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return node


func _on_location_changed(location_name: String, chapter_name: String) -> void:
	location.location_name = location_name
	location.chapter_name = chapter_name
	location.location_icon = UiKit.texture(UiAssets.ICON_HOME)


func _on_interaction_changed(text: String) -> void:
	prompt.prompt_text = text


## The inventory opens for its own button, and for the popup's "View in Inventory". The map opens indoors only; the other
## screens are not built yet.
func _on_screen_requested(screen_id: String) -> void:
	if screen_id == "inventory":
		if not inventory.visible:
			inventory.show_inventory()
	elif screen_id == "map":
		_on_map_requested()
	else:
		notifications.show_text("Coming soon")


## The Map button: closes the map if it is open. Inside a building it opens that building's plan, with the room the
## protagonist is in. Anywhere else there is no plan, and the notice says so.
func _on_map_requested() -> void:
	if floor_map.visible:
		floor_map.close()
		return
	if HudEvents.screen_open:
		return
	var scene := get_tree().current_scene
	var scene_id: String = str(scene.get("SCENE_ID")) if scene != null and scene.get("SCENE_ID") != null else ""
	var plan := FloorPlan.for_scene(scene_id)
	if plan.is_empty():
		notifications.show_text("Coming soon")
		return
	floor_map.show_plan(plan, FloorPlan.room_id_for_scene(scene_id))


func _on_slot_activated(_slot_index: int) -> void:
	notifications.show_text("Nothing to use here yet.")


## The quick slots leave the screen while a talk box is up, so they do not cover it.
func _on_dialogue_changed(is_open: bool) -> void:
	quick_slots.visible = not is_open


## Opening a box puts what is inside into the inventory, and takes the box out of it. The notice says what was added.
func _open_item(item_id: String) -> void:
	var names: Array = []
	for content_id in UiData.item(item_id).get("contents", []):
		SaveSystem.add_item(content_id)
		names.append(UiData.item(content_id).get("name", content_id))
	SaveSystem.state.inventory.erase(item_id)
	SaveSystem.state.opened_items[item_id] = true
	SaveSystem.save_game()
	if not names.is_empty():
		HudEvents.notification_requested.emit("Added to your inventory: " + ", ".join(PackedStringArray(names)))
	HudEvents.inventory_changed.emit()
	HudEvents.item_opened.emit(item_id)


## Reads a letter or a photo from the inventory: its views are shown one after another. The game takes no movement and
## no E while they are up.
func _view_item(item_id: String) -> void:
	HudEvents.screen_open = true
	for entry in UiData.item(item_id).get("view", []):
		viewer.show_item(entry)
		await viewer.closed
	HudEvents.screen_open = false
