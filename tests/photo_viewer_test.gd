extends SceneTree
## Checks the item viewer. The photo shows its front, and turns to its back by a tap, a drag or R, and back again. A second
## press does not restart a turn that is under way. A turn cancels a press that is still held, so the press's release does not
## undo it. A press during a turn starts nothing and moves nothing, and a press held through a turn does not move the photo when
## it is let go after the turn. A turn goes the short way round, so one that starts off-centre, or near an edge, lands in the
## middle of the other face. Closing in the middle of a turn stops it. A photo without a back does not turn, and a photo without
## a front says it is to come. A letter still shows its picture, drawn with linear filtering between mipmaps, and it is fitted
## whole to the screen, centred, with a margin above and below and the close cross clear of it, also after the screen changes
## size. The room behind the viewer is a tinted copy of the screen, first in the viewer, and only a window takes that copy. The
## viewer draws no frame of its own, and its close cross sits in the top right corner. A drag turns the photo either way and
## lets go to the nearer face, and a tap with a little drift still turns it. A drag that rests past the edge keeps the photo
## visible. A press or a lost release does not disturb a turn, and a turn always ends with the photo at its true angle. E closes
## the viewer only after MIN_SECONDS, and Esc closes it at once. Enter presses the focused close cross at once, and with the
## focus released Enter waits for the moment E waits for.
##
## Timing. A turn is a tween, so it ends after its seconds of frame time. The checks wait for a turn frame by frame, up to
## TURN_FRAME_LIMIT frames, and never on a fixed timer. The E and Enter moment rules are checked by setting the viewer's
## _open_for, so they do not wait for the clock either. A check that nothing changes waits a fixed count of frames.
##
## Windows. The GUI tap is checked only in a window, since a headless run does not route mouse events to controls. The picture
## of the room is checked both ways: there is none headless, and a window takes one. In a window the player's own keys can
## press the focused close cross (Enter or Space), close the item with Esc, or close it with E or Enter once MIN_SECONDS has
## passed. So each
## section that waits on frames first releases the close cross's focus and counts the viewer's closed signal, and a section
## that expects the item to stay open fails if that count is not zero.
##
## Run:
## Godot --headless --path . -s res://tests/photo_viewer_test.gd
## Godot --path . -s res://tests/photo_viewer_test.gd    (in a window, about 16 seconds)

const PHOTO_FRONT := "res://assets/items/photo_box_front.webp"
const PHOTO_BACK := "res://assets/items/photo_box_back.webp"
const LETTER := "res://assets/items/letter_arthur.webp"
## Where the left button is set for the turn checks. The top left corner of the window is off the photo at every window scale,
## because the photo is centred and sits well below it, and no control is there to take the press.
const OFF_PHOTO := Vector2(4, 4)
## The most frames a turn may take to end. A turn takes ItemViewer.TURN_SECONDS of frame time, so the limit only stops a turn
## that never ends from hanging the run.
const TURN_FRAME_LIMIT := 180

var failures: Array[String] = []
## How many times the viewer's closed signal has fired since the last _begin_section.
var _closes := 0


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


