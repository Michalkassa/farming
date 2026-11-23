#!/usr/bin/env python3
"""Generates the pixel art for the shop stall: the farmer who runs it (idle,
blink and waving frames), the striped awning, plank and counter tiles, and the
little stall that sits in the hub. Everything is drawn at native 1x pixel size
with hard edges and an automatic dark outline so it sits next to the 16px
Clover Valley art; Godot scales it up with nearest filtering.
Run from anywhere; writes into static/shop."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "static/shop"
CLOVER = ROOT / "Clover Valley V2 Free"

OUTLINE = (52, 30, 30)
# Shared with the stall art
STRAW, STRAW_LT = (238, 198, 98), (252, 226, 150)
WHITE = (255, 255, 255)
BUTTON = (250, 212, 84)
# Stall
RED, RED_DK = (214, 70, 64), (170, 46, 48)
CREAM, CREAM_DK = (252, 240, 214), (222, 204, 170)
WOOD, WOOD_DK, WOOD_LT = (156, 100, 56), (112, 68, 36), (190, 132, 76)
BACK, BACK_DK, BACK_LT = (110, 72, 44), (80, 50, 30), (130, 88, 54)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def get(self, x, y):
        return self.px.get((x, y))

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c, ymin=-999, ymax=999):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ymin <= y <= ymax and ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, c)

    def outline(self, c=OUTLINE):
        """Every empty pixel touching a filled one (4-way) becomes outline."""
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if (x, y) in self.px:
                    continue
                if any((x + dx, y + dy) in self.px
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    add.append((x, y))
        for p in add:
            self.px[p] = c

    def save(self, name):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,))
        im.save(OUT / name)
        return im


# --- Stall tiles --------------------------------------------------------------

def awning():
    """16x14, tiles horizontally: one red and one cream stripe, scalloped edge."""
    c = Canvas(16, 14)
    for x in range(16):
        stripe_red = x < 8
        base, dark = (RED, RED_DK) if stripe_red else (CREAM, CREAM_DK)
        lx = x % 8
        for y in range(0, 10):
            col = dark if y == 0 or lx in (0, 7) else base
            c.put(x, y, col)
        # Scallop: a half circle hanging under each stripe.
        for y in range(10, 14):
            dx = lx - 3.5
            dy = y - 9.5
            if (dx / 4.0) ** 2 + (dy / 3.6) ** 2 <= 1.0:
                c.put(x, y, dark if y == 13 or (dx / 4.0) ** 2 + (dy / 3.6) ** 2 > 0.55 else base)
    # Outline only the bottom so the tile edges stay seamless.
    for x in range(16):
        bottom = max(y for y in range(14) if c.get(x, y) is not None)
        if bottom + 1 < 14:
            c.put(x, bottom + 1, OUTLINE)
        else:
            c.put(x, 13, OUTLINE)
    c.rect(0, 0, 15, 0, OUTLINE)
    return c


def planks(base, dark, light, name, w=16, h=16, plank=4):
    """Vertical planks with seams, grain and nails; tiles both ways."""
    c = Canvas(w, h)
    for x in range(w):
        for y in range(h):
            lx = x % plank
            col = dark if lx == 0 else (light if lx == 1 else base)
            c.put(x, y, col)
    for px in range(0, w, plank):
        c.put(px + 2, (px * 5) % h, dark)
        c.put(px + 2, (px * 5 + 7) % h, dark)
        c.put(px + 2, 2, light)
        c.put(px + 2, h - 3, light)
    c.save(name)


def counter_top():
    """16x8 board along the top of the counter, tiles horizontally."""
    c = Canvas(16, 8)
    c.rect(0, 0, 15, 0, OUTLINE)
    c.rect(0, 1, 15, 1, WOOD_LT)
    c.rect(0, 2, 15, 4, WOOD)
    c.put(4, 3, WOOD_DK); c.put(11, 2, WOOD_DK); c.put(12, 2, WOOD_DK)
    c.rect(0, 5, 15, 5, WOOD_DK)
    c.rect(0, 6, 15, 6, OUTLINE)
    c.rect(0, 7, 15, 7, (60, 38, 22))           # shadow under the lip
    return c


def post():
    """8x16 upright, tiles vertically."""
    c = Canvas(8, 16)
    c.rect(0, 0, 0, 15, OUTLINE); c.rect(7, 0, 7, 15, OUTLINE)
    c.rect(1, 0, 1, 15, WOOD_LT)
    c.rect(2, 0, 5, 15, WOOD)
    c.rect(6, 0, 6, 15, WOOD_DK)
    c.put(3, 4, WOOD_DK); c.put(4, 11, WOOD_DK)
    return c


def shelf():
    """16x6 shelf board, tiles horizontally."""
    c = Canvas(16, 6)
    c.rect(0, 0, 15, 0, OUTLINE)
    c.rect(0, 1, 15, 1, WOOD_LT)
    c.rect(0, 2, 15, 3, WOOD)
    c.rect(0, 4, 15, 4, OUTLINE)
    c.rect(0, 5, 15, 5, (64, 40, 24))
    return c


# --- Hub stall ----------------------------------------------------------------

def stocked_shelf(c, x0, x1, y):
    """A little shelf across the stall's back wall, packed with goods."""
    c.rect(x0, y, x1, y, WOOD_LT)
    c.rect(x0, y + 1, x1, y + 1, WOOD_DK)
    goods = [(226, 64, 52), (250, 212, 84), (246, 140, 40), (130, 60, 170), (90, 160, 60),
             (255, 244, 222), (255, 150, 200), (226, 64, 52), (250, 212, 84), (110, 160, 230)]
    x = x0 + 1
    i = 0
    while x + 1 <= x1 - 1:
        col = goods[i % len(goods)]
        c.rect(x, y - 2, x + 1, y - 1, col)
        x += 3
        i += 1


