"""Writes scenes/Cafe.tscn with the café's static content as real nodes, so it shows in the 2D tab.

The picture, walls, lamps, lighting and furniture covers are nodes here; cafe.gd links to them.
Run this after changing the café's walls (data/cafe_interior_collision.json), the furniture outlines
(data/cafe_furniture_collision.json), the table art (assets/environments/furniture/cafe_group_*.png)
or its lamps.

Collision is polygons. Walls come from the collision data: a blob with one loop becomes a
CollisionPolygon2D, and a blob with holes (the wall ring around the café room) becomes
ConcavePolygonShape2D segments, because CollisionPolygon2D cannot have holes. Each piece of
furniture is its own CollisionPolygon2D. Each table group gets the convex outline of its art.
Needs OpenCV (cv2) and Pillow.
"""
import json

COLLISION = "data/cafe_interior_collision.json"
OUT = "scenes/Cafe.tscn"
PICTURE = "res://assets/environments/cafe_interior.webp"
# Furniture covers drawn from the picture (a region of the picture): (x, y, w, h).
PICTURE_FURNITURE = [(150, 385, 205, 310), (1310, 385, 190, 310), (290, 170, 190, 120),
                     (570, 200, 380, 118), (1010, 110, 490, 255), (1190, 230, 280, 95)]
# Table groups: the art rectangle in the picture (top-left corner, size) and its sprite index.
CUTOUTS = [((586, 368, 149, 137), 0), ((851, 368, 149, 137), 1),
           ((586, 519, 149, 141), 2), ((851, 519, 149, 141), 3)]
NL = "\n"

# The square wall blobs at the four tables are replaced by the table outlines below.
TABLE_SQUARES = [(584, 364, 148, 124), (860, 364, 124, 124), (584, 528, 148, 132), (860, 528, 124, 132)]
# The traced table outlines sit within a few pixels of the carved squares.
TABLE_TOLERANCE = 6
ALPHA_MIN = 128          # a table pixel is one at least this opaque
HULL_TOLERANCE_PX = 1.5  # simplification of each table's convex outline


def node(name, kind, parent, props=""):
    head = f'[node name="{name}" type="{kind}" parent="{parent}"]' if parent else f'[node name="{name}" type="{kind}"]'
    return head + NL + props


def bbox(points):
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return (min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys))


def is_table_square(solid):
    """True for the square blobs at the tables, which the table outlines replace."""
    if len(solid["loops"]) != 1:
        return False
    box = bbox(solid["loops"][0])
    return any(all(abs(a - b) <= TABLE_TOLERANCE for a, b in zip(box, square)) for square in TABLE_SQUARES)


def table_outline(group_index, origin):
    """Convex outline of one table group's art, in café picture pixels (origin = art's top-left)."""
    import cv2
    import numpy as np
    from PIL import Image
    rgba = np.asarray(Image.open(f"assets/environments/furniture/cafe_group_{group_index}.png").convert("RGBA"))
    mask = (rgba[..., 3] >= ALPHA_MIN).astype(np.uint8) * 255
    kernel = np.ones((3, 3), np.uint8)
    mask = cv2.morphologyEx(cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel), cv2.MORPH_CLOSE, kernel)
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    hull = cv2.convexHull(max(contours, key=cv2.contourArea))
    approx = cv2.approxPolyDP(hull, HULL_TOLERANCE_PX, True).reshape(-1, 2)
    ox, oy = origin
    return [[int(x) + ox, int(y) + oy] for x, y in approx]


