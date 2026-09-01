# Retention ledger — monthly Play Console pull (R2 Option A)

> **Constraint (owner directive 2026-09-01b, DEMAND.md): retention is
> measured from Play Console's aggregate device metrics ONLY. Do not
> propose or add analytics, telemetry, event beacons, or any
> phone-home to answer a retention question. The listing promises no
> ads, no tracking, plays offline — that promise is the product's
> strongest asset (see r3-supplement-trust-headline.md). If a question
> cannot be answered without new tracking, write down that it is
> unanswerable under the promise and name the closest aggregate-only
> proxy. Do not re-open this.**

Instrument of record for the Seven Hearths falsifiable prediction
(progress.md, v0.178.0): *day-7 retention among new devices moves off
1 within 28 days of ship (shipped 2026-09-01 → judge ~2026-09-29).*

## How to fill a row (10 minutes, owner holds Console access)

1. Play Console → Statistics: MAU, new devices for the month.
2. Statistics → retention view (or User acquisition → retained
   installers CSV via Cloud Storage, support.google.com answer
   6135870): D1 / D7 / D30 for the month's acquisition cohorts.
3. Store presence → Store listing performance: visitors → installs
   conversion.
4. Android vitals: crash rate, ANR rate (guardrail: keep 0).
5. Append one row; never edit old rows (they are the record).

## Ledger

| Pulled | Window | New devices | D1 | D7 | D30 | MAU | Listing conv. | Crash/ANR | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 2026-09-01 | baseline (pre-v0.178.0 on Play; prod build 0.59.0) | — | — | 7-day retention = 1 device | — | 28 | — (38 lifetime installs, 2 ratings) | 0 / 0 (28d) | Baseline from owner-relayed Console facts [console, 2026-08]. Seven Hearths not yet in any Play build. |
| ~2026-09-29 | Sep 2026 | | | | | | | | Prediction check. NOTE: Play prod is still 0.59.0 — if v0.178.0 has not shipped to Play by the pull date, the prediction window has not actually started for Play users; record and re-anchor. |

## Reading rules

- Tiny-n honesty: at ~28 MAU a one-device change is ~4% — never read
  a single row as a trend; three rows minimum before any conclusion.
- The prediction is judged against cohorts acquired AFTER the Seven
  Hearths build is live on the player's store channel (GitHub
  sideloaders count from v0.178.0; Play users only after the Play
  ship). Anchor each judgment to the right channel.
- Listing conversion rows feed R3: any listing change gets a note in
  the row it lands in, so before/after is readable.
- Traffic-channel attribution (traffic-channels.md, second pass): the
  Play Console acquisition timeline is the ONLY attribution
  instrument (no UTM, ever — see header). If the owner runs the
  channel sequence, each post gets its own note row here on its date
  ("posted r/AndroidGaming YYYY-MM-DD") so the weekly install delta
  next to it is readable. One channel per 7-day window; overlapping
  posts destroy the only attribution we have. Falsification criteria
  live in traffic-channels.md — judge each channel there, record the
  raw numbers here.
