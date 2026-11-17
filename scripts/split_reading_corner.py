"""Splits environments/bookstore/reading_corner_vintage.png into a floor rug and depth-sorted pieces.

The rug is walkable floor, so it is drawn under the character. The armchair with the reader, the lamp,
the side table and the plant each get their own base line, so the character walks behind them only
when her feet are higher on the picture than their base. The polygons are rough outlines in the
picture's own pixels. Run from the project folder: python scripts/split_reading_corner.py
"""
from PIL import Image, ImageDraw

SOURCE = "assets/environments/bookstore/reading_corner_vintage.png"
OUT = "assets/environments/bookstore/"

# Outlines in picture pixels, a little generous so no object edge is left on the rug layer.
PIECES = {
    "reading_corner_chair": {
        "base": 800,
        "polygon": [(360, 470), (372, 415), (410, 378), (480, 366), (520, 318), (560, 305), (610, 305),
                    (650, 330), (680, 355), (705, 380), (712, 420), (705, 460), (710, 500), (745, 560),
                    (835, 600), (840, 650), (825, 710), (790, 740), (880, 760), (885, 835), (840, 840),
                    (800, 845), (790, 880), (795, 920), (745, 928), (690, 925), (640, 910), (560, 910),
                    (535, 905), (510, 905), (520, 870), (455, 870), (445, 845), (420, 800), (415, 760),
                    (395, 730), (370, 690), (360, 600)],
    },
    "reading_corner_lamp": {
        "base": 690,
        "polygon": [(735, 280), (830, 272), (912, 300), (912, 420), (860, 440), (825, 470), (830, 520),
                    (845, 540), (845, 705), (790, 705), (790, 600), (800, 545), (795, 520), (815, 470),
                    (785, 430), (740, 410)],
    },
    "reading_corner_table": {
        "base": 800,
        "polygon": [(830, 585), (850, 530), (880, 505), (930, 498), (990, 510), (1025, 585), (1015, 640), (1015, 770),
                    (1000, 775), (935, 805), (925, 800), (862, 772), (855, 700), (840, 640)],
    },
    "reading_corner_plant": {
        "base": 770,
        "polygon": [(240, 600), (250, 540), (265, 505), (300, 495), (345, 500), (340, 560), (395, 550), (395, 620), (385, 690),
                    (386, 765), (340, 772), (290, 772), (283, 740), (278, 680), (255, 640)],
    },
}


def polygon_mask(size, polygon):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(polygon, fill=255)
    return mask


def main():
    picture = Image.open(SOURCE).convert("RGBA")
    width, height = picture.size
    combined = Image.new("L", (width, height), 0)
    for name, piece in PIECES.items():
        mask = polygon_mask((width, height), piece["polygon"])
        combined = Image.composite(Image.new("L", (width, height), 255), combined, mask)
        cut = picture.copy()
        cut.putalpha(Image.composite(picture.split()[3], Image.new("L", (width, height), 0), mask))
        box = cut.getbbox()
        cut = cut.crop(box)
        cut.save(OUT + name + ".png")
        # Offset (box left - 640, box top - base) places the piece where it was, with its base line at the base.
        print(name, "crop box", box, "offset", (box[0] - 640, box[1] - piece["base"]), "base", piece["base"])

    rug = picture.copy()
    rug.putalpha(Image.composite(Image.new("L", (width, height), 0), picture.split()[3], combined))
    rug.save(OUT + "reading_corner_rug.png")
    print("rug written")


if __name__ == "__main__":
    main()