def clip_to_square(points, square):
    """The outline clipped to its carved square, so chairs don't close the gaps between table rows."""
    import cv2
    import numpy as np
    x0, y0, w, h = square
    canvas = np.zeros((h + 2, w + 2), np.uint8)
    shifted = np.array([[x - x0 + 1, y - y0 + 1] for x, y in points], np.int32)
    cv2.fillPoly(canvas, [shifted], 1)  # fillPoly clips to the canvas
    contours, _ = cv2.findContours(canvas, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    hull = cv2.convexHull(max(contours, key=cv2.contourArea))
    approx = cv2.approxPolyDP(hull, HULL_TOLERANCE_PX, True).reshape(-1, 2)
    return [[int(x) + x0 - 1, int(y) + y0 - 1] for x, y in approx]


def nearest_square(origin):
    ox, oy = origin
    return min(TABLE_SQUARES, key=lambda s: (s[0] - ox) ** 2 + (s[1] - oy) ** 2)


def segment_points(loops):
    """Every loop as closed segments, flattened to the end points ConcavePolygonShape2D takes."""
    points = []
    for loop in loops:
        for i, p in enumerate(loop):
            points += [p, loop[(i + 1) % len(loop)]]
    return points


def point_list(points):
    return ", ".join(f"{x}, {y}" for x, y in points)


def main():
    solids = json.load(open(COLLISION))["solids"]
    furniture = [s for s in solids if s.get("kind") == "furniture"]
    blobs = [s for s in solids if s.get("kind") != "furniture"]
    walls = [s for s in blobs if not is_table_square(s)]
    if len(blobs) - len(walls) != len(TABLE_SQUARES):
        raise SystemExit(f"expected {len(TABLE_SQUARES)} table squares in {COLLISION}, "
                         f"found {len(blobs) - len(walls)}")
    ext = [
        '[ext_resource type="Script" path="res://scripts/cafe.gd" id="1_cafe"]',
        f'[ext_resource type="Texture2D" path="{PICTURE}" id="2_pic"]',
    ]
    for _, i in CUTOUTS:
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/environments/furniture/cafe_group_{i}.png" id="cut_{i}"]')
    subs = []
    nodes = [node("Cafe", "Node2D", "", 'script = ExtResource("1_cafe")' + NL)]
    nodes.append(node("Picture", "Sprite2D", ".",
                      'texture = ExtResource("2_pic")' + NL
                      + 'centered = false' + NL + 'z_index = -10' + NL))
    for k, ((x, y, _, _), i) in enumerate(CUTOUTS):
        outline = clip_to_square(table_outline(i, (x, y)), nearest_square((x, y)))
        nodes.append(node(f"TableCollider_{k}", "StaticBody2D", "."))
        nodes.append(node("Shape", "CollisionPolygon2D", f"TableCollider_{k}",
                          f"polygon = PackedVector2Array({point_list(outline)})" + NL))
    polygons = segments = 0
    for k, solid in enumerate(walls):
        loops = solid["loops"]
        nodes.append(node(f"Wall_{k}", "StaticBody2D", "."))
        if len(loops) == 1:
            polygons += 1
            nodes.append(node("Shape", "CollisionPolygon2D", f"Wall_{k}",
                              f"polygon = PackedVector2Array({point_list(loops[0])})" + NL))
        else:
            segments += 1
            subs.append(f'[sub_resource type="ConcavePolygonShape2D" id="wall_{k}"]' + NL
                        + f"segments = PackedVector2Array({point_list(segment_points(loops))})" + NL)
            nodes.append(node("Shape", "CollisionShape2D", f"Wall_{k}", f'shape = SubResource("wall_{k}")' + NL))
    for item in furniture:
        name = f"Item_{item['id']}"
        nodes.append(node(name, "StaticBody2D", "."))
        nodes.append(node("Shape", "CollisionPolygon2D", name,
                          f"polygon = PackedVector2Array({point_list(item['loops'][0])})" + NL))
    for k, (x, y, wd, ht) in enumerate(PICTURE_FURNITURE):
        nodes.append(node(f"Furniture_{k}", "Sprite2D", ".",
                          'texture = ExtResource("2_pic")' + NL + 'region_enabled = true' + NL
                          + f'region_rect = Rect2({x}, {y}, {wd}, {ht})' + NL + f'position = Vector2({x}, {y})' + NL
                          + f'metadata/rect = Rect2({x}, {y}, {wd}, {ht})' + NL
                          + f'metadata/origin = Vector2({x}, {y})' + NL + 'metadata/cutout = false' + NL))
    for (x, y, wd, ht), i in CUTOUTS:
        nodes.append(node(f"Table_{i}", "Sprite2D", ".",
                          f'texture = ExtResource("cut_{i}")' + NL + f'position = Vector2({x}, {y})' + NL
                          + f'metadata/rect = Rect2({x}, {y}, {wd}, {ht})' + NL
                          + 'metadata/origin = Vector2(0, 0)' + NL + 'metadata/cutout = true' + NL))
    loads = 1 + len(ext) + len(subs)
    text = (f'[gd_scene load_steps={loads} format=3]' + NL + NL + NL.join(ext) + NL + NL
            + NL.join(subs) + NL + NL.join(nodes))
    open(OUT, "w", encoding="utf-8").write(text)
    print("wrote", OUT, len(nodes), "nodes:", len(CUTOUTS), "table outlines,", len(furniture),
          "furniture outlines,", polygons, "polygon walls,", segments, "segment walls (with holes)")


if __name__ == "__main__":
    main()
