class_name DialogueStage
extends Control
## The full-screen side of a conversation (SceneDialogue): the room seen up close behind the people talking, a dark band
## at the bottom for the words, and the speaker drawn large on their side of the screen. Only the person speaking is shown.
##
## The background is the room's own painting when data/dialogue_backdrops.json names one for this scene, or for the zone
## (a home_events.json area) Amelia stands in. Until then it is the room's picture around Amelia, close up and softened,
## so it always matches the room as it is now (bare or settled, empty or furnished). At night it takes the night's tint.

const BACKDROPS := "res://data/dialogue_backdrops.json"
const AREAS := "res://data/home_events.json"
const BLUR_SHADER := "res://scripts/ui/dialogue_backdrop.gdshader"
## How much of the screen the close-up shows, compared with the normal view: smaller is closer.
const CLOSE_UP := 0.62
## The speaker's height on screen, as a share of the screen's height.
const FIGURE_HEIGHT := 0.82
const FADE_SECONDS := 0.25

var backdrop: TextureRect
var figure: TextureRect
## Which side the speaker stands on: "left" or "right".
var side := "left"
var _shade: TextureRect
var _host: Node2D
var _fade: Tween
## True while the stage is fading out, so asking again does not restart the fade.
var closing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	backdrop = TextureRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	figure = TextureRect.new()
	figure.name = "Figure"
	figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	figure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.visible = false
	add_child(figure)
	# The dark band the words sit on, rising from the bottom edge and over the speaker's lower half.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, Color(0, 0, 0, 0.88))
	var band := GradientTexture2D.new()
	band.gradient = gradient
	band.fill_from = Vector2(0, 0)
	band.fill_to = Vector2(0, 1)
	_shade = TextureRect.new()
	_shade.name = "Shade"
	_shade.texture = band
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)


## Brings the stage up for a conversation in the host scene: the background for where Amelia stands, faded in. Calling it
## while the stage is already up keeps it as it is, so a conversation of many speakers does not flicker between them.
func open(host: Node2D) -> void:
	_host = host
	var view := get_viewport().get_visible_rect().size
	size = view
	_shade.position = Vector2(0, view.y * 0.5)
	_shade.size = Vector2(view.x, view.y * 0.5)
	if visible and not closing and modulate.a > 0.99:
		return
	closing = false
	_set_backdrop()
	visible = true
	_fade_to(1.0)


## Takes the stage down, fading it out.
func close() -> void:
	if not visible or closing:
		return
	closing = true
	figure.visible = false
	_fade_to(0.0)


## Shows the speaker's picture on their side, or nobody when texture is null (narration, or someone without art yet).
func show_speaker(texture: Texture2D, on_side: String) -> void:
	side = on_side
	figure.texture = texture
	figure.visible = texture != null
	if texture == null:
		return
	var view := get_viewport().get_visible_rect().size
	var height := view.y * FIGURE_HEIGHT
	var width := height * texture.get_width() / float(texture.get_height())
	figure.size = Vector2(width, height)
	# The bust's cut-off bottom edge sits on the screen's bottom edge, so it never shows.
	var x := view.x * 0.04 if side == "left" else view.x * 0.96 - width
	figure.position = Vector2(x, view.y - height)


## Swaps the picture without moving it (the speaker's mouth while talking, or their expression).
func set_speaker_texture(texture: Texture2D) -> void:
	if figure.visible and texture != null:
		figure.texture = texture


func _process(_delta: float) -> void:
	if not visible or _host == null or not is_instance_valid(_host):
		return
	# At night the room behind the people is as dark as the room itself.
	var night := _host.get_node_or_null("NightTint") as CanvasModulate
	var tint := night.color if night != null and not night.is_queued_for_deletion() else Color.WHITE
	backdrop.self_modulate = tint


func _fade_to(alpha: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, FADE_SECONDS)
	if alpha <= 0.0:
		_fade.tween_callback(func():
			visible = false
			closing = false)


## The room's painting, if it has one, else the close-up of its picture around Amelia.
func _set_backdrop() -> void:
	if _host == null:
		backdrop.texture = null
		return
	var painting := _painting()
	if painting != null:
		backdrop.texture = painting
		backdrop.material = null
		return
	backdrop.texture = _close_up()
	var material := ShaderMaterial.new()
	material.shader = load(BLUR_SHADER)
	backdrop.material = material


## The painting data/dialogue_backdrops.json names for this scene and the zone Amelia stands in (a zone's own painting
## first, then the scene's), or null.
func _painting() -> Texture2D:
	if not FileAccess.file_exists(BACKDROPS):
		return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(BACKDROPS))
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var scene_id := str(_host.get("SCENE_ID"))
	var zone := _zone(scene_id)
	var scene_painting := ""
	for entry in data.get("backdrops", []):
		if entry.get("scene", "") != scene_id:
			continue
		var image: String = entry.get("image", "")
		if image == "" or not ResourceLoader.exists(image):
			continue
		if entry.get("zone", "") == zone and zone != "":
			return load(image)
		if entry.get("zone", "") == "":
			scene_painting = image
	return load(scene_painting) if scene_painting != "" else null


## The home_events.json area of this scene that Amelia stands in, or "".
func _zone(scene_id: String) -> String:
	var player = _host.get("player")
	if player == null:
		return ""
	var data = JSON.parse_string(FileAccess.get_file_as_string(AREAS))
	for area in data.get("areas", []):
		var r: Array = area.rect
		if area.scene == scene_id and Rect2(r[0], r[1], r[2], r[3]).has_point(player.position):
			return area.id
	return ""


## The scene's picture around Amelia, closer than the normal view.
func _close_up() -> Texture2D:
	var picture := _picture(_host)
	if picture == null:
		return null
	var texture: Texture2D = picture.texture
	var full := Vector2(texture.get_width(), texture.get_height())
	var view := get_viewport().get_visible_rect().size
	var scale_x: float = absf(picture.global_scale.x) if picture.global_scale.x != 0.0 else 1.0
	var region_size: Vector2 = view * CLOSE_UP / scale_x
	if region_size.x > full.x or region_size.y > full.y:
		region_size *= minf(full.x / region_size.x, full.y / region_size.y)
	var centre := full / 2.0
	var player = _host.get("player")
	if player != null:
		centre = picture.to_local(player.global_position) - picture.offset
		if picture.centered:
			centre += full / 2.0
		# A little above her feet, so the room behind her fills the screen rather than the floor.
		centre.y -= region_size.y * 0.15
	var corner := (centre - region_size / 2.0).clamp(Vector2.ZERO, full - region_size)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(corner, region_size)
	return atlas


## The scene's room picture: its largest Sprite2D, wherever the scene keeps it.
static func _picture(host: Node) -> Sprite2D:
	var best: Sprite2D = null
	var best_area := 0.0
	for node in host.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite.texture == null or sprite.region_enabled or sprite.hframes > 1 or sprite.vframes > 1:
			continue
		var area := sprite.texture.get_width() * sprite.texture.get_height() * absf(sprite.global_scale.x * sprite.global_scale.y)
		if area > best_area:
			best_area = area
			best = sprite
	return best
