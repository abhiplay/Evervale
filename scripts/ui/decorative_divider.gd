class_name DecorativeDivider
extends TextureRect
## A thin gold divider cut from the UI sheet. It keeps its own shape and never stretches.

const HEIGHT := 12.0


func _ready() -> void:
	texture = UiKit.texture(UiAssets.DIVIDER)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, HEIGHT)
