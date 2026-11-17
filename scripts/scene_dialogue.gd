class_name SceneDialogue
extends Control
## The dialogue box for scripted scenes and for things that say a line when used. A speaker with
## portrait art gets a portrait on the left, showing the expression each line asks for, and her mouth
## moves for a moment when a line appears. Lines are strings or {"text", "emotion"}. E, Enter or a
## click moves on. say() returns once the last line has been dismissed, so a scene script can wait.

signal closed
## The box opened (true) or closed (false). The scene that owns the box passes this on to the HUD.
signal talk_changed(is_open: bool)

const ART := "res://assets/ui/dialogue_box.png"
const ART_SIZE := Vector2(1953, 586)
const WIDTH := 820.0
## Inside the dark panel of the artwork, to the right of the portrait, as fractions of the box.
## The speaker's name sits on its own line above the text.
const NAME_RECT := Rect2(0.33, 0.33, 0.53, 0.13)
const TEXT_RECT := Rect2(0.33, 0.47, 0.53, 0.30)
## Portrait folders by speaker name. A speaker without one gets no portrait.
const PORTRAITS := {
	"Amelia": "res://assets/portraits/amelia/",
	"Evelyn": "res://assets/portraits/evelyn/",
	"Oliver": "res://assets/portraits/oliver/",
}
const PORTRAIT_SCALE := 0.9
## When a line appears, the talking expression shows for this long, then the line's own expression.
const TALK_SECONDS := 1.2
const TALK_FRAME := "talk_02"
## Lines of text that the text box holds inside its panel at this size. A longer line is shown on more than one page.
const MAX_LINES := 2

var is_open := false
var _queue: Array = []
var _speaker_label: Label
var _text_label: Label
var _portrait: TextureRect
var _portrait_folder := ""
var _emotion := "neutral"
var _talk_left := 0.0
var _textures := {}


func _ready() -> void:
	var box := ART_SIZE * (WIDTH / ART_SIZE.x)
	size = box
	mouse_filter = Control.MOUSE_FILTER_STOP
	var art := TextureRect.new()
	art.texture = load(ART)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = box
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size = Vector2(272, 290) * PORTRAIT_SCALE
	_portrait.position = Vector2(0, box.y - _portrait.size.y + 10)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.visible = false
	add_child(_portrait)
	# The speaker's name: bold and gold, on its own line.
	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.9
	_speaker_label = Label.new()
	_speaker_label.add_theme_font_override("font", bold)
	_speaker_label.add_theme_font_size_override("font_size", 24)
	_speaker_label.add_theme_color_override("font_color", Color("#e8c77a"))
	_speaker_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_speaker_label.add_theme_constant_override("shadow_offset_x", 1)
	_speaker_label.add_theme_constant_override("shadow_offset_y", 1)
	_speaker_label.position = Vector2(NAME_RECT.position.x * box.x, NAME_RECT.position.y * box.y)
	_speaker_label.size = Vector2(NAME_RECT.size.x * box.x, NAME_RECT.size.y * box.y)
	_speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_speaker_label)
	# The line itself: regular cream text under the name.
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text_label.add_theme_font_size_override("font_size", 20)
	_text_label.add_theme_color_override("font_color", Color("#f3e3c3"))
	_text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_text_label.add_theme_constant_override("shadow_offset_x", 1)
	_text_label.add_theme_constant_override("shadow_offset_y", 1)
	_text_label.position = Vector2(TEXT_RECT.position.x * box.x, TEXT_RECT.position.y * box.y)
	_text_label.size = Vector2(TEXT_RECT.size.x * box.x, TEXT_RECT.size.y * box.y)
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text_label)
	visible = false


## Shows the lines one at a time, with the speaker's name (or no name if speaker is empty).
func say(speaker: String, lines: Array) -> void:
	if lines.is_empty():
		return
	_queue.clear()
	for line in lines:
		_queue_pages(_as_entry(line))
	_portrait_folder = PORTRAITS.get(speaker, "")
	is_open = true
	visible = true
	talk_changed.emit(true)
	var view := get_viewport().get_visible_rect().size
	position = Vector2((view.x - size.x) / 2.0, view.y - size.y - 12.0)
	_speaker_label.text = speaker
	_speaker_label.visible = speaker != ""
	_show(_queue.pop_front())
	await closed


