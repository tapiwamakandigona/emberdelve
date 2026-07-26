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
    sides, a floor you can stand on and loot inside. The interior and the
    doors are 2 tiles tall — the body is ~20px, taller than one 16px tile,
    so a 1-tall vault can never be entered (alpha.5 shipped that bug: every
    sky-vault secret was uncollectable). Approach platforms belong at row
    top+3, level with the vault floor."""
    bot = top + 3
    l.fill(x0, x1, top, bot, "#")
    l.fill(x0 + 1, x1 - 1, top + 1, top + 2, ".")
    l.fill(x0, x0, top + 1, top + 2, "B")
    l.fill(x1, x1, top + 1, top + 2, "B")
    l.put((x0 + x1) // 2, top + 2, treasure)


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
    l.plat(52, 56, 12)
    l.plat(58, 62, 9)
    l.row(11, [(53, "c"), (55, "c")])
    l.put(59, 8, "f")
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
    l.plat(56, 61, 7)
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
    l.plat(78, 83, 8)
    l.plat(89, 93, 8)
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
    l.plat(90, 94, 11)
    sky_vault(l, 104, 108, 6)
    l.plat(99, 103, 9)
    l.plat(109, 113, 9)
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
    l.plat(86, 89, 11)
    sky_vault(l, 98, 102, 5)
    l.plat(93, 97, 8)
    l.plat(103, 107, 8)
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
    l.plat(105, 108, 11)
    sky_vault(l, 114, 118, 6)
    l.plat(110, 114, 9)
    l.plat(118, 122, 9)
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


# ---------------------------------------------------------------------------
# World 2 — Cinder Depths. Same design rules as World 1, plus a cave read:
# solid ceiling + stalactite drips, magma instead of brambles, galleries
# instead of canopy. Rosters and introduction order preserved from alpha.5
# (creepers everywhere, divers from l2, wisps/hounds mid-world).
# ---------------------------------------------------------------------------

def cave(l: Level, drips=()):
    """Cave dressing: a solid ceiling with hanging stalactites. Drips are
    (x, depth) pairs kept >= 4 rows above any standing surface so they never
    enter play space."""
    l.fill(0, l.w - 1, 0, 0)
    for x, depth in drips:
        l.fill(x, x, 1, depth)


def w2_l1():
    """Ashen Gate — the sealed way down. A surface shelf, the great gate
    (its hollow gatehouse still sealed), then terraces stepping into the
    dark. Teaches the Soot Creeper on terrain where walking off an edge is
    the whole point."""
    l = base(110, 20, {
        "name": "Ashen Gate",
        "lore": "Ash falls like snow here. It has never stopped.",
        "world": 2, "env": "cave", "music": "cave_combat", "par_s": 110,
        "sign1": "Soot Creepers never stop at ledges. Roll (DOWN+JUMP) through danger!",
        "sign2": "The old gate is sealed... but ash has cracked the stonework.",
    })
    cave(l, drips=((8, 2), (57, 3), (78, 2), (101, 2)))
    # --- surface shelf: raised entry terrace, safe runway
    l.fill(0, 26, 12, 19)
    l.put(4, 11, "P")
    l.row(11, [(8, "s"), (12, "r")])
    l.arc(9, 9, HOP)
    l.put(16, 11, "K")
    # --- the Ashen Gate: pillar stubs hang over the road (head-clear), and
    # the lintel is a hollow gatehouse — sealed doors, loot inside
    l.fill(20, 26, 2, 5)          # the gatehouse block over the road
    l.fill(21, 25, 3, 4, ".")     # hollow heart
    l.cracked(20, 20, 3, 4)       # sealed west door
    l.cracked(26, 26, 3, 4)       # sealed east door
    l.put(23, 4, "X")
    l.row(4, [(22, "c"), (24, "c")])
    l.fill(20, 20, 6, 8)          # pillar stubs end 2 rows above the head
    l.fill(26, 26, 6, 8)
    l.plat(9, 12, 9)              # step one of the climb
    l.plat(14, 18, 5)             # step two, level with the gate floor
    l.row(4, [(15, "c"), (17, "c")])
    l.put(24, 11, "s")
    # --- terraces stepping down into the depths
    l.fill(27, 42, 14, 19)
    l.fill(43, 58, 16, 19)  # meets the base ground level
    l.put(34, 13, "S")      # creeper walks off the terrace lip: the lesson
    l.row(13, [(29, "c"), (31, "c")])
    l.arc(40, 12, HOP)
    # --- ash basin: shallow spike pit under a platform route
    pit(l, 47, 49, "^")
    l.plat(46, 50, 13)
    l.row(12, [(47, "c"), (49, "c")])
    # --- lower hall: campfire, then patrols with room to fight
    l.put(60, 15, "K")
    l.put(62, 15, "r")
    l.put(66, 15, "S")
    l.ledge(70, 74, 13, depth=3)
    l.put(72, 12, "C")
    l.put(76, 15, "m")
    l.put(80, 15, "a")
    l.put(84, 15, "S")
    # --- feather perch over the ember seep
    pit(l, 88, 89, "~")
    l.plat(86, 91, 12)
    l.put(88, 11, "f")
    # --- buried strongroom + the way out
    l.put(95, 15, "K")
    strongroom(l, 98, 102)
    l.put(104, 15, "C")
    l.put(106, 15, "m")
    l.put(107, 15, "E")
    return l


def w2_l2():
    """Ember Vault — one grand breakable treasury. The approach hall earns
    the entrance; the vault is a sealed chamber (cracked doors at body
    height in both walls) with the gold inside, Cinder Divers hanging over
    it, and a reliquary behind a second seal."""
    l = base(120, 20, {
        "name": "Ember Vault",
        "lore": "They sealed their gold below. The heat kept it safe.",
        "world": 2, "env": "cave", "music": "cave_combat", "par_s": 120,
        "sign1": "Cinder Divers strike from above - watch for the shudder.",
        "sign2": "Slag Hounds charge on sight. Jump the rush - never trade.",
    })
    cave(l, drips=((12, 2), (30, 3), (52, 2), (72, 2), (96, 3), (112, 2)))
    # --- approach hall
    l.put(4, 15, "P")
    l.row(15, [(8, "s"), (12, "r"), (15, "m")])
    l.arc(9, 13, HOP)
    l.put(19, 15, "K")
    l.put(24, 15, "S")
    l.ledge(28, 33, 13, depth=3)
    l.row(12, [(29, "c"), (31, "c")])
    sky_vault(l, 36, 40, 6)
    l.plat(30, 35, 9)
    l.put(42, 15, "s")
    l.put(46, 15, "H")   # the hound guards the hall: long flat charge lane
    # --- fire moat before the vault door
    l.put(52, 15, "K")
    pit(l, 56, 58, "~")
    l.plat(55, 59, 12)
    l.row(11, [(56, "c"), (58, "c")])
    # --- THE VAULT: sealed shell, cracked doors at body height either side
    l.fill(62, 92, 5, 5)          # roof
    l.fill(62, 62, 6, 15)         # west wall...
    l.cracked(62, 62, 14, 15)     # ...with a breakable door
    l.fill(92, 92, 6, 15)         # east wall, same
    l.cracked(92, 92, 14, 15)
    l.row(15, [(66, "c"), (68, "c"), (70, "c"), (84, "c"), (86, "c")])
    l.put(72, 15, "C")
    l.ledge(76, 78, 13, depth=3)
    l.put(77, 12, "C")
    l.put(67, 9, "D")             # a guard hangs over each coin bed
    l.put(87, 9, "D")
    strongroom(l, 80, 83)         # the reliquary: best gold, second seal
    # --- past the vault: high gallery to the feather, last patrols
    l.put(96, 15, "K")
    l.put(100, 15, "S")
    l.plat(99, 103, 12)
    l.plat(105, 110, 8)
    l.put(108, 7, "f")
    l.put(103, 9, "D")
    l.row(15, [(105, "r"), (112, "m")])
    l.put(110, 15, "a")
    l.put(116, 15, "E")
    return l


def w2_l3():
    """Soot Falls — a tall cavern of black cascades. Basins step down like
    a falls system, coin trickles mark every drop line, and the curtain of
    cracked stone at the base of the big cascade hides the fallers' room."""
    l = base(121, 20, {
        "name": "Soot Falls",
        "lore": "Even the waterfalls burn black in the deep dark.",
        "world": 2, "env": "cave", "music": "cave_combat", "par_s": 130,
        "sign1": "The falls hide more than soot...",
        "sign2": "Ashbats nest above the spray. Duck the dive, then punish.",
    })
    cave(l, drips=((10, 2), (36, 3), (60, 2), (82, 3), (104, 2)))
    # --- headwater shelf
    l.fill(0, 24, 11, 19)
    l.put(4, 10, "P")
    l.row(10, [(8, "s"), (12, "r")])
    l.arc(9, 8, HOP)
    l.put(17, 10, "K")
    l.put(20, 10, "m")
    # --- first fall: drop to basin 1; the trickle marks the drop line
    l.fill(25, 52, 14, 19)
    for y in (11, 12, 13):
        l.put(25, y, "c")
    l.put(30, 13, "S")
    l.ledge(34, 38, 12, depth=2)
    l.put(36, 11, "C")
    l.put(42, 13, "a")
    l.put(46, 8, "V")   # the ashbat nests over basin 1
    l.arc(46, 12, HOP)
    # --- second fall: drop to the cavern floor; the soot pool burns
    for y in (14, 15):
        l.put(53, y, "c")
    pit(l, 56, 57, "~")
    l.plat(54, 58, 13)
    l.put(61, 15, "K")
    l.put(64, 15, "s")
    # --- the big cascade: hanging platforms step up to the feather...
    l.plat(70, 73, 12)
    l.plat(75, 78, 9)
    l.plat(80, 83, 6)
    l.put(81, 5, "f")
    l.row(11, [(71, "c"), (72, "c")])
    l.row(8, [(76, "c"), (77, "c")])
    # ...and the curtain at its base hides the fallers' room (low shell so
    # anyone can hop back out; the seal faces the falls)
    l.fill(86, 92, 13, 15)
    l.fill(87, 91, 14, 15, ".")
    l.cracked(86, 86, 14, 15)
    l.put(89, 15, "X")
    l.row(15, [(88, "c"), (90, "c")])
    l.put(94, 9, "D")
    # --- lowest hall: the spike pool, hound territory
    pit(l, 98, 100, "^")
    l.plat(97, 101, 12)
    l.put(104, 15, "K")
    l.put(108, 15, "H")
    strongroom(l, 111, 115)
    l.row(15, [(103, "m"), (106, "r")])
    l.put(114, 9, "D")
    l.put(117, 15, "C")
    l.put(119, 15, "E")
    return l


