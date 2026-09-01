# Game-feel borrowings — what the indie field does, what we take

Research pass 2026-09-01, per the standing directive: study how indie
devs make games feel good on low-end hardware and borrow what earns
its place. Method: web survey of current (2026) game-feel writing and
postmortems, checked against Emberdelve's existing juice inventory
before proposing anything — most "add juice" advice describes things
this game already ships.

## Sources worth keeping

- Balatro feedback analysis (blakecrosley.com/guides/design/balatro):
  feedback is not post-hoc polish — the score ROLL, sequential joker
  fires, and shake were designed with the scoring system. Lesson:
  juice belongs on the moments the design already calls important.
- Sinfull Studios "Why the Same Mechanics Feel Different" (2026-02):
  hit-stop of 3–6 frames on heavy contact is the single most reliable
  feel trick; ease-out on recovery, ease-in on anticipation.
- Solana Garden game-juice guide (2026-06): 150ms with overshoot beats
  150ms linear; curves carry more feel than durations.
- JRPG animation bible (github.com/patrickdugan/JRPG): combat
  animation must make the turn system EASIER TO READ — wind-up,
  concise active frames, held recovery. "It must never redefine a
  combat result" — the honesty framing, independently arrived at.
- Zero-alloc game loops (grzegorzotto.dev, 2026-05): hot-path
  allocation discipline (pools, out-params) is how a TS engine holds
  60fps on mid-range Android. Flutter analogue: no object churn inside
  paint()/build() on per-frame paths.
- Jetpack Compose RPG postmortem (2026): 40 monster variants from two
  sprite sheets via ColorFilter hue rotation, 50% RAM cut — exactly
  our doc-hue system (mender/cutler/hearthkeeper). Independent
  validation, nothing to change.

## Inventory check — already shipped (do NOT re-add)

Screen shake (damage-scaled), hit-stop (_hitStop at frac≥0.25),
hit-flash (white srcATop 60ms), squash/windup/knock/death timings,
exact-kill notes, DamagePop/TextPop with overshoot, spent-die ghost
flight, WeaponView easeOutBack follow-through, block pop with
overshoot, EmberDrift ambience, shader warmup so the FIRST juice
moment doesn't stutter, reduce-motion gating on all of it. The 2026
advice list is ~90% covered; the gap analysis found exactly two real
candidates.

## Borrow #1 — TAKEN: The Settling Count (summary embers roll-up)

Balatro's rolling score, sized to our one payoff number. "Embers
banked" on the summary was a static string — the screen the whole run
pays into showed its reward with no arrival. Now `_SettlingCount`
(summary_screen.dart) counts 0→N in 700ms easeOut, once, then rests.
Honesty contract: the resting value is exact; under reduce motion the
exact number shows on the first frame (a delayed fact is a cost, not
a courtesy). Pinned by test/settling_count_test.dart (exact rest,
climbs mid-flight, no replay, reduce-motion first-frame).

Deliberately NOT extended to: gold/ember top-bar deltas (mid-run
numbers change constantly — rolling them would blur cause and
effect), fights-won/floor rows (facts, not rewards — one settling
number keeps the eye on the one that matters).

## Borrow #2 — CONSIDERED, PARKED: sequential ledger-row reveal

Staggered row entrance on the summary panel (each ledger row fading
in ~80ms apart) would echo Balatro's sequential fires. Parked because
the summary already has a designed moment (delver + headline + ember
drift) and the panel is inside the drag RepaintBoundary — a stagger
would re-rasterize the cached column during entrance. Revisit only if
a summary redesign happens anyway.

## Rejected for this game

- Camera zoom-punch / look-ahead: no camera; combat is a fixed stage.
- Motion ghosts/trails: pixel sprites at 56dp read as smear, and
  per-frame ghost layers fight the repaint budget on low-end.
- Particles beyond EmberDrift/sparks: ambience is the identity;
  confetti isn't.
- Haptics on hits: worth a look ONLY as an opt-in setting; default-on
  vibration on a quiet turn-based game reads as noise. Backlog, owner
  call.

## Perf discipline confirmed by this pass

The zero-alloc article's rules map onto standing lessons (painters
hold their Paint objects, probes gate paints/frame). One addition to
watch in review: TweenAnimationBuilder in per-frame paths creates an
implicit animation controller per mount — fine for one-shots like
_SettlingCount, wrong for anything inside a combat frame loop.

Audit of every 60fps painter (2026-09-01): _EmberDriftPainter,
_EmberBurstPainter, _FlameWipePainter, weapons' sway painter, and
EmberLogotype all held their Paint objects already (the logo also
caches TextPainters and quantises its pulse). The one churn found and
fixed: _SpritePainter (sprites.dart) allocated a fresh Paint every
frame for every idling sprite — now a late-final per-instance Paint
(the painter instance survives frames; repaint rides the listenable).
Weapons' per-frame SweepGradient shader during a smear is inherent
(angle-dependent) and transient — left alone, documented here so
nobody "fixes" it into a stale-angle bug.
