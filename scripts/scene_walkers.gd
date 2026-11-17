class_name SceneWalkers
extends RefCounted
## Walking figures for the scripted scenes: a figure with its own walk sheets (Oliver, Evelyn), and figures that walk
## together to their targets. Used by OpeningSequence, BoxTalk and the florist. Every figure is in the group "figures" and
## has a feet collision, so each one knows where the others are and walks around them rather than through them.

## The gap kept between the feet of two figures while they walk, in pixels.
const GAP := 4.0
## A figure blocked for this long stops where it is, so a scene is never held up by two figures in each other's way.
const STUCK_SECONDS := 0.5


## A figure with its own walk sheets, built like the player's sprite. Its size is the player's scale times `size`.
## It has the player's feet collision, so the player cannot walk through it.
static func walker(host: Node2D, animations: String, size: float = 1.0) -> Node2D:
	# A static body, not an animatable one: an animatable body applies a position a physics frame late.
	var holder := StaticBody2D.new()
	# In a depth-sorted scene the figure is sorted with the furniture, so it has no fixed z.
	holder.z_index = 0 if host.DEPTH_SORTED else 5
	holder.add_to_group("figures")
	var sprite := CharacterSprite.new()
	sprite.name = "Walker"
	sprite.animations_path = animations
	sprite.character_scale = host.PLAYER_SCALE * size
	holder.add_child(sprite)
	holder.add_child(CharacterSprite.feet_collider(sprite.character_scale))
	return holder


## Walks each node to its target at the same time, and waits until they have all arrived. Each figure moves frame by frame
## and steps around the others' feet rather than through them. A figure that cannot move stops where it is.
static func walk_together(host: Node2D, moves: Array, seconds: float) -> void:
	var walkers: Array = []
	for move in moves:
		var node: Node2D = move[0]
		var target: Vector2 = move[1]
		var distance := node.position.distance_to(target)
		walkers.append({"node": node, "target": target, "speed": distance / maxf(seconds, 0.01), "stuck": 0.0, "done": distance < 0.5})
	var limit := seconds * 3.0
	var elapsed := 0.0
	while true:
		var delta: float = host.get_process_delta_time()
		var pending := false
		for walker in walkers:
			if not walker.done:
				_step(host, walker, delta)
				pending = pending or not walker.done
		elapsed += delta
		if not pending or elapsed >= limit:
			break
		await host.get_tree().process_frame
	for walker in walkers:
		var walk_sprite_node := walk_sprite(host, walker.node)
		if walk_sprite_node:
			walk_sprite_node.update_movement(Vector2.ZERO)


## Moves one figure a frame toward its target, unless the step would bring its feet into another figure's feet. A blocked
## figure first tries the step along one axis only, so it slides past a figure rather than stopping dead.
static func _step(host: Node2D, walker: Dictionary, delta: float) -> void:
	var node: Node2D = walker.node
	var walk_sprite_node := walk_sprite(host, node)
	var to_target: Vector2 = walker.target - node.position
	var remaining := to_target.length()
	if remaining < 0.5:
		node.position = walker.target
		walker.done = true
		if walk_sprite_node:
			walk_sprite_node.update_movement(Vector2.ZERO)
		return
	var step := to_target.normalized() * minf(walker.speed * delta, remaining)
	var used := Vector2.ZERO
	for candidate in [step, Vector2(step.x, 0.0), Vector2(0.0, step.y)]:
		if candidate.length() < 0.01:
			continue
		if not _blocked(node, node.position + candidate):
			used = candidate
			break
	if used != Vector2.ZERO:
		node.position += used
		walker.stuck = 0.0
		if walk_sprite_node:
			walk_sprite_node.update_movement(used.normalized())
		return
	walker.stuck += delta
	if walk_sprite_node:
		walk_sprite_node.update_movement(Vector2.ZERO)
	if walker.stuck >= STUCK_SECONDS:
		walker.done = true


## Whether a figure standing at `at` would come within GAP of another figure it is not already that close to. A figure
## already that close may still move, so two figures that start together can part.
static func _blocked(node: Node2D, at: Vector2) -> bool:
	var mine := feet_rect_at(node, at).grow(GAP)
	var now := feet_rect(node).grow(GAP)
	for other in node.get_tree().get_nodes_in_group("figures"):
		if other == node or other.get_parent() != node.get_parent():
			continue
		var theirs := feet_rect(other)
		if mine.intersects(theirs) and not now.intersects(theirs):
			return true
	return false


## The feet of a figure, as a rectangle in its parent's space: its collision shape, placed at the figure's position.
static func feet_rect(node: Node2D) -> Rect2:
	return feet_rect_at(node, node.position)


static func feet_rect_at(node: Node2D, at: Vector2) -> Rect2:
	# The feet's bounding box, whatever their shape (a capsule lying on its side, or a box).
	for child in node.get_children():
		if child is CollisionShape2D and child.shape != null:
			var local: Rect2 = child.transform * child.shape.get_rect()
			return Rect2(at + local.position, local.size)
	return Rect2(at, Vector2.ZERO)


## Turns two figures to face each other, each standing still. Used for a talk.
static func face_each_other(host: Node2D, first: Node2D, second: Node2D) -> void:
	var toward_second := second.position - first.position
	if toward_second.length() < 1.0:
		return
	var first_sprite := walk_sprite(host, first)
	if first_sprite:
		first_sprite.face(toward_second)
	var second_sprite := walk_sprite(host, second)
	if second_sprite:
		second_sprite.face(-toward_second)


## Turns one figure to face a point, standing still. Used when a talk has one figure facing the other side.
static func face_point(host: Node2D, node: Node2D, point: Vector2) -> void:
	var sprite := walk_sprite(host, node)
	if sprite:
		sprite.face(point - node.position)


## The walking sprite of a figure: the player's own sprite, or the sprite inside a walker.
static func walk_sprite(host: Node2D, node: Node2D) -> CharacterSprite:
	if node == host.player:
		return host.sprite
	return node.get_node_or_null("Walker") as CharacterSprite
