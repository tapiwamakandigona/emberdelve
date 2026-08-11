# Retention & content assessment — 2026-08-11

**Question asked (owner, 02:04):** can we add content so the game is less boring, and how likely are
people to come back daily / weekly / to uninstall?

**Method.** Content counted from `lib/data/*` and `lib/sim/*` at commit `eb949c4` (VERIFIED by
parsing the authoring-order lists, not by eyeballing). Economy numbers computed from the constants in
`lib/sim/run_layer.dart` and `lib/data/characters.dart` (VERIFIED). Market numbers are cited with
their source and vintage. Everything labelled ESTIMATE is my judgement, not measurement — Emberdelve
has no usable retention data of its own yet (see §1).

---

## 1. We are flying blind, and that is the first finding

- Play vitals: **"Data unavailable"** for crash rate and ANR rate; `Crashes and ANRs` shows
  *No results* over 13 Jul – 10 Aug. [play console, 2026-08-11]
- Install base of the current build: **0.00%**. 79.17% of the install base is still on version code
  **12 (0.3.9)**, released to internal testing on 24 Jul. [play console, 2026-08-11]
- Public ratings: **0 ratings, 0 reviews**. All three 5-star testing-feedback entries are on old
  builds (codes 12 and 19). [play console, 2026-08-11]
- Pre-launch report: **none has ever been generated**.

So nobody has yet played v0.4.x, and no D1/D7 number exists for this game. Every retention figure
below is a structural prediction from the design, not a measurement. Generating one real
pre-launch report is the cheapest way to get device-level evidence, and early access will produce
the first honest funnel.

## 2. What is actually in the game (VERIFIED counts)

| Content | Count | Notes |
|---|---|---|
| Delvers | **4** | kindler (free), warden 120, gambler 200, ascetic 320 embers |
| Dice | **30** | 4 d4, 8 d6, 7 d8, 6 d10/d12 tiers |
| Relics | **22** | |
| Boons | **15** | start-of-run picks |
| Enemies | **17** | 9 regular, 5 elite, **3 bosses** |
| Events | **16** | |
| Hearth themes | **4** | 1 free, then 60 / 60 / 100 embers |
| Map | **9 layers**, 1 act | layer 1 start, layer 9 boss, 2–4 nodes per middle layer |
| Modes | **2** | standard run + Daily Delve (one seed per calendar day) |
| Difficulties | 3 | easy, normal free; **hard is paid** |
| Ascension | rungs 0–20 | **rungs 1–20 are paid** (`maxAscensionFor`) |

Everything from the 2026-07-23 `gameplay-depth.md` backlog has effectively shipped: combos
(`lib/sim/combos.dart`), risky reroll, exact-kill/overkill, boon-on-restart, daily seed, haptics,
insights. **The turn is no longer the weak link. Volume and the shape of the long tail are.**

Genre reference point, same subgenre, also mobile: **Slice & Dice** ships 128 hero classes, 73
monsters, 473 items, 20 levels, many modes, online leaderboards and achievements
[Steam store page, read 2026-08-11]. Emberdelve is at roughly one order of magnitude less content.
That is not a criticism of a three-week-old game — it is the yardstick a r/roguelites reader
silently applies within 20 minutes.

## 3. The economy runs dry in about eleven runs

From the constants (normal difficulty):

- Embers per fight: `range(8, 20)` → mean **14**. Boss: **+40**.
- A path visits 7 middle nodes; kind weights give ≈3.1 fights, 1.1 elites, 1.1 events, 0.8 rests,
  0.8 shops → **≈5.2 combats + boss** per completed run.
- **≈113 embers per winning run.** Blended with losses (assume ~45% completion) ≈ **79/run**.
- Total ember sink that exists: 120 + 200 + 320 (delvers) + 60 + 60 + 100 (themes) = **860**.

**860 / 79 ≈ 11 runs to buy literally everything a free player can buy.** At an estimated 12–20
minutes a run that is **3–5 hours, i.e. day 3 to day 7** for an engaged player. After that:

- embers still accumulate, with **zero sink** — the number becomes decoration;
- the only remaining goals (hard difficulty, ascension rungs 1–20) are **behind the $3.99 Forge**;
- for a non-payer there is, structurally, **nothing left to work toward**.

That is the single most important retention fact about the current build.

## 4. Return-likelihood ratings

Market baseline, real data, not folklore: GameAnalytics 2025 across 11,600 games — **D1 median 22%**
(top quartile 25–27% Android), **D7 median 3.4–3.9%** (top quartile 7–8%). The widely quoted
"40% D1 / 20% D7" targets have no measured backing [GameGrowthAdvisor, 2026-03-17, citing
GameAnalytics 2025].

| Horizon | Rating | ESTIMATE | Why |
|---|---|---|---|
| **Comes back next day (D1)** | **6/10** | 20–28% | Strong on-ramp: tutorial overlay, easy-mode steering for fresh profiles, visible intent, deterministic resolution, 24.5 MB download, no ads, no timers. Weak: no reminder of any kind, no account, unknown crash profile on cheap devices. |
| **Plays again within the week (D7)** | **6.5/10** | 6–10% — above market median | The unlock cadence (first delver at 120 embers ≈ run 2) plus the Daily Delve carry week one. This is genuinely the strongest part of the design. |
| **Still playing at D30** | **3/10** | 1–3% free / 10–20% Forge owners | The §3 cliff lands squarely inside week two. No achievements, no leaderboards, no cloud save, no new content arriving, nothing to spend on. |
| **Uninstalls eventually** | **high, ~85–95%** | — | Normal for the genre and not the right thing to fight. The goal is to move the uninstall from day 4 to day 40, and to have it happen *after* a purchase and a review, not before. |

