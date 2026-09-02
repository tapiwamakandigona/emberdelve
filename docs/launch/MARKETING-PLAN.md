# Emberdelve — Marketing Plan (owner approved 2026-08-16)

**Decision (Tapiwa, 2026-08-16):** *"market the game, yes you can nudge testers."*
Marketing the dice roguelite is GO. (Emberwood platformer stays in dev on `main`;
its launch is a separate future plan.)

## The key unlock
The game is **already publicly installable** via Early Access / open testing:
`https://play.google.com/store/apps/details?id=com.tsorostudios.emberdelve`
(public store page returns HTTP 200 for a logged-out Zimbabwe visitor, shows Install).
So we do NOT need a production promote before marketing — **anyone can install it today.**

**This collapses two problems into one:** the only real blocker was zero crash-free data
(vitals "Data unavailable" from too few sessions). Driving installs via marketing IS the
fix — every new player generates the stability data we were missing. Market → data comes →
confident production promote later.

## No-money constraint
Owner rule: **no paid ads.** All distribution is free channels: Reddit (from Tapiwa's
phone — Reddit blocks datacenter IPs), LinkedIn (dev-log), and the existing tester base.

## Roles
- **Tapiwa (from his phone / residential IP):** post the Reddit threads, reply to Reddit
  comments (Reddit automation is impossible from the sandbox/VPS IPs — verified).
- **Me:** everything else — drafts (done), the tester nudge, LinkedIn dev-log (when the
  session is logged back in), monitoring installs/crash-free/ratings in Play Console, and
  iterating copy from what lands.

---

## Sequence

### Phase 0 — this week (no code, no risk)
1. **Nudge the 32 testers onto 0.7.0** (`TESTER-UPDATE-NUDGE.md`). Only 9% are on the newest
   build; getting the rest current + playing is the fastest path to real crash-free data.
   Channel: whatever Tapiwa actually used to recruit them (Discord/WhatsApp/friends is likely
   more effective than the Play email list). I drafted both an email and a DM version.
2. **Watch vitals daily** until a crash-free number appears. Target ≥98%.

### Phase 1 — soft push (once crash-free ≥98% shows, or after ~1 week of tester play)
3. **Reddit, from Tapiwa's phone** (`REDDIT-LAUNCH-POSTS.md`, live link already embedded):
   r/roguelites first, then r/incremental_games (+1 day), then r/AndroidGaming `[DEV]`.
   Reply to every comment in the first 3 hours. Space them out; never blast all three at once.
4. **LinkedIn dev-log** (`LINKEDIN-LAUNCH-POST.md`): the engineering-discipline angle, link in
   first comment. Slot on a weekday morning, not the same week as the UZ "day one" post.

### Phase 2 — production promote (when vitals confirm quality)
5. Console → Test & release → Production → Create new release, staged 20% → watch 24h → 100%.
   This is a one-way public action → it gets pressed by hand, deliberately.

### Phase 3 — sustain
6. Reply to every review + Reddit/LinkedIn comment. Log real feedback into
   `docs/improvements/`. Ship a small patch within a week of the push (signals a live game).
7. Feed the best organic feedback back to the game agent as prioritised issues.

---

## What I track (Play Console, weekly)
| Metric | Where | Now (2026-08-16) | Target |
|---|---|---|---|
| Installs | Statistics → Installed audience | 32 | growing |
| Crash-free rate | Android vitals | "Data unavailable" | ≥98% |
| % base on newest build (33) | Statistics | 9% | majority |
| Rating | Ratings & reviews | 0 ratings | ≥4.0★ |

## Guardrails
- No paid ads. No fake urgency / FOMO (breaks the game's ethics charter AND Reddit norms).
- Never post launch threads from the sandbox/VPS IPs — Reddit blocks them.
- Production promote = confirm with Tapiwa first (one-way public action).
- Keep the dice-game marketing on `legacy/dice-builder`; never touch `main` (Emberwood agent).
