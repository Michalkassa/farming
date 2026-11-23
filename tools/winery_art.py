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

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(self.h):
            for x in range(self.w):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
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


# ---------------------------------------------------------------- cellar ambience
STONE, STONE_D, STONE_L, MORTAR = (112, 98, 92), (84, 72, 70), (140, 126, 116), (58, 48, 48)


def stone_wall():
    """Tileable cellar stonework: staggered blocks with dark mortar."""
    p = Px()
    p.rect(0, 0, 15, 15, MORTAR)
    blocks = ((0, 0, 7, 3), (9, 0, 15, 3), (0, 5, 3, 9), (5, 5, 12, 9), (14, 5, 15, 9), (0, 11, 6, 15), (8, 11, 15, 15))
    for i, (x0, y0, x1, y1) in enumerate(blocks):
        c = (STONE, shade(STONE, -0.06), shade(STONE, 0.05))[i % 3]
        p.rect(x0, y0, x1, y1 - 1, c)
        p.rect(x0, y0, x1, y0, STONE_L)
        p.rect(x0, y1 - 1, x1, y1 - 1, STONE_D)
    for x, y in ((3, 2), (11, 1), (8, 7), (2, 13), (12, 13)):
        p.put(x, y, STONE_D)
    return p


def flagstones():
    p = Px()
    floor, floor_d, floor_l = (92, 78, 70), (66, 54, 50), (114, 98, 88)
    p.rect(0, 0, 15, 15, floor_d)
    for x0, y0, x1, y1 in ((0, 0, 9, 6), (11, 0, 15, 6), (0, 8, 4, 15), (6, 8, 15, 15)):
        p.rect(x0, y0, x1, y1 - 1, floor)
        p.rect(x0, y0, x1, y0, floor_l)
    return p


def wine_rack():
    """A wooden rack of bottle ends: glass circles with coloured foil."""
    w, h = 34, 44
    p = Px(w, h)
    wood, wood_d, wood_l = (120, 74, 42), (84, 50, 28), (156, 102, 60)
    p.rect(0, 0, w - 1, h - 1, wood_d)
    p.rect(1, 1, w - 2, 2, wood_l)
    p.rect(1, h - 3, w - 2, h - 2, wood)
    foils = [(196, 40, 70), (230, 190, 60), (120, 60, 160), (196, 40, 70), (60, 140, 90), (230, 190, 60)]
    i = 0
    for row in range(5):
        for col in range(4):
            cx, cy = 5 + col * 8, 6 + row * 8
            p.disc(cx, cy, 3, (30, 50, 40))
            p.disc(cx, cy, 1.5, foils[i % len(foils)])
            p.put(cx - 1, cy - 1, (180, 220, 200))
            i += 1
    for x in (0, w - 1):
        p.rect(x, 0, x, h - 1, wood)
    return p.outline()


def barrel_end():
    """A barrel lying on its side, seen end-on: hooped round face."""
    p = Px(24, 24)
    wood, wood_d, wood_l = (150, 96, 52), (104, 64, 34), (186, 128, 74)
    p.disc(11.5, 11.5, 11, (88, 88, 96))                 # outer hoop
    p.disc(11.5, 11.5, 9.5, wood)
    for x in range(3, 21, 4):
        p.line(x, 3, x, 20, wood_d)
    p.disc(11.5, 11.5, 2, wood_d)                        # bung
    p.disc(11, 11, 1, wood_l)
    for x, y in ((6, 5), (16, 6), (5, 15)):
        p.put(x, y, wood_l)
    return p.outline()


def cobweb():
    p = Px()
    web = (220, 220, 230)
    for i in range(0, 16, 1):
        if i < 15:
            p.put(i, 0, web) if i % 2 == 0 else None
    p.line(0, 0, 15, 15, web)
    p.line(0, 0, 7, 15, web)
    p.line(0, 0, 15, 7, web)
    for r in (5, 9, 13):
        for t in range(0, r + 1):
            x, y = t, r - t
            if (x + y) % 2 == 0:
                p.put(x, y, web)
    return p


