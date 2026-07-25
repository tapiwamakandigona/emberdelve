#!/usr/bin/env python3
"""tool/build_w2_levels.py — compose the World 2 'Cinder Depths' campaign
levels from hand-authored segments (deterministic per-level seeds).

Grid: 16 rows. Walkway on row 11, floor fill rows 12-14, bedrock row 15.
Cave ceiling: row 0 solid + hanging stalactites (rows 1-2) that never reach
jump height of the ground route. Segments keep every gap <= 4 columns and
always leave a landing within 2 tiles of the lip (runner-bot friendly).

Run: python3 tool/build_w2_levels.py   (idempotent, writes assets/levels/w2_l*.txt)
"""
import random
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "levels"
H = 16
WALK = 11  # row index of the walkway (entities stand here)


def blank_cols(n):
    return [['.'] * H for _ in range(n)]


def ground(cols, lo=12, hi=14):
    for c in cols:
        for y in range(lo, 15):
            c[y] = '#'
        c[15] = '#'
    return cols


def seg_flat(n, deco=''):
    cols = ground(blank_cols(n))
    for i, ch in enumerate(deco):
        if ch != '.':
            cols[i][WALK] = ch
    return cols


def seg_pit(width, hazard='^', coin=True):
    """Gap in the floor with a hazard bed; coins hang at jump-arc height."""
    n = width + 4
    cols = ground(blank_cols(n))
    for i in range(2, 2 + width):
        c = cols[i]
        for y in range(12, 15):
            c[y] = '.'
        c[13] = '#'  # hazard bed
        c[14] = '#'
        c[12] = hazard
    if coin:
        mid = 2 + width // 2
        cols[mid][9] = 'c'
    return cols


def seg_ledge(n=10, enemy='S'):
    """Raised ledge with a platform step up and loot on top."""
    cols = ground(blank_cols(n))
    # step platform
    for i in (2, 3):
        cols[i][9] = '='
    # ledge block
    for i in range(5, n - 1):
        for y in range(9, 12):
            cols[i][y] = '#'
        cols[i][8] = '.'
    cols[6][8] = 'c'
    cols[7][8] = enemy if enemy else 'c'
    return cols


def seg_vault(n=9, feather=False):
    """Secret vault: cracked walls flank a secret chest at walkway level."""
    cols = ground(blank_cols(n))
    cols[3][WALK] = 'B'
    cols[4][WALK] = 'X'
    cols[5][WALK] = 'B'
    # roof over the vault so it reads as a chamber
    for i in (2, 3, 4, 5, 6):
        cols[i][WALK - 2] = '#'
    if feather:
        cols[4][WALK - 1] = 'f'
    return cols


def seg_sky_route(n=12):
    """Optional overhead platform chain with coins (double-jump payoff)."""
    cols = ground(blank_cols(n))
    for i in (2, 3, 4):
        cols[i][7] = '='
    for i in (7, 8, 9):
        cols[i][5] = '='
    cols[3][6] = 'c'
    cols[8][4] = 'c'
    cols[9][4] = 'c'
    return cols


