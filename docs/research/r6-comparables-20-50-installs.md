# R6 — What comparable offline premium roguelites do at the 20–50-install stage that we don't (directive 2026-09-01g / 02a, question 3)

Scope: free-download + one-time-unlock (our model) and paid-premium offline roguelites on
Google Play, plus the few solo devs who *published their small-stage numbers*. Store assets,
screenshot order and first sixty seconds for the four genre leaders were already torn down in
R1 (docs/research/r1-first-session-teardown.md) and are referenced, not repeated. Every claim
below carries its source; inferences are marked.

## 1. The same-model comparables

| Game | Model / price | Where the offer lives | Source |
| --- | --- | --- | --- |
| **Slice & Dice** (tann) | Free demo, single IAP unlocks full game (reviews on the listing mention $7 and $9 — regional; the listing itself does not print a price) | **First sentence of the description**: "Free demo, no ads, single IAP to unlock the full game." Demo scope is not printed on the listing | [Play listing](https://play.google.com/store/apps/details?id=com.com.tann.dice) |
| **Card Crawl** (Tinytouchtales) | Free download, one-time unlock (US$2.99 at Android launch, later £4.99 on iOS listing) | "a free download with a one time in App purchase to unlock all content. There are no Ads" | [First week on Android](http://www.tinytouchtales.com/first-week-of-card-crawl-for-android/); [iOS listing](https://apps.apple.com/gb/app/card-crawl/id950955524) |
| **Shattered Pixel Dungeon** (Evan Debenham) | Free, complete; optional *supporter* purchases; itch paid build $10 | Supporter button sits on the **title screen beside Play** (`btnSupport` placed at `btnPlay.right()+2` / under Play in portrait — [TitleScene.java](https://github.com/00-Evan/shattered-pixel-dungeon/blob/master/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/scenes/TitleScene.java)) and is described as support, not content — "pay $10 to get some extras and support the developer" | [itch page FAQ](https://shattered-pixel.itch.io/shattered-pixel-dungeon); [Donations post 2014](https://shatteredpixel.com/blog/donations-in-shattered-pixel-dungeon.html) |
| **Void Tyrant** (Quite Fresh / Armor Games) | Free with ads, "convert to premium (NO ADS) with one purchase"; three one-time IAPs total ≈ $4.99 | Listing feature bullet; ad-removal framing | [Play listing](https://play.google.com/store/apps/details?id=com.armorgames.voidtyrant); [TouchArcade review](https://toucharcade.com/2019/07/26/void-tyrant-review) |
| **Dicey Dungeons** | Paid premium | — | R1 §2 |
| **Emberdelve** | Free, complete (easy+normal); $4.99 Forge = HARD + Ascension | Lock icon on the HARD segment; summary panel on a WON run; Settings | lib/meta/forge.dart; R5 §D |

Reading: **$4.99 is mid-pack** ($2.99 → $4.99 → ~$7–10). What differs is not price but
*where the sentence lives*: every same-model peer states the model in the first line of the
listing or on the title screen; ours is the last bullet of the description and a lock glyph
(R5 §A, §D). `[inference from the table]`

## 2. Small-stage numbers other solo devs published (the honest peer set)

These are the only primary sources for "what 20–50 installs looks like", because nobody at
that stage has anything else to publish.

- **Asterogue** (chr15m, paid Android roguelike, Nov–Dec 2020): **30 Android copies, $89**, Play
  conversion "about 1%". Launch checklist: r/roguelikes, own blog, two mailing lists,
  **RogueBasin listing + news**, Kenney and Roguelikes Discords (#advertise-releases), two
  local dev communities, Hacker News. —
  [devlog](https://chr15m.itch.io/asterogue/devlog/201756/sales-numbers-for-asterogue)
- **Erick Zanardo's puzzler** (paid, Android, Jul 31–Sep 1 2025): 495 listing visitors, 13
  direct buys (2.63%), 23 orders, 8 refunds, ~US$23 gross. —
  [dev.to](https://dev.to/erickzanardo/one-month-after-my-game-release-android-edition-3ncn)
- **Card Crawl Android launch week** (the *ceiling* case): a "New Games" feature slot at
  position #32 produced ~7,500 downloads/day; 4.72% paid; 3,153 ratings in a week; the
  1-star cluster was "not completely free" and battery drain/overheating. —
  [Tinytouchtales](http://www.tinytouchtales.com/first-week-of-card-crawl-for-android/)
- **Comet Rogue** (Steam, not Android, Apr 2025): 62 copies, 7 reviews after two weeks, one
  festival, ~100 wishlists; the dev's own diagnosis was coverage, not the game. —
  [Antique Gear Games](https://antiquegeargames.com/2025/04/15/comet-rogue-postmortem-a-successful-failure/)

Reading: at this stage the published peers are at **30–60 sales/installs with 1–3%
conversion and single-digit ratings** — i.e. exactly where we are. None of them fixed it
inside the app; the two who grew (Card Crawl, Shattered) did so through a **store feature**
and **years of visible updates** respectively (Shattered: "updated with new content roughly
every three months" is literally in the listing; 100k → 150k → 200k units across
[2024](https://shatteredpixel.com/blog/shattered-pixel-dungeon-in-2024.html) →
[Ten Years](https://shatteredpixel.com/blog/ten-years-of-shattered-pixel-dungeon.html) →
[2026](https://shatteredpixel.com/blog/shattered-pixel-dungeon-in-2026.html)).

## 3. Store assets and the first sixty seconds — what they do that we don't

Cross-checked against R1's teardown of Slice & Dice / Dicey Dungeons / Heroll / Dice Gambit
and Play's own asset guidance
([Add preview assets](https://support.google.com/googleplay/android-developer/answer/9866151);
[Best practices for your store listing](https://support.google.com/googleplay/android-developer/answer/13393723)):

1. **Model in sentence one.** Slice & Dice, Void Tyrant and Shattered all disambiguate the
   "In-app purchases" badge immediately. We do not (R5 §A). *Cost to fix: one paste; owner's
   call while the listing is frozen.*
2. **Eight screenshots, or a video, or both.** We ship five and no video. Play allows eight
   per device type and lists video among the assets used "to highlight and promote your app
   on Google Play and other Google promotional channels" (9866151). Slice & Dice's listing
   leads its feature list with the mechanic ("3D dice physics, choose which dice to reroll"). *R3's framed-r3 set is
   already five plates; three more slots are empty.*
3. **The paid tier is described as support or as "the rest of the game", never as a lock.**
   Shattered frames it as supporting the developer; Slice & Dice as "unlock the full game".
   Our title-screen surface is a padlock glyph with no copy (R5 §D). *Inference: a padlock
   with no sentence reads as a paywall; a sentence reads as an offer.*
4. **Visible cadence.** Shattered's listing promises an update every ~3 months; Card Crawl
   shipped expansions at months 3 and 9 ([1st anniversary](http://www.tinytouchtales.com/card-crawl-1st-anniversary/)).
   We have shipped 0.34.0 → 0.179.0 on GitHub in six weeks and **0.59.0 is the newest thing
   a Play visitor can see** — the cadence exists but is invisible where it counts.
5. **A launch channel list executed on day one** (Asterogue's checklist above). Ours exists
   (traffic-channels.md, ranked) and is unposted by the owner's decision. *Reported, not
   argued.*
6. **First sixty seconds**: R1 found our decision distance (tap 2 / roll at tap 4) already at
   the front of the genre; the peers' remaining edge is wall-clock cold start, which needs a
   device stopwatch we still owe.

## 4. What NOT to copy (carried from R1 and reaffirmed)

- Void Tyrant's ad-supported default — ads are banned here by standing rule.
- Any "rate us" button or pre-filter — Play's API forbids building UI around the dialog
  ([In-App Review quotas](https://developer.android.com/guide/playcore/in-app-review)); our
  one-ask charter stands.
- Discount/urgency copy — banned-words list in DEMAND.md.

## 5. Net

At 20–50 installs the comparables were not doing anything *inside the game* we are not doing;
they were doing three things *outside* it: saying the business model in the first line,
filling the asset slots, and getting the newest build in front of people. Two of the three
are listing pastes; the third is the v0.179.0 AAB already on the release page. All three are
owner calls under the current freeze.
