extends SceneTree
## Dumps the art, the occluders and the collision that each courtyard-style scene builds at runtime,
## as JSON, so scripts/build_visual_scenes.py can write them into the scene files.
## Run: Godot --headless --path . -s res://tests/export_scene_layout.gd

const SCENES := ["BedroomUpstairs", "Bookstore", "CaveEntrance", "CaveInterior", "ExteriorHome", "Forest", "HomeFloor1", "TempleCourtyard", "TownSquare"]
const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/layouts"
const VARS := ["SPAWN_DEFAULT", "SPAWNS", "HAS_DOOR", "ENTER_POSITION", "ENTER_LABEL", "ENTER_HOME_SCENE", "ENTER_HOME_SPAWN", "GATE_RECT", "EXITS", "IMAGE_SIZE", "PLAYER_SCALE", "MAP_PLACE", "SCENE_ID", "PICTURE_PATH"]


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	# Scene names may be given after "--"; otherwise every scene in SCENES is exported.
	var names: Array = OS.get_cmdline_user_args()
	if names.is_empty():
		names = SCENES
	for scene_name in names:
		save.state = save.new_game_state()
		var scene: Node = load("res://scenes/%s.tscn" % scene_name).instantiate()
		root.add_child(scene)
		for i in 5:
			await process_frame
		var data := {"scene": scene_name, "vars": _vars(scene), "nodes": []}
		for child in scene.get_children():
			_collect(child, scene, data.nodes)
		var f := FileAccess.open(OUT_DIR + "/" + scene_name + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify(data, "  "))
		f.close()
		print("exported %s: %d nodes" % [scene_name, data.nodes.size()])
		root.remove_child(scene)
		scene.free()
	quit(0)


func _vars(scene: Node) -> Dictionary:
	var out := {}
	for var_name in VARS:
		var value = scene.get(var_name)
		if value != null:
			out[var_name] = _jsonable(value)
	return out


## Sprites and collision bodies are kept. The player, the camera and the UI are not part of the scene art.
func _collect(node: Node, scene: Node, out: Array) -> void:
	if node is CharacterBody2D or node is Camera2D or node is CanvasLayer or node is Control or node is Area2D:
		return
	if node is Sprite2D:
		out.append(_sprite(node, scene))
	elif node is StaticBody2D:
		out.append(_body(node))
	elif node is Node2D:
		for child in node.get_children():
			_collect(child, scene, out)


func _sprite(s: Sprite2D, scene: Node) -> Dictionary:
	var d := {
		"type": "Sprite2D",
		"name": String(s.name),
		"position": _jsonable(s.position),
		"scale": _jsonable(s.scale),
		"z_index": s.z_index,
		"centered": s.centered,
		"visible": s.visible,
		"region_enabled": s.region_enabled,
		"region_rect": _jsonable(s.region_rect),
		"modulate": _jsonable(s.modulate),
		"meta": {},
	}
	# Occluders are listed by the script, with their rectangle, origin and whether they are a cut-out.
	var occluders = scene.get("occluder_sprites")
	if occluders is Array:
		for entry in occluders:
			if entry.get("node") == s:
				d.meta = {"rect": _jsonable(entry.rect), "origin": _jsonable(entry.origin), "cutout": entry.cutout}
	var tex: Texture2D = s.texture
	if tex is GradientTexture2D:
		var g := tex as GradientTexture2D
		var colors := []
		for c in g.gradient.colors:
			colors.append(_jsonable(c))
		d["gradient"] = {"colors": colors, "offsets": Array(g.gradient.offsets), "fill": g.fill,
			"fill_from": _jsonable(g.fill_from), "fill_to": _jsonable(g.fill_to), "width": g.width, "height": g.height}
	elif tex:
		d["texture"] = tex.resource_path
	return d


func _body(b: StaticBody2D) -> Dictionary:
	var shapes := []
	for c in b.get_children():
		if not (c is CollisionShape2D) or c.shape == null:
			continue
		var sh = c.shape
		if sh is RectangleShape2D:
			shapes.append({"type": "rect", "size": _jsonable(sh.size), "position": _jsonable(c.position)})
		elif sh is CircleShape2D:
			shapes.append({"type": "circle", "radius": sh.radius, "position": _jsonable(c.position)})
		elif sh is ConvexPolygonShape2D:
			shapes.append({"type": "convex", "points": _jsonable(sh.points)})
		elif sh is ConcavePolygonShape2D:
			shapes.append({"type": "segments", "points": _jsonable(sh.segments)})
	return {"type": "StaticBody2D", "name": String(b.name), "position": _jsonable(b.position), "shapes": shapes}


func _jsonable(value):
	if value is Vector2:
		return [value.x, value.y]
	if value is Vector2i:
		return [value.x, value.y]
	if value is Rect2:
		return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is Color:
		return [value.r, value.g, value.b, value.a]
	if value is PackedVector2Array:
		var pts := []
		for p in value:
			pts.append([p.x, p.y])
		return pts
	if value is Dictionary:
		var d := {}
		for k in value:
			d[str(k)] = _jsonable(value[k])
		return d
	if value is Array:
		var a := []
		for v in value:
			a.append(_jsonable(v))
		return a
	return value
