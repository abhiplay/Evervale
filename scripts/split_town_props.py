"""Cuts the street props out of the town props sheet (assets/environments/town/town_sheet_props.webp).

Each prop is one connected group of opaque pixels on the sheet's transparent background. Each is saved at its own
scale into assets/environments/town/props/, named after what it is. The placements live in data/town_props.json.
Run from the project folder: python scripts/split_town_props.py
"""
from collections import deque
import sys

import numpy as np
from PIL import Image

SHEET = "assets/environments/town/town_sheet_props.webp"
OUT = "assets/environments/town/props/"

# Sheet item bounding box (left, top, right, bottom) found by labelling the opaque pixels, and its display scale.
PROPS = {
    "tree_planter_1": ((21, 346, 260, 641), 0.8),
    "tree_planter_2": ((266, 378, 441, 628), 0.8),
    "food_cart": ((446, 413, 593, 601), 0.9),
    "cafe_table_set": ((630, 459, 784, 566), 0.9),
    "sandwich_board": ((810, 458, 900, 576), 1.0),
    "bench_1": ((926, 481, 1053, 566), 1.0),
    "flowerbox": ((1076, 469, 1213, 570), 1.0),
    "bench_2": ((1236, 482, 1362, 566), 1.0),
    "bicycle": ((1381, 473, 1511, 554), 1.0),
    "post_box": ((1523, 455, 1576, 575), 1.0),
    "town_lamp_post": ((1597, 403, 1706, 646), 0.85),
    "lamp_post": ((1735, 364, 1791, 654), 0.85),
    "bollard": ((1830, 496, 1868, 619), 1.0),
}


def label_opaque(alpha):
    """Labels 4-connected groups of opaque pixels; returns a label array (0 = empty)."""
    opaque = alpha > 40
    height, width = opaque.shape
    labels = np.zeros((height, width), dtype=np.int32)
    count = 0
    for y, x in zip(*np.nonzero(opaque)):
        if labels[y, x]:
            continue
        count += 1
        labels[y, x] = count
        queue = deque([(y, x)])
        while queue:
            cy, cx = queue.popleft()
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < height and 0 <= nx < width and opaque[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = count
                    queue.append((ny, nx))
    return labels


def main():
    sheet = np.array(Image.open(SHEET).convert("RGBA"))
    labels = label_opaque(sheet[:, :, 3])
    for name, (box, scale) in PROPS.items():
        left, top, right, bottom = box
        region = labels[top:bottom, left:right]
        # The label that covers most of the box is this prop's own group.
        ids, counts = np.unique(region[region > 0], return_counts=True)
        if ids.size == 0:
            sys.exit("no pixels for " + name)
        own = ids[np.argmax(counts)]
        piece = sheet[top:bottom, left:right].copy()
        piece[:, :, 3] = np.where(region == own, piece[:, :, 3], 0)
        image = Image.fromarray(piece, "RGBA")
        cropped = image.crop(image.getbbox())
        if scale != 1.0:
            cropped = cropped.resize((round(cropped.width * scale), round(cropped.height * scale)), Image.LANCZOS)
        cropped.save(OUT + name + ".png")
        print(name, cropped.size)


if __name__ == "__main__":
    main()
