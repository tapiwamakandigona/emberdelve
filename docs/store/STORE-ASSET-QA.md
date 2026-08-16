# Store asset QA + conversion pass (2026-08-16, Viktor)

Applied the "criticise with screenshots" method to the live-listing assets, because
after a Reddit click the **store page decides install-or-bounce** — it's the highest-
leverage marketing surface we control (no ad spend, pure conversion).

## Verdict
- **App icon (512):** ✅ strong. Molten-lava die on dark, high contrast, reads at 48px in
  a search grid. Keep as-is.
- **Feature graphic (1024×500):** ✅ good. Wordmark + tagline + die-tier motif, on-brand.
- **Screenshots (raw in-game, 1080×1920):** ⚠ the weak link. Problems for conversion:
  1. **No captions.** A browsing user skims images faster than text; a raw UI screen makes
     them work out the pitch. Top mobile games caption every shot with one benefit line.
  2. **Wrong lead.** Order led with the title screen (#1) and a stats ledger (#5) — neither
     sells the hook. The ledger even shows "9/23 wins", which reads as "you'll lose a lot."
  3. **Selling point buried.** "Every death is fair / no hidden math" is the differentiator
     and wasn't stated anywhere a skimmer would see it.

## Fix shipped
`tool/frame_store_screenshots.py` (repeatable) → `docs/store/screenshots/framed/`:
- Branded caption band per shot: Cinzel gold headline + Inter subline, ember accent rule,
  app palette (bg #14101e, ember #f2953f, gold, dim #a89ec0).
- Reordered to lead with the hook:
  1. **Every death is fair.** — Enemies always telegraph. No hidden math. *(combat)*
  2. **Real choices, every run.** — Push your luck — or walk in unaided. *(boon pick)*
  3. **Branching paths.** — See what an elite guards before you commit. *(map)*
  4. **Fair dice. No ads.** — No timers, no gacha. Free forever. *(title)*
  5. **Die forward.** — Bank embers. Unlock delvers, dice, ascension. *(ledger)*
- Regenerate any time the UI changes: `python tool/frame_store_screenshots.py`.

## To upload (owner / Viktor when console cooperates)
Play Console → Grow users → Store presence → Main store listing → Phone screenshots →
replace with `docs/store/screenshots/framed/*.png` (already 1080×1920, Play-compliant).
Reversible; not a release. Do this before driving Reddit traffic so the first visitors
hit the improved listing. NOTE 2026-08-16: the console's listing/testing pages were
throwing transient server errors (Google-side); retry when stable.
