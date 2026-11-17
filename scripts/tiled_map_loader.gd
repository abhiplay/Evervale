## Reads an area's Tiled map (JSON export, Tiled 1.10+). The map holds the picture, the solid
## rectangles, the occluders, the exits, the spawn points and the door, all in picture pixels.
##
## Layers: "solids" (rectangles), "occluders" (rectangles, with an optional "image" property for
## a cut-out), "exits" (rectangles with "scene" and "spawn"; a rectangle named "gate" is the walk
## to the world map), "spawns" (points, named by arrival ID; "default" is the start point) and
## "doors" (points with "label", "scene" and "spawn"). The picture layer is only for display in
## Tiled; the game reads the map property "picture".
##
## Used as: const TiledMapLoader = preload("res://scripts/tiled_map_loader.gd")


static func load_map(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[TiledMapLoader] Could not read %s" % path)
		return {}
	var props := _properties(parsed)
	var map := {
		"picture": props.get("picture", ""),
		"image_size": Vector2(float(props.get("image_width", 0)), float(props.get("image_height", 0))),
		"solids": [],
		"occluders": [],
		"exits": [],
		"gate": Rect2(),
		"spawns": {},
		"door": {},
	}
	for layer in parsed.get("layers", []):
		if layer.get("type", "") != "objectgroup":
			continue
		for obj in layer.get("objects", []):
			_read_object(layer.get("name", ""), obj, map)
	return map


static func _read_object(layer_name: String, obj: Dictionary, map: Dictionary) -> void:
	var obj_name: String = obj.get("name", "")
	var pos := Vector2(float(obj.get("x", 0)), float(obj.get("y", 0)))
	var rect := Rect2(pos, Vector2(float(obj.get("width", 0)), float(obj.get("height", 0))))
	var props := _properties(obj)
	match layer_name:
		"solids":
			map["solids"].append(rect)
		"occluders":
			if props.has("image"):
				map["occluders"].append({"rect": rect, "image": props["image"]})
			else:
				map["occluders"].append(rect)
		"exits":
			if obj_name == "gate":
				map["gate"] = rect
			else:
				var exit_data := {"rect": rect, "scene": props.get("scene", ""), "spawn": props.get("spawn", "")}
				if props.has("requires"):
					exit_data["requires"] = props["requires"]
				map["exits"].append(exit_data)
		"spawns":
			map["spawns"][obj_name] = pos
		"doors":
			map["door"] = {"pos": pos, "label": props.get("label", ""), "scene": props.get("scene", ""), "spawn": props.get("spawn", "")}


static func _properties(item: Dictionary) -> Dictionary:
	var result := {}
	for prop in item.get("properties", []):
		result[prop["name"]] = prop["value"]
	return result
