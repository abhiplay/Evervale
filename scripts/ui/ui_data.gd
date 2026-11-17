class_name UiData
## Reads the HUD's data: the items and what the quick slots hold, the chapter titles, and the names of places.
## The words live in data/hud.json and data/items.json, not in the scripts.

const HUD_FILE := "res://data/hud.json"
const ITEMS_FILE := "res://data/items.json"


static func load_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func item(item_id: String) -> Dictionary:
	return load_json(ITEMS_FILE).get(item_id, {})


## The item id each quick slot holds, in slot order. An empty string leaves a slot empty.
static func quick_slots() -> Array:
	return load_json(HUD_FILE).get("quick_slots", [])


## The key shown on each quick slot, in slot order. An empty string shows no key.
static func quick_keys() -> Array:
	return load_json(HUD_FILE).get("quick_keys", [])


static func chapter_title() -> String:
	var number := int(SaveSystem.state.get("current_chapter", 1))
	var titles: Dictionary = load_json(HUD_FILE).get("chapters", {})
	var title: String = titles.get(str(number), "")
	if title == "":
		return "Chapter %02d" % number
	return "Chapter %02d – %s" % [number, title]


static func location_name(place_id: String) -> String:
	var place: Dictionary = GameData.locations.get(place_id, {})
	return place.get("name", place_id)
