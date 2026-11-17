class_name SceneDialogue
extends Control
## The dialogue for scripted scenes and for things that say a line when used. Lines are strings or {"text", "emotion"}.
## E, Enter or a click moves on. say() returns once the last line has been dismissed, so a scene script can wait.
##
## It has two looks. A conversation (any line in a scripted scene, or anyone but Amelia speaking) plays on the stage
## (DialogueStage): the room close up behind the people talking, the speaker drawn large on their side, Amelia on the
## right and everyone else on the left, the name and the words over a dark band at the bottom, and Hide and Skip in the
## corner; the HUD steps aside. Amelia's own short remarks while exploring (looking round the house, petting the cat,
## looking at things) stay in the small box at the bottom, with her portrait on its left. In both, the speaker's mouth
## moves for a moment when a line appears.

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
## Which side of the stage each speaker stands on. Anyone not listed stands on the left.
const STAGE_SIDES := {"Amelia": "right"}
## The colour of each speaker's name on the stage. Anyone not listed gets the default.
const NAME_COLOURS := {
	"Amelia": Color("#e8c77a"),
	"Oliver": Color("#9cc3e6"),
	"Evelyn": Color("#a9d6a0"),
	"Henry": Color("#e3a774"),
	"Radio": Color("#c9b79a"),
}
const NAME_COLOUR := Color("#e8c77a")
## On Skip, each line shows for this long before the next.
const SKIP_SECONDS := 0.08
## After the last line, the stage waits this long for the scene's next line before it goes down, so a conversation of
## many speakers stays on one stage.
const STAGE_GRACE := 0.2
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
var _speaker := ""
var _textures := {}
## The full-screen stage for conversations, behind this box in the scene's UI layer.
var stage: DialogueStage
## True while the lines are on the stage rather than in the box.
var stage_mode := false
var _hide_button: Button
var _skip_button: Button
var _ui_hidden := false
var _skipping := false
var _skip_left := 0.0
var _grace_left := 0.0
var _art: TextureRect
var _box_size := Vector2.ZERO


func _ready() -> void:
	var box := ART_SIZE * (WIDTH / ART_SIZE.x)
	_box_size = box
	size = box
	mouse_filter = Control.MOUSE_FILTER_STOP
	var art := TextureRect.new()
	art.texture = load(ART)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = box
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	_art = art
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
	_hide_button = _stage_button(DialogueIcon.Kind.HIDE, _hide_words)
	_skip_button = _stage_button(DialogueIcon.Kind.SKIP, _skip_talk)
	visible = false
	stage = DialogueStage.new()
	stage.name = "DialogueStage"
	_attach_stage.call_deferred()


## The stage goes first in this box's layer, under the scene's fade, so a fade to black covers it too.
func _attach_stage() -> void:
	var layer := get_parent()
	if layer == null or stage.get_parent() != null:
		return
	layer.add_child(stage)
	layer.move_child(stage, 0)


## A round Hide or Skip button for the stage's corner, hidden until a conversation is on the stage.
func _stage_button(kind: DialogueIcon.Kind, action: Callable) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.size = Vector2(34, 34)
	button.visible = false
	button.pressed.connect(action)
	var icon := DialogueIcon.new(kind)
	icon.size = button.size
	button.add_child(icon)
	add_child(button)
	return button


## Shows the lines one at a time, with the speaker's name (or no name if speaker is empty).
func say(speaker: String, lines: Array) -> void:
	if lines.is_empty():
		return
	_queue.clear()
	_portrait_folder = PORTRAITS.get(speaker, "")
	_speaker = speaker
	stage_mode = _wants_stage(speaker)
	if stage_mode:
		_layout_stage(speaker)
	else:
		_layout_box()
	# The pages are worked out for the text area of the look in use.
	for line in lines:
		_queue_pages(_as_entry(line))
	is_open = true
	visible = true
	_ui_hidden = false
	talk_changed.emit(true)
	_speaker_label.text = speaker
	_speaker_label.visible = speaker != ""
	_show(_queue.pop_front())
	await closed


## A conversation plays on the stage: any line while the scene is scripted, or anyone but Amelia speaking. Amelia's own
## remarks while exploring stay in the box.
func _wants_stage(speaker: String) -> bool:
	var host := _host()
	# Without a scene around it (a box on its own), there is no room to put on the stage.
	if host == null:
		return false
	if host.get("scripted") == true:
		return true
	return speaker != "" and speaker != "Amelia"


## The scene this box belongs to (the one with the player in it), or null.
func _host() -> Node:
	var node := get_parent()
	while node != null and node.get("scripted") == null:
		node = node.get_parent()
	return node