def window():
    """A small arched cellar window with soft daylight and bars."""
    p = Px(20, 18)
    light, light_l = (170, 210, 235), (215, 236, 248)
    p.rect(2, 6, 17, 17, light)
    p.disc(9.5, 7, 7.5, light)
    for (x, y) in list(p.g):
        if y > 17:
            del p.g[(x, y)]
    p.rect(4, 4, 8, 9, light_l)
    for x in (6, 10, 14):
        p.rect(x, 0, x, 17, (60, 56, 60))
    p.rect(2, 11, 17, 11, (60, 56, 60))
    return p.outline((58, 48, 48))


def cat(frame):
    """A ginger cat curled up asleep; frame 1 breathes in and flicks the tail."""
    p = Px(18, 11)
    fur, fur_d, fur_l = (236, 150, 70), (196, 108, 46), (255, 196, 130)
    p.ellipse(9, 7 - (1 if frame else 0) * 0.5, 7.5, 3.6 + 0.4 * frame, fur)
    p.disc(4, 6, 3, fur)                                   # head
    p.put(2, 3, fur); p.put(3, 3, fur_d)                   # ears
    p.put(5, 3, fur); p.put(6, 3, fur_d)
    for x in (8, 11, 14):
        p.line(x, 4, x, 6, fur_d)                          # stripes
    p.put(3, 6, (60, 40, 40)); p.put(5, 6, (60, 40, 40))   # closed eyes
    p.put(4, 7, (240, 130, 150))                           # nose
    tail_tip = (17, 4) if frame else (16, 9)
    p.line(15, 8, tail_tip[0], tail_tip[1], fur_d)
    p.rect(6, 5, 12, 5, fur_l)
    return p.outline((92, 52, 36))


def candle(frame):
    p = Px(8, 16)
    wax, wax_d = (248, 236, 210), (220, 200, 170)
    p.rect(2, 7, 5, 15, wax)
    p.rect(5, 7, 5, 15, wax_d)
    p.put(2, 8, wax_d)
    p.put(3, 6, (60, 50, 40))                              # wick
    flame = ((3, 1), (3, 2), (2, 3), (3, 3), (4, 3), (3, 4), (2, 4), (4, 4), (3, 5)) if frame == 0 \
        else ((4, 1), (3, 2), (4, 2), (2, 3), (3, 3), (4, 3), (3, 4), (2, 4), (4, 4), (3, 5))
    for x, y in flame:
        p.put(x, y, (255, 180, 60))
    p.put(3, 4, (255, 240, 170))
    p.put(3, 3, (255, 240, 170))
    return p.outline((92, 60, 40))


def bubble():
    p = Px(5, 5)
    p.disc(2, 2, 2, (220, 160, 190))
    p.disc(2, 2, 1, (120, 40, 70))
    p.put(1, 1, (255, 235, 245))
    return p


def ambience():
    out = ROOT / "static/winery"
    stone_wall().save(out / "stone_wall.png")
    flagstones().save(out / "flagstones.png")
    wine_rack().save(out / "wine_rack.png")
    barrel_end().save(out / "barrel_end.png")
    cobweb().save(out / "cobweb.png")
    window().save(out / "window.png")
    cat(0).save(out / "cat_0.png")
    cat(1).save(out / "cat_1.png")
    candle(0).save(out / "candle_0.png")
    candle(1).save(out / "candle_1.png")
    bubble().save(out / "bubble.png")


def main():
    items = ROOT / "static/items"
    for name, colour in YEASTS.items():
        yeast_packet(colour).save(items / f"{name}.png")
    for name, colour in BOTTLES.items():
        bottle(colour).save(ROOT / "static/winery" / f"bottle_{name}.png")
    barrel().save(ROOT / "static/winery/barrel.png")
    ambience()
    print("wrote", len(YEASTS) + len(BOTTLES) + 1, "sprites")


if __name__ == "__main__":
    main()
