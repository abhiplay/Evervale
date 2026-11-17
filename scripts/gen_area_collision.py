"""Trace the walkable paths in an area picture and write its collision data.

The paths are the warm brown dirt. Foliage, rocks, logs and cave walls are solid. The dirt is
closed (small gaps filled), kept only where it touches an exit, widened a little so the
character body fits, and the picture edges are solid except at the exits.
Usage: python scripts/gen_area_collision.py <area>   (see AREAS)
Coordinates are image pixels; the picture is used at scale 1 in the game.
"""
import json
import os
import sys
from collections import deque
import numpy as np
from PIL import Image

CELL = 4

# Each area: its picture, the collision file it writes, and the exit openings (x0, y0, x1, y1)
# on the picture edges. Only the path that touches an exit is kept.
AREAS = {
    "forest": {
        "picture": "assets/environments/forest.webp",
        "out": "data/forest_collision.json",
        "exits": [(700, 860, 830, 941), (0, 360, 40, 450)],
        # Hand-drawn walkable ground (paths and grass clearings), in image pixels.
        "walk_polygons": [
            # top path, from the top edge down to the crossroads
            [(820, 0), (905, 0), (890, 150), (865, 300), (885, 420), (790, 420), (805, 300), (825, 150)],
            # grass clearing above the middle, below the rock
            [(560, 300), (700, 296), (800, 300), (805, 420), (560, 430), (545, 380)],
            # the long road across the picture, from the left edge to the right edge
            [(0, 335), (120, 360), (200, 395), (300, 420), (560, 440), (800, 430), (960, 420),
             (1100, 410), (1300, 398), (1500, 400), (1672, 400), (1672, 470), (1500, 466),
             (1300, 460), (1200, 442), (1100, 432), (1040, 458), (960, 490), (800, 500),
             (600, 490), (400, 500), (260, 500), (180, 470), (140, 440), (60, 440), (0, 440)],
            # the bottom path, from the crossroads down to the gate
            [(790, 470), (890, 470), (900, 560), (880, 660), (862, 800), (850, 941), (700, 941),
             (735, 820), (735, 720), (765, 640), (770, 560)],
            # the lower-left branch of the road
            [(0, 560), (120, 520), (200, 500), (260, 500), (250, 540), (150, 590), (60, 630), (0, 640)],
            # grass clearings between the roads
            [(890, 300), (1000, 290), (1100, 330), (1140, 410), (1000, 425), (890, 425)],
            # the road curving down to the right of the crossroads
            [(950, 480), (1100, 440), (1200, 440), (1300, 455), (1340, 500), (1280, 505), (1180, 480), (1050, 500), (960, 520)],
            [(560, 500), (780, 500), (760, 560), (700, 600), (600, 560)],
            [(900, 500), (1060, 500), (1040, 600), (960, 640), (900, 600)],
            [(380, 380), (520, 360), (560, 430), (380, 430)],
        ],
        # Solid things drawn on the grass: rocks, the log and the bush clump.
        "solid_carves": [
            (1030, 290, 130, 75),   # log
            (620, 205, 135, 85),    # big rock, top middle
            (680, 335, 40, 30),     # small rock
            (725, 275, 35, 25),     # pebbles by the rock
            (650, 540, 85, 75),     # rock, middle left
            (960, 515, 60, 35),     # small rock, middle right
            (880, 230, 130, 60),    # bush clump, top right
        ],
    },
    "home_floor1": {
        "picture": "assets/environments/home_floor1.webp",
        "out": "data/home_floor1_collision.json",
        "exits": [(655, 935, 140, 60)],  # the front door, to the courtyard
        # Hand-drawn walkable floor: the hall, the dining room, the kitchen and the gaps between.
        "walk_polygons": [
            [(160, 440), (900, 440), (900, 930), (160, 930)],          # the hall (stops at the bottom wall)
            [(520, 150), (900, 150), (900, 395), (520, 395)],          # the dining room
            [(545, 395), (900, 395), (900, 440), (545, 440)],          # the way from the dining room into the hall
            [(905, 400), (1010, 400), (1010, 600), (905, 600)],        # below the stairs
            [(900, 596), (1120, 596), (1120, 668), (975, 668), (975, 650), (900, 650)],  # the gap to the kitchen
            [(975, 660), (1270, 660), (1270, 880), (975, 880)],        # the kitchen floor
            [(655, 930), (795, 930), (795, 1020), (655, 1020)],        # the front door
        ],
        # Furniture and fittings standing on the floor: sofa, tables, chairs, stools, fridge, plants.
        "solid_carves": [
            (222, 495, 378, 125),   # sofa back
            (222, 495, 110, 300),   # sofa arm
            (212, 755, 85, 130),    # side table and lamp
            (405, 805, 100, 100),   # pouf
            (420, 655, 150, 120),   # coffee table
            (655, 200, 135, 110),   # dining table
            (622, 220, 40, 85),     # dining chairs
            (790, 220, 35, 85),
            (700, 300, 55, 60),
            (700, 165, 50, 35),
            (845, 715, 50, 120),    # bar stools
            (1215, 660, 60, 80),    # fridge
            (975, 660, 35, 40),     # plant by the bar
        ],
    },
    "bedroom_upstairs": {
        "picture": "assets/environments/bedroom_upstairs.webp",
        "out": "data/bedroom_upstairs_collision.json",
        "exits": [(215, 930, 135, 110)],  # the stairs down, the opening at the bottom left
        "walk_polygons": [
            [(200, 300), (1150, 300), (1150, 930), (200, 930)],  # the bedroom floor
            [(215, 925), (355, 925), (355, 1050), (215, 1050)],  # the stairs opening
        ],
        # Furniture standing on the floor: bed, nightstands, wardrobe, dresser, stool, plant, bench.
        "solid_carves": [
            (560, 290, 320, 460),   # bed and headboard
            (465, 330, 105, 110),   # left nightstand
            (870, 330, 105, 110),   # right nightstand
            (1150, 355, 115, 560),  # wardrobe
            (190, 200, 100, 470),   # dresser and mirror
            (290, 515, 65, 95),     # stool
            (1120, 180, 135, 155),  # plant
            (520, 880, 405, 55),    # bench at the foot of the bed
        ],
    },
    "bedroom_upstairs_empty": {
        "picture": "assets/environments/bedroom_upstairs_empty.webp",
        "out": "data/bedroom_upstairs_empty_collision.json",
        "exits": [(215, 930, 135, 110)],  # the stairs down, the opening at the bottom left
        "walk_polygons": [
            [(186, 306), (1262, 306), (1262, 930), (186, 930)],  # the empty bedroom floor, inside the walls
            [(215, 925), (355, 925), (355, 1050), (215, 1050)],  # the stairs opening
        ],
        # No furniture: the room is empty while Amelia looks around the house.
    },
    "town_front": {
        "picture": "assets/environments/town_front.webp",
        "out": "data/town_front_collision.json",
        "exits": [(680, 700, 140, 45)],  # the way back to the map, at the kerb
        # The sidewalk in front of the shops; the road and the buildings are solid.
        "walk_polygons": [
            [(75, 470), (1600, 470), (1600, 690), (1560, 725), (1450, 740), (160, 740), (90, 700)],
        ],
        # Street furniture on the sidewalk: cart, benches, planters, tables, tree, post box, bollards.
        "solid_carves": [
            (265, 445, 110, 160),   # cart
            (545, 630, 115, 70),    # bench
            (1225, 630, 115, 70),   # bench
            (360, 630, 105, 85),    # flower planter
            (1000, 668, 82, 54),    # tree planter only: the tree above it is walkable behind (drawn over her)
            (1122, 612, 40, 90),    # post box
            (492, 628, 25, 88),     # bollards
            (855, 625, 22, 90),
            (1178, 625, 22, 90),
            (648, 445, 45, 70),     # sign board
            (720, 430, 130, 70),    # café table and chairs
            (960, 430, 100, 70),    # café table and chairs
            (1355, 430, 115, 70),   # bicycle
            (224, 528, 30, 28),     # street lamp base, left
            (1473, 528, 31, 28),    # street lamp base, right
        ],
    },
    "bookstore_interior": {
        "picture": "assets/environments/bookstore_interior.webp",
        "out": "data/bookstore_interior_collision.json",
        "exits": [(740, 800, 195, 70)],  # the shop door, back out to the town
        # The floor inside the shop, and the way out through the front.
        "walk_polygons": [
            [(195, 110), (1475, 110), (1475, 700), (940, 700), (940, 870), (735, 870), (735, 700), (195, 700)],
        ],
        # Shelves, tables, chairs, the counter and the armchair.
        "solid_carves": [
            (240, 165, 130, 140),   # armchair and side table
            (420, 110, 100, 130),   # small shelf (ends above the gap behind the shelf run)
            (575, 110, 365, 140),   # tall shelves along the back wall
            (990, 160, 190, 100),   # shelves on the right
            (1095, 110, 85, 140),   # shelf by the counter
            (1205, 190, 245, 125),  # counter
            (485, 275, 105, 385),   # shelf run, left (starts below a gap the player can walk through)
            (1045, 250, 110, 410),  # shelf run, right
            (735, 292, 170, 158),   # display table, top (its collision now reaches the books and flowers on top)
            (735, 475, 170, 140),   # display table, bottom
            (260, 450, 190, 160),   # reading table and chairs, left
            (1210, 455, 200, 165),  # reading table and chairs, right
            (1462, 250, 20, 450),   # wall shelves, right
        ],
    },
    "cafe_interior": {
        "picture": "assets/environments/cafe_interior.webp",
        "out": "data/cafe_interior_collision.json",
        "shape": "polygon",  # outline each solid as a polygon instead of merged rectangles
        "furniture_file": "data/cafe_furniture_collision.json",  # each item becomes its own solid
        "exits": [(735, 800, 200, 80)],  # the café door, back out to the town
        # The café floor, and the way out through the front.
        "walk_polygons": [
            [(160, 90), (1500, 90), (1500, 686), (945, 686), (945, 905), (725, 905), (725, 686), (160, 686)],  # the floor stops above the wall lip
        ],
        # Booths, tables, the sofa, the counter and the cake cabinet.
        "solid_carves": [
            (150, 385, 205, 310),   # booths, left
            (1310, 385, 190, 310),  # booths, right
            (290, 170, 190, 120),   # sofa
            (245, 250, 95, 120),    # armchair
            (355, 260, 80, 80),     # small round table
            (570, 200, 380, 118),   # window tables and chairs
            (1010, 110, 490, 255),  # counter and back bar
            (1190, 230, 280, 95),   # cake cabinet
            (585, 365, 150, 125),   # central table, top left (leaves a gap to walk between the rows)
            (862, 365, 124, 125),   # central table, top right (narrowed to leave a gap by the counter)
            (585, 530, 150, 130),   # central table, bottom left
            (862, 530, 124, 130),   # central table, bottom right (narrowed)
            (130, 320, 70, 100),    # plant, left
            (1470, 320, 70, 100),   # plant, right
        ],
    },
    "florist_interior": {
        "picture": "assets/environments/florist_interior.webp",
        "out": "data/florist_interior_collision.json",
        "exits": [(740, 800, 195, 70)],  # the shop door, back out to the town
        "walk_polygons": [
            [(225, 290), (1450, 290), (1450, 700), (945, 700), (945, 905), (725, 905), (725, 700), (225, 700)],
        ],
        "solid_carves": [
            (249, 414, 240, 219),   # worktable and stool
            (688, 298, 300, 200),   # upper display shelf
            (693, 500, 290, 144),   # lower display shelf
            (1213, 440, 184, 230),  # fridge cabinet
            (1412, 478, 80, 121),   # chalkboard sign
            (1155, 488, 62, 192),   # flower buckets
            (1157, 290, 290, 80),   # counter
            (222, 170, 120, 140),   # armchair, if the walkable floor reaches it
        ],
    },
    "cave_interior": {
        "picture": "assets/environments/cave_interior.webp",
        "out": "data/cave_interior_collision.json",
        "exits": [(300, 820, 70, 45)],
        "floor_test": "lit_dirt",  # the floor is warm brown; walls are grey rock
        # Solid things standing on the floor: the round door, the crates, the mine cart.
        "solid_carves": [(470, 60, 110, 80), (395, 300, 75, 85), (215, 605, 75, 70)],
    },
    "cave_entrance": {
        "picture": "assets/environments/cave_entrance.webp",
        "out": "data/cave_entrance_collision.json",
        "exits": [(1640, 400, 1671, 452)],
    },
}


