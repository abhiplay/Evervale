class_name WalkMask
extends RefCounted
## Collision from a painted walk mask (data/walkmasks/*.png): a PNG the size of the room's picture, opaque where the
## room is solid (walls, the floor footprint of furniture) and transparent where Amelia can walk. Painting over the
## room's picture is how the collision is refined; scripts/gen_walk_masks.py made the first masks from the old
## rectangles.
##
## The mask is read on a grid of CELL pixels and its solid cells are merged into as few rectangles as possible, one
## StaticBody2D holding them all. Rectangles rather than traced outlines, because a ring of walls traced as one outline
## would fill the floor inside it.

const CELL := 2
const BODY_NAME := "WalkMaskSolids"


## Replaces the room's solids with the mask's: the scene's own wall and furniture bodies go (walking figures stay), and
## the mask's rectangles take their place.
static func apply(host: Node2D, mask_path: String) -> void:
	for child in host.get_children():
		if child is StaticBody2D and not child.is_in_group("figures"):
			host.remove_child(child)
			child.queue_free()
	var body := StaticBody2D.new()
	body.name = BODY_NAME
	for rect in rects(mask_path):
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = rect.get_center()
		body.add_child(collision)
	host.add_child(body)


## The mask's solid area as rectangles in picture pixels, merged row by row on the CELL grid.
static func rects(mask_path: String) -> Array[Rect2]:
	var texture: Texture2D = load(mask_path)
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var cols := ceili(image.get_width() / float(CELL))
	var rows := ceili(image.get_height() / float(CELL))
	# A cell is solid when the pixel at its centre is opaque.
	var result: Array[Rect2] = []
	## Rectangles still growing downward, by "start,end" column span: [first row, start col, end col].
	var open := {}
	for row in rows + 1:
		var spans := {}
		if row < rows:
			var y := mini(row * CELL + CELL / 2, image.get_height() - 1)
			var col := 0
			while col < cols:
				if _solid(image, col, y):
					var start := col
					while col < cols and _solid(image, col, y):
						col += 1
					spans["%d,%d" % [start, col]] = [start, col]
				else:
					col += 1
		# Spans that continue keep growing; the others close here.
		for key in open.keys():
			if not spans.has(key):
				var r: Array = open[key]
				result.append(Rect2(r[1] * CELL, r[0] * CELL, (r[2] - r[1]) * CELL, (row - r[0]) * CELL))
				open.erase(key)
		for key in spans:
			if not open.has(key):
				open[key] = [row, spans[key][0], spans[key][1]]
	return result


static func _solid(image: Image, col: int, y: int) -> bool:
	var x := mini(col * CELL + CELL / 2, image.get_width() - 1)
	return image.get_pixel(x, y).a > 0.5