def w2_l4():
    """Magma Gallery — miners carved galleries; the magma carved back. Two
    stacked routes: the lower hall broken by magma channels and totem
    sightlines, and an upper gallery running on pillar capitals."""
    l = base(131, 20, {
        "name": "Magma Gallery",
        "lore": "Miners carved galleries. The magma carved back.",
        "world": 2, "env": "cave", "music": "cave_combat", "par_s": 140,
        "sign1": "Totems spit farther in the dark. Keep moving.",
        "sign2": "The galleries run in tiers. Magma owns the floor - miners took the high road.",
    })
    cave(l, drips=((14, 2), (40, 2), (66, 3), (88, 2), (116, 2)))
    # --- mine mouth
    l.put(4, 15, "P")
    l.row(15, [(8, "s"), (11, "r"), (14, "m")])
    l.arc(9, 13, HOP)
    l.put(18, 15, "K")
    l.put(24, 15, "S")
    sky_vault(l, 28, 32, 5)
    l.plat(22, 27, 8)
    # --- the galleries: a colonnade carries the upper walkway
    for x in range(34, 90, 12):
        l.ledge(x, x + 2, 14, depth=2)   # pillar bases
        l.ledge(x, x + 2, 9, depth=2)    # capitals
    l.plat(34, 90, 7)                    # the upper gallery run
    l.row(6, [(38, "c"), (50, "c"), (62, "c"), (74, "c")])
    l.put(44, 9, "D")
    l.put(56, 6, "W")    # the wisp hunts the upper gallery
    l.put(86, 6, "f")
    # lower hall under the gallery: magma channels + totem sightlines
    l.row(15, [(39, "c"), (40, "c")])
    pit(l, 42, 43, "~")
    l.plat(41, 44, 12)
    l.put(50, 15, "O")
    l.put(62, 15, "K")
    pit(l, 65, 66, "~")
    l.plat(64, 68, 12)
    l.put(74, 15, "S")
    l.ledge(78, 82, 13, depth=3)
    l.put(80, 12, "C")
    l.put(86, 15, "s")
    # --- gallery end: the second totem holds the exit hall from a plinth
    l.ledge(94, 98, 13, depth=3)
    l.put(96, 12, "O")
    pit(l, 102, 104, "~")
    l.plat(101, 105, 12)
    l.row(11, [(102, "c"), (104, "c")])
    l.put(108, 15, "K")
    l.put(112, 15, "a")
    strongroom(l, 115, 119)
    l.put(122, 15, "C")
    l.row(15, [(110, "r"), (124, "m")])
    l.put(127, 15, "E")
    return l


