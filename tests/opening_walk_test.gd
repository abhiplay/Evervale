extends SceneTree
## Checks: through the whole opening, in the front yard and inside the house, no two figures' feet ever overlap, and the
## opening finishes with Evelyn and Oliver gone. It runs the real opening and samples every frame. Frame limits only. Run:
## Godot --headless --path . -s res://tests/opening_walk_test.gd

const MAX_FRAMES := 9000

var failures: Array[String] = []
var _overlap_frames := 0
var _min_gap := INF
var _pairs_seen := 0
## Where each of them was last seen in the front yard, which is where they reach the door.
var _yard_player := Vector2.INF
var _yard_evelyn := Vector2.INF
var _yard_oliver := Vector2.INF


func check(condition: bool, message: String) -> void:
	print(("  ok   " if condition else "  FAIL ") + message)
	if not condition:
		failures.append(message)


## The gap between two feet rectangles: negative when they overlap, otherwise the larger of the two side gaps.
func _gap(a: Rect2, b: Rect2) -> float:
	var gap_x := maxf(b.position.x - a.end.x, a.position.x - b.end.x)
	var gap_y := maxf(b.position.y - a.end.y, a.position.y - b.end.y)
	return maxf(gap_x, gap_y)


## Samples every pair of figures in the scene now on screen.
func _sample(scene: Node) -> void:
	var figures: Array = []
	for node in scene.get_tree().get_nodes_in_group("figures"):
		if scene.is_ancestor_of(node):
			figures.append(node)
	var overlapping := false
	for i in figures.size():
		for j in range(i + 1, figures.size()):
			var gap: float = _gap(SceneWalkers.feet_rect(figures[i]), SceneWalkers.feet_rect(figures[j]))
			_pairs_seen += 1
			_min_gap = minf(_min_gap, gap)
			if gap < 0.0:
				overlapping = true
	if overlapping:
		_overlap_frames += 1
	if scene.scene_file_path == "res://scenes/ExteriorHome.tscn":
		_yard_player = scene.player.position
		for node in figures:
			var walker = node.get_node_or_null("Walker")
			if walker == null:
				continue
			if walker.animations_path == "res://data/evelyn_animations.json":
				_yard_evelyn = node.position
			elif walker.animations_path == "res://data/oliver_animations.json":
				_yard_oliver = node.position


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	save.state = save.new_game_state()
	save.state.world_state["opening_stage"] = "pending"
	var yard = load("res://scenes/ExteriorHome.tscn").instantiate()
	root.add_child(yard)
	current_scene = yard
	var frames := 0
	while frames < MAX_FRAMES and save.state.world_state.get("opening_stage", "") != "done":
		await process_frame
		frames += 1
		var scene = current_scene
		# Between two scenes there is no current scene for a frame or two, while the next one loads.
		if scene == null or not is_instance_valid(scene) or not ("scene_dialogue" in scene):
			continue
		if scene.scene_dialogue.is_open:
			scene.scene_dialogue.advance()
		_sample(scene)

	check(save.state.world_state.get("opening_stage", "") == "done", "the opening finishes within its frame limit (%d frames)" % frames)
	check(_pairs_seen > 0, "figures were compared during the opening")
	check(_overlap_frames == 0, "no two figures' feet overlap at any frame of the opening (%d overlapping frames)" % _overlap_frames)
	check(_min_gap >= 0.0, "the closest two figures get in the opening is %.1f px" % _min_gap)
	check(_yard_player.distance_to(Vector2(748, 380)) < 12.0, "Amelia reaches the front door (%.1f px away)" % _yard_player.distance_to(Vector2(748, 380)))
	check(_yard_evelyn.distance_to(Vector2(718, 380)) < 12.0, "Evelyn reaches her place by the door (%.1f px away)" % _yard_evelyn.distance_to(Vector2(718, 380)))
	check(_yard_oliver.distance_to(Vector2(778, 380)) < 12.0, "Oliver reaches his place by the door (%.1f px away)" % _yard_oliver.distance_to(Vector2(778, 380)))
	# Freed figures leave the tree at the end of a frame, so give them a few frames to go.
	for i in 3:
		await process_frame
	var left := 0
	for node in current_scene.get_tree().get_nodes_in_group("figures"):
		if current_scene.is_ancestor_of(node) and node.get_node_or_null("Walker") != null:
			left += 1
	check(left == 0, "Evelyn and Oliver have left the house by the end of the opening")

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
