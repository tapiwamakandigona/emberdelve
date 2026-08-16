# Emberdelve — Launch Checklist & Go/No-Go

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

| # | Gate | Green threshold | Where to read it | Status |
|---|---|---|---|---|
| G1 | **Crash-free rate** | ≥ 98% sessions (ANR < 0.47%) | Play Console → Quality → Android vitals | ⛔ *no data yet — generate a pre-launch report* |
| G2 | **Pre-launch report** | 0 crashes on the robo test across device set | Play Console → Testing → Pre-launch report | ⛔ *never generated* |
| G3 | **Progression cliff closed** | P0 achievements **and** P1 ember sink shipped (see below) | `features.json` + build | ⛔ *P0/P1 not shipped* |
| G4 | **D1 retention on early-access cohort** | ≥ 20% (market median 22%) | Play Console → Statistics → Retention (needs real installs on v0.4.x) | ⛔ *0% on v0.4.x — nobody has played it yet* |
| G5 | **Public rating** | ≥ 4.0★ **or** 0 ratings (no bad ones locked in) | Play Console → Ratings | ✅ *0 ratings / 0 reviews — clean slate* |
| G6 | **Store listing final** | copy, 512 icon, 8 phone screenshots, feature graphic, privacy URL live | `docs/store/` | 🟡 *drafted; needs owner sign-off + live privacy URL* |
| G7 | **Signing = permanent upload key** | cert SHA-256 matches pinned fingerprint | `docs/release.md` / CI | ✅ *permanent keystore + CI verify in place* |

**Verdict logic:** all green → **GO**. Any ⛔ → **NO-GO, fix first**. 🟡 → owner action.

As of 2026-08-16 the honest verdict is **NO-GO for a full 1.0 launch** — but see the
two legitimate lighter options below.

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
