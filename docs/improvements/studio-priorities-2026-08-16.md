# What studios actually work on post-launch — and what Emberdelve takes from it

Research pass 2026-08-16 (owner directive: keep improving, GitHub releases
only, no Play submissions). Sources: Balancy LiveOps deconstruction of
Turborilla's Mad Skills Motocross 3 (2026-01), Microsoft "Evergreen Games"
(Minecraft/Candy Crush, 2026-05), Supersonic + Liquid&Grit + Apple FTUE
guides (2025), Playio ASO 2026, IndieGameBusiness community marketing
(2026-03), Birdor case studies of Dead Cells (2026-04) and Slay the Spire
(2026-02), GameDiscoverCo on Balatro (2024), Growth Memo on Wordle's
engineered virality (2022).

## The recurring priorities across studios

1. **Meta progression is what carries players past day 7–14** (Turborilla).
   Not more content — *systems* that scale without exhausting the team.
2. **Daily goals extend sessions without new content** (Turborilla): loops of
   small completable objectives, refreshed when finished.
3. **First-minute feel decides everything** (Dead Cells, all FTUE guides):
   teach through play, one step at a time, contextual mini-tutorials at the
   moment a system appears, early "aha"/quick-win, never a wall of rules.
4. **Trust is the evergreen engine** (Mojang: 17 years of free updates;
   "building trust starts the moment you ask somebody for money"). Matches
   our no-ads/no-gacha pillar — trust IS our differentiator.
5. **Updates are return-moments, not obligations** (Dead Cells: 34 free
   updates; players return because the game meaningfully changed, not
   because a streak threatened them).
6. **A strong loop changes the player, not the number** (Slay the Spire:
   lose → understand the defect → restart with a sharper theory). Retention
   = the player's growing model of the game. Make learning visible.
7. **Engineered share loops capture users for $0** (Wordle: spoiler-free,
   instantly recognizable, social-capital-driven share artifact; Balatro:
   seeds and clips made players and YouTubers the marketing channel).
8. **ASO + community are the organic capture channels** (Playio, IGB):
   store page must "feel like the game I was looking for" in 3 seconds;
   community = interaction and shared culture, built by documenting the
   journey, not by follower counts.

## What Emberdelve does NOT take

Subscriptions, decoy pricing, early power offers, FOMO gating, streak
threats, "Best value" badges. All contradict DEMAND.md pillar 1 and the
Mojang trust lesson — and our conversion story is trust-based.

## Ranked backlog (each item = one GitHub release)

| # | Release | Improvement | Studio lesson |
|---|---------|-------------|---------------|
| 1 | v0.8.0 "Tell the Tale" | Wordle-grade share artifact: spoiler-free emoji floor-trace for Daily/Weekly + copyable seed-challenge for any run ("same seed, beat my delve") | 7 — engineered share loop |
| 2 | v0.9.0 "Today's Trials" | Three rotating daily trials (seeded from the date, no server): small completable goals with ember rewards; a fresh set when done, never a streak | 2 — session extension without content |
| 3 | v0.10.0 "The First Delve" | FTUE rework: staged contextual tutorials (teach at the moment of first contact), first-run quick-win tuning, kill the up-front overlay wall | 3 — first-minute feel |
| 4 | v0.11.0 "The Delver's Ledger" | Make learning visible: post-run insight ("what this run taught"), per-die/per-enemy mastery stats, codex of seen enemies with tells | 6 — the loop changes the player |
| 5 | v0.12.0 | Return-moment content drop: new enemies/relics/events batch sized by what 1–4 taught us | 5 — updates as return moments |

Off-code, parallel: keep documenting the journey in release notes written
for players (community lesson 8) — the GitHub releases themselves are the
devlog artifact.