### Where the uninstall actually happens, in order

1. **Minutes 0–5, first fight.** The universal cliff. Already well defended.
2. **Runs 3–5.** All 9 regular enemies and most events have been seen. Repetition starts here — this
   is the "boring" the owner is feeling, and it is a *volume* problem, not a mechanics problem.
3. **Runs 8–11 (day 3–7). The big one.** Every purchasable thing is bought. Progression flatlines.
4. **The paywall beat.** A player who wants a harder game meets the Forge gate. Converts (good) or
   walks (bad) — and note that a player who churned at cliff 3 never even reaches this beat.
5. **Day 30+.** Nothing new has ever arrived. No content updates, no seasons, no reason for the app
   to re-enter their head.

## 5. What to build, in order of retention per hour of work

All of this passes spec §Ethics: no energy timers, no decaying streaks, no loss-framed
notifications, no FOMO expiry, no rigged near-misses, no pay-to-skip.

**P0 — Delver's Ledger achievements (~1–2 days).** 30–40 *metric* achievements over real feats
("win with the Ascetic", "end 10 fights on an exact kill", "clear layer 7 without a rest",
"beat all three bosses"). Evidence: users completing a **metric** achievement on day 1 retain at
**33.96% at D30** vs **20.46%** for users completing none; streak achievements only reach 25.57%,
and retention rises monotonically with achievement difficulty — up to 74% for the 30–100x bucket
[Trophy platform data, April 2026]. This is the rare retention lever that is *both* the most
effective and the most compatible with the ethics charter — hard, honest, non-time-based goals beat
streaks on their own numbers. `MetaState` already tracks `charRuns`, `charWins`, `exactKills`,
`bestExactStreak` and `runHistory`, so most of the data exists; this is mostly a data table plus a
screen. Local-first — no Play Games Services dependency.

**P1 — A bottomless ember sink (~1 day).** Ship 8–12 more hearth themes plus a cosmetic dice-skin
set, priced in embers, and a Codex (enemy/relic lore entries bought with embers). Cosmetic only, so
no power creep, no ethics problem — but the number on screen keeps meaning something past run 11.

**P2 — Content volume, data-only (~2–4 days).** `lib/data/*` is content-as-data with zero logic, so
this is the cheapest quality-per-hour work in the codebase: **17 → 30 enemies**, **3 → 6 bosses**,
**16 → 28 events**, plus ~10 relics. Target: a player should not see a repeat regular enemy inside
one run, and should meet a new boss on runs 1–6. This is the direct answer to "less boring".

**P3 — Weekly Delve + run mutators — DONE (v0.4.4, 2026-08-11).** Monday-aligned 7-day seed
(`weeklySeed`/`game/weekly.dart`) with ONE declared modifier per week, picked deterministically
from `data/mutators.dart` (`all_d4` Flint Week, `elites_only` Elite Gauntlet, `no_shops` No Quarter).
Modifiers live in the sealed sim as an opt-in `sim.mutators` set — empty on every normal/Daily run,
so the golden anchor is byte-for-byte unchanged. Local best kept in meta (`lastWeekly*`,
`weekliesPlayed`), one record, no streaks, no expiry (§Ethics) — a missed week is simply a missed
week. Title button + declared-rule blurb + recap, in-run badge, copyable summary result. Autoplay
(150 seeds/mutator, 0 invalids): normal 64% → no_shops 65% → all_d4 20% → elites_only 3% — a real
difficulty ladder. 21 new tests (`test/weekly_test.dart`). Future: leaderboard hook (P5) can read the
weekly seed+mutator directly.

**P4 — Cloud save (~2–3 days).** Progress currently lives in one local file via `path_provider`.
A wiped phone is a lost player, permanently. Play Games Services saved games, or Appwrite.

**P5 — Daily leaderboard (~3–5 days, needs a backend).** The strongest honest daily hook: a shared
seed plus other people's results. Needs infrastructure and moderation thinking, so it is last.

### One business question, not an engineering one

**Consider making `hard` free and keeping only the ascension ladder paid.** Hard difficulty is the
natural week-two content; today it sits behind the same gate as the endgame ladder. Players who
churn at cliff 3 never convert, so gating the *second week* likely costs more Forge sales than it
protects. Keeping ascension 1–20 paid still leaves a real supporter tier. This is a revenue call, so
it stays the owner's.

### Do not build

Streak counters, energy, daily-login rewards that decay, "your delvers miss you" notifications,
timed events that expire, or any near-miss amplification that is not real. They are banned by spec
§Ethics, and on the achievement data above, streak mechanics *underperform* metric goals anyway.
An **opt-in, neutral** "today's Delve is ready" notification is arguably compatible with the charter
— it is a fact, not a loss frame — but it is a judgement call for the owner, not a default.

## 6. How we will know it worked

Once early access has real users: watch D1 and D7 in Play's retention report, `runsPlayed`
distribution, the share of profiles that reach 11+ runs (cliff 3), Forge conversion among profiles
with 10+ runs, and achievement-completion rates by difficulty bucket. If D7 lands under ~5% with a
healthy D1, the problem is content volume; if D1 itself is under ~18%, the problem is the first
five minutes or stability on low-end devices.
