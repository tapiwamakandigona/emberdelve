#!/usr/bin/env python3
"""Annotate in-game screenshots into "how to play" guide plates.

Each plate = the raw 1080x1920 screenshot with numbered ember callouts
(rounded-rect target outline + numbered chip) and a legend band appended
below that explains every marked element in the game's own words (labels
mirror the v0.8.0 guided-tour copy in lib/ui/screens/tour_overlay.dart and
the node semantics in lib/ui/screens/map_screen.dart).

Brand palette (privacy page / frame_store_screenshots.py):
bg #14101e, ember #f2953f, gold #f0cd82, text #efe9dc, line #352c4e.

Output: docs/store/screenshots/howto/0N-*.png  (run from repo root or tool/)
"""

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs/store/screenshots")
OUT = os.path.join(SRC, "howto")
CINZEL = os.path.join(ROOT, "assets/fonts/Cinzel-Variable.ttf")
INTER = os.path.join(ROOT, "assets/fonts/Inter-Regular.ttf")

BG = (20, 16, 30)  # #14101e
EMBER = (242, 149, 63)  # #f2953f
GOLD = (240, 205, 130)  # #f0cd82
TEXT = (239, 233, 220)  # #efe9dc
DIM = (168, 158, 192)  # #a89ec0
LINE = (53, 44, 78)  # #352c4e

W, H = 1080, 1920
PAD = 44
CHIP_R = 34  # numbered chip radius

# Each plate: (source, out name, legend title, callouts)
# A callout: (box (x0,y0,x1,y1) around the element, chip anchor corner
# "tl"|"tr"|"bl"|"br", legend text).  Boxes measured on the 1080x1920 raws.
PLATES = [
    (
        "04-combat-roll.png",
        "01-combat-annotated.png",
        "Combat — how to read it",
        [
            ((64, 160, 770, 470), "bl",
             "Enemy HP and the turn counter. Get it to 0 before it gets you."),
            ((785, 350, 985, 470), "br",
             "Its next move. The badge always resolves exactly as shown — no hidden math."),
            ((55, 855, 1040, 1050), "tr",
             "Your HP. Blocked damage never touches it."),
            ((120, 1055, 985, 1335), "bl",
             "Your dice. Tap ROLL to throw them, then tap a die to pick it up."),
            ((40, 1415, 1040, 1580), "tl",
             "Spend it: ATTACK deals the die's value, BLOCK absorbs hits."),
            ((40, 1585, 1040, 1740), "tl",
             "One risky reroll per turn — rescue a bad face (the new face lands at -1 pip)."),
            ((40, 1755, 1040, 1900), "tl",
             "Done spending? END TURN — the enemy then does exactly what the badge showed."),
        ],
    ),
    (
        "03-map.png",
        "02-map-annotated.png",
        "The map — pick your path",
        [
            ((95, 1330, 265, 1530), "tr",
             "A glowing ring means you can go there now. Crossed swords = a fight."),
            ((120, 1535, 245, 1600), "br",
             "The die under a node is the reward for clearing it — gold means rarest."),
            ((410, 385, 670, 580), "bl",
             "Skull nodes are elites and bosses: tougher fights, richer rewards."),
            ((810, 660, 1010, 855), "bl",
             "? is an event — a choice with a risk and a payoff."),
            ((430, 1490, 650, 1710), "tl",
             "You start here. The whole delve is visible — commit before you climb."),
        ],
    ),
    (
        "02-boon-pick.png",
        "03-boon-annotated.png",
        "Boons — start each delve your way",
        [
            ((60, 195, 1020, 470), "bl",
             "Before every delve: one free blessing. Pick what suits your plan."),
            ((48, 855, 1035, 1190), "tr",
             "Every boon states exactly what it does — die size, limits, gold. Nothing is hidden."),
            ((45, 1690, 1040, 1875), "tl",
             "Or skip and walk in unaided — bigger bragging rights."),
        ],
    ),
    (
        "05-ledger.png",
        "04-ledger-annotated.png",
        "The Ledger — death still pays",
        [
            ((45, 320, 1040, 510), "tl",
             "Embers you bank survive every death. Spend them on permanent unlocks."),
            ((45, 530, 1040, 680), "tr",
             "Your lifetime record. Every delve counts, won or lost."),
            ((45, 690, 1040, 840), "tl",
             "Ascension: after you win, stack extra difficulty for better ember pay."),
            ((45, 1360, 1040, 1880), "tl",
             "Delvers: playable characters with different styles. Keep playing to unlock more."),
        ],
    ),
]