def box_sum(mask, k):
    """Count of set pixels in a k x k window around each pixel (k odd)."""
    pad = k // 2
    p = np.pad(mask.astype(np.int32), pad, mode="constant")
    c = np.cumsum(np.cumsum(p, axis=0), axis=1)
    c = np.pad(c, ((1, 0), (1, 0)), mode="constant")
    h, w = mask.shape
    return c[k:k + h, k:k + w] - c[0:h, k:k + w] - c[k:k + h, 0:w] + c[0:h, 0:w]


def dilate(mask, k):
    return box_sum(mask, k) > 0


def erode(mask, k):
    return box_sum(mask, k) == k * k


def close(mask, k):
    return erode(dilate(mask, k), k)


def opened(mask, k):
    return dilate(erode(mask, k), k)


def label(mask):
    """4-connected components, as a label grid (0 = empty)."""
    labels = np.zeros(mask.shape, np.int32)
    h, w = mask.shape
    count = 0
    for sy in range(h):
        for sx in range(w):
            if mask[sy, sx] and labels[sy, sx] == 0:
                count += 1
                labels[sy, sx] = count
                queue = deque([(sy, sx)])
                while queue:
                    y, x = queue.popleft()
                    for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and labels[ny, nx] == 0:
                            labels[ny, nx] = count
                            queue.append((ny, nx))
    return labels, count


