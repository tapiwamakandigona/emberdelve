# Emberdelve — UI Design System (M2, 2026-07-23)

Sources: UXPeak channel (owner-directed, 2026-07-23) — "The UX Psychology Behind
Apps People Can't Stop Using" (youtu.be/2TlIg3VokY8), "9 UI/UX Typography Laws",
UXPeak Medium tip series, plus mobile-game UI research. Applied to a portrait,
one-thumb, dark roguelite. All of this must respect docs/spec.md §Ethics —
UXPeak's own rule: psychology to clarify, never to manipulate.

## 1. UX psychology (from the flagged video, applied honestly)
| Principle | Application in Emberdelve |
|---|---|
| Smart defaults | One offer/option per choice screen is pre-highlighted "RECOMMENDED" (deterministic heuristic: biggest pool upgrade). Player scans + adjusts instead of deciding cold. Default character pre-selected. |
| Goal-gradient / endowed progress | Unlock tracks never render at 0%: the first run's completion honestly counts toward the first unlock ("2/8 — 6 to go" style). Progress bars everywhere show earned progress, never fake. |
| Value before commitment | Title screen: "Delve" is the single primary CTA — tap-to-play in 2 taps, no menus first. Death screen leads with gains (embers, track progress, insight), not "GAME OVER". |
| IKEA effect | Dice pool screen frames the pool as *built* ("Your pool — forged over 12 fights"). Forge names persist per run. |
| Loss aversion (ethical) | Never loss-framed nags. Inverted: death ledger shows what you KEEP (embers banked). Rest-vs-forge choice shows both outcomes before commit. |
| Anchoring/contrast | Shop prices always next to gold balance; upgrade offers show old→new die side by side. |

## 2. Typography (UXPeak "9 laws")
- Two families, both OFL, bundled: **Cinzel** (display — titles, screen headers, boss names) + **Inter** (UI/body/numbers, tabular figures for stats).
- Scale (px @ 1x): display 34, h1 26, h2 20, body 16, label 13, micro 11. Weights do hierarchy before size does.
- Line height: body 1.5; headings 1.15–1.2 (never 1.5 on large text).
- **Values over labels**: numbers (HP, gold, embers, damage) render big/bright; their labels small/dim UPPERCASE micro text.
- Left-align text blocks; center only short display lines. Line length ≤ ~38ch.
- Contrast: all text ≥ WCAG AA on the dark bg (checked in theme constants).

## 3. Spacing & layout
- 4/8pt grid: all paddings/gaps from {4,8,12,16,24,32,48}.
- Spacing encodes relationship (law #2): heading sits close to its content (8) and far from the previous block (24–32). Card inner padding 16, section gaps 24.
- Portrait 9:16, one-thumb: primary action always in the bottom 25% of the screen; destructive/secondary actions above it. One primary CTA per screen.
- Chunking: combat HUD groups = (enemy: intent+hp) top / (dice tray) middle / (actions) bottom.

## 4. Color
- Dark warm palette ("delve"): bg #141019, surface #1E1826, raised #2A2136, line #3A3148.
- Text: primary #EDE6DA, dim #9A8FA0, disabled #5E5668.
- Accent ember #F08A2C (primary CTA, embers); gold #E8C24A; HP #E05656; block #5B8DD9; success #6FBF73; danger #C24040.
- Node kinds keep distinct hue + icon letter (color never the only signal).
- Semantic use only — accent is *scarce* so hierarchy stays honest (UXPeak: emphasize the right element; if everything is loud, nothing is).

## 5. Motion & juice (M2)
- Feedback <100ms for every tap (scale 0.96 press, ripple-free custom).
- Dice roll: 300ms staggered tumble; damage numbers float+fade 500ms; HP bars animate width 250ms ease-out; screen shake 150ms on player damage ≥ 25% max HP.
- Never block input on animation > 400ms; all skippable by next tap.

## 6. Misc UXPeak tips applied
- Empty states coach ("No relics yet — elites guard them").
- Button order consistent: primary right/bottom, secondary left/top.
- No content behind banners: map shows the whole run; shop shows all stock at once.
- Forms N/A (game), but seed entry (daily runs later) gets smart default = today's seed.
