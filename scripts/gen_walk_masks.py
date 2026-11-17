"""Makes the first walk masks of the house from its current collision.

A walk mask is a PNG the size of the room's picture: opaque pixels are solid (walls, furniture bases), transparent
pixels are floor Amelia can walk on. The game builds the room's collision from it (scripts/walk_mask.gd), so the
mask can be refined by painting over the room's picture in any paint program; no code or rectangles to edit.

This script only seeds the masks: it draws the solids the house uses today (the scenes' bodies and the JSON
collision files), with the furniture footprints listed in REFINE drawn to the piece's real floor shape where a
rectangle was a poor fit (the round pouf, the L-shaped sofa). After that, the PNGs are the source of truth;
run it again only to start over.

Run: python scripts/gen_walk_masks.py   (from the project folder)
"""
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "walkmasks"
SIZE = (1448, 1086)
SOLID = (0, 0, 0, 255)


def scene_rects(scene_file):
    """The rectangle of every StaticBody2D in a .tscn, from its position and its shape's size."""
    text = (ROOT / "scenes" / scene_file).read_text(encoding="utf-8")
    sizes = dict(re.findall(r'\[sub_resource type="RectangleShape2D" id="([^"]+)"\]\s*size = Vector2\(([^)]+)\)', text))
    rects = []
    for name, x, y in re.findall(r'\[node name="(Body_\d+)" type="StaticBody2D"[^\]]*\]\s*position = Vector2\(([^,]+), ([^)]+)\)', text):
        shape = re.search(r'parent="%s"[^\]]*\]\s*(?:position = Vector2\(([^,]+), ([^)]+)\)\s*)?shape = SubResource\("([^"]+)"\)' % name, text)
        ox, oy = float(shape.group(1) or 0), float(shape.group(2) or 0)
        w, h = (float(v) for v in sizes[shape.group(3)].split(","))
        cx, cy = float(x) + ox, float(y) + oy
        rects.append((cx - w / 2, cy - h / 2, w, h))
    return rects


def json_rects(name):
    data = json.loads((ROOT / "data" / name).read_text(encoding="utf-8"))
    return [tuple(s["rect"]) for s in data["solids"]]


def draw(rects, refine=()):
    image = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    pen = ImageDraw.Draw(image)
    for x, y, w, h in rects:
        pen.rectangle([x, y, x + w - 1, y + h - 1], fill=SOLID)
    for kind, box in refine:
        if kind == "clear":
            pen.rectangle(box, fill=(0, 0, 0, 0))
        elif kind == "ellipse":
            pen.ellipse(box, fill=SOLID)
        elif kind == "rounded":
            pen.rounded_rectangle(box, radius=18, fill=SOLID)
    return image


# The settled ground floor's new furniture: the round pouf is an ellipse, not a box; the sofa is one rounded L; the
# dining set is the table and its four chairs, not the rug around them.
SETTLED_REFINE = [
    ("clear", [404, 806, 501, 899]),
    ("ellipse", [410, 812, 496, 896]),
    ("clear", [220, 492, 601, 789]),
    ("rounded", [222, 494, 600, 612]),
    ("rounded", [222, 560, 330, 786]),
    ("clear", [622, 180, 821, 359]),
    ("rounded", [640, 196, 806, 344]),
]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    ground = scene_rects("HomeFloor1.tscn")
    settled_new = [r for r in json_rects("home_floor1_settled_collision.json")]
    masks = {
        "home_floor1_bare.png": draw(ground),
        "home_floor1_settled.png": draw(ground + settled_new, SETTLED_REFINE),
        "bedroom_upstairs_furnished.png": draw(scene_rects("BedroomUpstairs.tscn")),
        "bedroom_upstairs_empty.png": draw(json_rects("bedroom_upstairs_empty_collision.json")),
    }
    for name, image in masks.items():
        image.save(OUT / name)
        print("wrote", OUT / name)


if __name__ == "__main__":
    main()