def hub_stall():
    """56x56 market stall for the hub, standing on its bottom edge."""
    c = Canvas(56, 56)
    # Shadow on the grass.
    shadow = Canvas(56, 56)
    shadow.ellipse(28, 52, 25, 3, (40, 110, 60))
    # Back wall and posts.
    c.rect(8, 18, 47, 36, BACK)
    for x in range(8, 48, 4):
        c.rect(x, 18, x, 36, BACK_DK)
    stocked_shelf(c, 9, 46, 24)
    stocked_shelf(c, 9, 46, 30)
    c.rect(5, 14, 8, 50, WOOD); c.rect(5, 14, 5, 50, WOOD_LT)
    c.rect(47, 14, 50, 50, WOOD); c.rect(50, 14, 50, 50, WOOD_DK)
    # Counter.
    c.rect(4, 36, 51, 38, WOOD_LT)
    c.rect(4, 39, 51, 50, WOOD)
    for x in range(4, 52, 4):
        c.rect(x, 39, x, 50, WOOD_DK)
    # Produce crates on the counter.
    for ox, fruit, leaf in ((9, (226, 64, 52), (90, 160, 60)),
                            (21, (246, 140, 40), (90, 160, 60)),
                            (35, (250, 212, 84), (90, 160, 60))):
        for i, (dx, dy) in enumerate(((1, 0), (4, 0), (7, 0), (2, -2), (5, -2))):
            c.rect(ox + dx, 33 + dy, ox + dx + 1, 34 + dy, fruit)
            if i >= 3:
                c.put(ox + dx, 32 + dy, leaf)
        c.rect(ox, 35, ox + 9, 36, WOOD_DK)
    # Striped awning with scallops.
    for x in range(2, 54):
        red = ((x - 2) // 6) % 2 == 0
        base, dark = (RED, RED_DK) if red else (CREAM, CREAM_DK)
        for y in range(6, 15):
            c.put(x, y, dark if y == 6 else base)
        lx = (x - 2) % 6
        if 1 <= lx <= 4:
            c.put(x, 15, base)
        if 2 <= lx <= 3:
            c.put(x, 16, base)
    # Little roof ridge and a pennant on top.
    c.rect(4, 4, 51, 5, RED_DK)
    c.rect(27, 0, 28, 3, WOOD_DK)
    c.rect(29, 0, 32, 1, BUTTON)
    c.outline()
    for p, col in shadow.px.items():
        c.px.setdefault(p, col)
    return c


class Scaled:
    """Draws on a Canvas in coordinates of a smaller design, scaled by k, so
    the art can be redrawn larger with crisp 1px outlines instead of being
    stretched."""
    def __init__(self, canvas, k):
        self.c, self.k = canvas, k

    def _a(self, v):
        return int(round(v * self.k))

    def rect(self, x0, y0, x1, y1, col):
        self.c.rect(self._a(x0), self._a(y0), self._a(x1 + 1) - 1, self._a(y1 + 1) - 1, col)

    def put(self, x, y, col):
        self.rect(x, y, x, y, col)


def coop(k=1.5):
    """Chicken coop on stilts, designed on a 32x36 grid and drawn at k times
    that size; its bottom edge stands on the ground."""
    c = Canvas(int(32 * k), int(36 * k))
    d = Scaled(c, k)
    # Stilts and the ramp down into the run.
    d.rect(6, 26, 7, 35, WOOD_DK); d.rect(24, 26, 25, 35, WOOD_DK)
    for i in range(9):
        d.rect(13 + i // 3, 27 + i, 18 + i // 3, 27 + i, WOOD_LT if i % 2 else WOOD)
    # Body: plank walls.
    d.rect(4, 14, 27, 26, WOOD)
    for x in range(4, 28, 4):
        d.rect(x, 14, x, 26, WOOD_DK)
    d.rect(4, 26, 27, 26, WOOD_DK)
    # Round-topped door with straw inside, and a little window.
    d.rect(13, 19, 18, 26, (60, 38, 22))
    d.rect(14, 18, 17, 18, (60, 38, 22))
    d.rect(14, 24, 17, 25, STRAW)
    d.put(13, 25, STRAW_LT); d.put(18, 24, STRAW)
    d.rect(22, 17, 25, 20, (120, 190, 220))
    d.rect(22, 17, 25, 17, WHITE)
    d.put(23, 19, (90, 150, 190))
    # Pitched red roof drawn per output row so the slope stays smooth.
    top, bottom = int(round(3 * k)), int(round(15 * k)) - 1
    for y in range(top, bottom + 1):
        t = (y - top) / max(1, bottom - top)
        half = int(round((3 + t * 13) * k))
        stripe = ((y - top) // max(1, int(round(3 * k)))) % 2
        c.rect(int(16 * k) - half, y, int(16 * k) + half - 1, y, RED_DK if stripe else RED)
    d.rect(1, 14, 30, 14, RED_DK)
    d.rect(14, 2, 17, 2, RED_DK)
    # Tiny egg sign over the door.
    d.rect(14, 15, 17, 16, CREAM)
    d.put(15, 15, (240, 220, 180))
    c.outline()
    return c


def doghouse():
    """22x20 dog house with a pitched red roof and an arched door;
    its bottom edge stands on the ground."""
    c = Canvas(22, 20)
    # Plank walls.
    c.rect(3, 9, 18, 18, WOOD)
    for x in range(3, 19, 4):
        c.rect(x, 9, x, 18, WOOD_DK)
    c.rect(3, 18, 18, 18, WOOD_DK)
    # Arched doorway.
    c.rect(8, 12, 13, 18, (44, 28, 18))
    c.rect(9, 11, 12, 11, (44, 28, 18))
    # Roof: overhanging gable.
    for y in range(1, 10):
        half = 2 + y
        c.rect(11 - half, y, 10 + half, y, RED if y % 3 else RED_DK)
    c.rect(0, 9, 21, 9, RED_DK)
    c.rect(9, 0, 12, 0, RED_DK)
    c.outline()
    return c


BARN_RED, BARN_DK = (186, 58, 48), (140, 40, 36)
BARN_ROOF, BARN_ROOF_DK = (110, 66, 52), (82, 46, 38)
TRIM = (246, 240, 226)


def barn(k=1.25):
    """Red barn with a gambrel roof, hay loft and big X-braced doors, designed
    on a 56x52 grid and drawn at k times that; bottom edge on the ground."""
    w, h = int(round(56 * k)), int(round(52 * k))
    c = Canvas(w, h)
    d = Scaled(c, k)
    a = lambda v: int(round(v * k))
    # Walls with vertical boards.
    d.rect(5, 22, 50, 50, BARN_RED)
    for x in range(7, 50, 4):
        d.rect(x, 22, x, 50, BARN_DK)
    # Gambrel roof, drawn per output row: shallow top, steep sides.
    for y in range(a(2), a(23)):
        t = y / k
        half = (12 + (t - 2) * 9 / 8) if t < 10 else (21 + (t - 10) * 6 / 12)
        half = int(round(half * k))
        band = int(t) % 4 == 0
        c.rect(a(28) - half, y, a(28) + half - 1, y, BARN_ROOF_DK if band else BARN_ROOF)
    d.rect(1, 22, 54, 22, BARN_ROOF_DK)
    # Hay loft door with white trim and straw peeking out.
    d.rect(23, 13, 32, 21, TRIM)
    d.rect(24, 14, 31, 20, (60, 38, 22))
    d.rect(24, 19, 31, 20, STRAW)
    d.put(25, 18, STRAW_LT); d.put(29, 18, STRAW)
    # Big double doors: white frame and X braces drawn in output pixels.
    d.rect(16, 30, 39, 50, TRIM)
    d.rect(17, 31, 27, 50, BARN_RED)
    d.rect(28, 31, 38, 50, BARN_RED)
    d.rect(27, 30, 28, 50, TRIM)
    for x0, x1 in ((a(17), a(27)), (a(28), a(38))):
        y0, y1 = a(31), a(51) - 1
        n = y1 - y0
        for i in range(n + 1):
            xa = x0 + round(i * (x1 - x0 - 1) / n)
            xb = x1 - 1 - round(i * (x1 - x0 - 1) / n)
            c.put(xa, y0 + i, TRIM); c.put(xb, y0 + i, TRIM)
    # Corner trim and a little window either side.
    d.rect(5, 23, 6, 50, TRIM); d.rect(49, 23, 50, 50, TRIM)
    for wx in (9, 42):
        d.rect(wx, 28, wx + 4, 32, TRIM)
        d.rect(wx + 1, 29, wx + 3, 31, (120, 190, 220))
    c.outline()
    return c


# --- Barn storage window ------------------------------------------------------

UI_U = 3                       # screen pixels per art pixel, like tools/ui_art.py


def ui_save(c, name):
    im = c.save(name)
    im.resize((im.width * UI_U, im.height * UI_U), Image.NEAREST).save(OUT / name)


def barn_frame():
    """16x16 nine-slice (6-cell margins): red barn boards with white trim
    around a dark plank interior. The centre tiles horizontally."""
    c = Canvas(16, 16)
    inside, seam = (74, 48, 30), (56, 36, 22)
    c.rect(0, 0, 15, 15, inside)
    for x in (6, 10, 14):
        c.rect(x, 6, x, 9, seam)
    for ring, col in ((0, OUTLINE), (1, TRIM), (2, BARN_RED), (3, BARN_RED), (4, BARN_DK), (5, OUTLINE)):
        n = 15 - ring
        c.rect(ring, ring, n, ring, col); c.rect(ring, n, n, n, col)
        c.rect(ring, ring, ring, n, col); c.rect(n, ring, n, n, col)
    # Board seams on the red border so it reads as planks.
    for x in (7, 11):
        c.put(x, 2, BARN_DK); c.put(x, 13, BARN_DK)
    for y in (7, 11):
        c.put(2, y, BARN_DK); c.put(13, y, BARN_DK)
    # Keep the tiled middle columns identical so the edges repeat cleanly.
    for x in range(6, 10):
        for y in list(range(0, 6)) + list(range(10, 16)):
            c.put(x, y, c.get(6, y) if x != 7 else c.get(7, y))
    ui_save(c, "barn_frame.png")


def crate_slot():
    """12x12 nine-slice (4-cell margins): a little wooden crate cubby."""
    c = Canvas(12, 12)
    c.rect(0, 0, 11, 11, (46, 30, 18))
    for ring, col in ((0, OUTLINE), (1, WOOD_LT), (2, WOOD), (3, WOOD_DK)):
        n = 11 - ring
        c.rect(ring, ring, n, ring, col); c.rect(ring, n, n, n, col)
        c.rect(ring, ring, ring, n, col); c.rect(n, ring, n, n, col)
    for x, y in ((1, 1), (10, 1), (1, 10), (10, 10)):
        c.put(x, y, (170, 170, 176))             # nails
    ui_save(c, "crate_slot.png")


def barn_wall():
    """16x16 interior barn boards (tile in both directions)."""
    c = Canvas(16, 16)
    base, seam, hi = (120, 52, 40), (88, 36, 30), (142, 66, 50)
    c.rect(0, 0, 15, 15, base)
    for x in (0, 8):
        c.rect(x, 0, x, 15, seam)
        c.rect(x + 1, 0, x + 1, 15, hi)
    for x, y in ((4, 3), (12, 9), (5, 12), (13, 2)):
        c.put(x, y, seam)
    c.save("barn_wall.png")


def straw_floor():
    """16x16 straw-strewn floor boards (tile in both directions)."""
    c = Canvas(16, 16)
    c.rect(0, 0, 15, 15, (150, 104, 60))
    c.rect(0, 7, 15, 7, (118, 80, 44)); c.rect(0, 15, 15, 15, (118, 80, 44))
    for x, y, col in ((2, 2, STRAW), (3, 3, STRAW), (9, 1, STRAW_LT), (10, 2, STRAW), (13, 5, STRAW),
                      (5, 10, STRAW_LT), (6, 11, STRAW), (11, 12, STRAW), (12, 13, STRAW_LT), (1, 13, STRAW)):
        c.put(x, y, col)
    c.save("straw_floor.png")


def beam():
    """16x10 roof beam (tiles horizontally)."""
    c = Canvas(16, 10)
    c.rect(0, 0, 15, 0, OUTLINE)
    c.rect(0, 1, 15, 2, WOOD_LT)
    c.rect(0, 3, 15, 7, WOOD)
    c.put(5, 5, WOOD_DK); c.put(12, 4, WOOD_DK)
    c.rect(0, 8, 15, 8, OUTLINE)
    c.rect(0, 9, 15, 9, (60, 26, 22))
    c.save("beam.png")


def lantern():
    """12x20 hanging lantern with a warm glow."""
    c = Canvas(12, 20)
    c.rect(5, 0, 6, 4, (70, 70, 76))             # chain
    c.rect(3, 5, 8, 6, (60, 60, 66))             # cap
    c.rect(2, 7, 9, 15, (255, 214, 120))         # glass
    c.rect(4, 9, 7, 13, (255, 244, 200))         # flame glow
    c.rect(2, 7, 2, 15, (60, 60, 66)); c.rect(9, 7, 9, 15, (60, 60, 66))
    c.rect(2, 16, 9, 17, (60, 60, 66))
    c.outline()
    c.save("lantern.png")


def settings_cog():
    """16x16 wooden cogwheel for the settings button."""
    import math
    c = Canvas(16, 16)
    cx = cy = 7.5
    for y in range(16):
        for x in range(16):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            tooth = math.cos(ang * 8) > 0.55          # eight teeth
            if r <= 4.6 or (tooth and r <= 7.3):
                c.put(x, y, WOOD_LT if dx + dy < -2 else (WOOD_DK if dx + dy > 3 else WOOD))
            if r <= 1.6:
                c.px.pop((x, y), None)                # axle hole
    for x, y in ((6, 6), (9, 9)):
        c.put(x, y, WOOD_DK)                          # grain
    c.outline()
    im = c.save("settings_cog.png")
    (OUT / "settings_cog.png").replace(ROOT / "static/ui/settings_cog.png")


def hay_bale():
    """24x16 hay bale for the corners of the barn window."""
    c = Canvas(24, 16)
    c.rect(1, 3, 22, 14, STRAW)
    c.rect(1, 3, 22, 4, STRAW_LT)
    for x, y in ((3, 6), (9, 9), (15, 5), (19, 11), (6, 12), (12, 13)):
        c.put(x, y, (198, 150, 62))
    for x in (6, 17):
        c.rect(x, 3, x, 14, (150, 96, 48))
    c.outline()
    c.save("hay_bale.png")


# --- Ground tiles -------------------------------------------------------------

TILE = 16                      # every ground tile matches the 16px grass and fences
SOIL = {
    "dry": ((156, 90, 60), (124, 72, 48), (177, 102, 68)),
    "wet": ((80, 48, 34), (64, 38, 27), (91, 54, 38)),
}
FURROW = {
    "dry": ((188, 122, 82), (106, 63, 42)),
    "wet": ((104, 64, 46), (52, 31, 22)),
}
SAND, SAND_DK, SAND_LT = (236, 206, 112), (214, 182, 94), (246, 222, 140)


def raised_bed(wet=False, tilled=False):
    """16x16 plot: a wooden raised bed seen from above and slightly in front,
    so the top rim and the front board give it depth."""
    c = Canvas(TILE, TILE)
    base, dark, light = SOIL["wet" if wet else "dry"]
    face = TILE - 4            # rows 0..11 are the top, 12..14 the front board
    c.rect(0, 0, TILE - 1, face, WOOD)
    c.rect(1, 0, TILE - 2, 0, WOOD_LT)
    c.rect(0, 1, 0, face - 1, WOOD_LT)
    c.rect(TILE - 1, 1, TILE - 1, face - 1, WOOD_DK)
    # Soil sunk inside the rim; the darker top/left edge reads as the inner wall.
    c.rect(2, 2, TILE - 3, face - 2, base)
    c.rect(2, 2, TILE - 3, 2, dark)
    c.rect(2, 2, 2, face - 2, dark)
    if tilled:
        hi, lo = FURROW["wet" if wet else "dry"]
        for y in (5, 8):
            c.rect(4, y - 1, TILE - 5, y - 1, hi)
            c.rect(4, y, TILE - 5, y, lo)
    else:
        for x, y in ((5, 4), (10, 5), (7, 8), (12, 8), (4, 9)):
            c.put(x, y, light if (x + y) % 2 else dark)
    # Front board facing the camera.
    c.rect(0, face + 1, TILE - 1, TILE - 2, WOOD_DK)
    c.rect(0, face + 1, TILE - 1, face + 1, WOOD)
    for x in (4, 11):
        c.put(x, face + 2, (90, 54, 28))
    c.rect(0, 0, TILE - 1, 0, OUTLINE)
    c.rect(0, 0, 0, TILE - 2, OUTLINE)
    c.rect(TILE - 1, 0, TILE - 1, TILE - 2, OUTLINE)
    c.rect(0, TILE - 1, TILE - 1, TILE - 1, OUTLINE)
    c.rect(1, face, TILE - 2, face, OUTLINE)
    return c


def path_sand():
    """16x16 sand that tiles seamlessly in every direction; the path script
    adds edges only where a path tile meets grass."""
    c = Canvas(TILE, TILE)
    c.rect(0, 0, TILE - 1, TILE - 1, SAND)
    for x, y in ((3, 2), (11, 4), (6, 9), (14, 11), (1, 13), (9, 14)):
        c.put(x, y, SAND_DK)
    for x, y in ((4, 2), (12, 4), (7, 9), (2, 6), (13, 1)):
        c.put(x, y, SAND_LT)
    c.rect(9, 6, 10, 6, SAND_DK)
    return c


def shop_icon(src, dst):
    """A shop icon from an animal sprite: drops the soft drop-shadow (any
    semi-transparent pixel) and crops to the animal so it can be drawn big."""
    im = Image.open(src).convert("RGBA")
    solid = Image.new("RGBA", im.size, (0, 0, 0, 0))
    for y in range(im.height):
        for x in range(im.width):
            px = im.getpixel((x, y))
            if px[3] == 255:
                solid.putpixel((x, y), px)
    solid.crop(solid.getbbox()).save(dst)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    coop().save("coop.png")
    doghouse().save("doghouse.png")
    barn().save("barn.png")
    barn_frame(); crate_slot(); hay_bale()
    barn_wall(); straw_floor(); beam(); lantern()
    settings_cog()
    shop_icon(ROOT / "static/animals/pig_walk_0.png", ROOT / "static/items/pig_icon.png")
    tiles = ROOT / "static/tilesets"
    for tilled in (False, True):
        for wet in (False, True):
            name = f"bed_{'tilled' if tilled else 'bare'}_{'wet' if wet else 'dry'}.png"
            raised_bed(wet, tilled).save(name)
            (OUT / name).replace(tiles / name)
    path_sand().save("path_sand.png")
    (OUT / "path_sand.png").replace(tiles / "path_sand.png")
    awning().save("awning.png")
    planks(WOOD, WOOD_DK, WOOD_LT, "counter_front.png")
    planks(BACK, BACK_DK, BACK_LT, "back_wall.png")
    counter_top().save("counter_top.png")
    post().save("post.png")
    shelf().save("shelf.png")
    hub_stall().save("hub_stall.png")
    print("wrote stall art to", OUT)


if __name__ == "__main__":
    main()
