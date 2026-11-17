"""Writes the courtyard-style scenes as real nodes, so their art and collision show in the Godot editor.

Input: the JSON layouts from tests/export_scene_layout.gd, which records what each scene builds at runtime
(picture, furniture, shadows, occluders, collision shapes, spawn points, doors and exits). Output: one
scenes/<Name>.tscn per scene. Each root keeps its script and its own root settings (such as MAP_DATA), and
gets metadata/static_scene = true, so scripts/exterior_home.gd links the nodes instead of building them again.

Before overwriting a scene, its old file is copied to the backup folder. Scenes listed in SKIP are not
written (the editor has them open; close them in the editor and remove them from SKIP to write them).
Usage: python scripts/build_visual_scenes.py [SceneName ...]
"""
import json
import re
import shutil
import sys
from pathlib import Path

LAYOUTS = Path(r"C:\Users\USER37\AppData\Local\Temp\claude\580beaddd45035b4\706b6a2c-a895-48fd-8729-9870ac3d8642\scratchpad\layouts")
BACKUPS = Path(r"C:\Users\USER37\AppData\Local\Temp\claude\580beaddd45035b4\706b6a2c-a895-48fd-8729-9870ac3d8642\scratchpad\scenes_before")
SCENES = Path("scenes")
SKIP = {"Forest", "TownSquare"}   # open in the Godot editor
NL = "\n"


def fmt(n):
    return f"{float(n):g}"


def vec(v):
    return f"Vector2({fmt(v[0])}, {fmt(v[1])})"


def rect(r):
    return f"Rect2({fmt(r[0])}, {fmt(r[1])}, {fmt(r[2])}, {fmt(r[3])})"


def color(c):
    return f"Color({fmt(c[0])}, {fmt(c[1])}, {fmt(c[2])}, {fmt(c[3])})"


def points(pts):
    return "PackedVector2Array(" + ", ".join(f"{fmt(x)}, {fmt(y)}" for x, y in pts) + ")"


def read_root_settings(old_text, root_name):
    """Root properties that the scene already sets (for example MAP_DATA), except the script."""
    settings = []
    inside = False
    for line in old_text.splitlines():
        if line.startswith("[node "):
            inside = line.startswith(f'[node name="{root_name}"')
            continue
        if inside and line.strip() and not line.startswith("[") and not line.startswith("script = "):
            settings.append(line)
        if inside and line.startswith("["):
            inside = False
    return settings


def read_script_line(old_text):
    m = re.search(r'\[ext_resource type="Script"[^\]]*path="(res://[^"]+)"[^\]]*\]', old_text)
    return m.group(1) if m else None


# Parts that stay in the script, because they change at runtime.
DROP = {
    # Covers hide part of a picture until a story flag is set.
    "TempleInterior": lambda item: item["type"] == "Sprite2D" and item.get("z_index") == -9,
    # The fog scrolls every frame.
    "WorldMap": lambda item: item["type"] == "Sprite2D" and item.get("texture") == "res://assets/map/fog.png",
}


# Scenes whose cut-out furniture art is traced into polygon collision. Each rule says which cut-outs count
# as furniture (by texture path). Walls and other solids stay rectangles.
FURNITURE = {
    "HomeFloor1": lambda texture: True,
    "Bookstore": lambda texture: True,
    "TownSquare": lambda texture: "tree" not in texture,
}
# Scenes whose solids are polygons (the file's "loops", in picture pixels) instead of rectangles.
POLYGON_SOLIDS = {
    "Forest": "data/forest_collision_polygons.json",
    "WorldMap": "data/world_map_collision_blocks.json",
}
ALPHA_MIN = 128          # a pixel is part of a piece at least this opaque (as the café tables)
HULL_TOLERANCE_PX = 1.5  # simplification of each outline (as the café tables)
MIN_PART_AREA = 20       # smaller specks are ignored; separate parts are kept


def art_outline(texture, origin):
    """Convex outline of a cut-out's art, in picture pixels (the same method as the café tables)."""
    import cv2
    import numpy as np
    from PIL import Image
    rgba = np.asarray(Image.open(texture.replace("res://", "", 1)).convert("RGBA"))
    mask = (rgba[..., 3] >= ALPHA_MIN).astype(np.uint8) * 255
    kernel = np.ones((3, 3), np.uint8)
    mask = cv2.morphologyEx(cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel), cv2.MORPH_CLOSE, kernel)
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    parts = [c for c in contours if cv2.contourArea(c) >= MIN_PART_AREA]
    hull = cv2.convexHull(np.vstack(parts))
    approx = cv2.approxPolyDP(hull, HULL_TOLERANCE_PX, True).reshape(-1, 2)
    ox, oy = origin
    return [[int(x) + ox, int(y) + oy] for x, y in approx]