def seg_diver_hall(n=12):
    """Open hall with a Cinder Diver hovering high over the route."""
    cols = ground(blank_cols(n))
    cols[n // 2][4] = 'D'
    cols[n // 2 - 2][WALK] = 'c'
    cols[n // 2 + 2][WALK] = 'c'
    return cols


def seg_chest(n=7, guarded='T'):
    cols = ground(blank_cols(n))
    cols[3][WALK] = 'C'
    if guarded:
        cols[5][WALK] = guarded
    return cols


def assemble(name, env_meta, segs, rng):
    cols = []
    for s in segs:
        cols += s
    # player start + exit door
    cols[2][WALK] = 'P'
    cols[-3][WALK] = 'E'
    # cave ceiling: row 0 solid, stalactites rows 1-2
    for i, c in enumerate(cols):
        c[0] = '#'
        if rng.random() < 0.18 and c[1] == '.':
            c[1] = '#'
            if rng.random() < 0.4 and c[2] == '.':
                c[2] = '#'
    # sparse cave decor on free walkway tiles (rocks/shrooms only)
    free = [i for i, c in enumerate(cols)
            if c[WALK] == '.' and c[WALK + 1] == '#']
    rng.shuffle(free)
    placed = 0
    last = -9
    for i in sorted(free):
        if i - last < 9:
            continue
        cols[i][WALK] = rng.choice('rrm')
        last = i
        placed += 1
        if placed >= 7:
            break
    rows = [''.join(cols[x][y] for x in range(len(cols))) for y in range(H)]
    return env_meta + [r.rstrip('.') or '.' for r in rows]


LEVELS = {
    'w2_l1': dict(
        title='Ashen Gate', par=110, seed=21,
        sign='Soot Creepers never stop at ledges. Roll (DOWN+JUMP) through danger!',
        segs=lambda: [
            seg_flat(8), seg_flat(8, '....s...'), seg_chest(8, guarded='S'),
            seg_pit(3, '~'), seg_flat(6), seg_sky_route(12), seg_vault(9),
            seg_flat(5, '..a..'), seg_pit(3, '~'), seg_ledge(10, enemy='S'),
            seg_vault(9, feather=True), seg_flat(6, '..c.c.'), seg_chest(7, 'S'),
            seg_flat(8),
        ]),
    'w2_l2': dict(
        title='Ember Vault', par=120, seed=22,
        sign='Cinder Divers strike from above - watch for the shudder.',
        segs=lambda: [
            seg_flat(8), seg_flat(6, '...s..'), seg_diver_hall(12),
            seg_pit(4, '^'), seg_vault(9, feather=True), seg_ledge(10, 'S'),
            seg_diver_hall(12), seg_chest(7, 'T'), seg_sky_route(12),
            seg_pit(3, '~'), seg_vault(9), seg_flat(5, '..a..'),
            seg_chest(7, 'S'), seg_flat(8),
        ]),
    'w2_l3': dict(
        title='Soot Falls', par=130, seed=23,
        sign='The falls hide more than soot...',
        segs=lambda: [
            seg_flat(8), seg_pit(3, '^'), seg_diver_hall(12), seg_vault(9),
            seg_ledge(10, 'S'), seg_pit(4, '^'), seg_sky_route(12),
            seg_chest(7, 'V'), seg_flat(5, '..a..'), seg_diver_hall(12),
            seg_vault(9, feather=True), seg_pit(3, '~'), seg_chest(7, 'S'),
            seg_flat(8),
        ]),
    'w2_l4': dict(
        title='Magma Gallery', par=140, seed=24,
        sign='Totems spit farther in the dark. Keep moving.',
        segs=lambda: [
            seg_flat(8), seg_flat(6, '...s..'), seg_chest(8, 'O'),
            seg_pit(4, '~'), seg_diver_hall(12), seg_vault(9, feather=True),
            seg_ledge(10, 'S'), seg_pit(4, '~'), seg_sky_route(12),
            seg_chest(7, 'O'), seg_diver_hall(12), seg_vault(9),
            seg_pit(3, '^'), seg_chest(7, 'S'), seg_flat(8),
        ]),
    'w2_l5': dict(
        title='Kiln Works', par=150, seed=25,
        sign='The Kiln Golem stirs beyond these works.',
        segs=lambda: [
            seg_flat(8), seg_pit(3, '~'), seg_chest(7, 'R'),
            seg_diver_hall(12), seg_vault(9), seg_ledge(10, 'S'),
            seg_pit(4, '^'), seg_sky_route(12), seg_chest(7, 'O'),
            seg_diver_hall(12), seg_pit(4, '~'), seg_vault(9, feather=True),
            seg_ledge(10, 'S'), seg_chest(7, 'V'), seg_flat(8),
        ]),
}


def main():
    for lid, spec in LEVELS.items():
        rng = random.Random(spec['seed'])
        meta = [
            f"meta: name={spec['title']}",
            'meta: world=2',
            'meta: env=cave',
            'meta: music=combat',
            f"meta: par_s={spec['par']}",
            f"meta: sign1={spec['sign']}",
        ]
        lines = assemble(lid, meta, spec['segs'](), rng)
        (OUT / f'{lid}.txt').write_text('\n'.join(lines) + '\n')
        print(f'{lid}.txt  ({len(lines[-1])} cols)')
    print('done.')


if __name__ == '__main__':
    main()
