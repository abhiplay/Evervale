"""Build the protagonist's walk sheets from the artist's 16-frame strips.

Each strip is one row of 16 walking frames on a transparent (or white) background. The
frames are cut out, their feet are lined up on one line, and each direction is written as
a single horizontal sheet, as data/character_animations.json expects.
Source strips face right for three of the directions, so those are flipped to face left.
Usage: python scripts/build_walk_sheets.py
"""
import json
import numpy as np
from PIL import Image

SRC = "C:/Users/USER37/AppData/Local/Temp/claude/580beaddd45035b4/c15251a5-cfec-40ff-8355-cabff13e9abd/images/"
OUT_DIR = "assets/characters/walk/"
FRAMES = 16
FPS = 12
# name: (source strip, flip horizontally so the figure faces the direction the game expects)
SHEETS = {
    "walk-front": ("31.webp", False),       # facing the viewer
    "walk-back": ("32.webp", False),        # facing away
    "walk-left": ("33.webp", True),         # profile, facing right in the strip
    "walk-front-left": ("35.webp", True),   # three-quarter front, facing right in the strip
    "walk-back-left": ("34.webp", True),    # three-quarter back, facing right in the strip
}
# Scale the strips up so the figure height matches the existing protagonist sheets (about 745 px).
TARGET_FRONT_HEIGHT = 745


def remove_edge_background(alpha, rgb):
    """Make the light background that touches the picture's edge transparent."""
    from PIL import ImageDraw
    light = (rgb.min(-1) > 205) & ((rgb.max(-1) - rgb.min(-1)) < 30) & (alpha > 0)
    mask = Image.fromarray((light * 255).astype(np.uint8), "L")
    draw = ImageDraw.Draw(mask)
    h, w = light.shape
    border = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] +              [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    for xy in border:
        if mask.getpixel(xy) == 255:
            draw.floodfill(xy, 128, thresh=0)
    background = np.asarray(mask) == 128
    out = alpha.copy()
    out[background] = 0
    return out


def keep_main_body(fg_cell):
    """Within one frame cell, keep the widest run of columns, so stray pieces of a neighbour go."""
    cols = fg_cell.sum(0) > 4
    best, start = (0, 0), None
    for x, on in enumerate(list(cols) + [False]):
        if on and start is None:
            start = x
        if not on and start is not None:
            if x - start > best[1] - best[0]:
                best = (start, x)
            start = None
    keep = np.zeros(fg_cell.shape[1], bool)
    keep[best[0]:best[1]] = True
    return fg_cell & keep[None, :]


def cut_frames(path):
    """Return the figure images of one strip, left to right, with their feet line."""
    im = Image.open(path).convert("RGBA")
    arr = np.asarray(im).astype(int)
    alpha = arr[..., 3].copy()
    rgb = arr[..., :3]
    # Remove the light background that touches the picture edge (white, or a faint grey),
    # but keep light areas inside the figures, such as white shoes.
    alpha[(alpha < 250) & (rgb.min(-1) > 200)] = 0
    alpha = remove_edge_background(alpha, rgb)
    arr[..., 3] = alpha
    im = Image.fromarray(arr.astype(np.uint8), "RGBA")  # crops below use the cleaned alpha
    # The strips are laid out on an even grid, one cell per frame. Side views have legs that
    # touch, so the cells are cut evenly rather than by gaps between figures.
    fg = alpha > 100
    cell = alpha.shape[1] / FRAMES
    frames = []
    for i in range(FRAMES):
        x0, x1 = int(round(i * cell)), int(round((i + 1) * cell))
        sub = keep_main_body(fg[:, x0:x1])
        rows = np.where(sub.any(1))[0]
        cols_on = np.where(sub.any(0))[0]
        if rows.size == 0:
            raise SystemExit(f"{path}: frame {i} is empty")
        top, bottom = int(rows.min()), int(rows.max()) + 1
        left, right = x0 + int(cols_on.min()), x0 + int(cols_on.max()) + 1
        crop = im.crop((left, top, right, bottom))
        frames.append({"image": crop, "top": top, "bottom": bottom})
    return frames


def figure_height(source):
    """Median height of the figures in one strip, in source pixels (feet to top of hair)."""
    frames = cut_frames(SRC + source)
    return float(np.median([f["bottom"] - f["top"] for f in frames]))


def build(name, source, flip):
    frames = cut_frames(SRC + source)
    feet = int(np.median([f["bottom"] for f in frames]))
    above = max(feet - f["top"] for f in frames)
    below = max(f["bottom"] - feet for f in frames)
    width = max(f["image"].width for f in frames) + 8
    height = above + below + 6
    sheet = Image.new("RGBA", (width * FRAMES, height), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img = f["image"]
        if flip:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        x = i * width + (width - img.width) // 2
        y = above - (feet - f["top"]) + 3
        sheet.paste(img, (x, y), img)
    feet_line = above + 3
    sheet_height_in_px = sheet.height
    return sheet, width, sheet_height_in_px, feet_line


def main():
    built = {}
    for name, (source, flip) in SHEETS.items():
        built[name] = build(name, source, flip)
    # Every view is scaled so the character is the same height on screen. The artist drew the
    # side view smaller and the back view larger, so each sheet is scaled by its own figure height.
    front_figure = figure_height(SHEETS["walk-front"][0])
    base = TARGET_FRONT_HEIGHT / built["walk-front"][2]
    animations = []
    for name, (sheet, width, height, feet_line) in built.items():
        scale = base * front_figure / figure_height(SHEETS[name][0])
        new_w = round(sheet.width * scale)
        new_h = round(height * scale)
        resized = sheet.resize((new_w, new_h), Image.LANCZOS)
        out = OUT_DIR + f"protagonist-{name}.png"
        resized.save(out)
        frame_w = round(width * scale)
        animations.append({
            "name": name,
            "file": f"res://{out}",
            "frames": FRAMES,
            "frame_width": frame_w,
            "frame_height": new_h,
            "anchor_y": round(feet_line * scale),
        })
        print(name, out, resized.size, "frame", frame_w, "x", new_h, "feet", round(feet_line * scale))
    data = {
        "_note": "Walk sheets for the protagonist, built by scripts/build_walk_sheets.py from the artist's 16-frame strips. Each sheet is a row of frames. anchor_y is the feet line in a frame, measured from the top.",
        "fps": FPS,
        "animations": animations,
    }
    with open("data/character_animations.json", "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    print("wrote data/character_animations.json")


if __name__ == "__main__":
    main()