def furniture_polygons(nodes, keep):
    """Replace the solid under each furniture cut-out with a convex polygon traced from the cut-out's art."""
    claimed = set()
    cutouts = [n for n in nodes if n["type"] == "Sprite2D" and n.get("meta", {}).get("cutout")
               and "texture" in n and keep(n["texture"])]
    for cut in cutouts:
        cx, cy, cw, ch = cut["meta"]["rect"]
        best, best_score = None, 0.0
        for body in nodes:
            if body["type"] != "StaticBody2D" or id(body) in claimed:
                continue
            if not body["shapes"] or body["shapes"][0]["type"] != "rect":
                continue
            shape = body["shapes"][0]
            sw, sh = shape["size"]
            sx, sy = shape.get("position", [0, 0])
            bx, by = body["position"]
            left, top = bx + sx - sw / 2, by + sy - sh / 2
            ix = max(0.0, min(left + sw, cx + cw) - max(left, cx))
            iy = max(0.0, min(top + sh, cy + ch) - max(top, cy))
            score = ix * iy / (sw * sh) if sw * sh else 0.0
            if score > best_score:
                best, best_score = body, score
        if best is not None and best_score >= 0.5:
            claimed.add(id(best))
            best["polygon"] = art_outline(cut["texture"], (cx, cy))
            best["shapes"] = []
            best["position"] = [0, 0]
    return nodes