## The box at the bottom of the screen, with the small portrait on its left.
func _layout_box() -> void:
	if stage.visible:
		_close_stage()
	var view := get_viewport().get_visible_rect().size
	size = _box_size
	position = Vector2((view.x - size.x) / 2.0, view.y - size.y - 12.0)
	_art.visible = true
	_speaker_label.position = Vector2(NAME_RECT.position.x * size.x, NAME_RECT.position.y * size.y)
	_speaker_label.size = Vector2(NAME_RECT.size.x * size.x, NAME_RECT.size.y * size.y)
	_speaker_label.add_theme_color_override("font_color", NAME_COLOUR)
	_text_label.position = Vector2(TEXT_RECT.position.x * size.x, TEXT_RECT.position.y * size.y)
	_text_label.size = Vector2(TEXT_RECT.size.x * size.x, TEXT_RECT.size.y * size.y)
	_hide_button.visible = false
	_skip_button.visible = false


## The whole screen: the stage behind, the name and words over its dark band, Hide and Skip in the corner.
func _layout_stage(speaker: String) -> void:
	var view := get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = view
	_art.visible = false
	_portrait.visible = false
	_speaker_label.position = Vector2(view.x * 0.2, view.y * 0.735)
	_speaker_label.size = Vector2(view.x * 0.6, 34)
	_speaker_label.add_theme_color_override("font_color", NAME_COLOURS.get(speaker, NAME_COLOUR))
	_text_label.position = Vector2(view.x * 0.2, view.y * 0.80)
	_text_label.size = Vector2(view.x * 0.6, view.y * 0.15)
	_skip_button.position = Vector2(view.x - 48, view.y - 46)
	_hide_button.position = Vector2(view.x - 90, view.y - 46)
	_hide_button.visible = true
	_skip_button.visible = true
	_grace_left = 0.0
	var host := _host()
	if stage.get_parent() == null:
		_attach_stage()
	stage.open(host)
	_set_stage_flag(true)


## Tells the HUD whether a conversation is on the stage (HudEvents.dialogue_stage). Looked up at run time: this script is
## also built by tests before the autoloads exist.
func _set_stage_flag(on: bool) -> void:
	var events := get_node_or_null("/root/HudEvents")
	if events != null:
		events.dialogue_stage = on


func _close_stage() -> void:
	stage.close()
	_skipping = false
	_set_stage_flag(false)


## Hide: the words and the speaker step aside to show the room; the next click or E brings them back.
func _hide_words() -> void:
	_ui_hidden = true
	_set_words_visible(false)


func _set_words_visible(on: bool) -> void:
	_speaker_label.visible = on and _speaker_label.text != ""
	_text_label.visible = on
	_hide_button.visible = on
	_skip_button.visible = on
	stage.figure.visible = on and stage.figure.texture != null and _portrait_folder != ""


## Skip: the rest of the conversation goes by quickly, line after line, until it ends.
func _skip_talk() -> void:
	_skipping = true
	_skip_left = 0.0


## Moves on to the next line, or closes the box after the last one.
func advance() -> void:
	if not is_open:
		return
	if _ui_hidden:
		_ui_hidden = false
		_set_words_visible(true)
		return
	if _queue.is_empty():
		is_open = false
		visible = false
		_portrait.visible = false
		_talk_left = 0.0
		# On the stage, the room stays up for a moment in case the scene's next line follows (see _process).
		_grace_left = STAGE_GRACE
		talk_changed.emit(false)
		closed.emit()
		return
	_show(_queue.pop_front())


func _process(delta: float) -> void:
	if _skipping and is_open:
		_skip_left -= delta
		if _skip_left <= 0.0:
			_skip_left = SKIP_SECONDS
			advance()
	_follow_stage(delta)
	var showing := _portrait.visible or (stage_mode and stage.figure.visible)
	if _talk_left <= 0.0 or not showing:
		return
	_talk_left -= delta
	if _talk_left <= 0.0:
		_refresh_portrait()


## Takes the stage down once a conversation is over: no line open, and the scene no longer scripted, for a moment.
func _follow_stage(delta: float) -> void:
	if is_open or stage == null or not stage.visible or stage.closing:
		return
	var host := _host()
	if host != null and host.get("scripted") == true and is_instance_valid(host) and not host.get("transitioning"):
		_grace_left = STAGE_GRACE
		return
	_grace_left -= delta
	if _grace_left <= 0.0:
		_close_stage()


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
	_set_stage_flag(false)


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
	var has_art := _portrait_folder != ""
	_talk_left = TALK_SECONDS if has_art else 0.0
	if stage_mode:
		_portrait.visible = false
		stage.show_speaker(_texture(TALK_FRAME) if has_art else null, STAGE_SIDES.get(_speaker, "left"))
		return
	_portrait.visible = has_art
	if _portrait.visible:
		_refresh_portrait()


func _refresh_portrait() -> void:
	var frame := _emotion
	if _talk_left > 0.0:
		frame = TALK_FRAME
	if stage_mode:
		stage.set_speaker_texture(_texture(frame))
		return
	_portrait.texture = _texture(frame)


## The portrait image for a frame name, falling back to neutral if that expression has no image.
func _texture(frame: String) -> Texture2D:
	var path: String = _portrait_folder + frame + ".png"
	if not _textures.has(path):
		_textures[path] = load(path)
	if _textures[path] == null:
		return _texture("neutral")
	return _textures[path]
