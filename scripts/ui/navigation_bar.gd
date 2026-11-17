class_name NavigationBar
extends HBoxContainer
## The four square buttons at the top right: Journal, Inventory, Map and Settings. Each one asks the game for its
## screen through HudEvents. Buttons can show a count with `notification_count`.

const BUTTONS := [
	["journal", "Journal", UiAssets.ICON_JOURNAL],
	["inventory", "Inventory", UiAssets.ICON_INVENTORY],
	["map", "Map", UiAssets.ICON_MAP],
	["settings", "Settings", UiAssets.ICON_SETTINGS],
]

var buttons := {}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry in BUTTONS:
		var button := IconButton.new()
		button.button_action = entry[0]
		button.label_text = entry[1]
		button.tooltip_text = entry[1]
		button.icon_texture = UiKit.texture(entry[2])
		button.activated.connect(_on_activated)
		add_child(button)
		buttons[entry[0]] = button


func _on_activated(action: String) -> void:
	HudEvents.screen_requested.emit(action)
