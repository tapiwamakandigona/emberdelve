# Emberdelve — itch.io page kit

Status: **PAGE BUILT 2026-08-16 (browser-automated).** Account `tsorostudios`
exists; page live in DRAFT at https://tsorostudios.itch.io/emberdelve with description,
cover, 5 screenshots, tags, AI disclosure (code+text), Play link. REMAINING: (1) Tapiwa
taps the itch verification email in Gmail, (2) butler push of the APK, (3) flip to Public. Free-only page — **itch payouts (PayPal/Payoneer) are blocked for ZW, so
donations/pricing stay OFF.** The page is a discovery + credibility surface for the
roguelite crowd; money happens on Play ($3.99 Forge) and, if greenlit, signed unlock
codes for sideloaders.

## Why itch.io (marketing rationale)

- The itch roguelite/roguelike audience is exactly the "ownership, offline, no
  dark patterns" crowd the game is built for.
- An itch page is a legitimate indie credential — reviewers, YouTubers, and
  r/roguelites readers check for one.
- It unlocks venues that require a public store/page (e.g. r/playmygame).
- Zero cost, no payment rail needed, no exclusivity.

## Page settings

| Field | Value |
|---|---|
| Title | Emberdelve |
| Project URL | emberdelve (→ tsorostudios.itch.io/emberdelve or under his account) |
| Short description / tagline | Fair dice, real choices. A pocket dice roguelite with zero ads, played offline. |
| Classification | Game |
| Kind of project | Android — upload the **universal APK** from the latest GitHub release (or the arm64 one + note) |
| Release status | In development |
| Pricing | **No payments** (see ZW payout note above) |
| Genre | Strategy (secondary: Card Game if allowed) |
| Tags | roguelite, roguelike, dice, turn-based, singleplayer, offline, android, pixel-art*(only if accurate — check with a screenshot before tagging)* |
| AI disclosure (itch asks) | Answer honestly per the game agent's actual asset provenance (PROVENANCE.md / CREDITS.md) |
| Community | Comments enabled |

## Description (paste as-is, itch supports basic formatting)

Use the **Full description** from `docs/store/play-listing.md` ("0.7.0 refresh"
section) verbatim — it's already honest and current. Then append this itch-specific
footer:

> ---
> **Where to get it**
> - Android (Google Play): https://play.google.com/store/apps/details?id=com.tsorostudios.emberdelve
> - Direct APK (always newest build): https://github.com/tapiwamakandigona/emberdelve/releases/latest
> - Everything else: https://tapiwa.me/emberdelve/
>
> Built solo in Kwekwe, Zimbabwe. No ads, no tracking, no energy timers — one
> optional one-time unlock supports development. The APK here may lag the GitHub
> release by a few days; GitHub is always newest.

## Screenshots

Upload the five framed shots from `docs/store/screenshots/framed/`:
01-combat-roll, 02-boon-pick, 03-map, 04-title, 05-ledger. Cover image: crop
04-title to itch's 630×500 (itch will prompt).

## Maintenance rule (for whoever updates the page)

When the game agent publishes a new GitHub release, replace the uploaded APK **or**
just keep the GitHub link authoritative and update the itch APK weekly at most.
Never let the page claim a version it doesn't ship.

## Account setup (phone-assisted, ~5 min)

1. itch.io → Register: username `tsorostudios` (fallback: `tapiwamadie`), email
   tapiwamakandigoner@gmail.com.
2. Tap the verification link that lands in Gmail.
3. Save the password where your ops side keeps credentials (paste it in chat and
   it gets locked down outside any repo).
4. Dashboard → Create new project → paste this kit.
