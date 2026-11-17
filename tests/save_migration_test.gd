extends SceneTree
## Checks: a save from before the opening scene plays the opening once, a finished opening stays
## finished, and a test run saves to its own file rather than the player's.
## Run: Godot --headless --path . -s res://tests/save_migration_test.gd

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")

	print("Old saves")
	var old_save := {"current_location": "home", "world_state": {}}
	var migrated: Dictionary = save._migrate(old_save)
	check(migrated.world_state.get("opening_stage", "") == "pending", "a save with no opening stage plays the opening")
	var finished: Dictionary = save._migrate({"world_state": {"opening_stage": "done"}})
	check(finished.world_state.get("opening_stage", "") == "done", "a finished opening stays finished")
	var finished_before_look: Dictionary = save._migrate({"world_state": {"opening_stage": "done"}})
	check(finished_before_look.world_state.get("house_task", "") == "active", "a finished opening from before the look-around starts it")

	print("Test saves")
	check(save.save_path == "user://evervale_test_save.json", "a test run saves to its own file")
	check(save.save_path != "user://evervale_save.json", "a test run never saves to the player's file")
	var absolute_test := ProjectSettings.globalize_path("res://tests/save_migration_test.gd")
	check(ProjectSettings.localize_path(absolute_test) == "res://tests/save_migration_test.gd", "a test given by absolute path is recognised as a test")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
