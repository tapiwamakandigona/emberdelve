# Apple Knight — visual reference pack

Screenshots of *Apple Knight* (Limitless LLC, web build on Poki) captured
2026-07-25 with Pixel-7 touch emulation (viewport 892×412 @2x → 1784×824 px).
This is the visual target for `docs/ak-parity-plan.md` (AKP-1..6) — so any
agent working a parity task can see exactly what AK looks like without
replaying it.

**Reference-only material.** Apple Knight's art and design are copyright
Limitless LLC. These images are for internal design comparison; never ship,
trace, or copy assets from them (`PROVENANCE.md` rules apply).

## Index

| File | What it shows | Notes for parity work |
|---|---|---|
| `01_main_menu.png` | Title screen | Campfire vignette with idle hero, big single PLAY, SHOP tile with live character preview, gear top-left. Selection brackets = focused element (menus are select-then-confirm). |
| `02_shop_skins.png` | Shop — skins tab | 3 tabs (SKINS/WEAPONS/ABILITIES), grid left, large preview + stats right, EQUIPPED state button, GET COINS (ad bait) top-right — we deliberately don't copy that. Skins have gameplay stats ("BASIC ARMOR, 3 HEARTS"). |
| `03_shop_weapons_equipped.png` | Shop — weapons tab | 13 weapons; per-weapon DAMAGE / RANGE / CRIT % / CRIT DAMAGE; big item art in preview panel. Maps to our `catalog.dart` stats almost 1:1. |
| `04_shop_weapon_locked.png` | Shop — locked weapon | "Thief's Blade": stats + SPECIAL (+10% movement speed) + red lock rule ("Buy 4 previous weapons to unlock"). Progression-gated shop, not just price-gated. |
| `05_shop_abilities.png` | Shop — abilities tab | The throwable/"ability" slot: apple (default, DAMAGE 3 / RANGE 20), fireball, bomb, bat, homing shots, heart etc. This is the model for AKP-4d's spell slot. |
| `06_gameplay_tutorial_start.png` | First seconds of Level 1 | Safe flat spawn, RUN sign with icon buttons, NPC ahead, no hazard in sight — the onboarding target for AKP-6. |
| `07_gameplay_run_hud.png` | Gameplay + full HUD | Top-left counters (hearts, apples x/30, lives, chests x/8, golden chests x/2, coins); arrows bottom-left; right-hand 4-button diamond: dash (»), apple (top-right), sword, jump (triangle). Layout target for AKP-5. |
| `08_gameplay_jump.png` | Jump arc | Character readability in air; ~12.5% of screen height (AKP-1 measurement source). |
| `09_gameplay_sword.png` | Melee swing | Swing readability target for AKP-3b. |
| `10_gameplay_dash.png` | Dash | Dash as first-class verb (AKP-2a). |
| `11_gameplay_apple_throw.png` | Apple throw | Lobbed arc projectile (AKP-4c). |
| `12_pause_menu.png` | Pause menu | PAUSED banner; VIEW CONTROLS; home/retry/settings/resume icon row. |
| `13_controls_bindings.png` | Controls popup | Keyboard verbs: Z jump, X melee, C **ability**, V **dash** — 4 action verbs + movement, confirming dash and ability are first-class. |
| `14_level_start_toast.png` | Level start toast | "Level 1: 3 lives left" — AK web build uses a lives system and goes straight into the level from PLAY (no level-select screen in this build). |

## Feel & animation measurements

[`feel-notes.md`](feel-notes.md) has frame-measured physics (jump airtime,
dash speed, apple trajectory, hit/collision FX language) from a 25 fps
recording, with per-verb filmstrips and GIF clips in
[`feel-frames/`](feel-frames/): jump_full, double_jump, dash, sword_combo,
apple_throw.

## Capture notes (repeatability)

- Poki page: `poki.com/en/g/apple-knight`, tap "Play now" ≈ (200,295) in an
  892×412 viewport, ~35-40 s load.
- Menus are **select-then-confirm**: a tap moves the selection brackets, the
  activation is a second tap or keyboard Enter. Automation should tap, then
  press Enter.
- Escape toggles pause. Web build has no settings screen reachable from the
  main menu gear under emulation (not captured); pets/merchant screens exist
  only in the mobile app, not this web build.