## Moves on to the next line, or closes the box after the last one.
func advance() -> void:
	if not is_open:
		return
	if _queue.is_empty():
		is_open = false
		visible = false
		_portrait.visible = false
		_talk_left = 0.0
		talk_changed.emit(false)
		closed.emit()
		return
	_show(_queue.pop_front())


func _process(delta: float) -> void:
	if _talk_left <= 0.0 or not _portrait.visible:
		return
	_talk_left -= delta
	if _talk_left <= 0.0:
		_refresh_portrait()


func _gui_input(event: InputEvent) -> void:
	# A touch also arrives as an emulated mouse click. Only the real click or the touch counts, so one tap moves on once.
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
	elif event is InputEventScreenTouch and event.pressed:
		advance()


func _exit_tree() -> void:
	# A scene left mid-line takes its box with it, so the HUD must not stay hidden.
	if is_open:
		talk_changed.emit(false)


func _as_entry(line) -> Dictionary:
	if line is Dictionary:
		return {"text": str(line.get("text", "")), "emotion": str(line.get("emotion", "neutral"))}
	return {"text": str(line), "emotion": "neutral"}


## Queues a line as one or more pages, so a long line is read over several taps and stays inside the box.
func _queue_pages(entry: Dictionary) -> void:
	var pages := pages_for(entry.text)
	if pages.is_empty():
		_queue.append(entry)
		return
	for page in pages:
		_queue.append({"text": page, "emotion": entry.emotion})


## The pages a line is shown on. Whole sentences are packed into each page while they fit the text box in MAX_LINES lines.
## A sentence too long for one page is cut at its words. Joined with spaces, the pages give back the line.
func pages_for(text: String) -> Array:
	var pages: Array = []
	var current := ""
	for sentence in _sentences(text):
		var joined: String = sentence if current.is_empty() else current + " " + sentence
		if _fits(joined):
			current = joined
		else:
			if not current.is_empty():
				pages.append(current)
			current = sentence
		while not current.is_empty() and not _fits(current):
			var cut := _longest_fit(current)
			pages.append(cut)
			current = current.substr(cut.length()).strip_edges()
	if not current.is_empty():
		pages.append(current)
	return pages


## Whether the text fits the text box in MAX_LINES lines.
func _fits(text: String) -> bool:
	_text_label.text = text
	return _text_label.get_line_count() <= MAX_LINES


## The longest run of whole words from the start of the text that fits one page. Always at least one word.
func _longest_fit(text: String) -> String:
	var words := text.split(" ", false)
	var best: String = words[0]
	var prefix := ""
	for word in words:
		var candidate: String = word if prefix.is_empty() else prefix + " " + word
		if not _fits(candidate):
			break
		prefix = candidate
	return prefix if not prefix.is_empty() else best


## The sentences of a text. Each ends after its full stop, question or exclamation mark, and any closing quote after it.
func _sentences(text: String) -> Array:
	var normal := " ".join(text.split(" ", false))
	var sentences: Array = []
	var start := 0
	var i := 0
	while i < normal.length():
		if normal[i] in [".", "!", "?"]:
			var end := i
			if end + 1 < normal.length() and normal[end + 1] in ["'", "\""]:
				end += 1
			if end + 1 >= normal.length() or normal[end + 1] == " ":
				sentences.append(normal.substr(start, end + 1 - start).strip_edges())
				start = end + 1
				i = end
		i += 1
	var rest := normal.substr(start).strip_edges()
	if not rest.is_empty():
		sentences.append(rest)
	return sentences


func _show(entry: Dictionary) -> void:
	_text_label.text = entry.text
	_emotion = entry.emotion
	_portrait.visible = _portrait_folder != ""
	_talk_left = TALK_SECONDS if _portrait.visible else 0.0
	if _portrait.visible:
		_refresh_portrait()


func _refresh_portrait() -> void:
	var frame := _emotion
	if _talk_left > 0.0:
		frame = TALK_FRAME
	_portrait.texture = _texture(frame)


## The portrait image for a frame name, falling back to neutral if that expression has no image.
func _texture(frame: String) -> Texture2D:
	var path: String = _portrait_folder + frame + ".png"
	if not _textures.has(path):
		_textures[path] = load(path)
	if _textures[path] == null:
		return _texture("neutral")
	return _textures[path]