def w2_l5():
    """Kiln Works — work floors ramp up to the great kiln, then back down
    to the boss door. The whole world's roster clocks in for a last shift;
    the kiln burns at the heart of the level."""
    l = base(134, 20, {
        "name": "Kiln Works",
        "lore": "The great kiln still turns. Something feeds it.",
        "world": 2, "env": "cave", "music": "cave_combat", "par_s": 150,
        "sign1": "The Kiln Golem stirs beyond these works.",
        "sign2": "Work floors ramp to the kiln. Everything down here feeds it - don't join them.",
    })
    cave(l, drips=((12, 2), (38, 2), (58, 3), (86, 2), (110, 2)))
    # --- clock-in floor
    l.put(4, 15, "P")
    l.row(15, [(8, "s"), (12, "r")])
    l.arc(9, 13, HOP)
    l.put(17, 15, "K")
    l.put(23, 15, "S")
    # --- work floor 1 (+2): the hound runs the flat
    l.fill(28, 52, 14, 19)
    l.put(36, 13, "H")
    l.row(13, [(31, "c"), (33, "c")])
    l.ledge(44, 48, 12, depth=2)
    l.put(46, 11, "C")
    # --- work floor 2 (+4): the wisp drifts between the rafters
    l.fill(53, 78, 12, 19)
    l.put(58, 11, "K")
    l.put(64, 11, "S")
    l.put(60, 6, "W")
    l.arc(68, 10, HOP)
    sky_vault(l, 70, 74, 4)
    l.plat(58, 62, 10)
    l.plat(64, 69, 7)
    # --- the great kiln: a dome with fire in its throat, feather above it
    l.fill(79, 81, 12, 19)   # floor 2 runs level into the kiln flank
    l.fill(82, 96, 10, 19)
    l.fill(86, 92, 8, 9)
    l.fill(88, 90, 8, 9, ".")
    l.fill(88, 90, 9, 9, "~")
    l.put(89, 6, "f")
    l.put(84, 9, "D")
    l.row(7, [(87, "c"), (91, "c")])
    l.put(94, 9, "O")
    # --- down the out-ramp to the boss door: the last guards
    l.fill(97, 108, 13, 19)
    l.put(100, 10, "D")
    l.row(12, [(104, "a"), (106, "a")])
    l.put(112, 15, "K")
    strongroom(l, 116, 120)
    l.put(124, 15, "R")   # the door warden
    l.put(127, 15, "C")
    l.row(15, [(122, "m"), (129, "r")])
    l.put(131, 15, "E")
    return l


def w2_boss():
    l = base(56, 20, {
        "name": "Kiln Golem",
        "lore": "Fired in the first kiln, it guards the last door.",
        "world": 2, "env": "cave", "music": "boss_combat", "par_s": 150,
        "sign1": "The Kiln Golem bars the deep door. Fire lingers where its embers fall - and vents erupt in waves. Keep moving!",
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
    l.put(28, 15, "M")
    l.put(25, 12, "a")
    l.put(31, 12, "a")
    l.put(42, 15, "a")
    l.put(52, 15, "E")
    l.row(15, [(46, "r"), (49, "r")])
    return l


ALL = {
    "w1_l1": w1_l1, "w1_l2": w1_l2, "w1_l3": w1_l3, "w1_l4": w1_l4,
    "w1_l5": w1_l5, "w1_boss": w1_boss,
    "w2_l1": w2_l1, "w2_l2": w2_l2, "w2_l3": w2_l3, "w2_l4": w2_l4,
    "w2_l5": w2_l5, "w2_boss": w2_boss,
}

if __name__ == "__main__":
    for name, fn in ALL.items():
        fn().write(name)
