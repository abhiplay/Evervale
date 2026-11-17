extends SceneTree
## Saves a picture of the bookstore with every solid drawn in the game, and the character's feet marked, to check the collision
## against the picture. Run without --headless: Godot --path . -s res://tests/bookstore_collision_debug_screenshot.gd

const OUT_DIR := "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/706b6a2c-a895-48fd-8729-9870ac3d8642/scratchpad/screenshots"


class Overlay extends Node2D:
	var shop
	func _draw() -> void:
		for body in shop.get_children():
			if not (body is StaticBody2D):
				continue
			for child in body.get_children():
				if child is CollisionShape2D and child.shape is RectangleShape2D:
					var size: Vector2 = child.shape.size
					var centre: Vector2 = body.position + child.position
					var rect := Rect2(centre - size / 2.0, size)
					draw_rect(rect, Color(1, 0.2, 0.2, 0.35), true)
					draw_rect(rect, Color(1, 0.4, 0.4, 1), false, 2.0)
		draw_circle(shop.player.position, 4.0, Color(0.2, 1, 0.2, 1))


func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/SaveSystem")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	save.state = save.new_game_state()
	var shop = load("res://scenes/TownSquare.tscn").instantiate()
	root.add_child(shop)
	current_scene = shop
	for i in 3:
		await process_frame
	shop.player.position = Vector2(760, 640)
	shop.scripted = true
	shop.camera.position_smoothing_enabled = false
	shop.camera.limit_left = -100000
	shop.camera.limit_right = 100000
	shop.camera.limit_top = -100000
	shop.camera.limit_bottom = 100000
	shop.camera.zoom = Vector2(0.9, 0.9)
	var overlay := Overlay.new()
	overlay.shop = shop
	overlay.z_index = 50
	shop.add_child(overlay)
	for i in 30:
		overlay.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png(OUT_DIR + "/town_collision_in_game.png")
	print("saved in-game collision overlay")
	quit(0)