def build(name):
    layout = json.loads((LAYOUTS / f"{name}.json").read_text(encoding="utf-8"))
    drop = DROP.get(name, lambda item: False)
    layout["nodes"] = [item for item in layout["nodes"] if not drop(item)]
    if name in FURNITURE:
        layout["nodes"] = furniture_polygons(layout["nodes"], FURNITURE[name])
    if name in POLYGON_SOLIDS:
        # The scene's solids come from the solids file instead of the ones the game built: a rectangle
        # ("rect": x, y, w, h) becomes a rectangle shape, and an outline ("loops") becomes polygons.
        solids = json.loads(Path(POLYGON_SOLIDS[name]).read_text(encoding="utf-8"))["solids"]
        bodies = []
        for s in solids:
            if "rect" in s:
                x, y, bw, bh = s["rect"]
                bodies.append({"type": "StaticBody2D", "name": s["id"], "position": [x + bw / 2, y + bh / 2],
                               "shapes": [{"type": "rect", "size": [bw, bh], "position": [0, 0]}]})
            else:
                bodies.append({"type": "StaticBody2D", "name": s["id"], "position": [0, 0], "shapes": [],
                               "loops": s["loops"]})
        layout["nodes"] = [item for item in layout["nodes"] if item["type"] != "StaticBody2D"] + bodies
    v = layout["vars"]
    target = SCENES / f"{name}.tscn"
    old_text = target.read_text(encoding="utf-8") if target.exists() else ""
    script = read_script_line(old_text) or f"res://scripts/{name.lower()}.gd"
    settings = read_root_settings(old_text, name)

    ext = {}          # texture path -> ext id
    subs = []         # sub resource blocks
    gradients = {}    # json key -> sub id
    shape_ids = 0
    nodes = []
    used = set()

    def ext_id(path):
        if path not in ext:
            ext[path] = f"t_{len(ext)}"
        return ext[path]

    def gradient_id(g):
        key = json.dumps(g, sort_keys=True)
        if key not in gradients:
            n = len(gradients)
            colors = ", ".join(fmt(x) for c in g["colors"] for x in c)
            subs.append(f'[sub_resource type="Gradient" id="grad_{n}"]' + NL
                        + f"colors = PackedColorArray({colors})" + NL
                        + "offsets = PackedFloat32Array(" + ", ".join(fmt(o) for o in g["offsets"]) + ")" + NL)
            subs.append(f'[sub_resource type="GradientTexture2D" id="gtex_{n}"]' + NL
                        + f'gradient = SubResource("grad_{n}")' + NL
                        + f"fill = {int(g['fill'])}" + NL
                        + f"fill_from = {vec(g['fill_from'])}" + NL + f"fill_to = {vec(g['fill_to'])}" + NL
                        + f"width = {int(g['width'])}" + NL + f"height = {int(g['height'])}" + NL)
            gradients[key] = f"gtex_{n}"
        return gradients[key]

    def unique(name_hint):
        base = re.sub(r"[^A-Za-z0-9_]", "_", name_hint) or "Node"
        candidate, n = base, 2
        while candidate in used:
            candidate, n = f"{base}_{n}", n + 1
        used.add(candidate)
        return candidate

    def node_block(name, kind, parent, props):
        head = f'[node name="{name}" type="{kind}"' + (f' parent="{parent}"]' if parent is not None else "]")
        return head + NL + "".join(line + NL for line in props)

    # Art and occluders, as the scene builds them at runtime.
    for i, item in enumerate(layout["nodes"]):
        if item["type"] == "Sprite2D":
            node_name = unique(item["name"] if not item["name"].startswith("@") and item["name"] else f"Sprite_{i}")
            props = []
            if "gradient" in item:
                props.append(f'texture = SubResource("{gradient_id(item["gradient"])}")')
            elif "texture" in item:
                props.append(f'texture = ExtResource("{ext_id(item["texture"])}")')
            if not item["centered"]:
                props.append("centered = false")
            if item["position"] != [0, 0]:
                props.append(f"position = {vec(item['position'])}")
            if item["scale"] != [1, 1]:
                props.append(f"scale = {vec(item['scale'])}")
            if item["z_index"] != 0:
                props.append(f"z_index = {item['z_index']}")
            if item["modulate"] != [1, 1, 1, 1]:
                props.append(f"modulate = {color(item['modulate'])}")
            meta = item.get("meta", {})
            if meta:
                # A cut-out is drawn whole. A piece of the picture is drawn from its rectangle.
                if not meta["cutout"]:
                    props.append("region_enabled = true")
                    props.append(f"region_rect = {rect([meta['origin'][0], meta['origin'][1], meta['rect'][2], meta['rect'][3]])}")
                props.append(f"metadata/rect = {rect(meta['rect'])}")
                props.append(f"metadata/origin = {vec(meta['origin'])}")
                props.append(f"metadata/cutout = {'true' if meta['cutout'] else 'false'}")
            elif item["region_enabled"]:
                props.append("region_enabled = true")
                props.append(f"region_rect = {rect(item['region_rect'])}")
            if not item["visible"]:
                props.append("visible = false")
            nodes.append(node_block(node_name, "Sprite2D", ".", props))
        elif item["type"] == "StaticBody2D":
            body = unique(item["name"] if not item["name"].startswith("@") and item["name"] else f"Body_{i}")
            body_props = []
            if item["position"] != [0, 0]:
                body_props.append(f"position = {vec(item['position'])}")
            nodes.append(node_block(body, "StaticBody2D", ".", body_props))
            if "loops" in item:
                # Solids outlined as polygons: one loop is a collision polygon; loops with holes are
                # concave shapes, given as the segments of every loop (CollisionPolygon2D has no holes).
                if len(item["loops"]) == 1:
                    nodes.append(node_block(unique("Shape"), "CollisionPolygon2D", body,
                                            [f"polygon = {points(item['loops'][0])}"]))
                else:
                    sid = f"shape_{shape_ids}"
                    shape_ids += 1
                    segments = []
                    for loop in item["loops"]:
                        for p_index, p in enumerate(loop):
                            segments += [p, loop[(p_index + 1) % len(loop)]]
                    subs.append(f'[sub_resource type="ConcavePolygonShape2D" id="{sid}"]' + NL
                                + f"segments = {points(segments)}" + NL)
                    nodes.append(node_block(unique("Shape"), "CollisionShape2D", body,
                                            [f'shape = SubResource("{sid}")']))
                continue
            if "polygon" in item:
                # Furniture: one convex polygon, in picture pixels, under a body at the origin.
                nodes.append(node_block(unique("Shape"), "CollisionPolygon2D", body,
                                        [f"polygon = {points(item['polygon'])}"]))
                continue
            for k, shape in enumerate(item["shapes"]):
                sid = f"shape_{shape_ids}"
                shape_ids += 1
                if shape["type"] == "rect":
                    subs.append(f'[sub_resource type="RectangleShape2D" id="{sid}"]' + NL + f"size = {vec(shape['size'])}" + NL)
                elif shape["type"] == "circle":
                    subs.append(f'[sub_resource type="CircleShape2D" id="{sid}"]' + NL + f"radius = {fmt(shape['radius'])}" + NL)
                elif shape["type"] == "convex":
                    subs.append(f'[sub_resource type="ConvexPolygonShape2D" id="{sid}"]' + NL + f"points = {points(shape['points'])}" + NL)
                elif shape["type"] == "segments":
                    subs.append(f'[sub_resource type="ConcavePolygonShape2D" id="{sid}"]' + NL + f"segments = {points(shape['points'])}" + NL)
                else:
                    continue
                shape_props = [f'shape = SubResource("{sid}")']
                if shape.get("position") and shape["position"] != [0, 0]:
                    shape_props.insert(0, f"position = {vec(shape['position'])}")
                cname = unique("Shape" if k == 0 else f"Shape_{k}")
                nodes.append(node_block(cname, "CollisionShape2D", body, shape_props))

    # Markers, so spawn points, the door, the gate and the exits show in the editor.
    markers = []
    for key, pos in (v.get("SPAWNS") or {}).items():
        markers.append((f"Spawn_{key}", [f"position = {vec(pos)}"]))
    if "SPAWN_DEFAULT" in v:
        markers.append(("Spawn_default", [f"position = {vec(v['SPAWN_DEFAULT'])}"]))
    if v.get("HAS_DOOR") and "ENTER_POSITION" in v:
        markers.append(("Door_enter", [f"position = {vec(v['ENTER_POSITION'])}",
                                       f'metadata/label = "{v.get("ENTER_LABEL", "")}"',
                                       f'metadata/scene = "{v.get("ENTER_HOME_SCENE", "")}"',
                                       f'metadata/spawn = "{v.get("ENTER_HOME_SPAWN", "")}"']))
    gate = v.get("GATE_RECT")
    if gate and gate[2] > 0 and gate[3] > 0:
        markers.append(("Gate", [f"position = {vec([gate[0] + gate[2] / 2, gate[1] + gate[3] / 2])}",
                                 f"metadata/area = {rect(gate)}"]))
    for i, ex in enumerate(v.get("EXITS") or []):
        r = ex["rect"]
        markers.append((f"Exit_{i}", [f"position = {vec([r[0] + r[2] / 2, r[1] + r[3] / 2])}",
                                      f"metadata/area = {rect(r)}",
                                      f'metadata/scene = "{ex.get("scene", "")}"',
                                      f'metadata/spawn = "{ex.get("spawn", "")}"']))
    if name == "WorldMap":
        # Each place's zone on the map (from data/locations.json): walking into it goes to the place.
        for location in json.loads(Path("data/locations.json").read_text(encoding="utf-8"))["locations"]:
            if location.get("zone") is None:
                continue  # places without a zone are not on the map yet
            zx, zy, zw, zh = location["zone"]
            markers.append((f"Zone_{location['id']}", [
                f"position = {vec([zx + zw / 2, zy + zh / 2])}",
                f"metadata/area = {rect(location['zone'])}",
                f'metadata/name = "{location["name"]}"',
                f'metadata/scene = "{location.get("scene", "")}"',
            ]))
    for mname, props in markers:
        nodes.append(node_block(unique(mname), "Marker2D", ".", props))

    ext_lines = [f'[ext_resource type="Script" path="{script}" id="1_script"]']
    ext_lines += [f'[ext_resource type="Texture2D" path="{p}" id="{i}"]' for p, i in ext.items()]
    loads = 1 + len(ext_lines) + len(subs)
    root = [f'[node name="{name}" type="Node2D"]', 'script = ExtResource("1_script")'] + settings
    root.append("metadata/static_scene = true")
    text = (f"[gd_scene load_steps={loads} format=3]" + NL + NL + NL.join(ext_lines) + NL + NL
            + NL.join(subs) + NL + NL + NL.join(root) + NL + NL + NL.join(nodes))
    return target, text, old_text


def main(names):
    BACKUPS.mkdir(parents=True, exist_ok=True)
    for name in names:
        if name in SKIP:
            print(f"skipped {name} (open in the editor)")
            continue
        target, text, old_text = build(name)
        backup = BACKUPS / f"{name}.tscn"
        if target.exists() and not backup.exists():
            shutil.copy2(target, backup)
        target.write_text(text, encoding="utf-8")
        print(f"wrote {target}: {text.count('[node ')} nodes")


if __name__ == "__main__":
    main(sys.argv[1:] or [p.stem for p in sorted(LAYOUTS.glob("*.json"))])
