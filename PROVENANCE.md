# Emberdelve Asset Provenance

> **Pivot note (2026-07-24):** the dice-era **image** entries below are historical — those files were removed in the platformer pivot (archived on `legacy/dice-builder`). **Audio and font entries remain shipped.** New platformer art entries are added as assets land.


Per-file origin, author, license, and modification record for every bundled
art and audio asset. Summarized attributions live in `CREDITS.md` and the
in-app Credits & Licenses screen; this file is the full audit trail.
(Staging paths mentioned below refer to the curation workspace where assets
were prepared; the files now live under `assets/`.)

---

# Emberdelve Art Provenance

Every file under `staging/art/`. Download/creation date for all entries: **2026-07-23**.
Only CC0 / CC-BY licensed sources were used; the repo is public and all assets are redistributable.

**Source packs:**
1. **0x72 DungeonTilesetII v1.7** by 0x72 — https://0x72.itch.io/dungeontileset-ii — license stated on page: "CC-0" / Creative Commons Zero v1.0 Universal. Individual pre-sliced frames obtained from public mirror: https://github.com/marceloferreira357/bun-crawler-client/tree/main/public/sprites/0x72_DungeonTilesetII_v1.7
2. **game-icons.net** icon collection — https://github.com/game-icons/icons — license.txt: "Icons provided under the Creative Commons 3.0 BY". Authors used: Lorc, Delapouite, Skoll.
3. **Original procedural work** created for this project by script (no AI image generation) — dedicated CC0.

