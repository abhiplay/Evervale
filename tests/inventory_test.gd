extends SceneTree
## Checks: the inventory lists what the save holds, selects an item and shows its words, offers Open Box for a box and
## Read for a letter. Opening the box puts what is inside into the inventory and takes the box out of it. Reading the letter
## shows its picture through the HUD's viewer. A photo offers View, and shows its front. While an item is shown the game
## takes no input. Run:
## Godot --headless --path . -s res://tests/inventory_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	var events = root.get_node("/root/HudEvents")
	var hud = root.get_node("/root/Hud")
	var opened: Array = []
	events.item_opened.connect(func(item_id: String): opened.append(item_id))
	save.start_new_game()
	var inventory = hud.inventory

	print("Listing")
	inventory.show_inventory()
	check(inventory.visible and events.screen_open, "the inventory opens and holds the game's input")
	check(inventory._items == ["flashlight"], "the inventory lists the flashlight")
	check(not inventory._open.visible and not inventory._read.visible, "the flashlight has nothing to open or read")
	inventory.hide_inventory()
	check(not events.screen_open, "closing the inventory gives the game its input back")

	print("The box")
	save.add_item("hidden_box", 1)
	inventory.show_inventory()
	check(inventory._items.size() == 2, "the box is listed once it is in the inventory")
	inventory._select(inventory._items.find("hidden_box"))
	check(inventory._name.text == "Hidden Box", "selecting the box shows its name")
	check(inventory._open.visible and not inventory._read.visible, "the box offers Open Box and no Read")
	inventory._on_choice("open")
	check(not inventory.visible, "Open Box closes the inventory")
	check(not hud.viewer.visible, "opening the box shows nothing: the contents go into the inventory")
	check(opened == ["hidden_box"], "the HUD reports the box as opened")
	check(save.state.opened_items.get("hidden_box", false), "the box is recorded as opened")
	check(not save.state.inventory.has("hidden_box"), "the box is taken out of the inventory")
	check(save.state.inventory.get("letter_arthur", 0) == 1, "the letter goes into the inventory")
	check(save.state.inventory.get("photo_box", 0) == 1, "the photo goes into the inventory")
	check(not events.screen_open, "the game has its input back after opening the box")

	print("The letter")
	inventory.show_inventory()
	inventory._select(inventory._items.find("letter_arthur"))
	check(inventory._name.text == "A letter", "selecting the letter shows its name")
	check(inventory._read.visible and not inventory._open.visible, "the letter offers Read and no Open Box")
	check(inventory._read._words.text == "Read", "the letter's button says Read")
	inventory._on_choice("read")
	check(not inventory.visible, "Read closes the inventory")
	check(hud.viewer.visible and events.screen_open, "the letter shows in the viewer and holds the game's input")
	check(hud.viewer._picture.texture != null, "the letter's picture is loaded")
	hud.viewer.close()
	await process_frame
	check(not hud.viewer.visible and not events.screen_open, "closing the letter gives the game its input back")

	print("The photo")
	inventory.show_inventory()
	inventory._select(inventory._items.find("photo_box"))
	check(inventory._name.text == "A photo", "selecting the photo shows its name")
	check(inventory._read.visible and not inventory._open.visible, "the photo offers View and no Open Box")
	check(inventory._read._words.text == "View", "the photo's button says View, not Read")
	inventory._on_choice("read")
	check(not inventory.visible, "View closes the inventory")
	check(hud.viewer.visible and events.screen_open, "the photo shows in the viewer and holds the game's input")
	check(hud.viewer._photo_picture.texture.resource_path == "res://assets/items/photo_box_front.webp", "the photo shows its front")
	hud.viewer.close()
	await process_frame
	check(not hud.viewer.visible and not events.screen_open, "closing the photo gives the game its input back")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
