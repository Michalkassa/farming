#!/usr/bin/env python3
"""Generates the orchard art: fruit item icons, every growth stage of the
orchard's trees, bushes and vines, and the cute decor for the orchard screen
(smiling sun, clouds, hills, shed, beehive, bees, butterflies, flowers, fence,
entrance arch and the hub signpost).

Trees reuse the Clover Valley pack's own tree stages so the orchard matches the
farm, with fruit drawn over the full-grown canopy. Everything else is drawn in
that pack's palette. Writes into static/items (fruit icons) and static/orchard."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PACK = ROOT / "Clover Valley V2 Free/Enviroment"
OUT = ROOT / "static/orchard"
ITEMS = ROOT / "static/items"

# Clover Valley palette.
NAVY = (25, 30, 60)            # leaf outline
INK = (0, 0, 5)
LEAF_D, LEAF_M, LEAF_L, LEAF_H = (15, 115, 115), (15, 165, 105), (65, 205, 115), (190, 215, 45)
WOOD_D, WOOD_2, WOOD_M, WOOD_L, WOOD_H = (55, 10, 20), (90, 20, 35), (140, 60, 50), (178, 98, 71), (220, 155, 120)
ITEM_OUTLINE = (43, 29, 20)    # matches the existing item icons
WHITE = (255, 255, 255)


class Px:
    def __init__(self, w=16, h=16):
        self.w, self.h, self.g = w, h, {}

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[(x, y)] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def disc(self, cx, cy, r, c):
        for y in range(self.h):
            for x in range(self.w):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.5:
                    self.put(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(self.h):
            for x in range(self.w):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0 + 0.5 / max(rx, ry):
                    self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            self.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)

    def outline(self, c=ITEM_OUTLINE):
        edge = set()
        for (x, y) in self.g:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in self.g and 0 <= n[0] < self.w and 0 <= n[1] < self.h:
                    edge.add(n)
        for p in edge:
            self.g[p] = c
        return self

    def paste(self, im, ox=0, oy=0):
        for y in range(im.height):
            for x in range(im.width):
                p = im.getpixel((x, y))
                if p[3] > 0:
                    self.put(ox + x, oy + y, p[:3])
        return self

    def image(self):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.g.items():
            im.putpixel((x, y), c + (255,))
        return im

    def save(self, path, scale=1):
        path.parent.mkdir(parents=True, exist_ok=True)
        im = self.image()
        if scale > 1:
            im = im.resize((self.w * scale, self.h * scale), Image.NEAREST)
        im.save(path)


def pack(sheet, box):
    return Image.open(PACK / sheet).convert("RGBA").crop(box)


# ------------------------------------------------------------------ fruit
# dark, base, light, plus which shape to draw on plants and as an icon.
FRUIT = {
    "grape":        ((70, 30, 110), (130, 60, 170), (195, 140, 225), "cluster"),
    "apple":        ((150, 20, 30), (215, 45, 45), (255, 135, 125), "round"),
    "pear":         ((120, 150, 30), (190, 215, 45), (238, 242, 150), "pear"),
    "lemon":        ((200, 160, 20), (255, 230, 90), (255, 250, 195), "oval"),
    "blueberry":    ((20, 50, 120), (45, 95, 195), (145, 185, 245), "berry"),
    "elderberry":   ((30, 20, 50), (75, 45, 105), (145, 105, 175), "berry"),
    "plum":         ((70, 20, 80), (135, 45, 135), (205, 125, 205), "round"),
    "fig":          ((80, 40, 80), (145, 85, 125), (205, 155, 175), "pear"),
    "pomegranate":  ((120, 10, 30), (195, 30, 50), (250, 115, 115), "round"),
    "raspberry":    ((160, 20, 70), (228, 62, 112), (255, 155, 185), "berry"),
    "blackberry":   ((20, 15, 40), (62, 42, 92), (135, 115, 175), "berry"),
    "cherry":       ((110, 0, 20), (205, 22, 42), (255, 125, 135), "cherry"),
    "peach":        ((220, 110, 60), (255, 172, 112), (255, 222, 182), "round"),
    "orange":       ((200, 90, 10), (242, 142, 32), (255, 202, 122), "round"),
    "mango":        ((220, 120, 20), (255, 192, 52), (255, 236, 142), "oval"),
    "passionfruit": ((60, 20, 70), (112, 52, 122), (182, 122, 192), "round"),
    "pineapple":    ((190, 120, 20), (242, 192, 42), (255, 236, 132), "pineapple"),
    "dragonfruit":  ((190, 30, 110), (242, 82, 162), (255, 172, 212), "dragon"),
    "golden_apple": ((190, 130, 10), (252, 202, 42), (255, 250, 182), "round"),
}

LEAF_ICON = (79, 180, 63)
LEAF_ICON_D = (47, 122, 46)
STEM = (105, 68, 35)


def icon(name):
    d, b, l, shape = FRUIT[name]
    p = Px()
    if name == "grape":
        for cx, cy in ((5, 6), (8, 6), (11, 6), (6, 9), (9, 9), (7, 12), (10, 9), (8, 12)):
            p.disc(cx, cy, 1.6, b)
            p.put(cx - 1, cy - 1, l)
        p.line(8, 4, 8, 2, STEM)
        p.rect(9, 2, 11, 3, LEAF_ICON)
    elif name in ("blueberry", "elderberry"):
        spots = ((6, 8), (10, 8), (8, 11)) if name == "blueberry" else ((5, 8), (8, 7), (11, 8), (6, 11), (10, 11), (8, 13))
        r = 2.4 if name == "blueberry" else 1.5
        p.line(8, 2, 8, 6, STEM)
        p.line(8, 4, 5, 7, STEM)
        p.line(8, 4, 11, 7, STEM)
        for cx, cy in spots:
            p.disc(cx, cy, r, b)
            p.put(cx - 1, cy - 1, l)
            if name == "blueberry":
                p.put(cx, cy, d)
    elif name in ("raspberry", "blackberry"):
        p.ellipse(8, 9, 4.5, 5, b)
        for y in range(5, 15):
            for x in range(3, 14):
                if (x, y) in p.g and (x + y) % 2 == 0:
                    p.put(x, y, l if y < 9 else b)
                elif (x, y) in p.g and (x * 3 + y) % 5 == 0:
                    p.put(x, y, d)
        p.rect(6, 3, 10, 4, LEAF_ICON)
        p.put(8, 2, LEAF_ICON_D)
    elif name == "cherry":
        p.line(8, 2, 5, 9, STEM)
        p.line(8, 2, 11, 10, STEM)
        p.rect(8, 2, 11, 3, LEAF_ICON)
        for cx, cy in ((5, 11), (11, 12)):
            p.disc(cx, cy, 2.6, b)
            p.put(cx - 1, cy - 1, l)
            p.put(cx - 1, cy - 2, WHITE)
    elif shape == "pear":
        p.disc(8, 11, 4, b)
        p.disc(8, 6, 2.6, b)
        p.rect(6, 10, 7, 11, l)
        p.put(6, 6, l)
        if name == "fig":
            p.put(8, 15, d)
            p.line(10, 7, 11, 12, d)
        p.line(8, 3, 9, 1, STEM)
        if name == "pear":
            p.rect(10, 2, 12, 3, LEAF_ICON)
    elif shape == "oval":
        if name == "lemon":
            p.ellipse(8, 9, 5.5, 4, b)
            p.put(2, 9, b)
            p.put(14, 9, b)
            p.rect(5, 7, 7, 7, l)
        else:  # mango, tilted with a blush
            p.ellipse(8, 9, 4.5, 5.5, b)
            p.disc(10, 11, 2, (240, 110, 60))
            p.rect(6, 6, 6, 8, l)
            p.line(8, 3, 9, 2, STEM)
            p.rect(9, 1, 12, 2, LEAF_ICON)
    elif shape == "pineapple":
        p.ellipse(8, 11, 4, 4.5, b)
        for y in range(7, 16):
            for x in range(3, 14):
                if (x, y) in p.g and (x + y) % 3 == 0:
                    p.put(x, y, d)
                elif (x, y) in p.g and (x - y) % 3 == 0:
                    p.put(x, y, l)
        for x0, x1 in ((8, 8), (6, 5), (10, 11), (7, 6), (9, 10)):
            p.line(8, 6, x1, 1 if x1 == 8 else 3, LEAF_ICON)
        p.put(8, 2, LEAF_ICON_D)
    elif shape == "dragon":
        p.ellipse(8, 9, 4.5, 5, b)
        for sx, sy in ((4, 7), (12, 7), (5, 12), (11, 12), (8, 4)):
            p.put(sx, sy, LEAF_ICON)
            p.put(sx + (1 if sx < 8 else -1 if sx > 8 else 0), sy - 1, LEAF_ICON)
        p.rect(6, 7, 7, 8, l)
        p.put(9, 10, d)
        p.put(7, 12, d)
    else:  # round: apple, plum, peach, orange, pomegranate, passionfruit, golden apple
        p.disc(8, 9, 5, b)
        p.rect(5, 6, 6, 7, l)
        p.put(5, 5, WHITE) if name in ("apple", "golden_apple", "plum") else None
        if name == "peach":
            p.line(10, 5, 10, 13, d)
        if name == "pomegranate":
            p.rect(7, 3, 9, 4, d)
            p.put(6, 3, d)
            p.put(10, 3, d)
        elif name == "passionfruit":
            for sx, sy in ((7, 10), (10, 8), (9, 12), (11, 11)):
                p.put(sx, sy, l)
        else:
            p.line(8, 4, 9, 2, STEM)
            p.rect(9, 2, 12, 3, LEAF_ICON)
        if name == "orange":
            p.put(8, 12, d)
    p.outline()
    if name == "golden_apple":
        for sx, sy in ((1, 2), (14, 5), (13, 14)):
            p.put(sx, sy, WHITE)
    return p


def fruit_dot(p, x, y, name):
    """A fruit hanging on a plant, centred at x, y (plant pixel space)."""
    d, b, l, shape = FRUIT[name]
    if shape == "cluster":                     # grapes
        for dx, dy in ((0, 0), (2, 0), (1, 2), (-1, 2), (3, 2), (0, 4), (2, 4), (1, 6)):
            p.put(x + dx, y + dy, b)
            p.put(x + dx + 1, y + dy, d)
            p.put(x + dx, y + dy + 1, d)
        p.put(x, y, l)
        p.put(x + 1, y - 1, (105, 68, 35))
    elif shape == "berry":
        for dx, dy in ((0, 0), (2, 1), (0, 2)):
            p.put(x + dx, y + dy, b)
            p.put(x + dx + 1, y + dy, d)
        p.put(x, y, l)
    elif shape == "cherry":
        p.put(x, y - 1, (105, 68, 35))
        for dx in (-1, 1):
            p.put(x + dx, y, b)
            p.put(x + dx, y + 1, d)
        p.put(x - 1, y, l)
    elif shape == "pineapple":
        p.rect(x - 2, y, x + 2, y + 6, b)
        for yy in range(y, y + 7):
            for xx in range(x - 2, x + 3):
                if (xx + yy) % 3 == 0:
                    p.put(xx, yy, d)
        p.rect(x - 2, y, x - 2, y + 6, d)
        p.rect(x + 2, y, x + 2, y + 6, d)
        for dx in (-2, -1, 0, 1, 2):
            p.put(x + dx, y - 1 - (1 if dx == 0 else 0), LEAF_H if dx % 2 else LEAF_L)
        p.put(x, y - 3, LEAF_H)
        p.put(x - 1, y + 1, l)
    elif shape == "dragon":
        p.rect(x - 1, y, x + 1, y + 3, b)
        p.put(x - 2, y + 1, b)
        p.put(x + 2, y + 2, b)
        p.put(x - 2, y, LEAF_H)
        p.put(x + 2, y + 1, LEAF_H)
        p.put(x, y + 3, d)
        p.put(x + 1, y + 3, d)
        p.put(x - 1, y, l)
    elif shape == "pear":
        p.put(x, y, b)
        p.rect(x - 1, y + 1, x + 1, y + 3, b)
        p.put(x + 1, y + 3, d)
        p.put(x, y + 3, d)
        p.put(x - 1, y + 1, l)
        p.put(x, y - 1, (105, 68, 35))
    elif shape == "oval":
        p.rect(x - 1, y, x + 1, y + 3, b)
        p.put(x + 1, y + 3, d)
        p.put(x - 1, y, l)
    else:                                       # round
        p.rect(x - 1, y, x + 1, y + 2, b)
        p.put(x - 1, y, l)
        p.put(x + 1, y + 2, d)
        p.put(x, y + 2, d)
        if name == "golden_apple":
            p.put(x - 2, y - 1, WHITE)


# ------------------------------------------------------------------ plants
TREE_FRUITS = ["apple", "pear", "orange", "plum", "lemon", "cherry", "fig", "peach", "mango", "pomegranate", "golden_apple"]
BUSH_FRUITS = ["blueberry", "raspberry", "elderberry", "blackberry", "pineapple"]
VINE_FRUITS = ["grape", "passionfruit", "dragonfruit"]

TREE_SPOTS = [(9, 12), (17, 8), (25, 13), (12, 21), (21, 19), (28, 24), (7, 28), (17, 29), (25, 31)]


def tree_stages():
    sprout = pack("Trees/Trees_free.png", (33, 67, 46, 79))
    young = pack("Trees/Trees_free.png", (48, 50, 64, 80))
    full = pack("Trees/Trees_free.png", (70, 24, 106, 80))
    w, h = full.size
    stages = []
    for im in (sprout, young, full):
        p = Px(w, h)
        p.paste(im, (w - im.width) // 2, h - im.height)
        stages.append(p)
    return stages, full


def bush_full():
    p = Px(26, 20)
    for cx, cy, r in ((7, 12, 5.5), (13, 9, 6.5), (19, 12, 5.5), (10, 14, 5), (16, 14, 5)):
        p.disc(cx, cy, r, LEAF_M)
    for (x, y) in list(p.g):
        if y >= 16:
            p.g[(x, y)] = LEAF_D
    for cx, cy, r in ((7, 10, 2.5), (13, 6, 3), (19, 10, 2.5)):
        p.disc(cx, cy, r, LEAF_L)
    for x, y in ((12, 4), (13, 4), (6, 8), (18, 8)):
        p.put(x, y, LEAF_H)
    p.outline(NAVY)
    return p


def pineapple_plant():
    p = Px(26, 20)
    for x1, y1 in ((2, 10), (5, 5), (9, 2), (13, 1), (17, 2), (21, 5), (24, 10), (7, 9), (19, 9)):
        p.line(13, 19, x1, y1, LEAF_M)
        p.line(13, 19, x1 + (1 if x1 < 13 else -1), y1 + 1, LEAF_D)
        p.put(x1, y1, LEAF_L)
    p.rect(10, 15, 16, 19, LEAF_D)
    p.outline(NAVY)
    return p


def bush_small():
    p = Px(26, 20)
    p.paste(pack("Decor/Natural_Decor_free.png", (1, 1, 14, 15)), 6, 6)
    return p


def sprout_on(w, h):
    p = Px(w, h)
    sprout = pack("Trees/Trees_free.png", (33, 67, 46, 79))
    p.paste(sprout, (w - sprout.width) // 2, h - sprout.height)
    return p


BUSH_SPOTS = [(5, 9), (11, 6), (17, 7), (21, 11), (8, 13), (14, 12)]


def trellis(p):
    w, h = p.w, p.h
    for x in (3, w - 4):
        p.rect(x, 4, x + 1, h - 1, WOOD_M)
        p.rect(x + 1, 4, x + 1, h - 1, WOOD_2)
    p.rect(1, 3, w - 2, 4, WOOD_L)
    p.rect(1, 5, w - 2, 5, WOOD_2)
    p.rect(3, 16, w - 4, 16, WOOD_M)
    for x in range(1, w - 1):
        if (x, 3) in p.g:
            p.put(x, 3, WOOD_H if x % 4 else WOOD_L)


def vine_leaves(p, coverage):
    """Leaves climbing the trellis; coverage 0..1 is how far up they've grown."""
    w, h = p.w, p.h
    top = round(h - 2 - coverage * (h - 6))
    spots = []
    for y in range(h - 2, top - 1, -3):
        for x in (4, w - 5):
            spots.append((x + (1 if (y // 3) % 2 else -1), y))
        if coverage > 0.6:
            for x in range(7, w - 7, 4):
                if (x + y) % 6 < 3 or y < 8:
                    spots.append((x, y))
    for x, y in spots:
        p.disc(x, y, 1.6, LEAF_M)
        p.put(x - 1, y - 1, LEAF_L)
        p.put(x, y - 1, LEAF_H if (x * y) % 5 == 0 else LEAF_L)


VINE_SPOTS = [(6, 8), (13, 7), (19, 9), (9, 18), (17, 17)]


def plants():
    stages, _ = tree_stages()
    tw, th = stages[0].w, stages[0].h
    for i, st in enumerate(stages):
        st.save(OUT / f"tree_{i}.png")
    for name in TREE_FRUITS:
        p = Px(tw, th)
        p.paste(stages[2].image())
        for x, y in TREE_SPOTS:
            fruit_dot(p, x, y, name)
        p.save(OUT / f"tree_{name}.png")

    sprout_on(26, 20).save(OUT / "bush_0.png")
    bush_small().save(OUT / "bush_1.png")
    full = bush_full()
    full.save(OUT / "bush_2.png")
    pine = pineapple_plant()
    pine.save(OUT / "pineapple_2.png")
    for name in BUSH_FRUITS:
        if name == "pineapple":
            p = Px(26, 20).paste(pine.image())
            fruit_dot(p, 13, 9, name)
        else:
            p = Px(26, 20).paste(full.image())
            for x, y in BUSH_SPOTS:
                fruit_dot(p, x, y, name)
        p.save(OUT / f"bush_{name}.png")

    vw, vh = 26, 34
    for i, cover in enumerate((0.0, 0.45, 1.0)):
        p = Px(vw, vh)
        trellis(p)
        if i == 0:
            sprout = pack("Trees/Trees_free.png", (33, 67, 46, 79))
            p.paste(sprout, (vw - sprout.width) // 2, vh - sprout.height)
        else:
            vine_leaves(p, cover)
        p.save(OUT / f"vine_{i}.png")
    for name in VINE_FRUITS:
        p = Px(vw, vh)
        trellis(p)
        vine_leaves(p, 1.0)
        for x, y in VINE_SPOTS:
            fruit_dot(p, x, y, name)
        p.save(OUT / f"vine_{name}.png")


# ------------------------------------------------------------------ decor
def sun():
    p = Px(24, 24)
    rays = (255, 214, 90)
    for i, (dx, dy) in enumerate(((0, -11), (8, -8), (11, 0), (8, 8), (0, 11), (-8, 8), (-11, 0), (-8, -8))):
        p.line(12 + dx * 7 // 11, 12 + dy * 7 // 11, 12 + dx, 12 + dy, rays)
    p.disc(12, 12, 6.5, (255, 200, 60))
    p.disc(11, 11, 5, (255, 226, 110))
    # Sleepy happy face with rosy cheeks.
    p.put(9, 11, WOOD_D)
    p.put(10, 11, WOOD_D)
    p.put(14, 11, WOOD_D)
    p.put(15, 11, WOOD_D)
    p.put(11, 14, WOOD_D)
    p.put(12, 15, WOOD_D)
    p.put(13, 14, WOOD_D)
    p.put(8, 13, (255, 140, 140))
    p.put(16, 13, (255, 140, 140))
    return p.outline((230, 150, 40))


def cloud(variant):
    p = Px(40, 16) if variant == 0 else Px(30, 14)
    puffs = ((8, 9, 5), (16, 6, 6), (25, 7, 5.5), (32, 10, 4.5)) if variant == 0 else ((7, 8, 4.5), (14, 6, 5.5), (22, 8, 4.5))
    for cx, cy, r in puffs:
        p.disc(cx, cy, r, WHITE)
    for (x, y) in list(p.g):
        if y >= p.h - 4:
            p.g[(x, y)] = (220, 236, 250)
    return p.outline((170, 200, 230))


def hills(far):
    w, h = 192, 48
    p = Px(w, h)
    import math
    base = (120, 200, 170) if far else (52, 182, 112)
    top = (150, 220, 185) if far else (90, 210, 125)
    for x in range(w):
        a = math.sin(x / w * math.tau * 2) * 7 + math.sin(x / w * math.tau * 3 + 1) * 5
        y0 = int((14 if far else 22) - a)
        for y in range(max(0, y0), h):
            p.put(x, y, top if y < y0 + 3 else base)
    if not far:
        for x in range(4, w, 23):
            y0 = min(y for (xx, y) in p.g if xx == x)
            p.disc(x, y0 + 2, 2.5, LEAF_M)
            p.put(x, y0, LEAF_L)
    return p


def shed():
    p = Px(44, 40)
    wall, wall_d = (238, 128, 120), (200, 92, 92)
    roof, roof_d = (120, 70, 140), (86, 46, 108)
    p.rect(5, 16, 38, 39, wall)
    for x in range(6, 38, 4):
        p.rect(x, 17, x, 39, wall_d)
    for i in range(0, 14):          # roof
        p.rect(2 + i, 15 - i, 41 - i, 15 - i, roof if i % 3 else roof_d)
    p.rect(1, 15, 42, 16, roof_d)
    p.rect(16, 25, 27, 39, WOOD_M)  # door
    p.rect(16, 25, 27, 25, WOOD_L)
    p.line(16, 26, 27, 38, WOOD_L)
    p.line(27, 26, 16, 38, WOOD_L)
    p.put(25, 32, (255, 214, 90))
    # Heart window under the roof.
    for x, y in ((19, 7), (20, 6), (21, 7), (22, 7), (23, 6), (24, 7), (19, 8), (24, 8), (20, 9), (23, 9), (21, 10), (22, 10)):
        p.put(x, y, (255, 214, 90))
    p.rect(20, 7, 23, 9, (255, 236, 150))
    p.rect(21, 10, 22, 10, (255, 236, 150))
    # Flower box.
    p.rect(6, 22, 13, 24, WOOD_M)
    for x, c in ((7, (255, 140, 200)), (9, (255, 230, 90)), (11, (255, 140, 200)), (13, WHITE)):
        p.put(x, 21, c)
        p.put(x, 20, LEAF_L)
    return p.outline(WOOD_D)


def beehive():
    p = Px(16, 20)
    gold, gold_d, gold_l = (236, 180, 60), (196, 130, 40), (255, 222, 120)
    p.rect(7, 0, 8, 2, WOOD_M)              # hanging from a post
    p.ellipse(7.5, 10, 6.5, 7.5, gold)
    for y in (6, 10, 14):
        for x in range(16):
            if (x, y) in p.g:
                p.put(x, y, gold_d)
    for (x, y) in list(p.g):
        if x < 6 and y in (4, 5, 8, 9, 12) and p.g[(x, y)] == gold:
            p.g[(x, y)] = gold_l
    p.ellipse(7.5, 14, 2, 1.6, WOOD_D)
    return p.outline(WOOD_D)


def bee(frame):
    p = Px(7, 6)
    p.rect(1, 3, 5, 5, (255, 214, 60))
    p.rect(3, 3, 3, 5, INK)
    p.put(5, 4, INK)
    wing = (220, 240, 255)
    if frame == 0:
        p.rect(2, 0, 3, 2, wing)
    else:
        p.rect(1, 1, 3, 2, wing)
    return p.outline(INK)


def butterfly(frame, colour):
    p = Px(9, 8)
    light = tuple(min(255, c + 70) for c in colour)
    p.rect(4, 2, 4, 6, INK)
    if frame == 0:
        p.ellipse(2, 3, 2, 2, colour)
        p.ellipse(6, 3, 2, 2, colour)
        p.disc(2, 6, 1.2, colour)
        p.disc(6, 6, 1.2, colour)
        p.put(2, 3, light)
        p.put(6, 3, light)
    else:
        p.rect(3, 1, 3, 6, colour)
        p.rect(5, 1, 5, 6, colour)
        p.put(3, 2, light)
        p.put(5, 2, light)
    p.put(3, 0, INK)
    p.put(5, 0, INK)
    return p.outline(INK)


def flower(petal, kind):
    p = Px(9, 12)
    p.line(4, 11, 4, 5, LEAF_D)
    p.rect(5, 8, 6, 9, LEAF_L)
    p.put(2, 9, LEAF_L)
    if kind == "tulip":
        p.rect(2, 2, 6, 5, petal)
        p.put(2, 1, petal)
        p.put(4, 1, petal)
        p.put(6, 1, petal)
        p.put(3, 3, tuple(min(255, c + 60) for c in petal))
    else:  # daisy
        for dx, dy in ((0, -2), (2, 0), (0, 2), (-2, 0), (1, -1), (-1, 1), (1, 1), (-1, -1)):
            p.put(4 + dx, 4 + dy, petal)
        p.put(4, 4, (255, 214, 60))
    return p.outline(NAVY)


def mushroom():
    p = Px(9, 9)
    p.ellipse(4, 3, 4, 2.6, (215, 45, 45))
    p.rect(3, 5, 5, 8, (245, 236, 210))
    for x, y in ((2, 2), (5, 1), (6, 3)):
        p.put(x, y, WHITE)
    return p.outline(WOOD_D)


def mound():
    p = Px(28, 9)
    p.ellipse(13.5, 4.5, 13, 4, (120, 72, 46))
    p.ellipse(13.5, 3.5, 11, 2.6, (150, 94, 60))
    for x, y in ((6, 4), (12, 3), (19, 5), (23, 4)):
        p.put(x, y, (100, 58, 38))
    return p


def fence():
    p = Px(16, 16)
    p.rect(1, 3, 4, 15, WOOD_M)
    p.rect(1, 3, 1, 15, WOOD_L)
    p.rect(1, 2, 4, 3, WOOD_H)
    p.rect(0, 6, 15, 7, WOOD_L)
    p.rect(0, 8, 15, 8, WOOD_2)
    p.rect(0, 11, 15, 12, WOOD_L)
    p.rect(0, 13, 15, 13, WOOD_2)
    return p.outline(WOOD_D)


def arch():
    p = Px(72, 44)
    for x in (4, 63):
        p.rect(x, 10, x + 4, 43, WOOD_M)
        p.rect(x, 10, x, 43, WOOD_L)
    p.rect(0, 6, 71, 18, WOOD_L)            # sign plank
    p.rect(0, 6, 71, 7, WOOD_H)
    p.rect(0, 17, 71, 18, WOOD_2)
    # Vines with little apples and flowers trailing over the plank.
    for x in range(0, 72, 3):
        y = 5 + (1 if (x // 3) % 2 else 0)
        p.disc(x, y, 1.4, LEAF_M)
        p.put(x, y - 1, LEAF_L)
    for x in range(2, 72, 11):
        p.disc(x, 20, 1.3, LEAF_M)
        fruit_dot(p, x + 1, 21, "apple")
    for x, c in ((8, (255, 140, 200)), (30, WHITE), (50, (255, 230, 90)), (66, (255, 140, 200))):
        p.put(x, 4, c)
    return p.outline(WOOD_D)


def signpost():
    p = Px(20, 30)
    p.rect(9, 10, 10, 29, WOOD_M)
    p.rect(9, 10, 9, 29, WOOD_L)
    p.rect(1, 3, 18, 13, WOOD_L)            # board pointing right
    p.rect(1, 3, 18, 3, WOOD_H)
    p.rect(1, 13, 18, 13, WOOD_2)
    p.put(19, 8, WOOD_L)
    p.rect(19, 6, 19, 10, WOOD_L)
    # A tiny apple and pear painted on the board.
    fruit_dot(p, 6, 7, "apple")
    fruit_dot(p, 12, 6, "pear")
    p.rect(8, 0, 9, 2, LEAF_M)               # leafy tuft on top
    p.put(10, 1, LEAF_L)
    return p.outline(WOOD_D)


def wheelbarrow():
    p = Px(26, 16)
    p.rect(3, 4, 19, 10, (196, 70, 60))
    p.rect(3, 4, 19, 5, (230, 110, 90))
    for x in range(5, 19, 3):                # heaped with fruit
        fruit_dot(p, x, 1, ["apple", "orange", "pear", "peach", "plum"][x % 5])
    p.line(19, 7, 25, 4, WOOD_M)
    p.line(19, 8, 25, 5, WOOD_D)
    p.disc(7, 12, 3, (60, 60, 70))
    p.disc(7, 12, 1.2, (150, 150, 160))
    p.rect(16, 11, 17, 15, WOOD_M)
    return p.outline(WOOD_D)


def sparkle():
    p = Px(7, 7)
    c = (255, 250, 200)
    p.line(3, 0, 3, 6, c)
    p.line(0, 3, 6, 3, c)
    p.put(3, 3, WHITE)
    return p


def decor():
    sun().save(OUT / "sun.png")
    cloud(0).save(OUT / "cloud_0.png")
    cloud(1).save(OUT / "cloud_1.png")
    hills(True).save(OUT / "hills_far.png")
    hills(False).save(OUT / "hills_near.png")
    shed().save(OUT / "shed.png")
    beehive().save(OUT / "beehive.png")
    bee(0).save(OUT / "bee_0.png")
    bee(1).save(OUT / "bee_1.png")
    for i, colour in enumerate(((255, 140, 200), (255, 214, 60), (120, 180, 255))):
        butterfly(0, colour).save(OUT / f"butterfly_{i}_0.png")
        butterfly(1, colour).save(OUT / f"butterfly_{i}_1.png")
    for i, (petal, kind) in enumerate((((255, 140, 200), "tulip"), (WHITE, "daisy"), ((255, 230, 90), "daisy"),
                                       ((215, 45, 45), "tulip"), ((170, 130, 255), "tulip"), ((255, 170, 120), "daisy"))):
        flower(petal, kind).save(OUT / f"flower_{i}.png")
    mushroom().save(OUT / "mushroom.png")
    mound().save(OUT / "mound.png")
    fence().save(OUT / "fence.png")
    arch().save(OUT / "arch.png")
    signpost().save(OUT / "signpost.png")
    wheelbarrow().save(OUT / "wheelbarrow.png")
    sparkle().save(OUT / "sparkle.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name in FRUIT:
        icon(name).save(ITEMS / f"{name}.png")
    plants()
    decor()
    print("wrote orchard art:", len(list(OUT.glob("*.png"))), "orchard sprites +", len(FRUIT), "fruit icons")


if __name__ == "__main__":
    main()
