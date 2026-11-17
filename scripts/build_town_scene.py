"""Writes scenes/TownSquare.tscn: the town picture, every street prop, every solid and the spawn and exit markers.

The scene is laid out like scenes/Bookstore.tscn, so it can be seen and edited in Godot's 2D tab:
- Picture: the town picture (z -10).
- Prop_<name>: each street prop, placed by its base line (position), marked as furniture so the script sorts it.
- Solid_<name>: each solid (a StaticBody2D with a rectangle shape). Shop fronts and road come from
  data/town_front_emporium_collision.json; props have a small solid under them (data/town_props.json).
- Spawn_* / Exit_* / Gate: markers for the spawns, the shop doors and the gate to the map.

Run from the project folder after editing the data: python scripts/build_town_scene.py
"""
import json
import zlib

from PIL import Image

PICTURE = "res://assets/environments/town/town_front_emporium.webp"
PROP_FOLDER = "res://assets/environments/town/props/"
PROPS_DATA = "data/town_props.json"
SHOP_DATA = "data/town_front_emporium_collision.json"
OUT = "scenes/TownSquare.tscn"
SCENE_UID = "uid://dod584e62kfhg"
SCRIPT = ("res://scripts/town_square.gd", "uid://dji14dl12rf7f")

SPAWNS = {
    "Spawn_from_map": (760, 640),
    "Spawn_from_bookstore": (333, 500),
    "Spawn_from_cafe": (652, 500),
    "Spawn_from_florist": (881, 505),
    "Spawn_default": (760, 640),
}
# The shop doors (the same rects the script's EXITS use) and the gate to the map.
EXITS = {
    "Exit_to_bookstore": ((333, 474), (300, 466, 66, 16)),
    "Exit_to_cafe": ((652, 474), (622, 466, 58, 16)),
    "Exit_to_florist": ((881, 478), (862, 470, 38, 16)),
}
GATE = ((750, 722), (680, 700, 140, 45))


def unique_id(name):
    return zlib.crc32(name.encode("utf8")) % 2147483647


def fmt(value):
    return ("%g" % value)


def main():
    props = json.load(open(PROPS_DATA, encoding="utf8"))["props"]
    shops = json.load(open(SHOP_DATA, encoding="utf8"))["solids"]

    ext = []  # (id, path)
    ext_ids = {}

    def texture(path):
        if path not in ext_ids:
            ext_ids[path] = "tex_%d" % len(ext_ids)
            ext.append((ext_ids[path], path))
        return ext_ids[path]

    shapes = []  # (id, size)
    nodes = []

    def shape(size):
        shape_id = "shape_%d" % len(shapes)
        shapes.append((shape_id, size))
        return shape_id

    def solid(name, rect):
        x, y, w, h = rect
        s = shape((w, h))
        nodes.append(
            f'[node name="{name}" type="StaticBody2D" parent="." unique_id={unique_id(name)}]\n'
            f"position = Vector2({fmt(x + w / 2.0)}, {fmt(y + h / 2.0)})\n\n"
            f'[node name="Shape" type="CollisionShape2D" parent="{name}" unique_id={unique_id(name + "/Shape")}]\n'
            f'shape = SubResource("{s}")\n\n')

    picture_tex = texture(PICTURE)
    nodes.append(
        f'[node name="Picture" type="Sprite2D" parent="." unique_id={unique_id("Picture")}]\n'
        f"z_index = -10\n"
        f'texture = ExtResource("{picture_tex}")\n'
        f"centered = false\n\n")

    for prop in props:
        name = prop["image"]
        path = PROP_FOLDER + name + ".png"
        width, height = Image.open(path.replace("res://", "")).size
        base_x, base_y = prop["base"]
        node = "Prop_" + name
        nodes.append(
            f'[node name="{node}" type="Sprite2D" parent="." unique_id={unique_id(node)}]\n'
            f"position = Vector2({fmt(base_x)}, {fmt(base_y)})\n"
            f'texture = ExtResource("{texture(path)}")\n'
            f"centered = false\n"
            f"offset = Vector2({fmt(-width / 2.0)}, {fmt(-height)})\n"
            f"metadata/furniture = true\n\n")
        if prop.get("solid"):
            solid("Solid_" + name + "_base", prop["solid"])

    for entry in shops:
        solid("Solid_" + entry["id"], entry["rect"])

    for name, (spawn_x, spawn_y) in SPAWNS.items():
        nodes.append(
            f'[node name="{name}" type="Marker2D" parent="." unique_id={unique_id(name)}]\n'
            f"position = Vector2({fmt(spawn_x)}, {fmt(spawn_y)})\n\n")
    for name, ((marker_x, marker_y), (x, y, w, h)) in EXITS.items():
        nodes.append(
            f'[node name="{name}" type="Marker2D" parent="." unique_id={unique_id(name)}]\n'
            f"position = Vector2({fmt(marker_x)}, {fmt(marker_y)})\n"
            f"metadata/exit_rect = Rect2({x}, {y}, {w}, {h})\n\n")
    (gate_x, gate_y), (x, y, w, h) = GATE
    nodes.append(
        f'[node name="Gate" type="Marker2D" parent="." unique_id={unique_id("Gate")}]\n'
        f"position = Vector2({fmt(gate_x)}, {fmt(gate_y)})\n"
        f"metadata/gate_rect = Rect2({x}, {y}, {w}, {h})\n\n")

    header = [f'[gd_scene format=3 uid="{SCENE_UID}"]', ""]
    header.append(f'[ext_resource type="Script" uid="{SCRIPT[1]}" path="{SCRIPT[0]}" id="1_script"]')
    for ext_id, path in ext:
        header.append(f'[ext_resource type="Texture2D" path="{path}" id="{ext_id}"]')
    header.append("")
    sub = "".join(
        f'[sub_resource type="RectangleShape2D" id="{shape_id}"]\nsize = Vector2({fmt(w)}, {fmt(h)})\n\n'
        for shape_id, (w, h) in shapes)
    root = (f'[node name="TownSquare" type="Node2D" unique_id={unique_id("TownSquare")}]\n'
            f'script = ExtResource("1_script")\n'
            f"metadata/static_scene = true\n\n")
    text = "\n".join(header) + "\n" + sub + root + "".join(nodes)
    with open(OUT, "w", encoding="utf8", newline="\n") as f:
        f.write(text.rstrip() + "\n")
    print("wrote", OUT, "props", len(props), "solids", len(shapes))


if __name__ == "__main__":
    main()
