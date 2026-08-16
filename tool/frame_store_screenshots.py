#!/usr/bin/env python3
"""Frame raw in-game screenshots into high-conversion Play Store screenshots.

Adds a branded caption band (Cinzel gold headline on dark) above each screen,
reorders to lead with the gameplay hook. Output: docs/store/screenshots/framed/.
Brand palette from the app's own privacy page: bg #14101e, ember #f2953f,
text #efe9dc, line #352c4e. Cinzel = display, Inter = subhead.
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs/store/screenshots")
OUT = os.path.join(SRC, "framed")
CINZEL = os.path.join(ROOT, "assets/fonts/Cinzel-Variable.ttf")
INTER = os.path.join(ROOT, "assets/fonts/Inter-Regular.ttf")

BG = (20, 16, 30)        # #14101e
EMBER = (242, 149, 63)   # #f2953f
GOLD = (240, 205, 130)
TEXT = (239, 233, 220)   # #efe9dc
DIM = (168, 158, 192)    # #a89ec0
LINE = (53, 44, 78)      # #352c4e

W, H = 1080, 1920
BAND = 300               # caption band height
PAD = 40

# (source file, headline, subline) — order = store order, hook first
PLATES = [
    ("04-combat-roll.png", "Every death is fair.",   "Enemies always telegraph. No hidden math."),
    ("02-boon-pick.png",   "Real choices, every run.", "Push your luck — or walk in unaided."),
    ("03-map.png",         "Branching paths.",        "See what an elite guards before you commit."),
    ("01-title.png",       "Fair dice. No ads.",      "No timers, no gacha. Free forever."),
    ("05-ledger.png",      "Die forward.",            "Bank embers. Unlock delvers, dice, ascension."),
]


def load_font(path, size):
    return ImageFont.truetype(path, size)


def draw_centered(draw, text, font, y, fill, max_w):
    # shrink to fit width
    size = font.size
    f = font
    while draw.textlength(text, font=f) > max_w and size > 20:
        size -= 4
        f = ImageFont.truetype(f.path, size)
    w = draw.textlength(text, font=f)
    draw.text(((W - w) / 2, y), text, font=f, fill=fill)
    return f


def make_plate(src_name, headline, subline, idx):
    canvas = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(canvas)

    # subtle diagonal texture in the band
    for x in range(-H, W, 14):
        d.line([(x, 0), (x + H, H)], fill=(24, 19, 36), width=1)
    d.rectangle([0, BAND, W, H], fill=BG)  # clear texture below band

    # ember accent rule under the band
    d.rectangle([0, BAND - 4, W, BAND], fill=EMBER)

    # headline (Cinzel gold) + subline (Inter dim)
    hfont = load_font(CINZEL, 92)
    sfont = load_font(INTER, 40)
    draw_centered(d, headline, hfont, 78, GOLD, W - 2 * PAD)
    draw_centered(d, subline, sfont, 205, DIM, W - 2 * PAD)

    # place the game screenshot below the band, scaled to fit
    shot = Image.open(os.path.join(SRC, src_name)).convert("RGB")
    avail_h = H - BAND - 2 * PAD
    avail_w = W - 2 * PAD
    ratio = min(avail_w / shot.width, avail_h / shot.height)
    nw, nh = int(shot.width * ratio), int(shot.height * ratio)
    shot = shot.resize((nw, nh), Image.LANCZOS)
    ox = (W - nw) // 2
    oy = BAND + PAD + (avail_h - nh) // 2
    # thin brand border
    d.rectangle([ox - 3, oy - 3, ox + nw + 2, oy + nh + 2], outline=LINE, width=3)
    canvas.paste(shot, (ox, oy))

    os.makedirs(OUT, exist_ok=True)
    out_path = os.path.join(OUT, f"{idx:02d}-{src_name.split('-',1)[1]}")
    canvas.save(out_path, "PNG")
    return out_path


def main():
    made = []
    for i, (src, head, sub) in enumerate(PLATES, start=1):
        p = make_plate(src, head, sub, i)
        made.append(p)
        print("wrote", os.path.relpath(p, ROOT))
    print(f"DONE {len(made)} framed screenshots -> {os.path.relpath(OUT, ROOT)}")


if __name__ == "__main__":
    main()
