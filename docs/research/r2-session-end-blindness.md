# R2 — Session-end blindness: honest options for seeing retention

Date: 2026-09-01. Owner brief (DEMAND 477857cf): analytics stay
**opt-in — that is a product pillar, not up for debate**. Research the
honest options for reducing our blindness about session ends and
retention, with the privacy cost of each. "Ask nothing and read Play
Console harder" is a legitimate finding.

## The problem, precisely

We shipped Seven Hearths with a falsifiable prediction (day-7
retention among new devices moves off 1 within 28 days) — but our
ability to CHECK that prediction is nearly blind:

- Firebase Analytics is opt-in, undecided = OFF
  (docs/telemetry-events.md). With 28 monthly active devices, the
  consenting subset is likely single digits — too small to read.
- We log `run_ended` but nothing at app close; even for consenters
  we can't distinguish "quit at title" from "quit mid-map".
- Play Console numbers (28 MAU, 7-day retention = 1) are our only
  population-complete signal, and we under-read them today.

## Option A — Ask nothing; read Play Console harder. **RECOMMENDED**

Privacy cost: **zero.** Google already collects this from every
install regardless of anything we do; the data exists whether we look
or not.

What's actually available free, no SDK [web, 2026-09-01]:
- Statistics page: MAU/DAU, new devices, returning users, custom
  date ranges, dimension splits (country, device, Android version).
- Retention cohorts: D1/D7/D30 per acquisition-week cohort — exactly
  the Seven Hearths verification instrument.
- User acquisition reports: retained installers (7 days after
  install) — downloadable monthly CSVs from Cloud Storage
  (support.google.com answer 6135870).
- Store listing performance: visitors → installs conversion (feeds
  R3 directly).
- Android vitals: crash/ANR rates (we already guard these).

Concrete practice change (this is the deliverable): a monthly
**retention ledger** — a dated markdown table in `docs/research/`
capturing new devices, D1/D7/D30 cohort retention, MAU, and listing
conversion, pulled from Console each month, so the v0.178.0
prediction gets checked against real cohorts on ~2026-09-29. Owner
holds Console access; the pull is a 10-minute manual task or a CSV
export we parse.

Limit: Console tells us WHETHER players return, never WHY they stop.
That gap is what R1-style qualitative work is for — it cannot be
closed by any amount of ethical telemetry at our scale anyway (n too
small to segment).

## Option B — Local, on-device session journal the player owns

Privacy cost: **zero network, but a design tax.** A small local file
(alongside emberdelve_meta.json) recording session starts/ends and
last-screen — shown to the PLAYER as a "Delver's Log" page, erasable
in Settings, never transmitted.

- Honest framing: this is a player feature (your own play history),
  not analytics. It only helps US if players volunteer it ("here's
  my log") — realistically never at scale.
- Verdict: worth doing only if the Delver's Log is independently a
  good player feature (it might be — pairs with the Ledger). As a
  blindness fix it's near-useless. Park it as a product idea, not an
  instrumentation plan.

## Option C — A genuinely informed consent prompt, better placed

Privacy cost: **unchanged in kind** (still Firebase, still opt-in),
but tries to raise the consent rate honestly.

- Today the disclosure fires at first launch — the moment of maximum
  distrust and minimum context. An honest alternative: ask AFTER the
  player has something invested (e.g., after first bank), with plain
  copy: "Want to help? Share anonymous play stats — here is exactly
  what we'd see: [the four events]. No names, no IDs, off by
  default, one tap to stop."
- Ceiling check: even a generous 3× consent-rate lift on 28 MAU
  yields maybe 10-15 consenting devices — still too small for
  cohort math. It improves anecdote, not statistics.
- Verdict: legitimate and charter-clean, but at current scale it
  cannot answer the retention question. Revisit if MAU > ~500.

## Option D — Privacy-first third-party analytics (Aptabase / TelemetryDeck / self-hosted)

Privacy cost: **real and new.** These are better citizens than
Firebase (no device identifiers, session-only counting, GDPR-clean;
Aptabase open-source/self-hostable, ~$14/mo hosted; TelemetryDeck
~$8/mo, differential privacy) [web, 2026-09-01]. But:

- They still exfiltrate events from the device, so under OUR pillar
  they'd still be opt-in — inheriting Option C's tiny-n ceiling
  while ADDING a vendor, a dependency, and a privacy-policy change.
- Verdict: **rejected at current scale.** The pillar makes the
  consent rate the bottleneck, not the vendor. If we ever revisit,
  self-hosted Aptabase is the least-bad candidate; note it and stop.

## Recommendation stack

1. **Adopt Option A now** — monthly retention ledger from Play
   Console; first entry due ~2026-09-29 to judge the Seven Hearths
   prediction (28-day window from v0.178.0 ship).
2. Keep Option C in the drawer with an explicit trigger: MAU > 500.
3. Option B only if the Delver's Log earns its place as a player
   feature on its own merits.
4. Option D rejected; re-evaluate only alongside Option C's trigger.

The honest headline: at 28 MAU, no ethical instrumentation exists
that beats reading Play Console carefully. Our blindness is mostly a
scale problem wearing a tooling costume.
