#!/usr/bin/env python3
"""Generates the pixel-art UI 9-slice textures (Minecraft flavoured): bevelled
dark panels, inset slots, chunky flat buttons, a plank sign. Everything is drawn
on a coarse pixel grid (one "pixel" = U screen px) with no anti-aliasing so it
matches the 16px item art. Run from the project root; writes into static/ui."""
from pathlib import Path
from PIL import Image

U = 3                      # screen px per art pixel
CELLS = 12                 # art pixels per side; 9-slice margins are 4 cells (12 px)
OUT = Path(__file__).resolve().parent.parent / "static/ui"

BLACK = (0, 0, 0)

def mix(c, other, t):
    return tuple(round(a + (b - a) * t) for a, b in zip(c, other))

class Grid:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < CELLS and 0 <= y < CELLS:
            self.px[(x, y)] = c

    def fill(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def ring(self, inset, c):
        n = CELLS - 1 - inset
        self.fill(inset, inset, n, inset, c); self.fill(inset, n, n, n, c)
        self.fill(inset, inset, inset, n, c); self.fill(n, inset, n, n, c)

    def bevel(self, inset, light, dark, raised=True):
        """Top/left edge one colour, bottom/right the other (the classic bevel)."""
        n = CELLS - 1 - inset
        tl, br = (light, dark) if raised else (dark, light)
        self.fill(inset, inset, n, inset, tl); self.fill(inset, inset, inset, n, tl)
        self.fill(inset, n, n, n, br); self.fill(n, inset, n, n, br)

    def save(self, name):
        im = Image.new("RGBA", (CELLS, CELLS), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,))
        im.resize((CELLS * U, CELLS * U), Image.NEAREST).save(OUT / name)

def panel(name, interior, light, dark, border=None):
    g = Grid()
    g.fill(0, 0, CELLS - 1, CELLS - 1, interior)
    g.ring(0, BLACK)
    if border:
        g.ring(1, border[0]); g.ring(2, border[1])
        g.bevel(3, light, dark)
    else:
        g.bevel(1, light, dark)
    g.save(name)

def button(name, base, pressed=False):
    g = Grid()
    fill = mix(base, BLACK, 0.18) if pressed else base
    g.fill(0, 0, CELLS - 1, CELLS - 1, fill)
    g.ring(0, BLACK)
    g.bevel(1, mix(base, (255, 255, 255), 0.45), mix(base, BLACK, 0.45), raised=not pressed)
    if not pressed:
        g.fill(2, 2, CELLS - 3, 2, mix(base, (255, 255, 255), 0.2))   # second highlight line
    g.save(name)

def slot(name, interior, light, dark):
    g = Grid()
    g.fill(0, 0, CELLS - 1, CELLS - 1, interior)
    g.ring(0, BLACK)
    g.bevel(1, dark, light)      # sunken: dark top/left, light bottom/right
    g.save(name)

def sign(name):
    g = Grid()
    wood, seam, hi = (124, 80, 42), (84, 52, 26), (156, 106, 58)
    g.fill(0, 0, CELLS - 1, CELLS - 1, wood)
    for y in (3, 7, 11):
        g.fill(0, y, CELLS - 1, y, seam)
    for y in (1, 5, 9):
        g.fill(0, y, CELLS - 1, y, hi)
    g.ring(0, BLACK)
    g.save(name)

def main():
    OUT.mkdir(exist_ok=True)
    brown = (46, 32, 20)
    panel("wood_panel.png", brown, (118, 86, 56), (14, 9, 5), border=((92, 60, 32), (128, 86, 48)))
    panel("card.png", (62, 44, 28), (120, 90, 60), (18, 12, 6))
    panel("badge_dark.png", (38, 26, 16), (14, 9, 5), (110, 82, 54))
    sign("wood_sign.png")
    for name, base in [("btn_cream", (96, 66, 40)), ("btn_green", (88, 170, 56)),
                       ("btn_gold", (214, 160, 40)), ("btn_red", (196, 62, 52))]:
        button(f"{name}.png", base); button(f"{name}_pressed.png", base, pressed=True)
    button("btn_gray.png", (58, 44, 32))
    slot("slot_inset.png", (34, 24, 14), (124, 94, 62), (12, 8, 4))
    slot("slot_sell.png", (58, 40, 10), (214, 170, 60), (12, 8, 4))
    print("wrote pixel UI textures to", OUT)

if __name__ == "__main__":
    main()
