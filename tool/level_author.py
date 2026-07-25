#!/usr/bin/env python3
"""tool/level_author.py — author the campaign levels from a small layout DSL.

Hand-counting columns in a 110-wide ASCII grid is how levels end up with a
hazard under the thumb buttons and an enemy 1.4 s from spawn. This module
places every feature at an explicit tile coordinate instead, then renders the
grid that ships in assets/levels/.

Design rules baked in (from the Apple Knight comparison, docs/ak-parity-plan.md
and the 2026-07-25 playtest):
  * SAFE_RUNWAY tiles of nothing-can-hurt-you after the spawn — AK teaches on
    empty ground before it tests
  * three terrain tiers, so a screen has an over-route and an under-route
    instead of one corridor
  * campfire checkpoints ('K') roughly every third of the level
  * secret chests always behind a cracked wall

Run: python3 tool/level_author.py         (writes assets/levels/w1_*.txt)
"""
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "levels"
SAFE_RUNWAY = 12  # tiles from spawn with no hazard and no enemy


class Level:
    def __init__(self, width: int, height: int, meta: dict):
        self.w, self.h = width, height
        self.meta = meta
        self.g = [["." for _ in range(width)] for _ in range(height)]

    # --- terrain -----------------------------------------------------------
    def fill(self, x0: int, x1: int, y0: int, y1: int, ch: str = "#"):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if 0 <= x < self.w and 0 <= y < self.h:
                    self.g[y][x] = ch

    def ground(self, x0: int, x1: int, top: int):
        """Solid earth from row [top] to the bottom of the level."""
        self.fill(x0, x1, top, self.h - 1)

    def plat(self, x0: int, x1: int, y: int):
        """One-way platform run (jump up through, press down to drop)."""
        self.fill(x0, x1, y, y, "=")

    def ledge(self, x0: int, x1: int, y: int, depth: int = 2):
        """Solid ledge block (walk on top, blocks from the side)."""
        self.fill(x0, x1, y, min(self.h - 1, y + depth - 1))

    def spikes(self, x0: int, x1: int, y: int):
        self.fill(x0, x1, y, y, "^")

    def fire(self, x0: int, x1: int, y: int):
        self.fill(x0, x1, y, y, "~")

    def cracked(self, x0: int, x1: int, y0: int, y1: int):
        self.fill(x0, x1, y0, y1, "B")

    # --- entities ----------------------------------------------------------
    def put(self, x: int, y: int, ch: str):
        assert self.g[y][x] == ".", f"({x},{y}) already holds {self.g[y][x]!r}"
        self.g[y][x] = ch

    def row(self, y: int, pairs):
        for x, ch in pairs:
            self.put(x, y, ch)

    def arc(self, x0: int, y0: int, shape, ch: str = "c"):
        """Coins along a jump arc: shape is a list of (dx, dy)."""
        for dx, dy in shape:
            self.put(x0 + dx, y0 + dy, ch)

    # --- output ------------------------------------------------------------
    def render(self) -> str:
        lines = [f"meta: {k}={v}" for k, v in self.meta.items()]
        for row in self.g:
            lines.append("".join(row).rstrip() or ".")
        return "\n".join(lines) + "\n"

    def write(self, name: str):
        (OUT / f"{name}.txt").write_text(self.render())
        print(f"wrote {name}.txt  {self.w}x{self.h}")


# A shallow "hop arc" of coins, reused so coin trails read as jump invitations.
HOP = [(0, 0), (1, -1), (2, -2), (3, -2), (4, -1), (5, 0)]


def base(width, height, meta):
    """A level with bedrock under everything: pits are shallow spike traps you
    can jump out of, never the bottomless chain-death wells of alpha.4."""
    l = Level(width, height, meta)
    l.ground(0, width - 1, 16)
    return l


def pit(l: Level, x0: int, x1: int, kind: str = "^"):
    """Carve a 2-tile-deep hazard pit (floor is spikes/fire on the bedrock)."""
    l.fill(x0, x1, 16, 17, ".")
    l.fill(x0, x1, 17, 17, kind)


