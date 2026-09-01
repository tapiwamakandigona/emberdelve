# Play apply day — v0.178.0 "The Seven Hearths" in ONE console session

Written 2026-09-01. The Sept-29 retention prediction (retention-ledger.md)
only starts for Play users when this ships — every day prod stays on
0.59.0 (code 85) delays the judgment window. When the owner authorises
the Play ship, this is the complete session, in order. Nothing here is
executed without the owner; nothing here requires a rebuild.

> Freeze rules (DEMAND 2026-09-01b): the tagged v0.178.0 AAB **is** the
> Play candidate — do NOT rebuild, re-tag, or cut a new release. Ship
> the existing artifact.

## Before the session (agent-side, no console)

1. Recapture screenshots the SAME day as the console session so the
   Daily Delve date matches: `flutter test tool/store_screenshots_test.dart`
   then `python3 tool/frame_store_screenshots.py --r3` (the R3 plate
   table is in the script since 2026-09-01; plain run regenerates the
   live-record `framed/` set — leave that one alone). Eyeball against
   docs/store/STORE-ASSET-QA.md. Dry-run proven 2026-09-01: full
   pipeline regenerated framed-r3 with the Sep 1 daily line, plates
   visually verified.
2. Download the release AAB and verify before handing it over:
   - Asset: `emberdelve-v0.178.0.aab` from the v0.178.0 GitHub release
     (sha256 `84eb0cba…`, versionCode 204, versionName 0.178.0).
   - Cert pin check: `/work/temp/v0601/rel/verify.py` — pin
     `031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d`.

## The console session (owner holds access, ~30 min)

Order matters: listing edits and the release land in one session so the
ledger's before/after stays readable as a single event.

1. **Production → Create release.** Upload the verified AAB (code 204).
   Play re-signs with the pinned key (v2 cert verified on the GitHub
   asset). If Play rejects for target SDK or declaration drift, STOP —
   record the exact error, do not improvise fixes in-session.
2. **Release notes** (player-facing, matches the TAGGED artifact — not
   the branch: the startup/animation/stillness work post-dates the tag
   and is NOT in this AAB. Banned-words list applies):
   > The Seven Hearths: light a hearth on the title screen each day
   > you play — whenever those days come, gaps cost nothing. The
   > seventh settles 60 embers. Plus many fixes and improvements since
   > the last update.
3. **Store listing, same session:**
   - Short description → live candidate from r3-supplement:
     "Fair dice roguelite. Build your pool, delve deep. No ads, no
     timers, no gacha." (already live — verify unchanged, don't churn).
   - Full description: apply play-listing.md current text (adds
     roguelike/turn-based/dungeon; never "deckbuilder"/Balatro/StS).
   - Screenshots: upload framed-r3 set (with the fresh title plate).
   - Trust line stays in the first two lines (r3 finding: the no-ads
     promise is the conversion asset).
4. **Rollout: 100%.** The install base is 38 lifetime / 28 MAU — a
   staged rollout adds delay, not safety, at this n. Vitals guardrail
   (0 crashes / 0 ANRs, 28 days clean) is already green.
5. **Checks while in there (10 min, fills the ledger):**
   - Statistics: MAU, new devices → note for the Sept-29 row.
   - Android vitals: confirm crash/ANR still 0; check whether the
     memory metrics have left "Limited data" (PLAY-QUALITY-2027.md
     dynamic-memory row is blocked on this).
   - Policy center: confirm clean, privacy policy URL resolves
     (https://tapiwamakandigona.github.io/emberdelve/store/privacy-policy.html
     — verified live 2026-09-01, covers all three packages).
   - Data safety: NO changes — the app still collects nothing
     (telemetry opt-in default OFF, manifest collection disabled,
     AD_ID removed). Any prompt to re-declare: answer identically.
6. **Same day, in the repo:** append a note row to retention-ledger.md
   ("v0.178.0 live on Play production YYYY-MM-DD, rollout 100%") —
   the Play prediction window starts HERE, re-anchor the ~2026-09-29
   judgment row to this date + 28 days.

## What NOT to do in-session

- No price changes ($4.99 Ember Forge stands; historical honors never
  re-price).
- No new tracks, no test-track cleanup, no country changes — one
  variable at a time or the ledger can't attribute anything.
- No posting the traffic-channel sequence the same week — the r/…
  sequence (traffic-channels.md) needs the new listing LIVE first, and
  posts are the owner's call and account; keep launch-week installs
  attributable to the release itself.

## Stale-doc notice

docs/launch/LAUNCH-CHECKLIST.md (2026-08-16, v0.7.0 era) is SUPERSEDED
by this runbook for the ship decision: its prices ($3.99), track facts
(production inactive), and gates predate the 0.59.0 prod release and
the v0.178.0 freeze. Kept for history; do not action it.
