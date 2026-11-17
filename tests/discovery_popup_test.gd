extends SceneTree
## Checks: the New Discovery popup shows the item first, offers the choice after a moment, reports the choice the
## player makes, and ignores a second choice. Run: Godot --headless --path . -s res://tests/discovery_popup_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	# Loaded at run time, because the popup uses the HudEvents autoload.
	var popup_script = load("res://scripts/ui/discovery_popup.gd")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var popup = popup_script.new()
	layer.add_child(popup)
	await process_frame
	var item := {
		"name": "Hidden Box",
		"description": "A strange, handcrafted box concealed beneath the floorboards.",
		"icon": "res://assets/ui/hud/Icons/hidden_box.png",
	}
	var chosen: Array = []
	popup.choice_made.connect(func(choice: String): chosen.append(choice))

	print("Showing the item")
	popup.show_discovery(item)
	check(popup.visible and popup._stage == 2, "the popup shows the item first")
	check(popup._name.text == "Hidden Box", "the item's name shows")
	check(popup._icon.texture != null, "the item's picture shows")
	check(popup._description.text.begins_with("A strange"), "the item's words show")
	check(popup._hint.visible and not popup._choices.visible, "no choice is offered yet")

	print("The choice")
	await create_timer(2.0).timeout
	check(popup._stage == 3, "after a moment the choice is offered")
	check(popup._choices.visible and not popup._hint.visible and not popup._description.visible and popup._icon.visible, "the choice replaces the words, and the item keeps floating")
	check(popup._buttons["open"]._glow.visible and not popup._buttons["leave"]._glow.visible, "only Open Box starts lit")
	popup._choose("open")
	check(chosen == ["open"], "the choice the player makes is reported")
	popup._choose("leave")
	check(chosen.size() == 1, "a second choice is ignored")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