| File | Source / pack | Author | Source URL | License | Date | Modifications |
|---|---|---|---|---|---|---|
| enemies/cinder_wisp.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `imp` assembled into a sheet (idle(4f), run(4f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| enemies/ash_rat.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `tiny_zombie` assembled into a sheet (idle(4f), run(4f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| enemies/soot_shade.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `zombie` assembled into a sheet (idle(3f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| enemies/ember_beetle.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `tiny_slug` assembled into a sheet (idle(4f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| enemies/soot_hound.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `chort` assembled into a sheet (idle(4f), run(4f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| enemies/ash_wraith.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `necromancer` assembled into a sheet (idle(4f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| enemies/cinder_crawler.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `swampy` assembled into a sheet (idle(4f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| enemies/ember_moth.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `angel` assembled into a sheet (idle(4f), run(4f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| enemies/slag_brute.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `orc_warrior` assembled into a sheet (idle(4f), run(4f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| enemies/pyre_howler.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `wogol` assembled into a sheet (idle(4f), run(4f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| enemies/kiln_golem.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `big_zombie` assembled into a sheet (idle(4f), run(4f); one state per row, 4 cols), nearest-neighbor upscale x2. |
| enemies/ash_reaper.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `skelet` assembled into a sheet (idle(4f), run(4f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| enemies/forge_warden.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `masked_orc` assembled into a sheet (idle(4f), run(4f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| enemies/molten_maw.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `big_demon` assembled into a sheet (idle(4f), run(4f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| enemies/ember_tyrant.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `ogre` assembled into a sheet (idle(4f), run(4f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| characters/kindler.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `wizzard_m` assembled into a sheet (idle(4f), run(4f), hit(1f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| characters/warden.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `knight_m` assembled into a sheet (idle(4f), run(4f), hit(1f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| characters/gambler.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `elf_m` assembled into a sheet (idle(4f), run(4f), hit(1f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| characters/ascetic.png | 0x72 DungeonTilesetII v1.7 | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Recolored to ember/ash palette (custom HSV remap script build_sprites.py); frames from base sprite `doc` assembled into a sheet (idle(4f), run(4f); one state per row, 4 cols), nearest-neighbor upscale x3. |
| ui/coin_anim.png | 0x72 DungeonTilesetII v1.7 (coin_anim) | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | 4-frame coin animation assembled into horizontal strip, nearest-neighbor x3. No recolor. |
| ui/currency/currency_coin.png | 0x72 DungeonTilesetII v1.7 (coin_anim_f0) | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Single frame, nearest-neighbor upscale x18. No recolor. |
| ui/ember_flow_anim.png | 0x72 DungeonTilesetII v1.7 (wall_fountain_mid_red_anim) | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | 3-frame lava-flow animation, recolored to ember palette, strip, x3. |
| ui/ember_pool_anim.png | 0x72 DungeonTilesetII v1.7 (wall_fountain_basin_red_anim) | 0x72 | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 Universal (Creative Commons Zero) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | 3-frame lava-pool animation, recolored to ember palette, strip, x3. |
| ui/dice/die_d4.png | game-icons.net (d4.svg) | Skoll | https://game-icons.net/1x1/skoll/d4.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/dice/die_d6.png | game-icons.net (dice-six-faces-six.svg) | Delapouite | https://game-icons.net/1x1/delapouite/dice-six-faces-six.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/dice/die_d8.png | game-icons.net (dice-eight-faces-eight.svg) | Delapouite | https://game-icons.net/1x1/delapouite/dice-eight-faces-eight.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/dice/die_d10.png | game-icons.net (d10.svg) | Skoll | https://game-icons.net/1x1/skoll/d10.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/dice/die_d12.png | game-icons.net (d12.svg) | Skoll | https://game-icons.net/1x1/skoll/d12.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/currency/currency_ember.png | game-icons.net (burning-embers.svg) | Lorc | https://game-icons.net/1x1/lorc/burning-embers.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/currency/currency_insight.png | game-icons.net (third-eye.svg) | Lorc | https://game-icons.net/1x1/lorc/third-eye.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/currency/currency_coin_alt.png | game-icons.net (cash.svg) | Lorc | https://game-icons.net/1x1/lorc/cash.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/nodes/node_fight.png | game-icons.net (crossed-swords.svg) | Lorc | https://game-icons.net/1x1/lorc/crossed-swords.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/nodes/node_elite.png | game-icons.net (crowned-skull.svg) | Lorc | https://game-icons.net/1x1/lorc/crowned-skull.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/nodes/node_rest.png | game-icons.net (campfire.svg) | Lorc | https://game-icons.net/1x1/lorc/campfire.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/nodes/node_shop.png | game-icons.net (swap-bag.svg) | Lorc | https://game-icons.net/1x1/lorc/swap-bag.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/nodes/node_event.png | game-icons.net (uncertainty.svg) | Lorc | https://game-icons.net/1x1/lorc/uncertainty.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/nodes/node_boss.png | game-icons.net (dragon-head.svg) | Lorc | https://game-icons.net/1x1/lorc/dragon-head.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_anvil.png | game-icons.net (anvil.svg) | Lorc | https://game-icons.net/1x1/lorc/anvil.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_fire_gem.png | game-icons.net (fire-gem.svg) | Delapouite | https://game-icons.net/1x1/delapouite/fire-gem.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_fire_ring.png | game-icons.net (fire-ring.svg) | Lorc | https://game-icons.net/1x1/lorc/fire-ring.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_fire_shield.png | game-icons.net (fire-shield.svg) | Lorc | https://game-icons.net/1x1/lorc/fire-shield.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_fire_bowl.png | game-icons.net (fire-bowl.svg) | Lorc | https://game-icons.net/1x1/lorc/fire-bowl.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_candle_flame.png | game-icons.net (candle-flame.svg) | Lorc | https://game-icons.net/1x1/lorc/candle-flame.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_ember_shot.png | game-icons.net (ember-shot.svg) | Lorc | https://game-icons.net/1x1/lorc/ember-shot.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_fireball.png | game-icons.net (fireball.svg) | Lorc | https://game-icons.net/1x1/lorc/fireball.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_fire_bottle.png | game-icons.net (fire-bottle.svg) | Lorc | https://game-icons.net/1x1/lorc/fire-bottle.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_fire_axe.png | game-icons.net (fire-axe.svg) | Lorc | https://game-icons.net/1x1/lorc/fire-axe.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_fire_breath.png | game-icons.net (fire-breath.svg) | Lorc | https://game-icons.net/1x1/lorc/fire-breath.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_fire_tail.png | game-icons.net (fire-tail.svg) | Lorc | https://game-icons.net/1x1/lorc/fire-tail.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_gem_pendant.png | game-icons.net (gem-pendant.svg) | Lorc | https://game-icons.net/1x1/lorc/gem-pendant.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_ring.png | game-icons.net (ring.svg) | Delapouite | https://game-icons.net/1x1/delapouite/ring.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_crown.png | game-icons.net (crown.svg) | Lorc | https://game-icons.net/1x1/lorc/crown.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_heart_bottle.png | game-icons.net (heart-bottle.svg) | Lorc | https://game-icons.net/1x1/lorc/heart-bottle.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_lantern.png | game-icons.net (lantern-flame.svg) | Lorc | https://game-icons.net/1x1/lorc/lantern-flame.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_candelabra.png | game-icons.net (lit-candelabra.svg) | Lorc | https://game-icons.net/1x1/lorc/lit-candelabra.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_metal_bar.png | game-icons.net (metal-bar.svg) | Lorc | https://game-icons.net/1x1/lorc/metal-bar.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_rune_stone.png | game-icons.net (rune-stone.svg) | Lorc | https://game-icons.net/1x1/lorc/rune-stone.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_skeleton_key.png | game-icons.net (skeleton-key.svg) | Lorc | https://game-icons.net/1x1/lorc/skeleton-key.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_locked_chest.png | game-icons.net (locked-chest.svg) | Lorc | https://game-icons.net/1x1/lorc/locked-chest.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_sword_smithing.png | game-icons.net (sword-smithing.svg) | Lorc | https://game-icons.net/1x1/lorc/sword-smithing.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/relics/relic_hammer_nails.png | game-icons.net (hammer-nails.svg) | Lorc | https://game-icons.net/1x1/lorc/hammer-nails.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/events/event_cave_entrance.png | game-icons.net (cave-entrance.svg) | Delapouite | https://game-icons.net/1x1/delapouite/cave-entrance.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/events/event_mine_wagon.png | game-icons.net (mine-wagon.svg) | Delapouite | https://game-icons.net/1x1/delapouite/mine-wagon.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/events/event_blacksmith.png | game-icons.net (blacksmith.svg) | Delapouite | https://game-icons.net/1x1/delapouite/blacksmith.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/events/event_coal_pile.png | game-icons.net (coal-pile.svg) | Delapouite | https://game-icons.net/1x1/delapouite/coal-pile.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/events/event_scroll.png | game-icons.net (scroll-unfurled.svg) | Lorc | https://game-icons.net/1x1/lorc/scroll-unfurled.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/events/event_conversation.png | game-icons.net (conversation.svg) | Lorc | https://game-icons.net/1x1/lorc/conversation.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/events/event_dust_cloud.png | game-icons.net (dust-cloud.svg) | Lorc | https://game-icons.net/1x1/lorc/dust-cloud.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/events/event_stone_tower.png | game-icons.net (stone-tower.svg) | Lorc | https://game-icons.net/1x1/lorc/stone-tower.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/events/event_mining.png | game-icons.net (mining.svg) | Lorc | https://game-icons.net/1x1/lorc/mining.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| ui/events/event_open_chest.png | game-icons.net (open-chest.svg) | Skoll | https://game-icons.net/1x1/skoll/open-chest.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ | 2026-07-23 | Rasterized from SVG (repo github.com/game-icons/icons), background square removed, glyph tinted single ember color, rendered to PNG. |
| backgrounds/bg_title.png | Original work for Emberdelve (procedural, build_bg.py) | Tsoro Studios (generated by Viktor, non-AI-image-gen: deterministic procedural script) | (created in-repo; no external source) | CC0 1.0 Universal (dedicated by author) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Title screen backdrop; layered value-noise ridges, gradients, dithering, ember particles at 270x480, nearest-neighbor x4 to 1080x1920. |
| backgrounds/bg_map.png | Original work for Emberdelve (procedural, build_bg.py) | Tsoro Studios (generated by Viktor, non-AI-image-gen: deterministic procedural script) | (created in-repo; no external source) | CC0 1.0 Universal (dedicated by author) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Map screen backdrop; layered value-noise ridges, gradients, dithering, ember particles at 270x480, nearest-neighbor x4 to 1080x1920. |
| backgrounds/bg_combat.png | Original work for Emberdelve (procedural, build_bg.py) | Tsoro Studios (generated by Viktor, non-AI-image-gen: deterministic procedural script) | (created in-repo; no external source) | CC0 1.0 Universal (dedicated by author) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Combat backdrop; layered value-noise ridges, gradients, dithering, ember particles at 270x480, nearest-neighbor x4 to 1080x1920. |
| backgrounds/bg_boss.png | Original work for Emberdelve (procedural, build_bg.py) | Tsoro Studios (generated by Viktor, non-AI-image-gen: deterministic procedural script) | (created in-repo; no external source) | CC0 1.0 Universal (dedicated by author) — https://creativecommons.org/publicdomain/zero/1.0/ | 2026-07-23 | Boss/summary backdrop; layered value-noise ridges, gradients, dithering, ember particles at 270x480, nearest-neighbor x4 to 1080x1920. |
| icon/app_icon_master_1024.png | Original composition; die glyph from game-icons.net dice-six-faces-six.svg by Delapouite | Tsoro Studios + Delapouite | https://game-icons.net/1x1/delapouite/dice-six-faces-six.html | CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/ (for the die glyph); remainder original, CC0 | 2026-07-23 | Procedural dark radial background, ember gradient fill applied through glyph alpha mask, Gaussian glow, spark particles, vignette. 1024x1024 master. |
| sprite_meta.json | Generated metadata (this pipeline) | Tsoro Studios | (generated) | CC0 1.0 Universal (dedicated) | 2026-07-23 | Machine-readable sheet layout: frame sizes, rows/states, frame counts, fps. |

---

# Emberdelve Audio Provenance

Every file in this directory tree, its origin, and its exact license.
All downloads made **2026-07-23** with `curl` from the URLs below (verified working that day).
Repo-safety rule applied: CC0 preferred; CC-BY only where the license text clearly
permits public redistribution with attribution (CC BY 3.0 / 4.0 do). No NC/ND/SA,
no AI-generated audio, no paid assets.

Common processing (ffmpeg 7.x): decode → trim leading silence → trim trailing
silence (−60 dB) → measured EBU R128 gain toward target loudness (music loops −19
LUFS, stings −18, SFX −13…−14 with peak limiting for short transients) →
`alimiter` ceiling −1.4 dBFS → short anti-click fades → OGG Vorbis (music q4,
SFX q4–5), 44.1 kHz, SFX mono / music stereo. All music decodes with peak ≤
−1.3 dBFS (no clipping). Exact per-file recipe:
`runs/2026-07-23-emberdelve-assets/audio-curator/build_audio.py`.

## Sources (packs)

| ID | Pack / Work | Author | License | Source URL | Download URL |
|----|-------------|--------|---------|------------|--------------|
| K-CAS | Casino Audio v1.1 | Kenney Vleugels (kenney.nl) | CC0 1.0 (License.txt in zip) | https://kenney.nl/assets/casino-audio | https://kenney.nl/media/pages/assets/casino-audio/2472606a04-1721639069/kenney_casino-audio.zip |
| K-IMP | Impact Sounds | Kenney Vleugels (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/impact-sounds | https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip |
| K-INT | Interface Sounds | Kenney Vleugels (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/interface-sounds | https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip |
| K-RPG | RPG Audio | Kenney Vleugels (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/rpg-audio | https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip |
| RD-100 | 100 CC0 SFX #2 | rubberduck | CC0 (page license field: "CC0") | https://opengameart.org/content/100-cc0-sfx-2 | https://opengameart.org/sites/default/files/sfx_100_v2.zip |
| RD-CRE | 80 CC0 creature SFX | rubberduck | CC0 | https://opengameart.org/content/80-cc0-creature-sfx | https://opengameart.org/sites/default/files/80-CC0-creature-SFX_0.zip |
| AD-RPG | RPG Sound Pack | artisticdude | CC0 (page license field: "CC0 / Public Domain") | https://opengameart.org/content/rpg-sound-pack | https://opengameart.org/sites/default/files/rpg_sound_pack.zip |
| SS-FAN | 10 Fanfares | Spring Spring | Multi-licensed: CC-BY 3.0 / CC-BY-SA 3.0 / OGA-BY 3.0 / **CC0** — used under CC0 | https://opengameart.org/content/10-fanfares | https://opengameart.org/sites/default/files/10%20fanfares_0.ogg |
| TC-DEF | Defeat | tcarisland | CC-BY 4.0 (attribution given in CREDITS.md) | https://opengameart.org/content/defeat | https://opengameart.org/sites/default/files/defeat_2.mp3 |
| AD-FIRE | Fire Crackling | AntumDeluge (submitter/author of record on page) | CC0 | https://opengameart.org/content/fire-crackling | https://opengameart.org/sites/default/files/fire-1.wav |
| QD-FIRE | Fire Loop | Iwan "qubodup" Gabovitch | CC-BY 3.0 (attribution given in CREDITS.md) | https://opengameart.org/content/fire-loop | https://opengameart.org/sites/default/files/qubodupFireLoop.ogg |
| KM | Kevin MacLeod music (incompetech.com) | Kevin MacLeod | CC BY 4.0 ("Creative Commons: By Attribution 4.0", per incompetech FAQ/license pages) | https://incompetech.com/music/royalty-free/ | see per-file rows |

## music/

| File | Source file | Pack | Processing |
|------|-------------|------|------------|
| title_menu.ogg | "Ossuary 1 - A Beginning" — https://incompetech.com/music/royalty-free/mp3-royaltyfree/Ossuary%201%20-%20A%20Beginning.mp3 | KM | trim silence, measured gain to −19 LUFS, 20/40 ms edge fades, OGG q4 stereo |
| map.ogg | "Ossuary 2 - Turn" — https://incompetech.com/music/royalty-free/mp3-royaltyfree/Ossuary%202%20-%20Turn.mp3 | KM | same as above |
| combat.ogg | "Curse of the Scarab" — https://incompetech.com/music/royalty-free/mp3-royaltyfree/Curse%20of%20the%20Scarab.mp3 | KM | same |
| boss_combat.ogg | "Five Armies" — https://incompetech.com/music/royalty-free/mp3-royaltyfree/Five%20Armies.mp3 | KM | same |
| victory.ogg | fanfare #1 (0.00–5.43 s cut of pack file) | SS-FAN | cut, −18 LUFS, 0.4 s fade-out, OGG q5 |
| defeat.ogg | first 12 s of "Defeat" | TC-DEF | cut, −18 LUFS, 2.5 s fade-out, OGG q5 |

## sfx/ (all OGG Vorbis q5, 44.1 kHz mono unless noted)

| File | Source file | Pack |
|------|-------------|------|
| dice_roll.ogg | dice-throw-2.ogg | K-CAS |
| die_assign.ogg | chip-lay-1.ogg | K-CAS |
| reroll.ogg | dice-shake-1.ogg | K-CAS |
| player_hit.ogg | impactPunch_heavy_000.ogg | K-IMP |
| enemy_hit.ogg | sfx100v2_hit_01.ogg | RD-100 |
| block.ogg | impactMetal_heavy_002.ogg + pitch-down (0.55×) body layer, limited −1.4 dB peak (v0.3.1: was too quiet next to hits) | K-IMP |
| enemy_death.ogg | monster_04.ogg | RD-CRE |
| boss_death.ogg | roar_02.ogg layered with pitch-down (0.72×) copy of itself | RD-CRE |
| victory.ogg | fanfare #3 (20.58–25.36 s cut of pack file) | SS-FAN |
| defeat.ogg | first 6.5 s of "Defeat", 1.5 s fade-out | TC-DEF |
| coin.ogg | handleCoins.ogg | K-RPG |
| forge.ogg | sfx100v2_metal_hit_02.ogg layered with inventory/metal-ringing.wav (+15 ms, −4 dB) | RD-100 + AD-RPG |
| heal.ogg | inventory/bottle.wav | AD-RPG |
| event_page.ogg | bookFlip2.ogg | K-RPG |
| ui_tap.ogg | click_001.ogg | K-INT |
| ui_back.ogg | back_001.ogg | K-INT |
| unlock.ogg | confirmation_002.ogg | K-INT |
| ember_gain.ogg | fire-1.wav, 0.15–0.75 s crackle cut | AD-FIRE |
| whoosh.ogg | battle/swing.wav | AD-RPG |
| ember_ambience_loop.ogg | qubodupFireLoop.ogg — author's seamless loop preserved (gain-only, no trim/fade) | QD-FIRE |

## Licenses in use

- **CC0 1.0**: https://creativecommons.org/publicdomain/zero/1.0/ — no attribution required (given anyway).
- **CC BY 3.0**: https://creativecommons.org/licenses/by/3.0/ — redistribution permitted with attribution.
- **CC BY 4.0**: https://creativecommons.org/licenses/by/4.0/ — redistribution permitted with attribution.

No Sonniss/GDC content was used (royalty-free but not openly redistributable — unsuitable for a public repo).

## Platformer (v2) assets — added 2026-07-24
Assembled by `tool/build_assets.py` from these verified packs (license checked on source page at download time):

| Pack | Author | Source | License | Used for |
|---|---|---|---|---|
| Royal Knight Platformer | pixivan | https://opengameart.org/content/royal-knight-platformer | CC0 1.0 | player animations (idle/run/jump/fall/hit/roll/attack1-3) |
| Sunny Land | ansimuz | https://opengameart.org/content/sunny-land-forest-of-illusion | CC0 1.0 | tileset, props (spikes/door/sign/platform/…), enemies (thornling/ashbat/hopper), gem→feather, cherry, enemy-death fx, bg layer |
| Forest Parallax Background | ansimuz | https://opengameart.org/content/forest-background | CC0 1.0 | bg/forest_* parallax layers |
| Pixel Adventure 1 | Pixel Frog | https://pixelfrog-assets.itch.io/pixel-adventure-1 | CC0 1.0 | items/apple, fx/fire |
| Items #1 | GrafxKid | https://opengameart.org/content/various-items | CC0 1.0 | items/coin (bg keyed out) |
| Animated pixel-art treasure chests | dustdfg | https://opengameart.org/content/animated-pixel-art-treasure-chests | **CC-BY 4.0** (credited in CREDITS.md) | items/chest |
| Mobile Controls | Kenney | https://kenney.nl/assets/mobile-controls | CC0 1.0 | hud buttons + icons; hud/btn_down.png is btn_left.png rotated 90° (tool/build_hud_extras.py) |
| Dash icon | original (Tsoro Studios, drawn by tool/build_hud_extras.py) | this repo | CC0 1.0 | hud/icon_dash.png |
| Spell icons | original (Tsoro Studios, drawn by tool/build_spell_icons.py) | this repo | CC0 1.0 | hud/icon_spell.png, shop/spell_ember_burst.png, shop/spell_stone_veil.png, shop/spell_hearth_light.png |

Full per-pack evidence recorded at curation time (staging MANIFEST, 2026-07-24).

## Platformer (v2) SFX pass — added 2026-07-25

Dice-era one-shots (`dice_roll`, `die_assign`, `reroll`, `forge`, `event_page`)
were removed from the bundle (dead since the pivot). New platformer verbs built
by `tool/build_platformer_sfx.py` (mono 44.1 kHz, highpass 40 Hz, peak-limited,
5 ms anti-click fades, OGG Vorbis q5; decoded peaks verified ≤ −1.4 dBFS):

| File | Source file | Pack / Work | Author | License | Modifications |
|---|---|---|---|---|---|
| sfx/jump.ogg | — (procedural) | Original synthesis in tool/build_platformer_sfx.py (numpy: triangle sweep 170→430 Hz + filtered-noise breath) | Tsoro Studios (script) | CC0 (dedicated) | n/a |
| sfx/double_jump.ogg | — (procedural) | Same synth, sweep 240→620 Hz | Tsoro Studios (script) | CC0 (dedicated) | n/a |
| sfx/secret.ogg | — (procedural) | Original synthesis (sine arpeggio E5-B5-E6-G#6 + 2nd-harmonic shimmer) | Tsoro Studios (script) | CC0 (dedicated) | n/a |
| sfx/land.ogg | impactSoft_medium_002.ogg | Kenney Impact Sounds (K-IMP, see Sources table above) | Kenney | CC0 1.0 | gain −4 dB |
| sfx/swing1.ogg | battle/swing.wav | RPG Sound Pack (AD-RPG) | artisticdude | CC0 | gain −5 dB |
| sfx/swing2.ogg | battle/swing2.wav | RPG Sound Pack (AD-RPG) | artisticdude | CC0 | pitch ×1.06, gain −5 dB |
| sfx/swing3.ogg | battle/swing3.wav | RPG Sound Pack (AD-RPG) | artisticdude | CC0 | pitch ×0.94, gain −4 dB |
| sfx/chest_open.ogg | sfx100v2_lock_open_01.ogg + repo coin.ogg | 100 CC0 SFX #2 (RD-100) + K-RPG (via repo coin.ogg) | rubberduck + Kenney | CC0 | coin layer +90 ms at −7 dB, trimmed 1.1 s |
| sfx/feather.ogg | sfx100v2_air_02.ogg | 100 CC0 SFX #2 (RD-100) | rubberduck | CC0 | pitch ×1.5, trimmed 0.5 s, gain −3 dB |
| sfx/medal.ogg | confirmation_001.ogg | Kenney Interface Sounds (K-INT) | Kenney | CC0 1.0 | trimmed 0.6 s |
## Skin sprite sheets — added 2026-07-25

Catalog skins (Ember Monk, Shadow Thief, Hearth Knight) are deterministic HSV
recolors of the base knight sheets (Royal Knight Platformer by pixivan, CC0 —
see the v2 packs table above), generated by `tool/build_skins.py`: saturated
red "cloth" pixels are hue-remapped (orange 28° / violet 275° / blue 214°) and
low-saturation "armor" pixels get per-channel multipliers (warmed / darkened /
gilded). Outlines and skin tones untouched. Outputs:
`assets/images/player/skins/<id>/{idle,run,jump,fall,hit,roll,attack1-3}.png`
— same CC0 licensing as the source pack.

## Weapon overlay sheets + bladeless body sheets — added 2026-07-26 (AKP-4a)

`tool/build_weapon_sprites.py` splits the baked-in ivory blade (`#fffff2`,
that exact color is blade/swing-FX-only in the pack) out of the base knight
sheets (Royal Knight Platformer by pixivan, CC0 — see the v2 packs table
above) into:
- `assets/images/player/body/*.png` — bladeless body sheets ('red' skin;
  `tool/build_skins.py` now recolors these, so all skins are bladeless);
- `assets/images/player/weapons/<weapon_id>/*.png` — per-weapon overlays:
  a deterministic hilt→blade→tip recolor gradient of the extracted blade
  mask (plus a 1px head dilation for axe/hammer silhouettes).
All derived exclusively from the CC0 source pack — same CC0 licensing.

## Shop icons — added 2026-07-25

Built by `tool/build_shop_icons.py`: SVG rasterized 512px → alpha-mask glyph →
two-tone ember tint → 20px pixelation → x4 nearest → 80x80 PNG under
`assets/images/shop/`. All from the game-icons collection
(https://github.com/game-icons/icons, CC BY 3.0, credited in CREDITS.md).

| File | Source icon | Author | License |
|---|---|---|---|
| shop/weapon_squire_blade.png | pointy-sword.svg | Lorc | CC BY 3.0 |
| shop/weapon_woodsman_axe.png | battered-axe.svg | Lorc | CC BY 3.0 |
| shop/weapon_ember_fang.png | curvy-knife.svg | Lorc | CC BY 3.0 |
| shop/weapon_warden_blade.png | broadsword.svg | Lorc | CC BY 3.0 |
| shop/weapon_skypiercer.png | barbed-spear.svg | Lorc | CC BY 3.0 |
| shop/weapon_wind_gods_hammer.png | flat-hammer.svg | Lorc | CC BY 3.0 |
| shop/ability_coin_magnet.png | magnet.svg | Lorc | CC BY 3.0 |
| shop/ability_apple_pouch.png | shiny-apple.svg | Lorc | CC BY 3.0 |
| shop/ability_haggler.png | price-tag.svg | Delapouite | CC BY 3.0 |
| shop/ability_chest_radar.png | radar-sweep.svg | Lorc | CC BY 3.0 |

## Footsteps — added 2026-07-25

| File | Source file | Pack / Work | Author | License | Modifications |
|---|---|---|---|---|---|
| sfx/step1.ogg | sfx100v2_footstep_01.ogg | 100 CC0 SFX #2 (RD-100) | rubberduck | CC0 | gain −8 dB, trimmed 0.22 s |
| sfx/step2.ogg | sfx100v2_footstep_02.ogg | 100 CC0 SFX #2 (RD-100) | rubberduck | CC0 | gain −8 dB, pitch ×0.96, trimmed 0.22 s |

## World 2 "Cinder Depths" environment — added 2026-07-25

Deterministic recolors of already-shipped Sunny Land CC0 art by
`tool/build_cave_assets.py` (no new sources): `tiles/tileset_cave.png`
(greens→cold ash, browns→dark basalt) and `bg/cave_{back,middle,front}.png`
(deep violet-gray dusk) + `bg/cave_lights.png` (ember glow). Same CC0
licensing as the source files.

## World 2 enemies — added 2026-07-25

Recolors of shipped Sunny Land CC0 sheets by `tool/build_w2_enemies.py`:
`enemies/soot_creeper.png` (from thornling.png — blues→soot, accents→ember)
and `enemies/cinder_diver.png` (from ashbat.png — plumage→dark ash,
beak/talons→hot ember). CC0, same as sources.

---

# Original-asset pass 1 — 2026-07-25 (zero required attributions)

Every CC-BY asset was replaced with **original work by Tsoro Studios**,
generated in-repo with no third-party inputs (no samples, soundfonts,
images, or traced references). Research + plan: `docs/original-assets.md`.
All new files are dedicated **CC0 1.0 Universal** by Tsoro Studios.

| File | Replaces (old source, old license) | Generator | New provenance |
|---|---|---|---|
| audio/music/title_menu.ogg | Kevin MacLeod "Ossuary 1 - A Beginning", CC-BY 4.0 | tool/build_original_music.py `compose_title` | Original composition "Delve Below" (90 BPM, A minor, 64-beat seamless loop), numpy synthesis |
| audio/music/map.ogg | Kevin MacLeod "Ossuary 2 - Turn", CC-BY 4.0 | `compose_map` | Original composition "Wayfarer's Ledger" (108 BPM, C major, seamless loop) |
| audio/music/combat.ogg | Kevin MacLeod "Curse of the Scarab", CC-BY 4.0 | `compose_combat` | Original composition "Sparks in the Undergrowth" (140 BPM, E minor, seamless loop) |
| audio/music/boss_combat.ogg | Kevin MacLeod "Five Armies", CC-BY 4.0 | `compose_boss` | Original composition "Grove Golem's Wrath" (152 BPM, D minor, seamless loop) |
| audio/music/defeat.ogg | tcarisland "Defeat", CC-BY 4.0 | `compose_defeat` | Original composition "Embers Fade" (70 BPM, A minor, non-looping, 2.5 s fade) |
| audio/sfx/defeat.ogg | tcarisland "Defeat", CC-BY 4.0 | `compose_defeat` (6.5 s cut) | Sting cut of "Embers Fade", 1.5 s fade |
| audio/sfx/ember_ambience_loop.ogg | qubodup "Fire Loop", CC-BY 3.0 | `fire_loop` | Procedural crackle synthesis (filtered noise bursts + rumble bed, wrap-around seam), 9.0 s seamless loop |
| images/items/chest.png | dustdfg "Animated pixel-art treasure chests", CC-BY 4.0 | tool/build_original_art.py `build_chest` | Original design (dark oak / ash-iron / ember-rune lock), 3×48×48 frames, engine contract unchanged |
| icon/app_icon_master_1024.png + android mipmaps | dice-era icon incorporating game-icons.net "dice-six-faces-six" (Delapouite), CC-BY 3.0 | `build_icon` | Original "ember in the delve" mark (flame over cave mouth), 64px grid, NEAREST-upscaled |

Mastering evidence (build log 2026-07-25): all music/sting outputs measured
to −19/−18 LUFS targets, alimiter ceiling, decoded peaks −9.44…−2.17 dBFS —
all ≤ the repo's −1.3 dBFS convention (asserted by the build script itself).

## Music engine v2 ("immersive") — 2026-07-25

The five music tracks + defeat sting were re-rendered by
`tool/build_original_music.py` **engine v2**: the same original compositions
(unchanged titles, keys, BPM, event data — see rows above) performed through
a far richer synthesis/mix engine (felt piano, Karplus-Strong plucks,
tremolo strings, convolution reverb with synthesized IRs, arrangement arcs,
humanized timing, mastered tonal balance). Still 100% first-principles
numpy/scipy synthesis — no samples, no soundfonts, no AI audio, no
third-party inputs — deterministic, CC0 1.0 by Tsoro Studios. Production
notes: `docs/music-production.md`. Music OGG quality raised q4 → q6 for the
denser spectrum.

Mastering evidence (engine v2 build log 2026-07-25): title −18.99 LUFS /
peak −6.45 dBFS · map −18.96 / −6.55 · combat −19.03 / −7.09 · boss −19.02 /
−8.83 · defeat −18.02 / −6.30 · sfx defeat sting peak −5.33 · all decoded
peaks ≤ −1.3 dBFS (asserted by the build script), seamless loops verified
(2×-render second-pass export).

The superseded rows above (Kevin MacLeod / tcarisland / qubodup / dustdfg /
game-icons dice glyph) are retained in this file as **historical record
only** — those files no longer ship.

## Audio pass v3 — phone-speaker remaster, 2026-07-25

Measured problem: the v2 set carried nearly all of its energy below 300 Hz
(land.ogg 100 %, player_hit 99.4 %, enemy_death 99.8 %, jump 96.6 %, music beds
88-91 %), which a phone loudspeaker cannot reproduce. Every one-shot was
rebuilt from recorded CC0 sources and mastered through one chain
(`tool/build_audio_v3.py`): mono 44.1 kHz -> 130 Hz high-pass -> presence lift
(2.6 kHz +3 dB, 5.2 kHz +2 dB) -> loudness matched THROUGH a 500 Hz
high-passed phone-speaker model -> soft limit -> peak <= -1.5 dBFS -> 4 ms edge
fades -> OGG q5. Measured results ship in `tool/audio_mix.json` and are pinned
by `test/audio_mix_test.dart`.

New sources this pass (all CC0, added to the Sources table above):

| Ref | Pack | Author | License | Page |
|---|---|---|---|---|
| K-UI | UI Audio | Kenney Vleugels | CC0 1.0 | https://kenney.nl/assets/ui-audio |
| K-JIN | Music Jingles | Kenney Vleugels | CC0 1.0 | https://kenney.nl/assets/music-jingles |
| JJ-512 | The Essential Retro Video Game Sound Effects Collection [512 sounds] | Juhani Junkala | CC0 | https://opengameart.org/content/512-sound-effects-8-bit-style |
| CM-CAVE | Crystal Cave (song18) | cynicmusic (Pixel Sphere) | CC0 | https://opengameart.org/content/crystal-cave-song18 |

| File | Source file | Pack / Work | License | Modifications |
|---|---|---|---|---|
| sfx/block.ogg | impactMetal_light_002.ogg | Kenney Impact Sounds (K-IMP) | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.0 dBFS, peak -3.2 dBFS |
| sfx/boss_death.ogg | sfx_exp_medium1.wav | Essential Retro Video Game SFX Collection (JJ-512), Juhani Junkala | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.2 dBFS, peak -0.8 dBFS |
| sfx/chest_open.ogg | creak2.ogg | Kenney RPG Audio (K-RPG) | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.2 dBFS, peak -3.8 dBFS |
| sfx/coin.ogg | sfx_coin_single3.wav | Essential Retro Video Game SFX Collection (JJ-512), Juhani Junkala | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -21.8 dBFS, peak -13.9 dBFS |
| sfx/danger_loop.ogg | sfx_lowhealth_alarmloop5.wav | Essential Retro Video Game SFX Collection (JJ-512), Juhani Junkala | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -32.1 dBFS, peak -17.0 dBFS |
| sfx/defeat.ogg | jingles_STEEL11.ogg | Kenney Music Jingles (K-JIN) | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.0 dBFS, peak -5.4 dBFS |
| sfx/double_jump.ogg | sfx100v2_air_03.ogg | 100 CC0 SFX #2 (RD-100), rubberduck | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.2 dBFS, peak -6.4 dBFS |
| sfx/ember_ambience_loop.ogg | sfx100v2_loop_ambient_01.ogg | 100 CC0 SFX #2 (RD-100), rubberduck | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -34.2 dBFS, peak -17.5 dBFS |
| sfx/ember_gain.ogg | sfx_sounds_interaction12.wav | Essential Retro Video Game SFX Collection (JJ-512), Juhani Junkala | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.0 dBFS, peak -7.6 dBFS |
| sfx/enemy_death.ogg | sfx100v2_wood_hit_03.ogg | 100 CC0 SFX #2 (RD-100), rubberduck | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.4 dBFS, peak -1.1 dBFS |
| sfx/enemy_hit.ogg | sfx100v2_hit_03.ogg | 100 CC0 SFX #2 (RD-100), rubberduck | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -23.8 dBFS, peak -2.0 dBFS |
| sfx/feather.ogg | confirmation_002.ogg | Kenney Interface Sounds (K-INT) | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.1 dBFS, peak -9.3 dBFS |
| sfx/heal.ogg | sfx_sounds_powerup11.wav | Essential Retro Video Game SFX Collection (JJ-512), Juhani Junkala | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.3 dBFS, peak -11.2 dBFS |
| sfx/jump.ogg | sfx100v2_air_02.ogg | 100 CC0 SFX #2 (RD-100), rubberduck | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.3 dBFS, peak -10.1 dBFS |
| sfx/land.ogg | footstep_grass_001.ogg | Kenney Impact Sounds (K-IMP) | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.9 dBFS, peak -1.3 dBFS |
| sfx/medal.ogg | confirmation_001.ogg | Kenney Interface Sounds (K-INT) | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -21.9 dBFS, peak -8.3 dBFS |
| sfx/player_hit.ogg | sfx_damage_hit1.wav | Essential Retro Video Game SFX Collection (JJ-512), Juhani Junkala | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.0 dBFS, peak -10.6 dBFS |
| sfx/secret.ogg | sfx_sounds_powerup1.wav | Essential Retro Video Game SFX Collection (JJ-512), Juhani Junkala | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.1 dBFS, peak -15.3 dBFS |
| sfx/step1.ogg | sfx100v2_footstep_01.ogg | 100 CC0 SFX #2 (RD-100), rubberduck | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -30.2 dBFS, peak -9.2 dBFS |
| sfx/step2.ogg | sfx100v2_footstep_02.ogg | 100 CC0 SFX #2 (RD-100), rubberduck | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -30.1 dBFS, peak -9.8 dBFS |
| sfx/swing1.ogg | swing.wav | RPG Sound Pack (AD-RPG), artisticdude | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.6 dBFS, peak -1.4 dBFS |
| sfx/swing2.ogg | swing2.wav | RPG Sound Pack (AD-RPG), artisticdude | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.0 dBFS, peak -3.6 dBFS |
| sfx/swing3.ogg | swing3.wav | RPG Sound Pack (AD-RPG), artisticdude | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.0 dBFS, peak -4.5 dBFS |
| sfx/ui_back.ogg | back_001.ogg | Kenney Interface Sounds (K-INT) | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -26.0 dBFS, peak -4.2 dBFS |
| sfx/ui_tap.ogg | click1.ogg | Kenney UI Audio (K-UI) | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -26.1 dBFS, peak -4.8 dBFS |
| sfx/unlock.ogg | metalLatch.ogg | Kenney RPG Audio (K-RPG) | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -21.9 dBFS, peak -1.5 dBFS |
| sfx/victory.ogg | jingles_STEEL07.ogg | Kenney Music Jingles (K-JIN) | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.0 dBFS, peak -3.6 dBFS |
| sfx/whoosh.ogg | sfx100v2_air_01.ogg | 100 CC0 SFX #2 (RD-100), rubberduck | CC0 | phone-band master: HP 130 Hz, presence +3/+2 dB, RMS -22.3 dBFS, peak -9.9 dBFS |

### Music

`tool/build_music_v3.py` re-masters the v2 tracks for the same speaker (95 Hz
high-pass, -4 dB at 180 Hz, +3/+4/+2 dB through 900 Hz/2.4 kHz/5 kHz, gentle
excitation, 11 kHz low-pass, phone-band RMS -26 dBFS, peak <= -2 dBFS) and adds
`cave_combat.ogg` for World 2 from CM-CAVE (Crystal Cave, cynicmusic, CC0).
Boss arenas now use `boss_combat.ogg`, which shipped in every previous APK
without a single level referencing it. Music assets: 3.8 MB -> 1.9 MB.

### Checkpoint art

`props/campfire_out.png` / `props/campfire_lit.png` — original pixel art,
every pixel placed by `tool/build_checkpoint_art.py` (Tsoro Studios, CC0).
