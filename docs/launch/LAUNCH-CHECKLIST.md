# Emberdelve — Launch Checklist & Go/No-Go

> **SUPERSEDED (2026-09-01)** for the ship decision by
> `docs/store/PLAY-APPLY-DAY.md`: prices, track facts, and gates below
> are from the v0.7.0 era (2026-08-16) and predate the 0.59.0 prod
> release, the $4.99 Ember Forge, and the v0.178.0 one-release freeze.
> Kept for history; do not action.

**Purpose.** Turn "should I release?" from a gut call into a data-backed decision.
"Release" here = promoting the current early-access build to a **full production
launch** with a coordinated free-channel push (Reddit + LinkedIn dev-log). It is a
**one-time discoverability moment** — Play surfaces new/updated apps hardest right
after a stable production release — so we spend it on a build that earns it.

> **Repo note (2026-08-16).** This game (Emberdelve, the dice roguelite that is on the
> Play Store) now lives on the **`legacy/dice-builder`** branch, currently **v0.7.0+33**.
> `main` was pivoted to a separate unreleased platformer ("Emberwood",
> `com.tsorostudios.emberwood`) built by a different agent. Keep marketing for the dice
> roguelite on THIS branch; do not touch `main`.
>
> **Data-freshness caveat:** the retention numbers cited below come from
> `docs/improvements/retention-2026-08-11.md`, taken at **v0.4.x**. The game has since
> advanced to v0.7.0 (13 keystones shipped per `keystones-shipped-2026-08-12.md`,
> `v7-gates-2026-08-12.md`). **Re-read the latest improvement docs + regenerate a Play
> Console retention pull before treating any specific figure as current.**

Store listing already says **"Free forever"** with a **$3.99 Forge IAP** (hard
difficulty + ascension rungs 1–20). So this is a real monetizable product, not a
throwaway free game — the launch should be treated accordingly.

---

## The one decision rule

> **Do not spend the launch moment on a build with an open progression cliff.**

The retention analysis (`docs/improvements/retention-2026-08-11.md`, VERIFIED counts)
found the single most important fact: a **free player buys everything purchasable in
~11 runs (day 3–7), then has nothing left to work toward.** Launching hard into that
cliff means paid acquisition of players who churn at day 5 and leave a mediocre
rating that outlives the fix. The download bump (22→34) is encouraging but is a
**vanity metric** — retention and rating decide the launch, not install count.

---

## GO / NO-GO gates (all must be green)

**Live console data as of 2026-08-16 (VERIFIED, `madie` session logged into Play Console):**
- Installed audience: **32** (was 22 on 7 Aug → this is the "22→34" bump). ~40% Zimbabwe, then AU/DE/UK ~6% each, 5 countries total.
- Tracks in use: `0.7.0 (33) "The Face Forge"` on **Early Access (open testing)**, full roll-out — but only **9.09%** of the base has updated to it. `0.4.2 (27)` Closed-testing Alpha holds **48.48%**. `12 (0.3.9)` Internal testing 15.15%. Production track = **Inactive**.
- Production **access granted** (12-tester gate cleared).
- Android vitals crash-free + ANR = **"Data unavailable"** (too few sessions + opt-in telemetry off).
- Ratings/reviews = **0**. Pre-launch report = **never generated**.

| # | Gate | Green threshold | Where to read it | Status (2026-08-16, VERIFIED) |
|---|---|---|---|---|
| G1 | **Crash-free rate** | ≥ 98% sessions (ANR < 0.47%) | Monitor & improve → Android vitals | ⛔ *"Data unavailable" — no vitals yet (few sessions + opt-in telemetry). Won't self-resolve without more players → G2 is the only path to stability evidence.* |
| G2 | **Pre-launch report** | 0 crashes on robo test across device set | Test & release → Pre-launch report | ⛔ *never generated even though 0.7.0 was uploaded to Early Access. Likely cause: the robo crawler can't drive a Flutter/Flame render canvas, so it yields nothing without a **Firebase Test Lab "game loop"** integration (`com.google.intent.action.TEST_LOOP` handler + `android.game_loop` metadata — a dev-side change, the Emberwood/dice agent's domain). Settings page (test creds / deep links / robo script) is ready if a game-loop target is added.* |
| G3 | **Progression cliff closed** | P0 achievements **and** P1 ember sink shipped | code on this branch | ✅ *VERIFIED shipped (2026-08-16). **P0:** `lib/data/achievements.dart` = 20 metric achievements (runs_won, char_wins, exact_kills, hard_wins, bosses_beaten, delvers_cleared, best_ascension …) — the metric type that retains best per the retention doc. **P1:** ember sink ≈ **3,175 embers** — hearth colors 4→12, 7 dice skins (150–400), 53-entry Codex (all 30 enemies + 23 relics, lore-only). vs the old 860-ember total that ran dry at run 11 → ~4× runway. Caveat: this is a structural fix; actual post-fix retention still unmeasured (needs G1 data).* |
| G4 | **D1 retention** | ≥ 20% (market median 22%) | Statistics → Retention | ⛔ *not measurable: base too small (32) and split across 3 tracks; only 9% on newest build* |
| G5 | **Public rating** | ≥ 4.0★ **or** 0 ratings | Ratings and reviews | ✅ *0 ratings / 0 reviews — clean slate, nothing bad locked in* |
| G6 | **Store listing final** | copy, 512 icon, screenshots, feature graphic, privacy URL live | `docs/store/` | 🟡 *assets present (512 icon, 5 phone screenshots + 1024×500 feature graphic, full listing copy). Privacy URL **VERIFIED LIVE 2026-08-16**: https://tapiwamakandigona.github.io/emberdelve/store/privacy-policy.html → HTTP 200, correctly branded Emberdelve, "collects no data" (the `main`→Emberwood pivot did NOT break it). Remaining: owner sign-off on copy + Play Console Data-safety form (telemetry was added in 0.4.3 — must update before any new upload).* |
| G7 | **Signing = permanent upload key** | cert SHA-256 matches pinned fingerprint | `docs/release.md` / CI | ✅ *permanent keystore + CI verify in place* |