func _initialize() -> void:
	await process_frame
	var hud = root.get_node("/root/Hud")
	var viewer: ItemViewer = hud.viewer
	viewer.closed.connect(_on_viewer_closed)
	var photo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))["photo_box"]
	var photo_entry: Dictionary = photo["view"][0]
	# The room binds E and Enter to "interact" when it loads (room.gd). This test has no room, so it binds both keys the same way.
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	for keycode in [KEY_E, KEY_ENTER]:
		var interact_key := InputEventKey.new()
		interact_key.physical_keycode = keycode
		InputMap.action_add_event("interact", interact_key)

	print("The room behind the viewer")
	check(viewer.get_child(0) == viewer._backdrop_picture and viewer.get_child(1) == viewer._tint, "the backdrop and its tint are the first things in the viewer")
	check(viewer._backdrop_picture.mouse_filter == Control.MOUSE_FILTER_IGNORE and viewer._tint.mouse_filter == Control.MOUSE_FILTER_IGNORE, "neither backdrop layer takes the mouse")
	check(viewer._backdrop_picture.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "the backdrop picture is drawn with linear filtering")
	var stale := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGB8))
	viewer._backdrop_picture.texture = stale
	viewer.show_item(photo_entry)
	check(viewer._backdrop_picture.texture != stale, "opening the viewer takes a new copy of the room")
	if DisplayServer.get_name() == "headless":
		check(viewer._backdrop_picture.texture == null, "headless, there is no picture of the room, so the copy is empty and nothing errors")
	else:
		check(viewer._backdrop_picture.texture != null, "a window takes a picture of the room behind the viewer")
	viewer._backdrop_picture.texture = stale
	viewer.show_item({"type": "letter", "title": "A letter", "text": "Some words."})
	check(viewer._backdrop_picture.texture == stale, "an item shown while the viewer is open keeps the copy it has")
	viewer.close()
	check(not viewer.visible, "the viewer closes before the next check")

	print("The photo")
	viewer.show_item(photo_entry)
	check(viewer.visible, "the photo opens in the viewer")
	check(viewer._photo_picture.texture != null and viewer._photo_picture.texture.resource_path == PHOTO_FRONT, "the photo shows its front")
	check(not viewer.showing_back and viewer.has_back(), "the photo has a back and opens on its front")
	check(viewer._turn_button.is_visible_in_tree(), "the turn button shows for a photo with a back")
	check(viewer._photo_holder.is_visible_in_tree(), "the photo's holder shows")
	check(FileAccess.get_file_as_string("res://assets/items/photo_box_front.webp.import").contains("mipmaps/generate=true"), "the photo is imported with mipmaps, so it shrinks cleanly")
	check(viewer._photo_picture.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "the photo is drawn with linear filtering between its mipmaps")

	print("Mipmaps")
	viewer.show_item(photo_entry)
	var photo_image: Image = viewer._photo_picture.texture.get_image()
	check(photo_image != null and photo_image.has_mipmaps(), "the loaded photo's image has mipmaps, so it shrinks without shimmer")
	var back_image: Image = viewer._back_face.get_image()
	check(back_image != null and back_image.has_mipmaps(), "the loaded back of the photo has mipmaps, so it shrinks without shimmer")
	check(FileAccess.get_file_as_string("res://assets/items/photo_box_back.webp.import").contains("mipmaps/generate=true"), "the photo's back is imported with mipmaps")
	viewer.show_item({"type": "image", "image": LETTER})
	var letter_image: Image = viewer._picture.texture.get_image()
	check(letter_image != null and letter_image.has_mipmaps(), "the loaded letter's image has mipmaps, so it is drawn at its smaller size without aliasing")
	check(FileAccess.get_file_as_string("res://assets/items/letter_arthur.webp.import").contains("mipmaps/generate=true"), "the letter is imported with mipmaps")

	print("Turning over")
	viewer.show_item(photo_entry)
	await _begin_section(viewer)
	viewer.turn_over()
	await _await_turn(viewer)
	check(viewer.showing_back and viewer._photo_picture.texture.resource_path == PHOTO_BACK, "a turn ends on the back")
	check(absf(viewer._angle - PI) < 0.001, "the photo lies at PI on its back")
	viewer.turn_over()
	await _await_turn(viewer)
	check(not viewer.showing_back and viewer._photo_picture.texture.resource_path == PHOTO_FRONT, "a second turn returns to the front")
	check(_closes == 0, "nothing closed the item during these turns")

	print("The turn button")
	await _begin_section(viewer)
	viewer._turn_button._button.pressed.emit()
	await _await_turn(viewer)
	check(viewer.showing_back, "the turn button's own press turns the photo to its back")
	viewer._turn_button._button.pressed.emit()
	await _await_turn(viewer)
	check(not viewer.showing_back, "a second press of the turn button returns it to the front")
	check(_closes == 0, "nothing closed the item during these turns")

	print("A second turn during a turn")
	await _begin_section(viewer)
	viewer.turn_over()
	var running: Tween = viewer._turn_tween
	await process_frame
	viewer.turn_over()
	check(viewer._turn_tween == running and running.is_running(), "a turn that is under way is not restarted")
	await _await_turn(viewer)
	check(viewer.showing_back, "the turn ends on the back, because the second press did nothing")
	viewer.turn_over()
	await _await_turn(viewer)
	check(not viewer.showing_back, "the photo is back on its front before the next check")
	check(_closes == 0, "nothing closed the item during these turns")

	print("A tap")
	await _begin_section(viewer)
	_tap(viewer, Vector2(288, 192))
	await _await_turn(viewer)
	check(viewer.showing_back, "a tap on the photo turns it to the back")
	_tap(viewer, Vector2(288, 192))
	await _await_turn(viewer)
	check(not viewer.showing_back, "a second tap turns it back to the front")
	check(_closes == 0, "nothing closed the item during these taps")

	print("A tap with 12 px of drift")
	# Each turn from a middle goes forward on a tie, so the angle keeps growing across taps. This section starts from a fresh item.
	viewer.show_item(photo_entry)
	await _begin_section(viewer)
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(288, 192), true))
	viewer._photo_holder.gui_input.emit(_mouse_move(Vector2(300, 192)))
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(300, 192), false))
	await _await_turn(viewer)
	check(viewer.showing_back and absf(viewer._angle - PI) < 0.001, "a tap with 12 px of drift turns the photo to its back, and it stays there")
	check(viewer._photo_picture.texture.resource_path == PHOTO_BACK, "the photo shows its back after the drifting tap")
	viewer.turn_over()
	await _await_turn(viewer)
	check(not viewer.showing_back, "the photo is back on its front before the next check")
	check(_closes == 0, "nothing closed the item during this tap")

	print("A drag")
	viewer.show_item(photo_entry)
	await _begin_section(viewer)
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(100, 192), true))
	viewer._photo_holder.gui_input.emit(_mouse_move(Vector2(300, 192)))
	check(viewer.showing_back and absf(viewer._angle - 200.0 * PI / 300.0) < 0.001, "mid-drag, the photo is on its back and follows the mouse")
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(300, 192), false))
	await _await_turn(viewer)
	check(viewer.showing_back and absf(viewer._angle - PI) < 0.001, "letting go snaps the photo to the back")
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(300, 192), true))
	viewer._photo_holder.gui_input.emit(_mouse_move(Vector2(100, 192)))
	check(not viewer.showing_back, "dragged back, the photo is on its front")
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(100, 192), false))
	await _await_turn(viewer)
	check(not viewer.showing_back and absf(viewer._angle) < 0.001, "letting go snaps the photo to the front")
	check(_closes == 0, "nothing closed the item during this drag")

	print("A drag to the left from the front")
	await _begin_section(viewer)
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(300, 192), true))
	viewer._photo_holder.gui_input.emit(_mouse_move(Vector2(100, 192)))
	check(viewer.showing_back and absf(viewer._angle + 200.0 * PI / 300.0) < 0.001, "a drag to the left from the front reaches the back")
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(100, 192), false))
	await _await_turn(viewer)
	check(viewer.showing_back and absf(viewer._angle + PI) < 0.001 and viewer._photo_picture.texture.resource_path == PHOTO_BACK, "letting go snaps the photo to the back")
	check(_closes == 0, "nothing closed the item during this drag")

	print("A drag to the right from the back")
	await _begin_section(viewer)
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(100, 192), true))
	viewer._photo_holder.gui_input.emit(_mouse_move(Vector2(300, 192)))
	check(not viewer.showing_back, "a drag to the right from the back reaches the front")
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(300, 192), false))
	await _await_turn(viewer)
	check(not viewer.showing_back and absf(viewer._angle) < 0.001 and viewer._photo_picture.texture.resource_path == PHOTO_FRONT, "letting go snaps the photo to the front")
	check(_closes == 0, "nothing closed the item during this drag")

	print("A tap through the GUI")
	if DisplayServer.get_name() == "headless":
		# A headless run does not route mouse events to controls, so only a windowed run can check this.
		print("  skip   the GUI tap needs a window: run without --headless to check it")
	else:
		await _begin_section(viewer)
		var centre: Vector2 = viewer._photo_holder.get_global_rect().get_center()
		root.push_input(_mouse_button(centre, true))
		root.push_input(_mouse_button(centre, false))
		await _await_turn(viewer)
		check(viewer.showing_back, "a press and a release at the photo's centre, sent to the root, turn the photo")
		if viewer.showing_back:
			viewer.turn_over()
			await _await_turn(viewer)
		check(not viewer.showing_back, "the photo is on its front again after the GUI check")
		check(_closes == 0, "nothing closed the item during the GUI tap")

	print("R")
	await _begin_section(viewer)
	root.push_input(_key(KEY_R, true))
	check(not viewer._is_turning() and not viewer.showing_back, "an echo of R does not turn the photo")
	root.push_input(_key(KEY_R))
	check(viewer._is_turning(), "R turns the photo")
	await _await_turn(viewer)
	check(viewer.showing_back, "R turns the photo to its back")
	root.push_input(_key(KEY_R))
	await _await_turn(viewer)
	check(not viewer.showing_back, "a second R turns it back to the front")
	check(_closes == 0, "nothing closed the item during these turns")

	print("The turn button's visibility")
	viewer.show_item(photo_entry)
	check(viewer._turn_button.is_visible_in_tree(), "the turn button is shown again for the photo")

	print("Closing in the middle of a turn")
	viewer.show_item(photo_entry)
	viewer.turn_over()
	await _begin_section(viewer)
	check(viewer._is_turning(), "a turn is under way")
	_closes = 0
	viewer.close()
	check(not viewer._is_turning() and not viewer.visible, "closing stops the turn and hides the viewer")
	check(_closes == 1, "closing emits closed once")
	viewer.show_item(photo_entry)
	await _begin_section(viewer)
	check(not viewer.showing_back and viewer._angle == 0.0 and viewer._photo_picture.scale.x == 1.0, "the next photo opens on its front, at full width")
	check(viewer._photo_picture.texture.resource_path == PHOTO_FRONT, "the next photo shows its front")
	await _wait_frames(30)
	check(not viewer._is_turning() and not viewer.showing_back, "nothing turns the photo after it has opened")
	check(_closes == 0, "the next photo stays open, and nothing closes it")

	print("A drag that rests past the edge")
	viewer.show_item(photo_entry)
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(300, 192), true))
	viewer._photo_holder.gui_input.emit(_mouse_move(Vector2(470, 192)))
	check(viewer.showing_back, "a drag past the edge leaves the photo on its back")
	check(absf(viewer._photo_picture.scale.x - absf(cos(1.78))) < 0.01, "the photo keeps its true width where the drag rests, about 0.21")
	check(viewer._photo_picture.scale.x > 0.1, "the drag does not leave the photo edge-on")

	print("A press during a turn")
	viewer.show_item(photo_entry)
	await _begin_section(viewer)
	viewer.turn_over()
	var turning: Tween = viewer._turn_tween
	await process_frame
	var angle_before_press: float = viewer._angle
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(288, 192), true))
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(288, 192), false))
	check(viewer._angle == angle_before_press, "a press and a release during a turn leave the angle where the turn had got to")
	check(viewer._turn_tween == turning and viewer._is_turning(), "a press and a release during a turn start no second turn")
	await _await_turn(viewer)
	check(viewer.showing_back and absf(viewer._angle - PI) < 0.001 and viewer._photo_picture.scale.x > 0.99, "the turn ends on the back, drawn at full width")
	check(_closes == 0, "nothing closed the item during this turn")

	print("A press held through a turn")
	# A press and a release in one frame cannot tell a refused press from a taken one, since both leave the angle as it was. A press
	# held through the turn can: if the press were taken, its release would put the angle back to where the press was.
	viewer.show_item(photo_entry)
	await _begin_section(viewer)
	await _set_button_state(true)
	viewer.turn_over()
	await process_frame
	var angle_before_held_press: float = viewer._angle
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(288, 192), true))
	check(viewer._is_turning() and not viewer._pressing and viewer._angle == angle_before_held_press, "a press during a turn is refused, and the turn goes on")
	await _await_turn(viewer)
	var angle_at_held_end: float = viewer._angle
	await _set_button_state(false)
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(288, 192), false))
	check(viewer._angle == angle_at_held_end, "the release after the turn leaves the angle where the turn left it")
	check(viewer.showing_back and absf(viewer._angle - PI) < 0.001, "the photo is on the opposite face, its back, after the release")
	check(_closes == 0, "nothing closed the item during this turn")

	print("A release during a turn that began after the press")
	viewer.show_item(photo_entry)
	await _begin_section(viewer)
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(288, 192), true))
	viewer._turn_to(PI, ItemViewer.TURN_SECONDS)
	var turning_after_press: Tween = viewer._turn_tween
	await process_frame
	var angle_before_release: float = viewer._angle
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(288, 192), false))
	check(viewer._angle == angle_before_release, "a release during a turn that began after the press undoes nothing")
	check(viewer._turn_tween == turning_after_press and viewer._is_turning() and not viewer._pressing, "a release during a turn that began after the press starts no second turn")
	await _await_turn(viewer)
	check(viewer.showing_back and absf(viewer._angle - PI) < 0.001, "the photo ends on its back, where that turn took it")
	check(_closes == 0, "nothing closed the item during this turn")

	print("A lost release")
	await _set_button_state(false)
	viewer.show_item(photo_entry)
	await _begin_section(viewer)
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(100, 192), true))
	viewer._photo_holder.gui_input.emit(_mouse_move(Vector2(300, 192)))
	viewer.turn_over()
	check(viewer._is_turning() and not viewer._pressing and not viewer._dragging, "with no release, turn_over drops the lost press and starts the turn")
	await _await_turn(viewer)
	check(not viewer.showing_back and absf(viewer._angle) < 0.001, "the turn takes the photo from its back to the middle of its front")
	check(_closes == 0, "nothing closed the item during this turn")

	print("A release after a turn does not undo it")
	viewer.show_item(photo_entry)
	await _begin_section(viewer)
	await _set_button_state(true)
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(288, 192), true))
	check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and viewer._pressing, "the press is still held when the turn starts")
	viewer.turn_over()
	check(viewer._is_turning() and not viewer._pressing, "a turn that starts while the press is held cancels the press")
	await _await_turn(viewer)
	var angle_at_end: float = viewer._angle
	await _set_button_state(false)
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(288, 192), false))
	check(viewer._angle == angle_at_end, "the release after the turn leaves the angle where the turn left it")
	check(viewer.showing_back and absf(viewer._angle - PI) < 0.001, "the photo is on the opposite face, its back, after the release")
	check(_closes == 0, "nothing closed the item during this turn")

	print("Motion during a turn does not move the card")
	viewer.show_item(photo_entry)
	await _begin_section(viewer)
	await _set_button_state(true)
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(100, 192), true))
	check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and viewer._pressing, "the press is still held when the turn starts")
	viewer.turn_over()
	await process_frame
	var angle_mid_turn: float = viewer._angle
	viewer._photo_holder.gui_input.emit(_mouse_move(Vector2(300, 192)))
	check(viewer._is_turning() and viewer._angle == angle_mid_turn and not viewer._dragging, "a drag of 200 px during a turn does not move the photo")
	await _await_turn(viewer)
	check(viewer.showing_back and absf(viewer._angle - PI) < 0.001, "the turn still ends on the back")
	check(viewer._photo_picture.scale.x > 0.99, "after the motion the photo is at full width, not edge-on")
	await _set_button_state(false)
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(300, 192), false))
	check(_closes == 0, "nothing closed the item during this turn")

	print("A turn from near an edge ends settled on the far face")
	viewer.show_item(photo_entry)
	await _begin_section(viewer)
	viewer._set_angle(PI / 2.0 - 0.05, false)
	viewer.turn_over()
	await _await_turn(viewer)
	check(viewer.showing_back and absf(viewer._angle - PI) < 0.001, "a turn from near the edge of the front ends in the middle of the back")
	check(viewer._photo_picture.scale.x > 0.9, "the photo is at full width after a turn from near the edge")
	check(_closes == 0, "nothing closed the item during this turn")

	print("A turn from off-centre takes the short way")
	viewer.show_item(photo_entry)
	await _begin_section(viewer)
	viewer._set_angle(-PI / 4.0, false)
	viewer.turn_over()
	await _await_turn(viewer)
	check(viewer.showing_back and absf(viewer._angle + PI) < 0.001, "a turn from -PI / 4 on the front ends at -PI, the nearer middle of the back, and not at +PI")
	check(viewer._photo_picture.texture.resource_path == PHOTO_BACK, "the photo shows its back after the short turn")
	check(_closes == 0, "nothing closed the item during this turn")

	print("Settling")
	viewer.show_item(photo_entry)
	viewer._angle = PI / 2.0 - 0.1
	viewer._set_angle(PI / 2.0 + 0.1, true)
	check(viewer._photo_picture.scale.x <= 0.0011 and viewer.showing_back, "a turn through the edge-on angle draws the photo edge-on, on its back")
	viewer._settle()
	check(absf(viewer._photo_picture.scale.x - absf(cos(PI / 2.0 + 0.1))) < 0.001, "settling draws the photo at its true angle")

	print("Snap ties and an edge-on start")
	check(absf(viewer._snap_target(-PI / 2.0)) < 0.001, "a drag that ends on the edge at -PI / 2 settles on the front")
	check(absf(viewer._snap_target(-3.0 * PI / 2.0) + PI) < 0.001, "a drag that ends on the edge at -3 PI / 2 settles on the back")
	check(viewer._snap_target(-PI / 2.0) == 0.0, "the edge at -PI / 2 snaps to the middle of the front, exactly 0.0")
	check(viewer._snap_target(-3.0 * PI / 2.0) == -PI, "the edge at -3 PI / 2 snaps to the middle of the back, exactly -PI")
	for angle: float in [-3.0 * PI / 2.0, -PI / 2.0, PI / 2.0, 3.0 * PI / 2.0]:
		check(viewer._face_is_back(angle) == viewer._face_is_back(viewer._snap_target(angle)), "the edge at %.4f snaps to the face it is on" % angle)
	check(absf(viewer._crossing(PI / 2.0, PI / 2.0 - 0.1) - PI / 2.0) < 0.001, "a turn that starts edge-on crosses at its start")
	viewer.show_item(photo_entry)

	print("A photo without a back")
	viewer.show_item({"type": "photo", "title": "A photo", "front": PHOTO_FRONT})
	check(not viewer.has_back() and not viewer._turn_button.is_visible_in_tree(), "a photo without a back has no turn button")
	viewer.turn_over()
	check(viewer._angle == 0.0 and not viewer._is_turning(), "turn_over does nothing to a photo without a back")
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(100, 192), true))
	viewer._photo_holder.gui_input.emit(_mouse_move(Vector2(300, 192)))
	viewer._photo_holder.gui_input.emit(_mouse_button(Vector2(300, 192), false))
	check(viewer._angle == 0.0 and not viewer.showing_back, "a drag does nothing to a photo without a back")

	print("A photo still to come")
	viewer.show_item({"type": "photo", "title": "A photo", "front": ""})
	check(viewer._body.text == "Photo to come." and viewer._body.is_visible_in_tree(), "the photo says it is to come")
	check(not viewer._photo_holder.visible and not viewer.has_back(), "there is no holder for a photo still to come")

	print("A letter")
	viewer.show_item({"type": "image", "image": LETTER})
	check(viewer._picture.texture != null and viewer._picture.visible, "the letter's picture shows")
	check(viewer._picture.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "the letter's picture is drawn with linear filtering between its mipmaps")
	check(not viewer.has_back() and not viewer._turn_button.is_visible_in_tree(), "a letter has no turn")
	var letter_texture: Texture2D = viewer._picture.texture
	var letter_fit: Vector2 = viewer._picture.custom_minimum_size
	check(absf(letter_fit.y - (viewer.size.y - 48.0)) < 0.5, "the letter is as tall as the screen, less 24 px above and below")
	check(absf(letter_fit.x / letter_fit.y - float(letter_texture.get_width()) / letter_texture.get_height()) < 0.001, "the letter keeps the shape of its picture")
	check(not viewer._scroll.visible, "the letter is not in a scroll")
	print("Letter on screen")
	await _begin_section(viewer)
	await process_frame
	var letter_rect: Rect2 = viewer._picture.get_global_rect()
	check(letter_rect.position.x >= 0.0 and letter_rect.position.y >= 0.0 and letter_rect.end.x <= viewer.size.x and letter_rect.end.y <= viewer.size.y, "the letter lies inside the screen, its top and bottom clear of the edges")
	check(letter_rect.position.y >= ItemViewer.FIT_MARGIN - 0.5, "the letter's top is at least FIT_MARGIN from the top of the screen, to half a pixel")
	check(letter_rect.end.y <= viewer.size.y - ItemViewer.FIT_MARGIN + 0.5, "the letter's bottom is at least FIT_MARGIN from the bottom of the screen, to half a pixel")
	check(absf(letter_rect.size.y - (viewer.size.y - 2.0 * ItemViewer.FIT_MARGIN)) < 0.5, "laid out, the letter is as tall as the screen, less FIT_MARGIN above and below, to half a pixel")
	check(absf(letter_rect.get_center().x - viewer.size.x / 2.0) < 1.0, "the letter's centre is within 1 px of the screen's centre")
	check(absf(letter_rect.get_center().x - viewer.size.x / 2.0) < 0.5, "the letter is centred on the screen")
	check(not letter_rect.intersection(viewer._close.get_global_rect()).has_area(), "the close cross does not overlap the letter")
	check(_closes == 0, "nothing closed the item while the letter was laid out")
	viewer.show_item({"type": "letter", "title": "A letter", "text": "Some words."})
	check(viewer._body.text == "Some words." and viewer._body.is_visible_in_tree() and not viewer._picture.visible, "a text letter shows its words")

	print("A letter on a narrow screen")
	viewer.size = Vector2(320.0, 568.0)
	viewer.show_item({"type": "image", "image": LETTER})
	var narrow_fit: Vector2 = viewer._picture.custom_minimum_size
	var letter_shape: float = float(viewer._front_face.get_width()) / float(viewer._front_face.get_height())
	var narrow_width := 320.0 - 2.0 * ItemViewer.FIT_MARGIN - 2.0 * (ItemViewer.CLOSE_MARGIN + CloseCross.SIZE.x)
	check(absf(narrow_fit.x - narrow_width) < 0.5 and absf(narrow_fit.x / narrow_fit.y - letter_shape) < 0.001, "a letter wider than the room beside the close cross, on a narrow screen, is fitted to that room and keeps its shape")
	viewer._fit()
	check(absf(viewer._picture.custom_minimum_size.y - (viewer.size.y - 2.0 * ItemViewer.FIT_MARGIN)) < 0.5, "fitting the viewer again refits the letter to the screen's height")
	viewer.show_item({"type": "image", "image": LETTER})

	print("The close cross clears a wide letter")
	await _begin_section(viewer)
	var letter_face: Texture2D = viewer._front_face
	viewer._front_face = ImageTexture.create_from_image(Image.create(200, 100, false, Image.FORMAT_RGB8))
	viewer._fit_letter()
	var clear_width := viewer.size.x - 2.0 * ItemViewer.FIT_MARGIN - 2.0 * (ItemViewer.CLOSE_MARGIN + CloseCross.SIZE.x)
	check(viewer._picture.custom_minimum_size.x <= clear_width + 0.001, "a picture twice as wide as it is tall is no wider than the room that leaves the close cross clear")
	check(absf(viewer._picture.custom_minimum_size.x - clear_width) < 0.5, "that picture is fitted to the room beside the close cross, not made smaller")
	await process_frame
	check(not viewer._picture.get_global_rect().intersection(viewer._close.get_global_rect()).has_area(), "laid out, that picture does not overlap the close cross")
	viewer._front_face = letter_face
	viewer._fit_letter()
	check(_closes == 0, "nothing closed the item while the wide letter was laid out")

	print("The frame and the corner")
	check(not _draws_frame(viewer._picture), "the letter's picture draws no frame of its own")
	check(not _draws_frame(viewer._photo_holder), "the photo holder draws no frame of its own")
	check(not _draws_frame(viewer._photo_picture), "the photo picture draws no frame of its own")
	check(not _has_frame(viewer, viewer._turn_row), "no control under the viewer draws a frame, except the turn button, which draws its own on purpose")
	var stray := Panel.new()
	var border := StyleBoxFlat.new()
	border.set_border_width_all(2)
	stray.add_theme_stylebox_override("panel", border)
	viewer.add_child(stray)
	check(_has_frame(viewer, viewer._turn_row), "a panel with a bordered StyleBoxFlat under the viewer is found")
	viewer.remove_child(stray)
	stray.free()
	check(not _has_frame(viewer, viewer._turn_row), "with that panel removed, the viewer has no frame again")
	# The base is the hit area the viewer's own buttons use, so the hover override is the only bordered style of this button.
	var stray_button := UiKit.hit_area()
	stray_button.add_theme_stylebox_override("hover", border)
	viewer.add_child(stray_button)
	check(_has_frame(viewer, viewer._turn_row), "a button with a bordered hover style under the viewer is found")
	viewer.remove_child(stray_button)
	stray_button.free()
	check(not _has_frame(viewer, viewer._turn_row), "with that button removed, the viewer has no frame again")
	await _begin_section(viewer)
	var close_rect: Rect2 = viewer._close.get_global_rect()
	var screen_width: float = viewer.get_viewport_rect().size.x
	check(absf(close_rect.end.x - (screen_width - 18.0)) < 0.5 and absf(close_rect.position.y - 18.0) < 0.5, "the close cross sits in the top right corner")
	check(viewer._close.anchor_left == 1.0 and viewer._close.anchor_right == 1.0 and viewer._close.anchor_top == 0.0 and viewer._close.anchor_bottom == 0.0, "the close cross is anchored to the top right")
	check(_closes == 0, "nothing closed the item during this section")

	print("E, Enter and Esc")
	viewer.show_item({"type": "letter", "title": "A letter", "text": "Some words."})
	root.push_input(_key(KEY_E))
	check(viewer.visible, "E does not close the item in its first moments")
	viewer._open_for = 0.4
	root.push_input(_key(KEY_E))
	check(viewer.visible, "E does not close the item at 0.4 seconds")
	viewer._open_for = ItemViewer.MIN_SECONDS
	root.push_input(_key(KEY_E))
	check(not viewer.visible, "E closes the item once MIN_SECONDS has passed")
	viewer.show_item({"type": "letter", "title": "A letter", "text": "Some words."})
	root.push_input(_key(KEY_ESCAPE))
	check(not viewer.visible, "Esc closes the item at once")
	viewer.show_item({"type": "letter", "title": "A letter", "text": "Some words."})
	await process_frame
	check(viewer.get_viewport().gui_get_focus_owner() == viewer._close._button, "the close cross has the focus one frame after the viewer opens")
	viewer._open_for = 0.0
	root.push_input(_key(KEY_ENTER))
	root.push_input(_key(KEY_ENTER, false, false))
	check(not viewer.visible and viewer._open_for < ItemViewer.MIN_SECONDS, "Enter, pressed and released on the focused close cross, closes the item at once, before MIN_SECONDS")
	viewer.show_item({"type": "letter", "title": "A letter", "text": "Some words."})
	await process_frame
	# With the focus released, Enter takes the moment rule that E takes, so it waits for MIN_SECONDS as E does.
	viewer.get_viewport().gui_release_focus()
	viewer._open_for = 0.4
	root.push_input(_key(KEY_ENTER))
	root.push_input(_key(KEY_ENTER, false, false))
	check(viewer.visible, "with the focus released, Enter does not close the item at 0.4 seconds")
	viewer._open_for = ItemViewer.MIN_SECONDS
	root.push_input(_key(KEY_ENTER))
	root.push_input(_key(KEY_ENTER, false, false))
	check(not viewer.visible, "with the focus released, Enter closes the item once MIN_SECONDS has passed, as E does")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _on_viewer_closed() -> void:
	_closes += 1


