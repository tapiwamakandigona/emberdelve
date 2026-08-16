# Emberdelve — LinkedIn launch post (draft)

**Context / strategy.** Tapiwa's LinkedIn audience is professional/engineering, **not**
the game's player audience. So this post is NOT a "download my game" ad — it converts
worse and reads as spam to that crowd. It is a **building-in-public / engineering**
story that happens to have a shipped artifact at the end. The goal is credibility and
network, not installs. Link goes in the **first comment**, never the body (LinkedIn
suppresses reach on posts with external links in the body).

**Voice:** Tapiwa's — first person, short sentences, humble, concrete, no corporate
filler, no emoji spray. He's a 20-year-old solo builder in Zimbabwe about to start
Electrical & Electronics Engineering at UZ. That story is an asset — use it plainly,
don't oversell it.

**Timing:** respect the LinkedIn cadence rule — no post within ~36h of another, and
adding a position OVERWRITES the headline (don't do that near a post). Slot this on a
weekday morning, not the same week as the UZ "day one" post.

---

## Draft A — the engineering-discipline angle (recommended)

I spent the last few weeks building a small game, solo, and the part I'm proudest of isn't the game — it's the discipline I forced on myself to ship it.

Emberdelve is a dice roguelite. One rule shaped every decision: every death has to be fair. No hidden modifiers, no rigged near-misses. That sounds like a design choice, but it's really an engineering one — it means the whole game logic is a sealed, deterministic core with no randomness the player can't trace. Same seed, same outcome, every time. That let me test it the way you'd test a real system: 200+ automated tests, an autoplay bot running thousands of seeded runs to catch balance bugs and crashes before a human ever sees them.

A few things I learned building alone:
- Determinism isn't just a gameplay gimmick — it's the only way one person can trust a system they can't manually QA at scale.
- The bugs that scared me most weren't crashes. They were the quiet ones — a "shared" daily seed that was secretly random for every player. Automated parity checks caught it; a human never would have.
- Shipping is a skill you only get by shipping. The first build was embarrassing. It's meant to be.

It's live on Google Play now, free. I'm starting Electrical & Electronics Engineering at the University of Zimbabwe next week, and honestly this project taught me more about building real systems than anything else I've done.

If you've ever shipped something solo — what's the one discipline that saved you?

*(link to the game in the first comment)*

---

## Draft B — the shorter, personal-milestone angle

Three weeks ago I decided to build and actually ship a game by myself. Today it's live.

Emberdelve is a small dice roguelite with one promise: every death is fair — rules you can learn, no hidden math, every run reproducible from its seed. That last part is really an engineering decision, and it's what let me test the whole thing with an autoplay bot across thousands of runs instead of hoping.

I'm 20, based in Zimbabwe, and I start Electrical & Electronics Engineering at UZ next week. Building this taught me that the gap between "I could build that" and "I built that and people can use it" is entirely about finishing. That gap is where most ideas die.

Not asking for anything — just marking the milestone, and genuinely curious what other solo builders here wish they'd known before their first ship.

*(link in first comment)*

---

## First-comment text (both drafts)

Here it is if you want to try it — free, offline, no ads: [Play Store link]. Feedback from anyone who plays it is worth more to me than a download. 🎲

## Notes
- Reply to every comment for the first few hours — engagement in the first hour drives reach.
- Do NOT boost or run ads (owner constraint + not worth it for this audience).
- If someone in-network is a game dev / designer, take that to DMs — that's the real value of this post.
