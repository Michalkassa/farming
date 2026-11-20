#!/usr/bin/env python3
"""Generates the crop sprites: growing stages, ripe plants, harvested-item icons
and seed bags. Writes into static/crops and static/items.

By default only the seed bags are written; pass --all to also regenerate the
crop sprites (the ones on disk have hand touch-ups this script doesn't know).

Every sprite is a 16x16 grid drawn with fills, then given a dark 1px outline
where a filled pixel touches a transparent one, which keeps the set cohesive."""
from pathlib import Path
from PIL import Image

PAL = {
    "o": (43, 29, 20),      # outline
    "g": (47, 122, 46),     # dark green
    "G": (79, 180, 63),     # green
    "h": (143, 224, 106),   # light green
    "y": (184, 134, 11),    # gold dark
    "Y": (233, 184, 36),    # gold
    "w": (247, 221, 122),   # wheat light
    "r": (158, 26, 26),     # dark red
    "R": (224, 51, 46),     # red
    "p": (247, 128, 122),   # pink highlight
    "c": (184, 83, 27),     # dark orange
    "C": (240, 127, 34),    # orange
    "l": (251, 176, 96),    # light orange
    "k": (28, 28, 28),      # seed black
    "W": (244, 244, 244),   # white
    "d": (28, 92, 38),      # melon dark green
    "D": (58, 154, 58),     # melon green
    "m": (126, 211, 106),   # melon light
    "b": (105, 68, 35),     # brown (seeds/tie)
    "B": (191, 151, 52),    # bag tan
}

class Px:
    def __init__(self):
        self.g = {}

    def put(self, x, y, c):
        if 0 <= x < 16 and 0 <= y < 16:
            self.g[(x, y)] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def disc(self, cx, cy, r, c):
        for y in range(16):
            for x in range(16):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.5:
                    self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            self.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)

    def rows(self, x, y, text, skip="."):
        for dy, row in enumerate(text.split("\n")):
            for dx, ch in enumerate(row):
                if ch != skip:
                    self.put(x + dx, y + dy, ch)

    def outline(self, c="o"):
        edge = set()
        for (x, y) in self.g:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (x + dx, y + dy) not in self.g and 0 <= x + dx < 16 and 0 <= y + dy < 16:
                    edge.add((x + dx, y + dy))
        for p in edge:
            self.g[p] = c

    def image(self):
        im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        for (x, y), c in self.g.items():
            im.putpixel((x, y), PAL[c] + (255,))
        return im


def sprite(fn):
    p = Px()
    fn(p)
    p.outline()
    return p.image()

# ---------------------------------------------------------------- shared stages
def stage_seed(p):
    for x in (4, 8, 12):
        p.rect(x, 12, x + 1, 13, "b")

def stage_sprout(p):
    p.line(8, 14, 8, 10, "g")
    p.rect(6, 10, 7, 11, "G"); p.put(6, 10, "h")
    p.rect(9, 9, 10, 10, "G"); p.put(10, 9, "h")

# ---------------------------------------------------------------- wheat
def wheat_stalks(p, top, head_char, stem_char, head_h):
    for x in (4, 8, 12):
        p.line(x, 14, x, top + head_h, stem_char)
        p.rect(x - 1, top, x + 1, top + head_h, head_char)
        p.put(x, top, "w" if head_char == "Y" else "h")

def wheat_young(p):
    for x in (4, 8, 12):
        p.line(x, 14, x, 9, "G"); p.put(x, 9, "h")

def wheat_grown(p):
    wheat_stalks(p, 3, "G", "g", 4)

def wheat_ripe(p):
    wheat_stalks(p, 2, "Y", "y", 5)

def wheat_item(p):  # tied sheaf
    for x in (4, 8, 12):
        p.line(x, 14, x, 6, "y")
        p.rect(x - 1, 2, x + 1, 6, "Y"); p.put(x, 2, "w"); p.put(x - 1, 4, "w")

# ---------------------------------------------------------------- carrot
def fronds(p, base_y, height, spread):
    p.line(8, base_y, 8, base_y - height, "G")
    p.line(8, base_y, 8 - spread, base_y - height + 1, "G")
    p.line(8, base_y, 8 + spread, base_y - height + 1, "G")
    p.put(8, base_y - height, "h"); p.put(8 - spread, base_y - height + 1, "h")