## Starts a section that waits on frames. The close cross gives up its focus, so a real Enter or Space cannot press it, and the
## closed signal is counted from here. show_item asks for the focus in a deferred call, which runs during the frame that the
## wait lets pass, so the focus is released again after that frame.
func _begin_section(viewer: ItemViewer) -> void:
	viewer._close._button.release_focus()
	_closes = 0
	await process_frame
	viewer._close._button.release_focus()


## Waits, frame by frame, until the viewer's turn ends. The limit stops a turn that never ends from hanging the run; the check
## after the wait then fails.
func _await_turn(viewer: ItemViewer) -> void:
	var frames := 0
	while viewer._is_turning() and frames < TURN_FRAME_LIMIT:
		await process_frame
		frames += 1


## Lets a fixed number of frames run, for a check that nothing happens. The count does not depend on the clock.
func _wait_frames(count: int) -> void:
	for _frame in count:
		await process_frame


## Sets the left button's state as the game's Input sees it, which a turn reads to tell whether a press is still held. Input
## applies the event at the next frame, so this waits one frame.
func _set_button_state(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = OFF_PHOTO
	event.global_position = OFF_PHOTO
	Input.parse_input_event(event)
	await process_frame


## A press and a release at the same spot on the photo.
func _tap(viewer: ItemViewer, at: Vector2) -> void:
	viewer._photo_holder.gui_input.emit(_mouse_button(at, true))
	viewer._photo_holder.gui_input.emit(_mouse_button(at, false))


func _mouse_button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	return event


func _mouse_move(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event


func _key(keycode: int, echo: bool = false, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event


## True when a control under this node, or the node itself, draws a bordered StyleBoxFlat in one of its styles. The walk skips the
## node named as skip and everything under it. The Turn over button draws its own frame on purpose, so the check leaves its row out.
func _has_frame(node: Node, skip: Node = null) -> bool:
	if node is Control and _draws_frame(node as Control):
		return true
	for child in node.get_children():
		if child != skip and _has_frame(child, skip):
			return true
	return false


## True when a control's effective panel, normal, hover, pressed, focus or disabled style is a StyleBoxFlat with a border. An
## override counts, and so does the style the theme gives the control. A style the control does not have is skipped: for such a
## style get_theme_stylebox returns a bordered fallback. A focus style is drawn only on a control that can take the focus.
func _draws_frame(control: Control) -> bool:
	for style_name in ["panel", "normal", "hover", "pressed", "focus", "disabled"]:
		if style_name == "focus" and control.focus_mode == Control.FOCUS_NONE:
			continue
		if not control.has_theme_stylebox(style_name):
			continue
		var style := control.get_theme_stylebox(style_name) as StyleBoxFlat
		if style != null and _has_border(style):
			return true
	return false


func _has_border(style: StyleBoxFlat) -> bool:
	return style.border_width_left > 0 or style.border_width_top > 0 or style.border_width_right > 0 or style.border_width_bottom > 0
