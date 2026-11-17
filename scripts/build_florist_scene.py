"""Writes scenes/Florist.tscn with the florist shop's static content as real nodes, so it shows in the Godot editor.

The picture, the furniture (visible), its shadows, the hidden occluders that draw the furniture over the
character when she is behind it, and the collision are all nodes here. scripts/florist.gd links the
occluders to the character.

Collision: each furniture piece gets a convex polygon traced from its art (the same method as the café
tables), in place of the rectangle it replaces in data/florist_interior_collision.json. The walls stay
rectangles. Run this after changing the furniture positions below or the solids in the collision data.
Needs OpenCV (cv2) and Pillow.
"""
import json

import cv2
import numpy as np
from PIL import Image

OUT = "scenes/Florist.tscn"
COLLISION = "data/florist_interior_collision.json"
PICTURE = "res://assets/environments/florist_interior.webp"
FURNITURE_DIR = "res://assets/environments/furniture/"
FURNITURE_FILES = "assets/environments/furniture/"
# Each piece: node name, image file, top-left corner in the picture (its rectangle is the image's size),
# and the solid in the collision data that its polygon replaces.
FURNITURE = [
    ("worktable", "florist_worktable_placed.png", (249, 414), "solid_6"),
    ("shelf_upper", "florist_shelf_upper_placed.png", (688, 298), "solid_2"),
    ("shelf_lower", "florist_shelf_lower_placed.png", (693, 500), "solid_10"),
    ("fridge", "florist_fridge_placed.png", (1213, 440), "solid_7"),
    ("sign", "florist_sign_placed.png", (1412, 478), "solid_8"),
    ("buckets", "florist_buckets_placed.png", (1155, 488), "solid_9"),
]
ALPHA_MIN = 128          # a pixel is part of a piece at least this opaque (as the café tables)
HULL_TOLERANCE_PX = 1.5  # simplification of each outline (as the café tables)
MIN_PART_AREA = 20       # smaller specks are ignored; separate parts such as a stool are kept
NL = "\n"


def node(name, kind, parent, props=""):
    head = f'[node name="{name}" type="{kind}" parent="{parent}"]' if parent else f'[node name="{name}" type="{kind}"]'
    return head + NL + props


def fmt(n):
    return f"{n:g}"


def point_list(points):
    return ", ".join(f"{x}, {y}" for x, y in points)


def furniture_outline(image, origin):
    """Convex outline of one piece's art, in picture pixels. Every part of the piece is inside it."""
    rgba = np.asarray(Image.open(FURNITURE_FILES + image).convert("RGBA"))
    mask = (rgba[..., 3] >= ALPHA_MIN).astype(np.uint8) * 255
    kernel = np.ones((3, 3), np.uint8)
    mask = cv2.morphologyEx(cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel), cv2.MORPH_CLOSE, kernel)
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    parts = [c for c in contours if cv2.contourArea(c) >= MIN_PART_AREA]
    hull = cv2.convexHull(np.vstack(parts))
    approx = cv2.approxPolyDP(hull, HULL_TOLERANCE_PX, True).reshape(-1, 2)
    ox, oy = origin
    return [[int(x) + ox, int(y) + oy] for x, y in approx]


