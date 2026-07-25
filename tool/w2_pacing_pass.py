#!/usr/bin/env python3
"""tool/w2_pacing_pass.py — pacing/fairness pass over the World 2 grids.

World 1 was re-authored from scratch (tool/level_author.py). World 2 keeps its
layouts but gets the same fairness rules applied mechanically:

  1. SAFE RUNWAY   — no enemy within 16 tiles of the spawn, no hazard within 14
  2. NO AMBUSH PIT — no enemy within 3 columns of a spike/fire tile (the
                     measured death loop was "creeper knocks you into spikes")
  3. DENSITY CAP   — at most 3 enemies per 20-tile window (Apple Knight paces
                     encounters; alpha.4 stacked them)
  4. EARLY PITS    — hazard runs in the first 40 % of a level are capped at
                     2 columns (a trivial hop) so the opening cannot drain a
                     run before the player has learned the level
  5. CHECKPOINTS   — three campfires spread across the level

Enemies are relocated, never deleted, so the progressive-introduction
guarantees in test/world2_levels_test.dart still hold.

Run: python3 tool/w2_pacing_pass.py
"""
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DIR = REPO / "assets" / "levels"
LEVELS = ["w2_l1", "w2_l2", "w2_l3", "w2_l4", "w2_l5"]
ENEMY = set("TVORGSDWH")
HAZARD = set("^~")
SAFE_ENEMY, SAFE_HAZARD = 16, 14
HAZARD_CLEARANCE = 3
WINDOW, MAX_PER_WINDOW = 20, 3


def load(p):
    meta, rows = [], []
    for line in p.read_text().split("\n"):
        if not line.strip():
            continue
        (meta if line.startswith("meta:") else rows).append(line)
    w = max(len(r) for r in rows)
    return meta, [list(r.ljust(w, ".")) for r in rows]


def save(p, meta, g):
    p.write_text("\n".join(meta + ["".join(r).rstrip() or "." for r in g]) + "\n")


def relocate(g, x, y, haz_cols, taken, w, h, spawn_x):
    """Find the nearest legal home to the right for the enemy at (x,y)."""
    for nx in range(x + 4, w - 3):
        if nx - spawn_x <= SAFE_ENEMY or nx in taken:
            continue
        if any(abs(nx - hx) <= HAZARD_CLEARANCE for hx in haz_cols):
            continue
        if g[y][nx] != ".":
            continue
        below = g[y + 1][nx] if y + 1 < h else "#"
        # walkers need footing; flyers are happy in open air
        if below in "#=" or all(g[yy][nx] == "." for yy in range(y, min(h, y + 3))):
            return nx
    return None


def main():
    for name in LEVELS:
        p = DIR / f"{name}.txt"
        meta, g = load(p)
        h, w = len(g), len(g[0])
        spawn = next((x, y) for y in range(h) for x in range(w) if g[y][x] == "P")
        sx = spawn[0]
        log = []

        # hazards first: clear them out of the runway, then index the columns
        for y in range(h):
            for x in range(sx, min(w, sx + SAFE_HAZARD + 1)):
                if g[y][x] in HAZARD:
                    g[y][x] = "#"
                    log.append(f"hazard@{x} filled (runway)")
        # cap early hazard runs at 2 columns
        early = int(w * 0.4)
        for y in range(h):
            x = 0
            while x < early:
                if g[y][x] in HAZARD:
                    run = x
                    while run < w and g[y][run] in HAZARD:
                        run += 1
                    if run - x > 2:
                        for fx in range(x + 2, run):
                            g[y][fx] = "#"
                            if y - 1 >= 0 and g[y - 1][fx] == ".":
                                g[y - 1][fx] = "#"
                        log.append(f"early pit {x}-{run - 1} narrowed to 2")
                    x = run
                else:
                    x += 1

        haz_cols = {x for y in range(h) for x in range(w) if g[y][x] in HAZARD}

        enemies = [(x, y) for y in range(h) for x in range(w) if g[y][x] in ENEMY]
        taken = {x for x, _ in enemies}
        for x, y in enemies:
            too_close_spawn = x - sx <= SAFE_ENEMY
            on_a_ledge = any(abs(x - hx) <= HAZARD_CLEARANCE for hx in haz_cols)
            crowded = sum(1 for ex, _ in enemies
                          if abs(ex - x) <= WINDOW // 2) > MAX_PER_WINDOW
            if not (too_close_spawn or on_a_ledge or crowded):
                continue
            nx = relocate(g, x, y, haz_cols, taken, w, h, sx)
            if nx is None:
                continue
            g[y][nx], g[y][x] = g[y][x], "."
            taken.discard(x)
            taken.add(nx)
            enemies = [(nx, y) if (ex, ey) == (x, y) else (ex, ey)
                       for ex, ey in enemies]
            why = ("runway" if too_close_spawn else
                   "hazard edge" if on_a_ledge else "crowding")
            log.append(f"{g[y][nx]} {x}->{nx} ({why})")

        # campfires — never within 8 columns of an enemy (a campfire next to
        # a patrol is a respawn loop) and never over a hazard
        enemy_cols = {ex for ex, _ in enemies}
        placed = []
        for frac in (0.25, 0.5, 0.75):
            want = int(w * frac)
            done = False
            for dx in range(0, 20):
                for x in (want + dx, want - dx):
                    if not (0 <= x < w) or any(abs(x - q) < 12 for q in placed):
                        continue
                    if any(abs(x - ex) <= 8 for ex in enemy_cols):
                        continue
                    if any(abs(x - hx) <= 3 for hx in haz_cols):
                        continue
                    for y in range(h - 2, 0, -1):
                        if (g[y][x] == "." and g[y + 1][x] == "#"
                                and g[y - 1][x] == "."):
                            g[y][x] = "K"
                            placed.append(x)
                            done = True
                            break
                    if done:
                        break
                if done:
                    break
        save(p, meta, g)
        print(f"{name}: campfires {placed}; {len(log)} edits")
        for line in log:
            print(f"    {line}")


if __name__ == "__main__":
    main()
