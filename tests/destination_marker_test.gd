extends SceneTree
## Checks the destination marker (DestinationMarker, data/destinations.json): on the world map it sits on the destination's
## zone; in a scene it sits at the way in (the door, the shop's exit, or the gate); it is hidden where the destination is
## reached; and the objective's destination is the one the mission step names. Run:
## Godot --headless --path . -s res://tests/destination_marker_test.gd

var failures: Array[String] = []
## The marker's script, loaded once the autoloads exist (a class_name reference would not compile in a -s test).
var MARKER
var TRACKER


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	MARKER = load("res://scripts/destination_marker.gd")
	TRACKER = load("res://scripts/mission_tracker.gd")
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	var plain := Node2D.new()

	print("On the world map")
	var town_on_map: Dictionary = MARKER.resolve(plain, true, "town_square")
	check(town_on_map.get("position", Vector2.ZERO).is_equal_approx(Vector2(788, 703)), "Town Square sits on its zone on the map")
	check(town_on_map.get("label", "") == "Town Square", "the label is the destination's name")
	var home_on_map: Dictionary = MARKER.resolve(plain, true, "home")
	check(home_on_map.get("position", Vector2.ZERO).is_equal_approx(Vector2(685, 488)), "Home sits on its zone on the map")
	check(MARKER.resolve(plain, true, "cafe").is_empty(), "the café is inside the Town Square, so the map shows no mark for it")
	check(MARKER.resolve(plain, true, "").is_empty(), "no objective destination, no marker")

	print("In the Town Square")
	var town = load("res://scenes/TownSquare.tscn").instantiate()
	var cafe_door: Dictionary = MARKER.resolve(town, false, "cafe")
	check(cafe_door.get("position", Vector2.ZERO).is_equal_approx(Vector2(651, 466)), "the café is marked above its door")
	check(cafe_door.get("label", "") == "Café", "the café's label is Café")
	check(MARKER.resolve(town, false, "town_square").is_empty(), "Town Square is hidden inside the Town Square")
	var home_from_town: Dictionary = MARKER.resolve(town, false, "home")
	check(home_from_town.get("position", Vector2.ZERO).is_equal_approx(Vector2(750, 700)), "Home from the Town Square is marked at the gate to the map")
	town.free()

	print("In the courtyard and the house")
	var courtyard = load("res://scenes/ExteriorHome.tscn").instantiate()
	var door: Dictionary = MARKER.resolve(courtyard, false, "home")
	check(door.get("position", Vector2.ZERO) == courtyard.ENTER_POSITION, "Home is marked at the house door from the courtyard")
	var to_town: Dictionary = MARKER.resolve(courtyard, false, "town_square")
	check(not to_town.is_empty(), "the Town Square is marked at the courtyard's gate")
	courtyard.free()
	var floor1 = load("res://scenes/HomeFloor1.tscn").instantiate()
	check(MARKER.resolve(floor1, false, "home").is_empty(), "inside the house, Home is reached, so no mark")
	floor1.free()

	print("In the café and the bookstore")
	var cafe = load("res://scenes/Cafe.tscn").instantiate()
	check(MARKER.resolve(cafe, false, "cafe").is_empty(), "inside the café, the café is reached, so no mark")
	cafe.free()

	print("The objective's destination")
	save.state.completed_missions = ["M01", "M02"]
	save.state.world_state["talked_to"] = ["henry_collins"]
	TRACKER.update()
	check(TRACKER.current_step().get("destination", "") == "cafe", "after meeting Henry, the objective's destination is the café")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
