# Checkpoint 19 — v1.0.0-alpha.16 "Small-Phone Sweep" (2026-08-31)

## What
Automated the DEMAND overflow gate: every meta screen at small-phone sizes
(320×568 portrait, 568×320 landscape) with 1.3× accessibility text, loaded
save (max wallet, all medals). test/overflow_sweep_test.dart, 10 cases.

## Red-first evidence (old code)
- title_screen.dart:188 menu Row overflowed 201 px right @320 portrait.
- title_screen.dart:107 Column overflowed 103 px bottom @568×320.
- level_select_screen.dart:29 AppBar actions overflowed 14 px (WalletChip).
- shop_screen.dart:374 card Row overflowed 17 px (price+BUY) and 0.225 px
  (EQUIP variant); shop_screen.dart:470 _WeaponStats bars overflowed 38 px.

## Fixes
- Title menu: Center > FittedBox(scaleDown) around the whole SafeArea
  column — uniform shrink on tiny surfaces, natural size elsewhere.
- WalletChip + shop trailing purchase cluster: withClampedTextScaling(1.0)
  (compact chrome stays base scale; description text keeps 1.3x and wraps).
- _WeaponStats bar rows: FittedBox(scaleDown, centerLeft).
- FittedBox in an UNBOUNDED Row (AppBar actions) is a no-op — it only
  shrinks when constraints force it. Clamp/measure instead.

## Harness learnings
- main_webtest.dart now serves meta screens: ?screen=title|select|shop|
  settings|credits, ?coins=N, ?allclear=1.
- pumpAndSettle hangs on looping animations AND ballistic flings — bounded
  pump loops instead.
- Second rootBundle.loadString of the same asset in one suite can starve
  under FakeAsync — pre-warm the cache inside tester.runAsync first.

## Results
- Sweep 10/10; suite 421 passed + 1 skipped; analyze clean.
- Look pass phone+desktop title/select/shop: no change at normal sizes.

## Next candidates
- Shop disabled-BUY contrast (carry-forward from this look pass).
- On-device perf (P-M7, hardware); Play beta (P-M10, owner call).