def font(path, size):
    return ImageFont.truetype(path, size)


def rounded_box(draw, box, color, width=4, radius=22):
    draw.rounded_rectangle(box, radius=radius, outline=color, width=width)


def chip(draw, cx, cy, n, f):
    draw.ellipse(
        (cx - CHIP_R, cy - CHIP_R, cx + CHIP_R, cy + CHIP_R),
        fill=BG, outline=EMBER, width=4,
    )
    t = str(n)
    tw = draw.textlength(t, font=f)
    draw.text((cx - tw / 2, cy - f.size / 2 - 4), t, font=f, fill=GOLD)


def chip_pos(box, corner):
    x0, y0, x1, y1 = box
    m = 6  # overlap the outline corner slightly so chip reads as attached
    return {
        "tl": (x0 + m, y0 + m),
        "tr": (x1 - m, y0 + m),
        "bl": (x0 + m, y1 - m),
        "br": (x1 - m, y1 - m),
    }[corner]


def wrap(draw, text, f, max_w):
    words, lines, cur = text.split(), [], ""
    for w_ in words:
        t = (cur + " " + w_).strip()
        if draw.textlength(t, font=f) <= max_w:
            cur = t
        else:
            lines.append(cur)
            cur = w_
    if cur:
        lines.append(cur)
    return lines


def build(src_name, out_name, title, callouts):
    shot = Image.open(os.path.join(SRC, src_name)).convert("RGB")
    assert shot.size == (W, H), f"{src_name}: unexpected size {shot.size}"

    f_chip = font(INTER, 40)
    f_title = font(CINZEL, 54)
    f_entry = font(INTER, 34)
    f_num = font(INTER, 34)

    # measure legend height first
    probe = ImageDraw.Draw(shot)
    entry_w = W - 2 * PAD - 96
    blocks = [wrap(probe, txt, f_entry, entry_w) for _, _, txt in callouts]
    line_h = 46
    legend_h = 40 + 78 + sum(len(b) * line_h + 26 for b in blocks) + 30

    img = Image.new("RGB", (W, H + legend_h), BG)
    img.paste(shot, (0, 0))
    d = ImageDraw.Draw(img)

    # callouts on the screenshot
    for i, (box, corner, _) in enumerate(callouts, 1):
        rounded_box(d, box, EMBER)
        cx, cy = chip_pos(box, corner)
        chip(d, cx, cy, i, f_chip)

    # legend band
    y = H
    d.rectangle((0, y, W, H + legend_h), fill=BG)
    d.line((0, y, W, y), fill=LINE, width=3)
    y += 40
    t = title.upper()
    tw = d.textlength(t, font=f_title)
    d.text(((W - tw) / 2, y), t, font=f_title, fill=GOLD)
    y += 78
    for i, lines in enumerate(blocks, 1):
        ncx, ncy = PAD + 30, y + 24
        d.ellipse((ncx - 26, ncy - 26, ncx + 26, ncy + 26),
                  fill=BG, outline=EMBER, width=3)
        t = str(i)
        tw = d.textlength(t, font=f_num)
        d.text((ncx - tw / 2, ncy - f_num.size / 2 - 3), t, font=f_num, fill=GOLD)
        ty = y
        for ln in lines:
            d.text((PAD + 96, ty), ln, font=f_entry, fill=TEXT)
            ty += line_h
        y = max(ty, ncy + 26) + 26

    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, out_name)
    img.save(out, "PNG", optimize=True)
    print(f"wrote {out}  {img.size[0]}x{img.size[1]}")


def main():
    for src, out, title, callouts in PLATES:
        build(src, out, title, callouts)


if __name__ == "__main__":
    main()
