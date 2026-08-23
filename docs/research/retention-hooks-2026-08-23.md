# Retention hooks research — what keeps players delving (2026-08-23)

Directive: "research what makes audiences addicted to our game and interested in
playing it, hooks and all." Grounded in a web pass (sources below) + the first
outside player review (WhatsApp, Aug 23) + our own ethics charter (docs/spec.md
§Ethics: no fake urgency, no streak shame, no FOMO vocabulary — the banned-word
sweep is enforced by tests). Everything here is a *kind hook*: transparent,
player-serving, no dark patterns. That is a positioning asset, not a constraint.

## What the industry data says (2026 sources)

1. **First session decides D1.** Benchmarks put a healthy D1 at ~22–27%+; the
   levers are first-session speed, first-win timing, and tutorial framing
   (gamegrowthadvisor.com 2026-03, segwise.ai 2026-07). → v0.26.0's anchored
   tour attacks exactly this. Easy-mode steer (steerToEasy) already lands the
   first win early.
2. **Deckbuilders retain via agency-under-randomness.** "You have to feel like
   you could have done something different" (ggrecon roundtable); the ~70/30
   skill/luck feel (NYU Game Innovation Lab via StS2 analysis). → Our fairness
   bands (easy 80–90 / normal 55–70 / hard 30–45) and honest event copy are the
   moat; never trade them for a hook.
3. **Meta-progression motivates when it adds options, not raw power**
   (bugnet.io 2026-06). → Ember sinks that widen choice (characters, codex,
   cosmetics) are correct; permanent stat creep would trivialize the run skill
   loop and break our fairness claims.
4. **Every session should end with a visible next action** — "a collection
   milestone, a quest chain… a cliffhanger without the trap" (gamebracelet
   2026-04). → Our summary screen currently ends cold. Biggest open gap.
5. **Content expectation: ~8+ hours before a player has seen everything**
   (newtonarrative). Unlock pacing matters in both directions.
6. **Ethical microloops are a real school of design** (game-online.pro
   2026-05): transparent about what you get, why, and what happens next;
   "pleasantly compelled, not trapped." No purchase pushes at high-stress
   moments (gamineai). → Matches the charter we already test-enforce.
7. **Enemy variety that demands specific responses** keeps the core loop from
   becoming "math homework" (choostgames 2026-04). → Our intent/behavior mix
   already leans this way; future content drops should add *response puzzles*,
   not stat sponges.

## What our first outside review says (n=1, weight accordingly)

- "Finished easy mode… game is good and fun" → the Easy→Normal bridge is now a
  live retention moment with zero design on it.
- "Still don't understand what's a delve" → the core noun is unexplained
  anywhere in-game. Charming confusion once; friction at scale.
- Asks: character customisation; changing backgrounds. Likes: boss designs,
  music (9/10).

## Hook map for Emberdelve (prioritized, all charter-clean)

| # | Hook | Mechanism | Status |
|---|------|-----------|--------|
| 1 | Identity/expression | Delver dyes on the character you pick (review ask) | v0.27.0 |
| 2 | World freshness | Depth-graded strata backgrounds (review ask) | v0.28.0 |
| 3 | Next-action ending | Summary screen: earned next step (Normal nudge after Easy win, codex/collection progress line) | v0.29.0 candidate |
| 4 | Naming the fantasy | "A delve" defined in-game (one lore line + codex) | v0.29.0 candidate |
| 5 | Social proof loop | Play In-App Review after 2nd win (marketing ask; API-quota silent, once per install) | queued |
| 6 | Collection pull | Codex completion % made visible where it's earned | later |
| 7 | Mastery ladder | Ascension already exists; surface "next ascension" on win | later |

Anti-goals (would violate charter or fairness): daily streak counters with
loss-aversion framing, timed offers, push-notification nagging, permanent
power meta-progression, purchase prompts after a loss.

Sources: overbaked.studio (2026-07), blog.birdor.com StS case study (2026-02),
ggrecon roundtable, jinguli StS2 analysis (2026-03), bugnet.io (2026-06),
newtonarrative (2025-05), choostgames (2026-04), gamegrowthadvisor (2026-03),
gameboard.online (2026-05), game-online.pro (2026-05), gamineai (2026-03),
pushwoosh (2026-06), segwise.ai (2026-07), playio (2026-07), gamebracelet
(2026-04).