def sky_vault(l: Level, x0: int, x1: int, top: int, treasure: str = "X"):
    """A sealed pocket in the air: solid shell, cracked-wall doors on both
    sides, a floor you can stand on and loot inside."""
    bot = top + 2
    l.fill(x0, x1, top, bot, "#")
    l.fill(x0 + 1, x1 - 1, top + 1, top + 1, ".")
    l.fill(x0, x0, top + 1, top + 1, "B")
    l.fill(x1, x1, top + 1, top + 1, "B")
    l.put((x0 + x1) // 2, top + 1, treasure)


def strongroom(l: Level, x0: int, x1: int, treasure: str = "X",
               ground_top: int = 16):
    """A sealed room ON the path: walk up, break the cracked wall at body
    height, walk in. (The alpha.4 'secret' was an open pocket in the wall —
    nothing to find, nothing to break.)"""
    top, bot = ground_top - 2, ground_top - 1
    l.fill(x0, x1, top, bot, "#")
    l.fill(x0 + 1, x1 - 1, top, bot, ".")
    l.fill(x0, x0, top, bot, "B")
    l.fill(x1, x1, top, bot, "B")
    l.put((x0 + x1) // 2, bot, treasure)


# ---------------------------------------------------------------------------
# World 1 — Emberwood. Three tiers, teach-then-test pacing, two campfires.
# ---------------------------------------------------------------------------

def w1_l1():
    l = base(100, 20, {
        "name": "Forest Edge",
        "lore": "Where the deep wood begins, and the road home ends.",
        "world": 1,
        "music": "combat",
        "par_s": 120,
        "sign1": "Hold LEFT/RIGHT to run. Tap JUMP - tap again in the air to double-jump!",
        "sign2": "Light a campfire to save your progress. Fall here and you come back to it.",
        "sign3": "Tap SWORD to swing - three quick taps chain a combo.",
        "sign4": "Tap DASH to roll through danger. Hold DOWN to drop through thin platforms.",
    })
    # --- safe runway: nothing can hurt you for the first 12 tiles
    l.put(4, 15, "P")
    l.row(15, [(8, "s"), (11, "b"), (14, "m")])
    l.arc(9, 13, HOP)
    # --- a harmless step teaches the jump
    l.ledge(20, 26, 14, depth=2)
    l.row(13, [(22, "c"), (23, "c"), (24, "c")])
    # --- first campfire, before the first real threat
    l.put(30, 15, "K")
    l.put(32, 15, "s")
    # --- first hazard: 3-wide spike pit, coins arcing over it
    pit(l, 36, 38, "^")
    l.arc(34, 13, HOP)
    # --- first enemy on open ground with room to swing
    l.put(44, 15, "s")
    l.put(48, 15, "T")
    l.put(46, 15, "a")
    # --- upper route: platforms over the fire pit, feather as the payoff
    l.plat(52, 57, 11)
    l.plat(60, 65, 9)
    l.row(10, [(53, "c"), (55, "c"), (57, "c")])
    l.put(62, 8, "f")
    pit(l, 58, 60, "~")
    # --- mound with a chest on top, thornling patrolling below
    l.ledge(68, 76, 13, depth=3)
    l.put(71, 12, "C")
    l.put(78, 15, "T")
    # --- second campfire before the treasure stretch
    l.put(80, 15, "K")
    l.put(82, 15, "s")
    # --- two hidden vaults: one buried, one up in the canopy
    strongroom(l, 84, 88)
    sky_vault(l, 62, 66, 4)
    l.plat(56, 61, 6)
    l.put(92, 15, "C")
    l.put(96, 15, "E")
    l.row(15, [(90, "b"), (94, "t")])
    return l


def w1_l2():
    l = base(112, 20, {
        "name": "Old Orchard",
        "lore": "The trees still fruit. Something else still feeds.",
        "world": 1,
        "music": "combat",
        "par_s": 130,
        "sign1": "Hoppers leap at you - time your swing for the landing.",
        "sign2": "Coins over a pit are a dare, not a trap. Double-jump the arc.",
        "sign3": "Ashbats dive from the canopy. Duck under, then punish.",
        "hopper1": "46,15",
        "hopper2": "78,15",
    })
    l.put(4, 15, "P")
    l.row(15, [(9, "s"), (12, "b"), (16, "m"), (19, "t")])
    l.arc(10, 13, HOP)
    # canopy walk (upper route) over the whole first third
    l.plat(22, 28, 10)
    l.plat(32, 38, 8)
    l.plat(42, 47, 10)
    l.row(9, [(24, "c"), (26, "c"), (28, "c")])
    l.row(7, [(34, "c"), (36, "f")])
    # ground route under it
    l.ledge(24, 30, 14, depth=2)
    pit(l, 34, 37, "^")
    l.put(40, 15, "K")
    l.put(42, 15, "s")
    l.put(44, 15, "a")
    l.put(52, 15, "T")
    l.put(50, 13, "V")
    # orchard terrace: two stacked ledges, chest on the upper one
    l.ledge(56, 64, 13, depth=3)
    l.ledge(60, 68, 10, depth=2)
    l.put(62, 9, "C")
    l.arc(50, 12, HOP)
    pit(l, 70, 74, "~")
    l.plat(70, 74, 12)
    l.put(76, 15, "s")
    l.put(80, 15, "K")
    l.put(84, 13, "V")
    l.put(88, 15, "T")
    strongroom(l, 92, 96)
    sky_vault(l, 84, 88, 5)
    l.plat(78, 83, 7)
    l.plat(89, 93, 7)
    l.put(100, 15, "C")
    l.put(104, 15, "a")
    l.put(108, 15, "E")
    l.row(15, [(98, "r"), (106, "b")])
    return l


def w1_l3():
    l = base(118, 20, {
        "name": "Bramble Hollow",
        "lore": "The brambles grew over something that wanted hiding.",
        "world": 1, "music": "combat", "par_s": 140,
        "sign1": "Ember Totems spit fire on sight. Break the line - then close in.",
        "sign2": "The hollow runs deep. The high road is safer; the low road pays.",
        "sign3": "Cracked walls hide strongrooms. Swing at anything that looks weak.",
    })
    l.put(4, 15, "P")
    l.row(15, [(9, "s"), (13, "b"), (17, "m")])
    l.arc(10, 13, HOP)
    l.put(20, 15, "K")
    # the hollow: a wide sunken bowl with a spike floor and two ways across
    l.fill(26, 44, 16, 17, ".")
    # Spikes in short runs with bare floor between them: a fall into the
    # hollow costs a heart, not the run.
    l.spikes(29, 31, 17)
    l.spikes(35, 38, 17)
    l.spikes(42, 43, 17)
    l.plat(28, 32, 13)
    l.plat(35, 39, 11)
    l.plat(41, 45, 13)
    l.row(12, [(29, "c"), (31, "c")])
    l.row(10, [(36, "c"), (38, "f")])
    l.ledge(48, 54, 13, depth=3)
    l.put(50, 12, "O")
    l.put(46, 15, "s")
    l.put(58, 15, "T")
    l.put(56, 15, "a")
    l.put(60, 15, "K")
    # terraces climbing out of the hollow, totem covering the stairs
    l.ledge(64, 70, 14, depth=2)
    l.ledge(70, 76, 12, depth=4)
    l.ledge(76, 82, 10, depth=6)
    l.put(78, 9, "O")
    l.put(73, 11, "C")
    l.row(13, [(66, "c"), (68, "c")])
    pit(l, 86, 89, "^")
    l.plat(85, 90, 12)
    l.put(92, 15, "s")
    l.put(94, 13, "V")
    strongroom(l, 96, 100)
    sky_vault(l, 104, 108, 6)
    l.plat(99, 103, 8)
    l.plat(109, 113, 8)
    l.put(106, 15, "C")
    l.put(110, 15, "T")
    l.put(114, 15, "E")
    l.row(15, [(112, "r")])
    return l


def w1_l4():
    l = base(118, 20, {
        "name": "Charcoal Camp",
        "lore": "They burned the wood to keep the wood away.",
        "world": 1, "music": "combat", "par_s": 140,
        "sign1": "Rotshields block from the front. Roll past, or bait the guard-turn.",
        "sign2": "Kiln heat below. Take the mounds.",
        "sign3": "Three medals: finish it, open every chest, and don't get hit.",
    })
    l.put(4, 15, "P")
    l.row(15, [(9, "s"), (12, "m"), (15, "b")])
    l.arc(10, 13, HOP)
    l.put(19, 15, "K")
    l.ledge(24, 30, 14, depth=2)
    l.put(27, 13, "R")
    l.row(13, [(24, "c"), (25, "c")])
    pit(l, 34, 37, "~")
    l.plat(33, 38, 12)
    l.put(40, 15, "s")
    l.put(43, 15, "a")
    # kiln stack: three mounds at rising heights, chest at the top
    l.ledge(46, 51, 14, depth=2)
    l.ledge(53, 58, 12, depth=4)
    l.ledge(60, 65, 10, depth=6)
    l.put(62, 9, "C")
    l.put(55, 11, "R")
    l.row(13, [(47, "c"), (49, "c")])
    l.row(9, [(64, "f")])
    l.put(68, 15, "K")
    l.put(70, 15, "s")
    pit(l, 74, 78, "~")
    l.plat(73, 77, 11)
    l.plat(79, 83, 13)
    l.put(86, 15, "T")
    l.put(84, 12, "V")
    strongroom(l, 90, 94)
    sky_vault(l, 98, 102, 5)
    l.plat(93, 97, 7)
    l.plat(103, 107, 7)
    l.put(100, 15, "C")
    l.put(104, 15, "R")
    l.put(108, 15, "a")
    l.put(114, 15, "E")
    l.row(15, [(110, "t"), (112, "b")])
    return l


def w1_l5():
    l = base(128, 20, {
        "name": "Rootway Ruins",
        "lore": "Roots hold the old stones together now.",
        "world": 1, "music": "combat", "par_s": 160,
        "sign1": "The colonnade splits: over the top, or through the sunken court.",
        "sign2": "Everything in the wood is here. Keep moving, keep swinging.",
        "sign3": "The last door is close. Spend your dash, not your hearts.",
        "hopper1": "58,15",
        "hopper2": "96,15",
    })
    l.put(4, 15, "P")
    l.row(15, [(9, "s"), (13, "b"), (16, "m"), (20, "t")])
    l.arc(10, 13, HOP)
    l.put(24, 15, "K")
    # colonnade: pillars with a walkable roof (upper route) and a shaded floor
    for x in range(30, 62, 8):
        l.ledge(x, x + 2, 14, depth=2)   # pillar bases: step-ups, not walls
        l.ledge(x, x + 2, 9, depth=2)    # capitals, held up by the pillars
    l.plat(31, 35, 12)
    l.plat(43, 47, 12)
    l.plat(55, 59, 12)
    l.plat(30, 62, 7)
    l.row(6, [(34, "c"), (42, "c"), (50, "c"), (58, "f")])
    l.put(36, 15, "T")
    l.put(44, 15, "O")
    l.put(52, 13, "V")
    l.put(41, 15, "a")
    l.put(66, 15, "K")
    l.put(64, 15, "s")
    # sunken court: drop in for the chest, climb the terrace back out
    l.fill(70, 84, 16, 17, ".")
    l.spikes(76, 79, 17)  # one 4-wide run, bare floor either side
    l.put(72, 17, "C")
    l.plat(70, 74, 13)
    l.plat(80, 84, 13)
    l.row(12, [(71, "c"), (73, "c"), (81, "c")])
    l.put(88, 15, "R")
    l.put(86, 15, "s")
    l.ledge(92, 98, 13, depth=3)
    l.put(94, 12, "O")
    pit(l, 98, 101, "^")
    l.plat(97, 102, 11)
    strongroom(l, 105, 109)
    sky_vault(l, 114, 118, 6)
    l.plat(110, 114, 8)
    l.plat(118, 122, 8)
    l.put(112, 15, "C")
    l.put(120, 15, "T")
    l.put(126, 15, "E")
    l.row(15, [(123, "r")])
    return l


def w1_boss():
    l = base(52, 20, {
        "name": "Grove Golem",
        "lore": "The grove grew a warden. It does not want visitors.",
        "world": 1, "music": "boss_combat", "par_s": 150,
        "sign1": "The Grove Golem guards the door. Watch its wind-up - then strike!",
    })
    l.put(3, 15, "P")
    l.put(7, 15, "s")
    l.put(10, 15, "K")
    l.put(13, 15, "a")
    # arena with two safe ledges: the alpha arena was a flat box with nowhere
    # to break line of sight, so the slam was unavoidable.
    l.ledge(18, 22, 12, depth=2)
    l.ledge(30, 34, 12, depth=2)
    l.plat(24, 28, 9)
    l.put(26, 15, "G")
    l.put(20, 11, "a")
    l.put(32, 11, "a")
    l.put(40, 15, "a")
    l.put(48, 15, "E")
    l.row(15, [(44, "b"), (46, "t")])
    return l


def w2_boss():
    l = base(56, 20, {
        "name": "Kiln Golem",
        "lore": "Fired in the first kiln, it guards the last door.",
        "world": 2, "env": "cave", "music": "boss_combat", "par_s": 150,
        "sign1": "The Kiln Golem bars the deep door. Bait its slam - then burn it down!",
    })
    l.put(3, 15, "P")
    l.put(7, 15, "s")
    l.put(10, 15, "K")
    l.put(13, 15, "a")
    # A different fight from the Grove arena: fire channels split the floor
    # into three islands, so the Kiln Golem has to be fought in stages.
    pit(l, 20, 22, "~")
    pit(l, 34, 36, "~")
    l.ledge(24, 26, 13, depth=3)
    l.ledge(30, 32, 13, depth=3)
    l.plat(19, 23, 10)
    l.plat(33, 37, 10)
    l.fill(0, 55, 2, 2, "#")
    l.put(28, 15, "G")
    l.put(25, 12, "a")
    l.put(31, 12, "a")
    l.put(42, 15, "a")
    l.put(52, 15, "E")
    l.row(15, [(46, "r"), (49, "r")])
    return l


ALL = {
    "w1_l1": w1_l1, "w1_l2": w1_l2, "w1_l3": w1_l3, "w1_l4": w1_l4,
    "w1_l5": w1_l5, "w1_boss": w1_boss, "w2_boss": w2_boss,
}

if __name__ == "__main__":
    for name, fn in ALL.items():
        fn().write(name)
