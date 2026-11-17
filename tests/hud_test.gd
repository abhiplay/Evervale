extends SceneTree
## Checks: the HUD components show what they are given (text, icons, counts, keys and states), the navigation
## buttons ask for their screens, the quick slots show the flashlight from the inventory, and the prompt, the
## objective, the place and the notices follow HudEvents. Run: Godot --headless --path . -s res://tests/hud_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.start_new_game()
	var hud = root.get_node("/root/Hud")
	var events = root.get_node("/root/HudEvents")
	check(hud != null and events != null, "the HUD and its events are running")

	print("Components")
	var icon := IconButton.new()
	icon.icon_texture = UiKit.texture(UiAssets.ICON_JOURNAL)
	icon.tooltip_text = "Journal"
	icon.button_action = "journal"
	icon.notification_count = 3
	root.add_child(icon)
	await process_frame
	check(icon._icon.visible, "an icon button shows its icon")
	check(icon._badge.visible and icon._badge._text.text == "3", "a count shows on the badge")
	var pressed: Array = []
	icon.activated.connect(func(action: String): pressed.append(action))
	icon._button.pressed.emit()
	check(pressed == ["journal"], "pressing an icon button reports its action")
	icon.is_enabled = false
	check(icon._button.disabled and icon.modulate.a < 1.0, "a disabled icon button is dimmed and cannot be pressed")
	icon.notification_count = 0
	check(not icon._badge.visible, "a badge hides at zero")
	icon.queue_free()

	var wide := HorizontalButton.new()
	wide.label_text = "Enter House"
	wide.key_binding = "E"
	root.add_child(wide)
	await process_frame
	check(wide._label.text == "Enter House", "a horizontal button shows its words")
	check(wide._keycap.visible and (wide._keycap.get_child(0) as Label).text == "E", "a horizontal button shows its key")
	wide.key_binding = ""
	check(not wide._keycap.visible, "a horizontal button without a key hides the key")
	wide.queue_free()

	var slot := ItemSlot.new()
	root.add_child(slot)
	await process_frame
	check(slot.is_empty and slot._plus.visible, "an empty item slot shows a plus")
	slot.item_texture = UiKit.texture(UiAssets.ICON_MAP)
	slot.item_quantity = 2
	check(not slot.is_empty and not slot._plus.visible, "a slot with an item shows the item, not the plus")
	check(slot._quantity.visible and slot._quantity.text == "2", "a slot shows how many it holds")
	slot.queue_free()

	var location: LocationPanel = hud.location
	events.location_changed.emit("Home", "Chapter 01 – The Arrival")
	check(location._name.text == "Home", "the place name shows")
	check(location._chapter.text == "Chapter 01 – The Arrival", "the chapter shows")

	print("Objective, prompt and notices")
	events.objective_changed.emit("Look around the house", "2 of 11 places checked.", false)
	var objective: ObjectivePanel = hud.objective_panel
	check(objective.objective_title == "Look around the house", "an objective shows its title")
	check(objective.objective_description == "2 of 11 places checked.", "an objective shows its description")
	check(not objective._tick.visible, "an unfinished objective has an empty box")
	events.objective_changed.emit("Look around the house", "Found a box.", true)
	check(objective._tick.visible, "a finished objective ticks its box")
	events.objective_cleared.emit()
	await _wait(hud, 0.6)
	check(not objective.visible, "a cleared objective hides")

	print("The chevron")
	events.objective_changed.emit("Look around the house", "3 of 11 places checked.", false)
	await _wait(hud, 0.4)
	location._toggle()
	await _wait(hud, 0.4)
	check(not objective.expanded and not objective.visible, "the chevron folds the objective away")
	events.objective_changed.emit("Look around the house", "4 of 11 places checked.", false)
	await _wait(hud, 0.4)
	check(not objective.visible, "a folded objective stays hidden when it changes")
	location._toggle()
	await _wait(hud, 0.4)
	check(objective.expanded and objective.visible, "the chevron opens the objective again")
	events.objective_cleared.emit()
	await _wait(hud, 0.4)

	events.interaction_changed.emit("Enter house")
	check(hud.prompt.prompt_text == "Enter house" and hud.prompt.visible, "a prompt shows when something can be done")
	events.interaction_changed.emit("")
	await _wait(hud, 0.4)
	check(not hud.prompt.visible, "the prompt hides when nothing can be done")

	events.notification_requested.emit("Hello there")
	check(hud.notifications._label.text == "Hello there" and hud.notifications.visible, "a notice shows its words")

	print("Navigation and quick slots")
	var journal: IconButton = hud.navigation.buttons["journal"]
	check(journal._label.text == "Journal", "a navigation button is labelled")
	journal._button.pressed.emit()
	check(hud.notifications._label.text == "Coming soon", "a screen that is not built yet says so")
	var slots: Array = hud.quick_slots.slots
	check(slots.size() == 3, "there are three quick slots")
	check(not slots[0].is_empty and slots[0].item_quantity == 1, "the first quick slot holds the flashlight")
	check(slots[0]._key.visible and (slots[0]._key.get_child(0) as Label).text == "Q", "the first quick slot shows its key")
	check(slots[1].is_empty and slots[2].is_empty, "the other quick slots are empty")
	save.add_item("flashlight", 1)
	check(slots[0].item_quantity == 2, "a new item in the inventory updates its slot")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


## Lets the HUD run for a moment, so its fades and tweens finish.
func _wait(node: Node, seconds: float) -> void:
	await node.get_tree().create_timer(seconds).timeout
