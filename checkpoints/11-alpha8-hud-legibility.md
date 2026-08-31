# v1.0.0-alpha.8+20 — The Readable Wood (HUD legibility)

## For testers

- Every HUD number — coins, apples, chests, feathers, lives, the timer — and
  the level-name intro now carry a crisp dark pixel outline. In the sunlit
  forest levels of World 1 they used to disappear into the sky; now they read
  instantly on every level, light or dark.
- Settings screen: no visual change (internal deprecation cleanup).

## Technical

- `HudReadout.hudTextStyle`: four 1px cardinal `Shadow`s in ink `0xFF201826`,
  zero blur. Shadows bake into each `_HudText` slot's cached `TextPainter`,
  so the steady-state frame cost is unchanged (no per-frame layout).
- Regression test `hud_layout_test.dart` — "HUD text carries a full ink
  outline": pins all four sides present, fully opaque, zero blur, ink
  luminance < 0.05. Fails on the previous code (VERIFIED via stash run),
  passes now.
- `settings_screen.dart`: two `SwitchListTile.activeColor` →
  `activeThumbColor` (Flutter 3.44 deprecation); analyze back to zero issues.
- Suite: 364/364 green (was 363). Web-harness look pass re-verified on
  w1_l1 + w1_l3 at 915×412 (evidence: session shots, 2026-08-31).
