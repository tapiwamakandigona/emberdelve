# R3 — Store listing conversion research (document only; live listing FROZEN)

Date: 2026-09-01. Owner brief (DEMAND 477857cf): research ONLY. 38
lifetime installs, 2 ratings; production Play build 0.59.0 (code 85).
Nothing here touches the live listing — this is the proposed listing
as a document, for the owner to apply when Play unfreezes.

## Where conversion actually happens (2026 research)

From Play CRO guides and listing-experiment write-ups [web,
2026-09-01] (asomobile.net 2026-07, appdrift.co 2026-04, sentinelaso
2026-02, pressplay.run 2026-03, theionproject 2026-05, storelit
2026-03, Play Console help):

1. **Icon is the highest-leverage single asset.** Split-second
   processing at small size; reducing visual clutter typically lifts
   conversion 5-15%; warm colors (orange/red) outperform cool across
   studies. *Our icon is already an ember on dark — warm, simple. Low
   priority.*
2. **First 2-3 screenshots decide everything** — they render in
   search results before anyone opens the listing. Rules: large
   captions legible without zooming, benefit-first overlays beat
   feature lists, problem→solution narrative across the first 3
   frames, portrait for a portrait game.
3. **Short description (80 chars)** is both indexed for search and
   the first sentence a browser reads. Best structure: primary
   keyword + user benefit + differentiator, phrased like a person
   describing the game to a friend.
4. **Ratings count is a conversion input we can't copy-edit.** At 2
   ratings the social-proof slot is effectively empty; the shipped
   review-ask fix (PR #98, in v0.178.0, riding to Play later) is the
   real lever here. Nothing in the listing can substitute.
5. **Store Listing Experiments are free** (up to 3 variants vs
   current, icon/graphic/screenshots/descriptions) — but need
   traffic to reach significance. At ~38 installs' worth of
   visitors, experiments won't converge; run them only after some
   acquisition push. Custom store listings (per-segment pages) are
   even further out. Sequence: fix defaults now → experiment when
   traffic exists.

## Audit of our current listing vs those levers

- **Short description (live):** "Fair dice roguelite. Build your
  pool, delve deep. No ads, no timers, no gacha." — good, but leads
  with a claim ("fair") that means nothing until trusted, and the
  higher-volume "roguelike" spelling + "turn-based" are missing
  (Play indexes roguelike/roguelite as distinct queries — audit of
  2026-08-16 in play-listing.md still stands).
- **Screenshot set (docs/store/screenshots):** 01-title,
  02-boon-pick, 03-map, 04-combat-roll, 05-ledger. Two problems vs
  the research: (a) the first frame is the TITLE screen — zero
  gameplay, zero benefit — when the first frame does the most work;
  (b) caption discipline unknown; benefit-first overlays are the
  documented win.
- **Full description:** strong, honest, keyword-audited 2026-08-16.
  R1 adds one sharpening: Slice & Dice (1M+ installs) leads its copy
  with TRUST ("undo freely, no hidden mechanics, everything
  visible"). Our equivalent trust facts — deterministic seeded runs,
  telegraphed enemies, no hidden modifiers, 20.6 MB vs a peer-median
  52.7 MB — belong in the first screen of text, not the FAIR BY
  DESIGN block near the bottom.

## Proposed listing (document only — owner applies later)

**App name (unchanged):** `Emberdelve: Dice Roguelite`

**Short description (74 chars, keyword + benefit + differentiator):**
`Turn-based dice roguelike. Fair, learnable runs — no ads, plays offline.`

**Screenshot order + benefit-first captions (same 5 assets, reordered;
frames 1-3 tell problem→solution: real decisions → fair information →
what a run is):**
1. 04-combat-roll — caption: "Every roll is a real decision"
2. 02-boon-pick — "See what you're choosing — nothing hidden"
3. 03-map — "Pick your path. Honest reward previews."
4. 05-ledger — "Die forward — every run banks progress"
5. 01-title — "Free full game. One honest unlock. 21 MB."

**Full description change (one move, no rewrite):** lift a 3-line
trust block to directly under the opening line —
> Every death is fair: enemies telegraph their next move, dice
> resolve by learnable rules, and every run is a seeded delve — the
> same choices always play out the same way. Zero ads. 21 MB.

…then the existing sections unchanged (BUILD YOUR POOL onward),
keeping the 2026-08-16 keyword additions.

## What we deliberately do NOT claim (standing honesty guardrails)

No "deckbuilder", no Balatro/poker/Yahtzee/Slay-the-Spire hooks, no
invented ratings language, no urgency vocabulary (banned-words list
applies to store copy too). Dicey Dungeons remains the one honest
peer anchor.

## Sequenced plan for when the freeze lifts

1. Apply short description + screenshot reorder/captions + trust
   block (all above). One console session, no new assets needed
   (captions may need re-export from docs/store/framed pipeline).
2. Let the v0.178.0 review-ask fix reach production and accumulate
   ratings (the missing conversion input).
3. Only after an acquisition push (itch devlogs, launch posts —
   docs/marketing) gives real visitor volume: run a Store Listing
   Experiment, first test = icon variants, second = first-screenshot
   variants, per the leverage order above.
4. Record listing conversion (visitors → installs) in the monthly
   retention ledger (R2 Option A) so changes get judged by data.

## Addendum (2026-09-01) — proposed screenshot set rendered

The proposed reorder + captions now exist as ready assets in
`docs/store/screenshots/framed-r3/` (generated by the existing
`tool/frame_store_screenshots.py` pipeline with the R3 plate table;
the current live-record `framed/` set is untouched). Captions as
shipped in the assets (all banned-word-clean, all verified claims):

1. combat — "Every roll is a real decision." / "Assign, reroll once, push your luck."
2. boon — "Nothing hidden." / "See what you're choosing — honest previews."
3. map — "Pick your path." / "See what an elite guards before you commit."
4. ledger — "Die forward." / "Every run banks progress. Rank up, unlock."
5. title — "Free full game. 21 MB." / "One honest unlock. No ads, no timers."

Note for the console session that eventually applies these: recapture
on apply day so the Daily Delve date matches — the R3 plate table now
lives in the framing script itself (`tool/frame_store_screenshots.py
--r3`, added 2026-09-01; set regenerated and verified same day). Full
runbook: docs/store/PLAY-APPLY-DAY.md.
