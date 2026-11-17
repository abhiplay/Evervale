class_name BasePanel
extends NinePatchRect
## A frame cut from the UI sheet. The corners keep their size and only the middle stretches, so the ornaments are
## never squashed. Whatever sits inside is placed by its own container or anchors.


func setup(frame_path: String, margin_x: int, margin_y: int) -> void:
	texture = UiKit.texture(frame_path)
	patch_margin_left = margin_x
	patch_margin_right = margin_x
	patch_margin_top = margin_y
	patch_margin_bottom = margin_y
	draw_center = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
