# Checkpoint 05 — Play closed testing goes live + tester campaign day one (2026-07-24)

Narrative record of publishing day: what we did, how it went, and what it
taught us. Companion to the 2026-07-24 entries in `progress.md` and the
"Google Play closed testing" section of `docs/release.md`.

## 1. The publish journey — how we got to "live"

- **Submission → review → PASSED.** The closed-testing submission (release
  **12, v0.3.9+12** — the molten-obsidian icon build, CI-signed with the
  permanent upload key) cleared Google Play review on 2026-07-24. The app is
  live on the **"Closed testing - Alpha"** track in **177 countries** under
  developer account **Tsoro Studios**.
- Store listing (copy from `docs/store/play-listing.md`, screenshots from
  `docs/store/screenshots/`) and privacy policy (GitHub Pages) were accepted
  as-is — no listing rejections.
- Tester plumbing: a public Google Group (`emberdelve@googlegroups.com`,
  one-click join, no approval) is wired to the Alpha track; testers join the
  group → open the opt-in link → install from the Play Store.
  - Opt-in: https://play.google.com/apps/testing/com.tsorostudios.emberdelve
  - Store: https://play.google.com/store/apps/details?id=com.tsorostudios.emberdelve

## 2. The constraint that shaped the day

Personal developer accounts must show **12+ opted-in testers for 14
continuous days** before "Apply for production" unlocks. So the moment review
passed, the real job became **tester recruiting** — every hour without 12
testers delays launch a day.

## 3. Tester recruiting — what we did

**Reddit test-for-test.** Posted recruiting threads on the two communities
built for exactly this:

- r/AndroidClosedTesting — https://www.reddit.com/r/AndroidClosedTesting/comments/1v5dybo/
  (subreddit rule: only Google Play / Google Groups links allowed in posts)
- r/TestersCommunity — https://www.reddit.com/r/TestersCommunity/comments/1v5e11b/
  (requires "Testers Needed" flair; mods ask devs to add
  `testers-community@googlegroups.com` to the track — done, submitted for
  review same day)

The norm there is **reciprocity**: devs test each other's apps. We honored
every deal the same day — joined their groups, opted in, installed their apps
on the owner's test device, and replied to confirm. Partners reciprocated
(rounds 1–3, in order):

| Reddit user | Their app | Status |
|---|---|---|
| Vincibolle | Pump! | Opted in (app not available for our devices — no install possible) |
| goatboythc | Light Painter Cam | Full reciprocation (paid app at 100%-off promo) |
| donkaike | Songbird | Full reciprocation |
| Lazy_Time3597 | Risk Rush | Full reciprocation |
| ResortOk7888 | MineFreeper | Full reciprocation (they reported our opt-in link "broken" — link verified fine) |
| SillyVermicelli7169 | Poker-ish | Joined + opted in; install pending |
| Drivepulse00 | DrivePulse | Email-based test list; awaiting their link |
| Traditional_Ride1503 | FieldReportX | Joined + opted in; install pending — **we committed to keep testing 16+ days** |
| Sad_Possibility6623 | VoiceOfDestiny | Joined + opted in; install pending |

One approach was **declined**: a dev asked for a 5-star review of their
*live* production app instead of a test. Review-for-review violates Play
policy; we don't do it. (No review was written.)

A transient Play-web outage blocked some remote installs late in the day
(install dialog never loaded); opt-ins were completed regardless — opt-in is
what counts for the tester criterion — and installs retry later.

## 4. How it went — outcomes

- **Group membership 10 → 20 in ~90 minutes** after the Reddit posts went up.
- **The 12-tester criterion was MET the same day** (2026-07-24) — the Play
  dashboard flipped to a checkmark. The 14-day clock is running:
  earliest "Apply for production" **~2026-08-07**, realistic public launch
  **~Aug 10–14**.
- Note: once the criterion is met, Play **hides the exact opted-in count**;
  proxies are group membership + testing-track install stats. A dip below 12
  resets the clock, so recruiting continues (over-recruit; some testers will
  drop).

## 5. First tester feedback (day one)

- **"How is damage calculated?"** — answered publicly with the real formula
  from `lib/sim/combat.dart`: attack = die face + die bonuses + pair bonus +
  relic bonuses; enemy block absorbs damage first. This exposed a real gap,
  and we **publicly promised an in-game tutorial "in the next update"** —
  `lib/ui/screens/tutorial_overlay.dart` exists; wiring/verifying it is a
  blocker for the next release.
- One tester in Germany reported the app "can't load" — it is live there;
  most likely they installed without joining the group/opting in first.
  Onboarding instructions may need to be even more explicit.

## 6. Lessons recorded

1. **Recruiting is the launch bottleneck**, not the build. Post to
   test-for-test communities the moment the track is live.
2. **Reciprocate fast and visibly** — same-day reciprocation is why partners
   followed through and the criterion was met in hours, not days.
3. Verified Play mechanics (full list in `docs/release.md`): updates and
   listing edits do NOT reset the 14-day clock; testers get no explicit
   update notification (Play auto-updates ≤~24h); mid-review submissions
   trigger a confirmable "restart review?" dialog.
4. Follow each subreddit's posting rules exactly (link restrictions, flair,
   mod group) — removals waste a day.
5. Never trade store reviews. Test-for-test only.

## 7. Next

- Keep the tester count safely above 12 through ~Aug 7 (monitoring is
  automated on the owner's side; obligations honored for partners' test
  windows).
- Next update: **in-game tutorial (promised, blocker)** + the
  core-gameplay-simplification pass the owner is considering + refreshed
  screenshots — all in **one** submission.
- ~Aug 7: "Apply for production" questionnaire → Google application review →
  production release review → public launch.
