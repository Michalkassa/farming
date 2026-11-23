#!/usr/bin/env python3
"""Generates the winery sprites: yeast packets, wine bottles
(one per buff colour) and the big barrel for the winery screen. Same recipe as
crop_art.py: fills on a small grid, then a dark 1px outline wherever a filled
pixel touches a transparent one. Run from anywhere; writes into static/items
and static/winery."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUTLINE = (43, 29, 20)


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

    def line(self, x0, y0, x1, y1, c):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            self.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)

    def outline(self, c=OUTLINE):
        edge = set()
        for (x, y) in self.g:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if (nx, ny) not in self.g and 0 <= nx < self.w and 0 <= ny < self.h:
                    edge.add((nx, ny))
        for p in edge:
            self.g[p] = c
        return self

    def save(self, path):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.g.items():
            im.putpixel((x, y), c + (255,))
        path.parent.mkdir(parents=True, exist_ok=True)
        im.save(path)


def shade(c, t):
    """t < 0 darkens, t > 0 lightens."""
    target = (0, 0, 0) if t < 0 else (255, 255, 255)
    return tuple(round(a + (b - a) * abs(t)) for a, b in zip(c, target))


# ---------------------------------------------------------------- yeasts
YEASTS = {  # id: label colour
    "bakers_yeast": (214, 170, 92),
    "wine_yeast": (142, 38, 66),
    "ale_yeast": (205, 140, 40),
    "mead_yeast": (232, 186, 40),
    "champagne_yeast": (226, 222, 196),
    "wild_yeast": (92, 150, 70),
}


def yeast_packet(colour):
    p = Px()
    paper = (238, 226, 196)
    p.rect(4, 3, 11, 14, paper)
    p.rect(4, 3, 11, 4, shade(paper, -0.15))          # crimped top
    for x in range(4, 12, 2):
        p.put(x, 2, shade(paper, -0.15))
    p.rect(5, 7, 10, 11, colour)                       # label band
    p.rect(5, 7, 10, 7, shade(colour, 0.25))
    for x, y in ((6, 9), (8, 8), (9, 10), (7, 10)):    # yeast "bubbles"
        p.put(x, y, shade(colour, 0.55))
    p.rect(11, 5, 11, 13, shade(paper, -0.25))         # side shadow
    return p.outline()


# ---------------------------------------------------------------- bottles
BOTTLES = {  # effect: wine colour
    "verdant": (96, 176, 64),
    "rainkeeper": (70, 130, 214),
    "bounty": (226, 132, 40),
    "shepherd": (214, 196, 150),
    "merchant": (232, 190, 50),
    "fortune": (40, 170, 130),
    "reach": (140, 80, 190),
    "vinegar": (150, 130, 70),
}


def bottle(wine):
    p = Px()
    glass = (40, 70, 50)
    p.rect(7, 1, 8, 2, (150, 100, 60))                    # cork
    p.rect(7, 3, 8, 5, glass)                             # neck
    p.rect(6, 6, 9, 6, glass)
    p.rect(5, 7, 10, 14, glass)
    p.rect(6, 8, 9, 13, wine)                             # wine showing through
    p.rect(6, 8, 9, 8, shade(wine, 0.3))
    p.rect(6, 10, 9, 12, (240, 230, 200))                 # label
    p.rect(7, 11, 8, 11, wine)
    p.put(6, 9, (255, 255, 255))                          # glint
    return p.outline()


# ---------------------------------------------------------------- barrel
def barrel():
    w, h = 48, 52
    p = Px(w, h)
    wood, dark, light = (150, 96, 52), (104, 64, 34), (186, 128, 74)
    hoop, hoop_hi = (88, 88, 96), (150, 150, 160)
    for y in range(4, h - 2):
        # Bulge: widest in the middle.
        t = abs(y - h / 2) / (h / 2)
        half = round(22 - 4 * t * t)
        for x in range(w // 2 - half, w // 2 + half):
            stave = (x - (w // 2 - half)) * 7 // (2 * half)
            c = wood if stave % 2 == 0 else shade(wood, -0.08)
            if x == w // 2 - half or x == w // 2 + half - 1:
                c = dark
            p.put(x, y, c)
    # Top rim (we look slightly down at the lid).
    for x in range(6, w - 6):
        p.put(x, 3, dark)
        p.put(x, 4, light)
        p.put(x, 5, dark)
    for y in (9, 10, h - 9, h - 8):
        for x in range(w):
            if (x, y) in p.g:
                p.put(x, y, hoop_hi if y in (9, h - 9) else hoop)
    # Stave seams.
    for y in range(6, h - 3):
        for x in range(w):
            if (x, y) in p.g and (x, y) not in ((x, 9), (x, 10)) and x % 7 == 3 and p.g[(x, y)] not in (hoop, hoop_hi):
                p.put(x, y, shade(wood, -0.18))
    # Tap.
    p.rect(22, h - 16, 25, h - 13, (120, 120, 128))
    p.rect(23, h - 12, 24, h - 11, (90, 90, 96))
    return p.outline()


def main():
    items = ROOT / "static/items"
    for name, colour in YEASTS.items():
        yeast_packet(colour).save(items / f"{name}.png")
    for name, colour in BOTTLES.items():
        bottle(colour).save(ROOT / "static/winery" / f"bottle_{name}.png")
    barrel().save(ROOT / "static/winery/barrel.png")
    print("wrote", len(YEASTS) + len(BOTTLES) + 1, "sprites")


if __name__ == "__main__":
    main()
