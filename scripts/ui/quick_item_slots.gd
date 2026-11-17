class_name QuickItemSlots
extends HBoxContainer
## The three quick-access slots at the bottom left. The layout in data/hud.json says what each slot holds, and the
## slot shows how many the inventory has. Pressing a slot emits `slot_activated` with its number.

signal slot_activated(slot_index: int)

const SLOT_COUNT := 3
## The first slot, the flashlight's, is drawn larger than the others, as in the reference.
const FEATURED_SCALE := 1.3

var slots: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in SLOT_COUNT:
		var slot := ItemSlot.new()
		slot.slot_index = i
		slot.activated.connect(func(index: int): slot_activated.emit(index))
		add_child(slot)
		slot.size_flags_vertical = Control.SIZE_SHRINK_END
		if i == 0:
			slot.custom_minimum_size = ItemSlot.SIZE * FEATURED_SCALE
		slots.append(slot)
	refresh()


## Fills each slot from the inventory: the item the layout gives it, and how many the player has.
func refresh() -> void:
	var layout: Array = UiData.quick_slots()
	var keys: Array = UiData.quick_keys()
	var inventory: Dictionary = SaveSystem.state.inventory
	for i in slots.size():
		var slot: ItemSlot = slots[i]
		slot.key_hint = str(keys[i]) if i < keys.size() else ""
		var item_id: String = str(layout[i]) if i < layout.size() else ""
		var count := int(inventory.get(item_id, 0)) if item_id != "" else 0
		if count > 0:
			var icon_path: String = UiData.item(item_id).get("icon", "")
			slot.item_texture = UiKit.texture(icon_path) if ResourceLoader.exists(icon_path) else null
			slot.item_quantity = count
		else:
			slot.item_texture = null
			slot.item_quantity = 0