def main():
    solids = json.load(open(COLLISION))["solids"]
    replaced = {solid_id for _, _, _, solid_id in FURNITURE}
    missing = replaced - {s["id"] for s in solids}
    if missing:
        raise SystemExit(f"collision data has no {sorted(missing)}")
    walls = [s for s in solids if s["id"] not in replaced]

    ext = [
        '[ext_resource type="Script" path="res://scripts/florist.gd" id="1_florist"]',
        f'[ext_resource type="Texture2D" path="{PICTURE}" id="2_pic"]',
    ]
    for k, (_, image, _, _) in enumerate(FURNITURE):
        ext.append(f'[ext_resource type="Texture2D" path="{FURNITURE_DIR}{image}" id="f_{k}"]')
    subs = [
        '[sub_resource type="Gradient" id="shadow_gradient"]' + NL
        + "colors = PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0)" + NL
        + "offsets = PackedFloat32Array(0, 1)" + NL,
        '[sub_resource type="GradientTexture2D" id="shadow_tex"]' + NL
        + 'gradient = SubResource("shadow_gradient")' + NL
        + "fill = 1" + NL + "fill_from = Vector2(0.5, 0.5)" + NL + "fill_to = Vector2(1, 0.5)" + NL
        + "width = 128" + NL + "height = 128" + NL,
    ]
    nodes = [node("Florist", "Node2D", "", 'script = ExtResource("1_florist")' + NL)]
    nodes.append(node("Picture", "Sprite2D", ".",
                      'texture = ExtResource("2_pic")' + NL + "centered = false" + NL + "z_index = -10" + NL))

    sizes = []
    for k, (name, image, (x, y), _) in enumerate(FURNITURE):
        w, h = Image.open(FURNITURE_FILES + image).size
        sizes.append((w, h))
        # A soft shadow on the floor under the piece.
        nodes.append(node(f"Shadow_{name}", "Sprite2D", ".",
                          'texture = SubResource("shadow_tex")' + NL
                          + f"scale = Vector2({fmt(w * 0.0045)}, {fmt(h * 0.0040)})" + NL
                          + f"position = Vector2({fmt(x + w / 2)}, {fmt(y + h * 0.62)})" + NL
                          + "modulate = Color(0, 0, 0, 0.5)" + NL + "z_index = -1" + NL))
        # The visible piece, on the floor.
        nodes.append(node(f"Prop_{name}", "Sprite2D", ".",
                          f'texture = ExtResource("f_{k}")' + NL + "centered = false" + NL
                          + f"position = Vector2({x}, {y})" + NL + "z_index = 0" + NL))
    for k, (name, image, (x, y), _) in enumerate(FURNITURE):
        w, h = sizes[k]
        # The same piece, hidden until she stands behind it. scripts/florist.gd shows it over her then.
        nodes.append(node(f"Occluder_{name}", "Sprite2D", ".",
                          f'texture = ExtResource("f_{k}")' + NL + "centered = false" + NL
                          + f"position = Vector2({x}, {y})" + NL + "visible = false" + NL + "z_index = 6" + NL
                          + f"metadata/rect = Rect2({x}, {y}, {w}, {h})" + NL
                          + "metadata/origin = Vector2(0, 0)" + NL + "metadata/cutout = true" + NL))

    # Furniture collision: a convex polygon traced from the art, in picture pixels.
    polygon_count = 0
    for name, image, (x, y), _ in FURNITURE:
        outline = furniture_outline(image, (x, y))
        polygon_count += 1
        nodes.append(node(f"Item_{name}", "StaticBody2D", "."))
        nodes.append(node("Shape", "CollisionPolygon2D", f"Item_{name}",
                          f"polygon = PackedVector2Array({point_list(outline)})" + NL))

    # Walls: rectangles, as before.
    for solid in walls:
        x, y, w, h = solid["rect"]
        sid = solid["id"]
        subs.append(f'[sub_resource type="RectangleShape2D" id="wall_{sid}"]' + NL
                    + f"size = Vector2({w}, {h})" + NL)
        nodes.append(node(f"Wall_{sid}", "StaticBody2D", ".",
                          f"position = Vector2({fmt(x + w / 2)}, {fmt(y + h / 2)})" + NL))
        nodes.append(node("Shape", "CollisionShape2D", f"Wall_{sid}", f'shape = SubResource("wall_{sid}")' + NL))

    loads = 1 + len(ext) + len(subs)
    text = (f"[gd_scene load_steps={loads} format=3]" + NL + NL + NL.join(ext) + NL + NL
            + NL.join(subs) + NL + NL.join(nodes))
    open(OUT, "w", encoding="utf-8").write(text)
    print("wrote", OUT, len(nodes), "nodes:", polygon_count, "furniture polygons,", len(walls), "wall rectangles")


if __name__ == "__main__":
    main()
