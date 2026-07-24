#!/usr/bin/env python3
"""tool/build_assets.py — assemble game-ready sprites from curated source packs.

Sources are CC0/CC-BY packs staged locally (URLs + licenses in PROVENANCE.md).
Run: python3 tool/build_assets.py <staging_dir>
Outputs into assets/images/ as animation strips (one row, fixed frame size)
plus passthrough copies. Idempotent.
"""
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "images"


def strip_from_files(files, out, size=None):
    """Concatenate individual frame files into one horizontal strip."""
    frames = [Image.open(f).convert("RGBA") for f in files]
    if size is None:
        size = frames[0].size
    w, h = size
    sheet = Image.new("RGBA", (w * len(frames), h))
    for i, fr in enumerate(frames):
        fx = (w - fr.width) // 2
        fy = h - fr.height  # bottom-align
        sheet.paste(fr, (i * w + fx, i * w * 0 + fy))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"strip  {out.relative_to(REPO)}  {len(frames)}f {w}x{h}")


def copy(src, out):
    out.parent.mkdir(parents=True, exist_ok=True)
    Image.open(src).convert("RGBA").save(out)
    print(f"copy   {out.relative_to(REPO)}")


def slice_strip(src, out, frame_w, frame_h, y=0, xs=None, count=None,
                key_bg=False):
    """Cut frames out of an atlas/strip and re-emit as a clean strip.

    key_bg: treat the atlas corner pixel color as transparent (GrafxKid
    sheets ship on a solid backdrop).
    """
    im = Image.open(src).convert("RGBA")
    if key_bg:
        bg = im.getpixel((0, 0))
        px = im.load()
        for yy in range(im.height):
            for xx in range(im.width):
                if px[xx, yy][:3] == bg[:3]:
                    px[xx, yy] = (0, 0, 0, 0)
    if xs is None:
        count = count or im.width // frame_w
        xs = [i * frame_w for i in range(count)]
    sheet = Image.new("RGBA", (frame_w * len(xs), frame_h))
    for i, x in enumerate(xs):
        sheet.paste(im.crop((x, y, x + frame_w, y + frame_h)), (i * frame_w, 0))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"slice  {out.relative_to(REPO)}  {len(xs)}f {frame_w}x{frame_h}")


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: build_assets.py <staging_dir>")
    S = Path(sys.argv[1])

    # --- Player: 'Royal Knight' by pixivan (CC0). 22x24 base, 40x30 attacks.
    kn = S / "pixivan_knight_hero"
    slice_strip(kn / "Combat Ready Idle.png", OUT / "player/idle.png", 22, 24)
    slice_strip(kn / "Run.png", OUT / "player/run.png", 22, 24)
    slice_strip(kn / "Jump.png", OUT / "player/jump.png", 22, 24)
    slice_strip(kn / "Fall.png", OUT / "player/fall.png", 22, 24)
    slice_strip(kn / "Hit Front.png", OUT / "player/hit.png", 22, 24)
    slice_strip(kn / "Roll.png", OUT / "player/roll.png", 22, 24)
    slice_strip(kn / "Attack 1.png", OUT / "player/attack1.png", 40, 30)
    slice_strip(kn / "Attack 2.png", OUT / "player/attack2.png", 40, 30)
    slice_strip(kn / "Attack 3.png", OUT / "player/attack3.png", 40, 30)

    # --- Tiles & props: Sunny Land by ansimuz (CC0).
    sl = S / "ansimuz_sunny_land"
    copy(sl / "environment/layers/tileset.png", OUT / "tiles/tileset.png")
    props = sl / "environment/props"
    for name, out in [
        ("spikes.png", "props/spikes.png"),
        ("door.png", "props/door.png"),
        ("door-opened.png", "props/door_open.png"),
        ("sign.png", "props/sign.png"),
        ("small-platform.png", "props/platform.png"),
        ("block.png", "props/block.png"),
        ("block-big.png", "props/block_big.png"),
        ("bush.png", "props/bush.png"),
        ("tree.png", "props/tree.png"),
        ("rock.png", "props/rock.png"),
        ("shrooms.png", "props/shrooms.png"),
    ]:
        copy(props / name, OUT / out)

    # --- Enemies: Sunny Land (CC0).
    sp = sl / "sprites"
    strip_from_files(sorted((sp / "opossum").glob("*.png")),
                     OUT / "enemies/thornling.png")  # walker
    eagle = [sp / f"eagle/eagle-attack-{i}.png" for i in range(1, 5)]
    strip_from_files(eagle, OUT / "enemies/ashbat.png")  # flyer
    strip_from_files(sorted((sp / "frog/idle").glob("*.png")),
                     OUT / "enemies/hopper_idle.png")
    strip_from_files(sorted((sp / "frog/jump").glob("*.png")),
                     OUT / "enemies/hopper_jump.png")
    strip_from_files(sorted((sp / "enemy-death").glob("*.png")),
                     OUT / "fx/enemy_death.png", size=(40, 41))

    # --- Items.
    strip_from_files(sorted((sp / "gem").glob("*.png")),
                     OUT / "items/feather.png")  # rare currency visual
    strip_from_files(sorted((sp / "cherry").glob("*.png")),
                     OUT / "items/cherry.png")
    # Apple: Pixel Adventure 1 by Pixel Frog (CC0), 17f 32x32.
    pa = S / "pixelfrog_pixel_adventure_1"
    slice_strip(pa / "Items/Fruits/Apple.png", OUT / "items/apple.png", 32, 32)
    # Coin: GrafxKid 'Items' (CC0) — 4 frames of 16x16 at row y=80.
    slice_strip(S / "grafxkid_items/Items_1.png", OUT / "items/coin.png",
                16, 16, y=80, xs=[96, 112, 128, 144], key_bg=True)
    # Chest: dustdfg (CC-BY 4.0, credited) — 3 frames 48x48 (closed->open).
    slice_strip(S / "dustdfg_treasure_chests/round/gold/chest_gold.png",
                OUT / "items/chest.png", 48, 48)

    # --- Hazards: fire trap (Pixel Frog, CC0), 3f 16x32.
    slice_strip(pa / "Traps/Fire/On (16x32).png", OUT / "fx/fire.png", 16, 32)

    # --- Backgrounds: ansimuz parallax forest (CC0) + Sunny Land layers.
    pf = S / "ansimuz_parallax_forest/layers"
    copy(pf / "parallax-forest-back-trees.png", OUT / "bg/forest_back.png")
    copy(pf / "parallax-forest-middle-trees.png", OUT / "bg/forest_middle.png")
    copy(pf / "parallax-forest-front-trees.png", OUT / "bg/forest_front.png")
    copy(pf / "parallax-forest-lights.png", OUT / "bg/forest_lights.png")
    copy(sl / "environment/layers/back.png", OUT / "bg/sunny_back.png")

    # --- Touch HUD: Kenney Mobile Controls (CC0).
    kc = S / "kenney_mobile_controls/Sprites"
    flat = kc / "Flat" / "Default"
    if not flat.is_dir():
        # pack layout fallback: find first dir containing button_circle.png
        cands = list(kc.rglob("button_circle.png"))
        flat = cands[0].parent
    for name, out in [
        ("direction_left.png", "hud/btn_left.png"),
        ("direction_right.png", "hud/btn_right.png"),
        ("button_circle.png", "hud/btn_round.png"),
    ]:
        copy(flat / name, OUT / out)
    icons = kc / "Icons" / "Default"
    for name, out in [
        ("icon_jump.png", "hud/icon_jump.png"),
        ("icon_sword.png", "hud/icon_sword.png"),
        ("icon_pause.png", "hud/icon_pause.png"),
    ]:
        src = icons / name
        if src.exists():
            copy(src, OUT / out)
        else:
            print(f"MISSING {name} — pick alternative icon")

    print("done.")


if __name__ == "__main__":
    main()
