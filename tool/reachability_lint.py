#!/usr/bin/env python3
"""tool/reachability_lint.py — static collectible-reachability lint.

The runner-bot test proves the DOOR is reachable; nothing proved the
chests/secrets/feathers were. This lint flood-fills the level with the
player's real movement budget and reports any collectible (c a f C X),
campfire or exit the fill cannot touch.

Movement model (from lib/game/tuning.dart + test/physics_test.dart):
  * double-jump rise budget: verified empirically (tmp probe 2026-07-26):
    a standing double-jump lands on a 4-row-high ledge -> RISE = 4
  * horizontal reach while airborne: ~6 columns (maxGapTiles is 7 with a
    running start; 6 is the safe planning number)
  * falls: unlimited depth, same horizontal drift
  * cracked walls ('B') are breakable -> passable (and standable-on)
  * the body is 2 tiles tall: a cell needs head clearance to be occupied

A jump is approximated as up-then-across-then-down cell paths with
collision checks per cell. Over-approximation is impossible (every move is
collision-checked); under-approximation is possible in exotic geometry, so
treat reports as "must review", not "must be broken".

Run: python3 tool/reachability_lint.py [level ...]   (default: all)
Exits 1 if any collectible is unreachable.
"""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LEVELS = REPO / "assets" / "levels"

RISE = 4          # verified: standing double-jump lands a 4-row ledge
REACH = 6         # airborne horizontal reach, in columns
SOLID = "#"       # only true solids block; 'B' breaks, '=' is one-way
TARGETS = set("cafCXKE")


def load(name):
    rows = [ln for ln in (LEVELS / f"{name}.txt").read_text().splitlines()
            if not ln.startswith("meta:")]
    w = max(len(r) for r in rows)
    return [list(r.ljust(w, ".")) for r in rows]


def lint(name):
    g = load(name)
    h, w = len(g), len(g[0])

    def tile(x, y):
        if 0 <= x < w and 0 <= y < h:
            return g[y][x]
        return SOLID

    def passable(x, y):
        # Cell the body can occupy (feet cell + head cell above).
        return tile(x, y) != SOLID and tile(x, y - 1) != SOLID

    def standable(x, y):
        below = tile(x, y + 1)
        return passable(x, y) and below in (SOLID, "=", "B")

    # --- flood fill over stand cells --------------------------------------
    start = next((x, y) for y in range(h) for x in range(w)
                 if g[y][x] == "P")
    seen_stand = set()
    touched = set()          # every cell the body passes through
    frontier = [start]

    def touch(x, y):
        touched.add((x, y))
        touched.add((x, y - 1))  # head cell collects too

    while frontier:
        sx, sy = frontier.pop()
        if (sx, sy) in seen_stand or not passable(sx, sy):
            continue
        seen_stand.add((sx, sy))
        touch(sx, sy)
        # walk + jump: rise, drift across, optionally rise again (the late
        # double jump), then fall. Modelling the second rise matters: real
        # arcs are diagonal, and an up-then-across rectangle cannot thread
        # jumps that pass under an overhang before popping up onto it.
        for rise in range(RISE + 1):
            # ascend straight up first (collision-checked per cell)
            ok = True
            for dy in range(1, rise + 1):
                if not passable(sx, sy - dy):
                    ok = False
                    break
            if not ok:
                continue
            for second in range(0, RISE - rise + 1):
                drift_y = sy - rise
                apex_target = drift_y - second
                for ddir in (-1, 1):
                    for drift in range(REACH + 1):
                        # drift across at the first-jump height
                        ax, blocked = sx, False
                        for dx in range(1, drift + 1):
                            ax = sx + ddir * dx
                            if not passable(ax, drift_y):
                                blocked = True
                                break
                            touch(ax, drift_y)
                        if blocked:
                            continue
                        # late double jump straight up at the far column
                        ok2 = True
                        for yy in range(drift_y - 1, apex_target - 1, -1):
                            if not passable(ax, yy):
                                ok2 = False
                                break
                            touch(ax, yy)
                        if not ok2:
                            continue
                        apex_y = apex_target
                        # fall straight down until landing (one-way '='
                        # and 'B' tops land; hazards don't stop the fall)
                        fy = apex_y
                        while fy < h:
                            if standable(ax, fy):
                                if (ax, fy) not in seen_stand:
                                    frontier.append((ax, fy))
                                break
                            if not passable(ax, fy + 1):
                                break
                            touch(ax, fy + 1)
                            fy += 1

    # --- report ------------------------------------------------------------
    missed = []
    for y in range(h):
        for x in range(w):
            ch = g[y][x]
            if ch in TARGETS:
                near = {(x, y), (x, y - 1), (x, y + 1), (x - 1, y),
                        (x + 1, y)}
                if not (near & touched):
                    missed.append(f"{ch}@({x},{y})")
    return missed


def main():
    names = sys.argv[1:] or sorted(p.stem for p in LEVELS.glob("*.txt"))
    bad = False
    for n in names:
        missed = lint(n)
        status = "OK " if not missed else "FAIL"
        print(f"{status} {n}" + (f"  unreachable: {', '.join(missed)}"
                                 if missed else ""))
        bad |= bool(missed)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