**Verdict logic:** all green → **GO**. Any ⛔ → **NO-GO, fix first**. 🟡 → owner action.

As of 2026-08-16 the honest verdict is **NO-GO for a confident full 1.0 launch** — the
blocker is not the platform (production access is granted) but **zero stability evidence**
(G1/G2). Because a robo pre-launch report doesn't work out-of-the-box for a Flutter/Flame
render canvas (see G2), the realistic paths to real crash data are, cheapest first:
1. **Get the 32 testers onto 0.7.0 and read live crash-free** — only 9% have updated; nudge
   the rest, then vitals populate from real sessions. Zero code, just tester comms.
2. **Add a Firebase Test Lab game-loop** (dev-side, the game agent) so pre-launch reports
   and automated device-matrix crash tests actually run.
3. Only after ≥98% crash-free is shown → full 1.0 launch push.
See the lighter options below.

---

## Two things that ARE safe to do now

1. **Lift the early-access label on the same build** (if crash-free is confirmed via a
   pre-launch report). Low-risk: it's the same binary, just more discoverable. Do NOT
   pair it with a marketing push yet.
2. **Recruit the current 34 into feedback.** They are your most valuable asset — people
   who downloaded an unknown game. In-app or via the listing, ask the one question that
   matters: *"What made you stop playing?"* That answer is worth more than 100 more
   installs.

---

## Pre-1.0 punch list (in retention-per-hour order, from the retention doc)

Ship P0 + P1 before the launch push — together they close the day-3–7 cliff, which is
the only thing standing between a launch and a wave of day-5 churn.

- [ ] **P0 — Delver's Ledger achievements (~1–2 days).** 30–40 *metric* achievements
      over real feats. Evidence: day-1 metric-achievement completers retain **33.96% at
      D30** vs 20.46% for none [Trophy, Apr 2026]. `MetaState` already tracks the data.
- [ ] **P1 — Bottomless ember sink (~1 day).** 8–12 more hearth themes + cosmetic
      dice-skins + a Codex, all priced in embers. Keeps the ember number meaningful
      past run 11. Cosmetic-only → no power creep, no ethics breach.
- [ ] *(post-launch)* P2 content volume, P4 cloud save, P5 daily leaderboard.

**Definition of 1.0:** G1–G7 all green **and** P0+P1 shipped. That is the build the
launch moment deserves.

---

## Launch-day runbook (when 1.0 is reached)

1. **T-3 days:** promote to production, staged rollout 20% → watch vitals 24h → 100%.
2. **T-0 morning (Harare):** post the r/roguelikes / r/incremental_games launch thread
   (see `REDDIT-LAUNCH-POSTS.md`) from your phone / residential IP — *never* from the
   sandbox or VPS (both are IP-blocked by Reddit; verified). Value-first, not spammy.
3. **T-0 midday:** r/AndroidGaming "[DEV]" thread; reply to every comment within the
   first 3 hours (the algorithm and the humans both reward this).
4. **T-0:** LinkedIn dev-log post (see `LINKEDIN-LAUNCH-POST.md`) — the *building-in-
   public* angle, not a "download my game" ad. Link in first comment, not the body.
5. **T+1..7:** reply to every review and Reddit comment. Log what players actually say
   into `docs/improvements/`. First patch within a week signals a live game.

## Anti-patterns (do not do)
- No paid ads (owner constraint: free channels only).
- No FOMO / fake-urgency copy — violates the game's own ethics spec, and roguelike
  communities punish it instantly.
- Never launch on a version you'd be embarrassed to have reviewed at 1-star.
- Never post launch threads from datacenter IPs (sandbox/Azure VPS) — Reddit blocks them.
