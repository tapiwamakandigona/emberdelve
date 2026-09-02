# Owner Console checklist — the six numbers that turn R4/R5 inference into fact (≈10 min)

Play Console → Emberdelve. Record each with the date; paste into retention-ledger.md's next row.

| # | Where | Read | Why it matters |
| --- | --- | --- | --- |
| 1 | Financial reports → Orders (lifetime) | Unit count of `ember_forge_unlock` | R4 §2 predicts **1**. If it is 2+, the $4.25 figure was a period, not lifetime, and R4's conversion math changes. |
| 2 | Ratings and reviews → Ratings | *Users* and whether *Total ratings* is shown | R4 §4.2: Total ratings appears at 5+; the public star is expected at/after that point. |
| 3 | Grow users → Store performance → Conversion analysis (90 days) | Visitors, unique clicks, CTR | **The decisive number.** Visitors ≫ installs = listing leak (R3 applies now). Visitors ≈ installs = traffic problem (traffic-channels.md). Note the June/July 2026 metric change to unique clicks ([9859173](https://support.google.com/googleplay/android-developer/answer/9859173)). |
| 4 | Statistics → Retention (acquisition cohorts) | D1 / D7 / D30 for August's cohort | R5 rests on "D7 = 1 device". A D1 figure says whether people even reopen once. |
| 5 | Statistics → New users acquired, **Lifetime** (dropdown, not 28 days) | Lifetime unique installers | The public badge says **50+** while the directive says 38 — different metrics (R4 §7). This is the denominator every ratio in R4 should use. |
| 6 | Ratings and reviews → Testing feedback | Count of tester ratings | Tester ratings never reach the public listing ([9845334](https://support.google.com/googleplay/android-developer/answer/9845334)); if the 5-star of 31 Aug is here, it will never surface on the page regardless of volume. |

Do not act on any single row; the ledger's tiny-n rule stands (one device ≈ 4% at 28 MAU).