def carrot_young(p):
    fronds(p, 14, 4, 2)

def carrot_grown(p):
    fronds(p, 13, 7, 4)
    p.rect(7, 13, 9, 14, "c")

def carrot_ripe(p):
    fronds(p, 12, 8, 5)
    p.rect(6, 12, 10, 14, "C"); p.put(6, 12, "l"); p.put(7, 13, "l")

def carrot_item(p):  # upright carrot, leafy top
    widths = [1, 2, 3, 3, 4, 4, 5, 5, 6]
    for i, w in enumerate(reversed(widths)):
        y = 6 + i
        p.rect(8 - w // 2, y, 8 - w // 2 + w - 1, y, "C")
    for y in (8, 11): p.line(6, y, 9, y, "c")
    p.line(6, 6, 6, 9, "l")
    p.line(8, 5, 8, 1, "G"); p.line(7, 5, 5, 2, "G"); p.line(9, 5, 11, 2, "G")
    p.put(8, 1, "h"); p.put(5, 2, "h")

# ---------------------------------------------------------------- corn
def corn_stalk(p, top):
    p.line(8, 14, 8, top, "g")
    p.line(8, 12, 4, 9, "G"); p.line(8, 9, 12, 6, "G"); p.line(8, 7, 5, 4, "G")
    p.put(4, 9, "h"); p.put(12, 6, "h")

def corn_young(p):
    p.line(8, 14, 8, 8, "g")
    p.line(8, 12, 5, 10, "G"); p.line(8, 10, 11, 8, "G"); p.put(8, 8, "h")

def corn_grown(p):
    corn_stalk(p, 2)
    p.rect(9, 8, 10, 12, "G"); p.put(9, 8, "h")

def corn_ripe(p):
    corn_stalk(p, 1)
    p.rect(9, 7, 11, 12, "Y"); p.put(10, 8, "w"); p.put(10, 10, "w")
    p.line(11, 13, 12, 9, "G")

def corn_item(p):  # cob in husk
    p.rect(6, 1, 9, 12, "Y")
    for y in range(1, 13):
        for x in range(6, 10):
            if (x + y) % 2 == 0: p.put(x, y, "w")
    p.line(5, 14, 4, 5, "G"); p.line(5, 14, 6, 12, "G"); p.rect(4, 11, 5, 14, "G")
    p.line(10, 14, 11, 5, "G"); p.line(10, 14, 9, 12, "G"); p.rect(10, 11, 11, 14, "G")
    p.put(4, 6, "h"); p.put(11, 6, "h")

# ---------------------------------------------------------------- tomato
def tomato_young(p):
    p.line(8, 14, 8, 10, "g"); p.disc(8, 10, 2, "G"); p.put(7, 9, "h")

def tomato_grown(p):
    p.line(8, 14, 8, 6, "g"); p.disc(8, 8, 4, "G"); p.put(6, 6, "h")
    for x, y in ((6, 9), (10, 8)): p.put(x, y, "g")

def tomato_ripe(p):
    p.line(8, 14, 8, 6, "g"); p.disc(8, 8, 4, "G"); p.put(6, 5, "h")
    for x, y in ((5, 9), (10, 7), (8, 11)):
        p.rect(x, y, x + 1, y + 1, "R"); p.put(x, y, "p")

def tomato_item(p):
    p.disc(8, 9, 5, "R")
    p.rect(6, 6, 7, 7, "p"); p.put(5, 8, "p")
    p.rect(4, 12, 12, 13, "r"); p.line(4, 11, 4, 12, "r"); p.line(12, 11, 12, 12, "r")
    p.put(8, 4, "g"); p.put(8, 3, "g")
    p.rect(6, 5, 10, 5, "G"); p.put(5, 6, "G"); p.put(11, 6, "G"); p.put(7, 4, "G"); p.put(9, 4, "G")

# ---------------------------------------------------------------- strawberry
def berry_plant(p):
    p.line(8, 14, 8, 11, "g")
    p.line(8, 12, 4, 10, "G"); p.line(8, 12, 12, 10, "G"); p.line(8, 11, 8, 8, "G")
    p.rect(3, 9, 4, 10, "G"); p.rect(12, 9, 13, 10, "G"); p.rect(7, 7, 9, 8, "G")
    p.put(3, 9, "h"); p.put(13, 9, "h"); p.put(7, 7, "h")

def strawberry_young(p):
    p.line(8, 14, 8, 12, "g"); p.rect(5, 11, 6, 12, "G"); p.rect(10, 11, 11, 12, "G"); p.put(8, 11, "h")

def strawberry_grown(p):
    berry_plant(p)
    for x, y in ((5, 8), (11, 8)):
        p.put(x, y, "W"); p.put(x, y - 1, "W"); p.put(x - 1, y, "W"); p.put(x + 1, y, "W"); p.put(x, y, "Y")

def strawberry_ripe(p):
    berry_plant(p)
    for x, y in ((4, 12), (11, 12), (8, 10)):
        p.rect(x, y, x + 1, y + 1, "R"); p.put(x, y, "p")

def strawberry_item(p):
    widths = [8, 8, 8, 7, 6, 5, 4, 3, 2]
    for i, w in enumerate(widths):
        y = 5 + i
        p.rect(8 - (w + 1) // 2, y, 8 - (w + 1) // 2 + w - 1, y, "R")
    for x, y in ((6, 7), (9, 8), (7, 10), (10, 6), (8, 12), (5, 9)): p.put(x, y, "w")
    p.put(5, 6, "p"); p.put(6, 6, "p")
    p.rect(5, 4, 11, 4, "G"); p.rect(6, 3, 10, 3, "G"); p.line(4, 5, 5, 5, "G"); p.line(11, 5, 12, 5, "G")
    p.put(8, 2, "g"); p.put(8, 1, "g"); p.put(6, 3, "h")

# ---------------------------------------------------------------- watermelon
def melon_vine(p):
    p.line(2, 13, 14, 13, "g")
    for x in (3, 8, 13):
        p.rect(x - 1, 10, x + 1, 12, "G"); p.put(x - 1, 10, "h")

def watermelon_young(p):
    p.line(4, 13, 12, 13, "g"); p.rect(5, 11, 6, 12, "G"); p.rect(10, 11, 11, 12, "G"); p.put(5, 11, "h")

def watermelon_grown(p):
    melon_vine(p)
    p.disc(8, 11, 2, "D"); p.put(7, 10, "m")

def watermelon_ripe(p):
    p.line(2, 8, 14, 8, "g")
    for x in (3, 13): p.rect(x - 1, 5, x + 1, 7, "G"); p.put(x - 1, 5, "h")
    for y in range(8, 15):
        half = 5 if 9 <= y <= 13 else 4 if y in (8, 14) else 5
        p.rect(8 - half, y, 8 + half, y, "D")
    for x in (5, 8, 11): p.line(x, 8, x, 14, "d")
    p.put(5, 9, "m"); p.put(6, 9, "m")

def watermelon_item(p):  # a slice, flat top
    for y in range(5, 15):
        half = [7, 7, 7, 6, 6, 5, 4, 3, 2, 1][y - 5]
        p.rect(8 - half, y, 8 + half, y, "d")
    for y in range(5, 13):
        half = [6, 6, 5, 5, 4, 3, 2, 1][y - 5]
        p.rect(8 - half, y, 8 + half, y, "m")
    for y in range(5, 12):
        half = [5, 5, 4, 4, 3, 2, 1][y - 5]
        p.rect(8 - half, y, 8 + half, y, "R")
    for x, y in ((5, 7), (9, 6), (7, 9), (11, 8), (8, 11)): p.put(x, y, "k")
    p.rect(3, 5, 13, 5, "p")

# ---------------------------------------------------------------- seed bags
BAG = """\
...aaaaaaaaaa...
..abbbbbbbbbba..
.acbbbbbbbbbbba.
.aaddccdcdcddaa.
.aeaaaaaaaaaaea.
.abeeeeeeeeeeba.
.abbbbbbbbbbbda.
.aebbbbbbbbbbba.
.aebbbbbbbbbbda.
.abbbbbbbbbbbda.
.aebbbbbbbbbbba.
.akebbbbbbbbbda.
.aekebbbbbbbbda.
.akekebbbbbbbda.
..akkkeebbbbda..
...aaaaaaaaaa..."""
BAG_PAL = {"a": (25, 30, 60), "b": (191, 151, 52), "c": (255, 206, 71), "d": (225, 178, 61),
           "e": (146, 116, 40), "k": (105, 83, 28)}
# 8x8 crop pictures for the bag front. Each gets a white border and a thin
# dark edge, like a sticker, so the crop reads clearly even at small sizes.
GLYPHS = {
    "wheat": ("..Y..Y..\n"
              ".YwYYwY.\n"
              ".YYYYYY.\n"
              "..YwYY..\n"
              "...yy...\n"
              "...yy...\n"
              "..yyyy..\n"
              "........"),
    "carrot": ("..G.G...\n"
               "...GhG..\n"
               "..CCCC..\n"
               "..lCCC..\n"
               "..CCCc..\n"
               "...CCc..\n"
               "...Cc...\n"
               "....c..."),
    "corn": ("...GG...\n"
             "..YwYG..\n"
             "..wYwG..\n"
             "..YwYG..\n"
             ".GwYwG..\n"
             ".GYwYG..\n"
             "..GGG...\n"
             "...g...."),
    "tomato": ("...gg...\n"
               "..GGGG..\n"
               ".RRpRRR.\n"
               ".RpRRRR.\n"
               ".RRRRRR.\n"
               ".RRRRRr.\n"
               "..RRRr..\n"
               "...rr..."),
    "strawberry": (".GGGGG..\n"
                   "..GhG...\n"
                   ".RRpRR..\n"
                   ".RwRRwR.\n"
                   ".RRRwRR.\n"
                   "..RwRR..\n"
                   "..RRR...\n"
                   "...R...."),
    "watermelon": ("pRRRRRRp\n"
                   "RRkRRkRR\n"
                   "mRRRRRRm\n"
                   ".mRkRRm.\n"
                   ".dmRRmd.\n"
                   "..dmmd..\n"
                   "...dd...\n"
                   "........"),
}
GLYPH_AT = (4, 5)              # top-left of the 8x8 picture on the bag
STICKER_WHITE = (255, 255, 255)

def seed_bag(crop):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(BAG.split("\n")):
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((x, y), BAG_PAL[ch] + (255,))
    glyph = {}
    for dy, row in enumerate(GLYPHS[crop].split("\n")):
        for dx, ch in enumerate(row):
            if ch != ".":
                glyph[(GLYPH_AT[0] + dx, GLYPH_AT[1] + dy)] = PAL[ch]
    # Two rings around the picture: white, then the dark outline colour.
    def ring(shape):
        out = set()
        for (x, y) in shape:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in shape and 0 <= q[0] < 16 and 0 <= q[1] < 16:
                    out.add(q)
        return out
    white = ring(set(glyph))
    dark = ring(set(glyph) | white)
    for q in dark:
        im.putpixel(q, PAL["o"] + (255,))
    for q in white:
        im.putpixel(q, STICKER_WHITE + (255,))
    for q, col in glyph.items():
        im.putpixel(q, col + (255,))
    return im

CROPS = {
    "wheat": (wheat_young, wheat_grown, wheat_ripe, wheat_item),
    "carrot": (carrot_young, carrot_grown, carrot_ripe, carrot_item),
    "corn": (corn_young, corn_grown, corn_ripe, corn_item),
    "tomato": (tomato_young, tomato_grown, tomato_ripe, tomato_item),
    "strawberry": (strawberry_young, strawberry_grown, strawberry_ripe, strawberry_item),
    "watermelon": (watermelon_young, watermelon_grown, watermelon_ripe, watermelon_item),
}

def seed_bags(root: Path):
    for name in CROPS:
        seed_bag(name).save(root / "static/items" / f"{name}_seeds.png")
    print("wrote", len(CROPS), "seed bags")

def main(root: Path):
    crops, items = root / "static/crops", root / "static/items"
    sprite(stage_seed).save(crops / "stage_seed.png")
    sprite(stage_sprout).save(crops / "stage_sprout.png")
    for name, (young, grown, ripe, item) in CROPS.items():
        sprite(young).save(crops / f"{name}_young.png")
        sprite(grown).save(crops / f"{name}_grown.png")
        sprite(ripe).save(crops / f"{name}_ripe.png")
        sprite(item).save(items / f"{name}.png")
        seed_bag(name).save(items / f"{name}_seeds.png")
    print("wrote", 2 + len(CROPS) * 5, "sprites")

if __name__ == "__main__":
    import sys
    root = Path(__file__).resolve().parent.parent
    # `--all` also rewrites the crop sprites, which have hand edits on disk.
    main(root) if "--all" in sys.argv else seed_bags(root)