def merge_rects(grid):
    h, w = grid.shape
    used = np.zeros_like(grid, bool)
    rects = []
    for y in range(h):
        x = 0
        while x < w:
            if grid[y, x] and not used[y, x]:
                x1 = x
                while x1 < w and grid[y, x1] and not used[y, x1]:
                    x1 += 1
                y1 = y + 1
                while y1 < h and all(grid[y1, x:x1]) and not any(used[y1, x:x1]):
                    y1 += 1
                used[y:y1, x:x1] = True
                rects.append((x, y, x1 - x, y1 - y))
                x = x1
            else:
                x += 1
    return rects


def trace_polygons(area):
    """Walkable ground drawn by hand: the polygons are filled, everything else is solid."""
    from PIL import ImageDraw
    im = np.asarray(Image.open(area["picture"]).convert("RGB")).astype(int)
    h, w = im.shape[:2]
    mask_img = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask_img)
    for poly in area["walk_polygons"]:
        draw.polygon(poly, fill=1)
    walk_full = np.asarray(mask_img).astype(bool)
    ch_n, cw_n = h // CELL, w // CELL
    walk = walk_full[:ch_n * CELL, :cw_n * CELL].reshape(ch_n, CELL, cw_n, CELL).mean(axis=(1, 3)) > 0.5
    walk = walk.copy()
    walk[:, 0] = walk[:, 0]  # edges handled below
    edge = np.zeros_like(walk)
    edge[:1, :] = True
    edge[-1:, :] = True
    edge[:, :1] = True
    edge[:, -1:] = True
    open_cells = np.zeros_like(walk)
    for x0, y0, x1, y1 in area["exits"]:
        open_cells[y0 // CELL:y1 // CELL + 1, x0 // CELL:x1 // CELL + 1] = True
    walk[edge & ~open_cells] = False
    for x0, y0, cw, ch in area.get("solid_carves", []):
        walk[y0 // CELL:(y0 + ch) // CELL, x0 // CELL:(x0 + cw) // CELL] = False
    return im, walk


SIMPLIFY_PX = 3.0  # outline tolerance in picture pixels, well under the character's body width


def polygon_solids(solid):
    """Each solid blob as simplified loops in picture pixels: loops[0] is the outline, the rest are holes.

    A hole is walkable ground fully enclosed by solid (the café room sits inside its wall ring).
    CollisionPolygon2D cannot have holes, so blobs with holes are written as loops and built as
    segments by the scene generator.
    """
    import cv2
    pixels = np.kron(solid.astype(np.uint8), np.ones((CELL, CELL), np.uint8)) * 255
    contours, hierarchy = cv2.findContours(pixels, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)
    hierarchy = hierarchy[0]

    def simplified(contour):
        approx = cv2.approxPolyDP(contour, SIMPLIFY_PX, True).reshape(-1, 2)
        return [[int(x), int(y)] for x, y in approx] if len(approx) >= 3 else None

    blobs = []
    for i, contour in enumerate(contours):
        # Holes are added to their outline below; contours smaller than one grid cell are specks.
        if hierarchy[i][3] != -1 or cv2.contourArea(contour) < CELL * CELL:
            continue
        loops = [simplified(contour)]
        for j, hole in enumerate(contours):
            if hierarchy[j][3] == i and cv2.contourArea(hole) >= CELL * CELL:
                loop = simplified(hole)
                if loop:
                    loops.append(loop)
        if loops[0]:
            blobs.append(loops)
    return blobs


def load_furniture(path):
    """Hand-placed furniture outlines: [{"id": ..., "polygon": [[x, y], ...]}, ...]. None means none."""
    if not path:
        return []
    with open(path, encoding="utf-8") as f:
        return json.load(f)["items"]


def rasterize_items(items, shape):
    """Pixel mask of the furniture outlines, for a wall grid of the given shape (in cells)."""
    import cv2
    ch_n, cw_n = shape
    pixels = np.zeros((ch_n * CELL, cw_n * CELL), np.uint8)
    for item in items:
        cv2.fillPoly(pixels, [np.array(item["polygon"], np.int32)], 1)
    return pixels.astype(bool)


def to_cells(pixels):
    ch_n, cw_n = pixels.shape[0] // CELL, pixels.shape[1] // CELL
    return pixels.reshape(ch_n, CELL, cw_n, CELL).mean(axis=(1, 3)) > 0.5


def mostly_furniture(loop, item_px):
    """True when a hole in the walls is (almost) all furniture, so the furniture's outline covers it."""
    import cv2
    mask = np.zeros(item_px.shape, np.uint8)
    cv2.fillPoly(mask, [np.array(loop, np.int32)], 1)
    mask = mask.astype(bool)
    return mask.sum() > 0 and (mask & item_px).sum() >= 0.9 * mask.sum()


def write_collision(area, im, walk):
    h, w = im.shape[:2]
    ch_n, cw_n = walk.shape
    # Smooth the solid edges so the body never wedges in a sliver: gaps narrower than the body
    # (about 20 pixels) are filled, and thin spikes poking into the walkable ground are removed.
    solid = close(~walk, 5)
    solid = opened(solid, 3)
    walk = ~solid
    if area.get("shape") == "polygon":
        items = load_furniture(area.get("furniture_file"))
        item_px = rasterize_items(items, solid.shape)
        # Each furniture item is its own solid, so the walls are carved around it.
        solid = solid & ~to_cells(item_px)
        walk = ~solid
        blobs = polygon_solids(solid)
        # A hole in the walls that the furniture fills is covered by the furniture's own outline.
        blobs = [[loops[0]] + [h for h in loops[1:] if not mostly_furniture(h, item_px)] for loops in blobs]
        solids = [{"id": f"solid_{i}", "loops": loops} for i, loops in enumerate(blobs)]
        solids += [{"id": item["id"], "kind": "furniture", "loops": [item["polygon"]]} for item in items]
        unit = f"solid blobs (outline plus holes) and {len(items)} furniture outlines"
    else:
        rects = merge_rects(solid)
        solids = [{"id": f"solid_{i}", "rect": [x * CELL, y * CELL, cwid * CELL, chei * CELL]}
                  for i, (x, y, cwid, chei) in enumerate(rects)]
        unit = "solid rectangles"
    with open(area["out"], "w", encoding="utf-8") as f:
        json.dump({
            "_note": f"Solid areas of {area['picture']}, in image pixels. Generated by scripts/gen_area_collision.py. The dirt paths and grass clearings are walkable.",
            "solids": solids,
        }, f)
    print(f"{len(solids)} {unit} written to {area['out']}")
    overlay = im.astype(np.uint8).copy()
    walk_px = np.zeros((h, w), bool)
    walk_px[:ch_n * CELL, :cw_n * CELL] = np.kron(walk, np.ones((CELL, CELL), bool))
    overlay[walk_px] = (overlay[walk_px] * 0.4 + np.array([0, 255, 0]) * 0.6).astype(np.uint8)
    # The debug overlay is only written when its folder exists on this machine.
    overlay_dir = "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/c15251a5-cfec-40ff-8355-cabff13e9abd/scratchpad/"
    if os.path.isdir(overlay_dir):
        Image.fromarray(overlay).save(overlay_dir + area["out"].split("/")[-1] + ".png")


def trace(area):
    if "walk_polygons" in area:
        im, walk = trace_polygons(area)
        write_collision(area, im, walk)
        return
    im = np.asarray(Image.open(area["picture"]).convert("RGB")).astype(int)
    h, w = im.shape[:2]
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    mx, mn = im.max(-1), im.min(-1)
    sat = mx - mn
    if area.get("floor_test") == "lit_dirt":
        path = (r > g) & (g > b) & (r - b > 30) & (r - b < 90) & (mx > 90) & (mx < 230) & (sat > 35)
    else:
        path = (r > g) & (g > b) & (mx > 70) & (mx < 200) & (sat > 10) & (sat < 70) & (r - b > 12)

    # Work on the coarse grid: the paths are wide, and it keeps the search quick.
    ch_n, cw_n = h // CELL, w // CELL
    cells = path[:ch_n * CELL, :cw_n * CELL].reshape(ch_n, CELL, cw_n, CELL).mean(axis=(1, 3)) > 0.3
    cells = close(cells, 5)
    cells = opened(cells, 2 if not area.get("floor_test") else 4)
    labels, _ = label(cells)
    if area.get("floor_test"):
        # Keep every floor patch of a reasonable size, so no part of the room is cut off.
        sizes = np.bincount(labels.ravel())
        keep = {i for i in range(1, len(sizes)) if sizes[i] >= 40}
    else:
        keep = set()
        for x0, y0, x1, y1 in area["exits"]:
            keep |= set(np.unique(labels[y0 // CELL:y1 // CELL + 1, x0 // CELL:x1 // CELL + 1])) - {0}
    walk = np.isin(labels, list(keep))
    walk = dilate(walk, 3)  # widen by about 12 pixels so the character body fits
    for x0, y0, cw, ch in area.get("solid_carves", []):
        walk[y0 // CELL:(y0 + ch) // CELL, x0 // CELL:(x0 + cw) // CELL] = False

    # The picture edges are solid, except the exit openings.
    edge = np.zeros_like(walk)
    edge[:2, :] = True
    edge[-2:, :] = True
    edge[:, :2] = True
    edge[:, -2:] = True
    open_cells = np.zeros_like(walk)
    for x0, y0, x1, y1 in area["exits"]:
        open_cells[y0 // CELL:y1 // CELL + 1, x0 // CELL:x1 // CELL + 1] = True
    walk[edge & ~open_cells] = False

    write_collision(area, im, walk)



if __name__ == "__main__":  # usage: python scripts/gen_area_collision.py <area>
    trace(AREAS[sys.argv[1]])
