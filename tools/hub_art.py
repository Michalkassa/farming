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

def paste_keeper(c, ox, oy, rows=15):
    """The scarecrow from the Clover Valley objects sheet, minding the stall."""
    sheet = Image.open(CLOVER / "Enviroment/Objects/Objects_free.png").convert("RGBA")
    keeper = sheet.crop((0, 2, 16, 2 + rows))
    for y in range(keeper.height):
        for x in range(keeper.width):
            r, g, b, a = keeper.getpixel((x, y))
            if a > 0:
                c.put(ox + x, oy + y, (r, g, b))


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
    paste_keeper(c, 20, 21)
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


# --- Raised beds -------------------------------------------------------------

BED = 20                       # one plot, in world pixels
SOIL = {
    "dry": ((156, 90, 60), (124, 72, 48), (177, 102, 68)),
    "wet": ((80, 48, 34), (64, 38, 27), (91, 54, 38)),
}
FURROW = {
    "dry": ((188, 122, 82), (106, 63, 42)),
    "wet": ((104, 64, 46), (52, 31, 22)),
}


def raised_bed(wet=False, tilled=False):
    """20x20 plot: a wooden raised bed seen from above and slightly in front,
    so the top rim and the front board give it depth."""
    c = Canvas(BED, BED)
    base, dark, light = SOIL["wet" if wet else "dry"]
    face = BED - 5             # rows 0..14 are the top, 15..18 the front board
    # Wooden rim around the top face.
    c.rect(0, 0, BED - 1, face, WOOD)
    c.rect(1, 0, BED - 2, 0, WOOD_LT)
    c.rect(0, 1, 0, face - 1, WOOD_LT)
    c.rect(BED - 1, 1, BED - 1, face - 1, WOOD_DK)
    # Soil, sunk inside the rim: darker top edge reads as the inner wall.
    c.rect(2, 2, BED - 3, face - 2, base)
    c.rect(2, 2, BED - 3, 2, dark)
    c.rect(2, 2, 2, face - 2, dark)
    if tilled:
        hi, lo = FURROW["wet" if wet else "dry"]
        for y in (5, 9, 12):
            c.rect(4, y - 1, BED - 5, y - 1, hi)
            c.rect(4, y, BED - 5, y, lo)
    else:
        for x, y in ((5, 5), (12, 4), (8, 9), (15, 10), (4, 11), (11, 12), (14, 6)):
            c.put(x, y, light if (x + y) % 2 else dark)
    # Front board: the side of the bed facing the camera.
    c.rect(0, face + 1, BED - 1, BED - 2, WOOD_DK)
    c.rect(0, face + 1, BED - 1, face + 1, WOOD)
    for x in (4, 10, 15):
        c.put(x, face + 2, (90, 54, 28))
    # Outline: top and sides, then the ground line under the board.
    c.rect(0, 0, BED - 1, 0, OUTLINE)
    c.rect(0, 0, 0, BED - 2, OUTLINE)
    c.rect(BED - 1, 0, BED - 1, BED - 2, OUTLINE)
    c.rect(0, BED - 1, BED - 1, BED - 1, OUTLINE)
    c.rect(1, face, BED - 2, face, OUTLINE)
    return c


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    coop().save("coop.png")
    beds = ROOT / "static/tilesets"
    for tilled in (False, True):
        for wet in (False, True):
            name = f"bed_{'tilled' if tilled else 'bare'}_{'wet' if wet else 'dry'}.png"
            im = raised_bed(wet, tilled)
            im.save(name)
            (OUT / name).replace(beds / name)
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
