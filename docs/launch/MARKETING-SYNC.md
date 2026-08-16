# Marketing ↔ Build sync

Purpose: one file where the marketing side (Viktor, Tapiwa's marketing agent)
and the build side (the game-improvement agent) can see each other's state.
Marketing owns `docs/launch/` and `docs/store/`; build owns the rest.

## Distribution state — 2026-08-16

- **tapiwa.me/emberdelve/ now has a Direct APK card** linking
  `github.com/tapiwamakandigona/emberdelve/releases/latest` (portfolio commit
  `2944a52`, live-verified). The README's "download page" reference is now
  accurate: visitors get Play (early access) AND the newest GitHub build.
- **Google Play still ships 0.7.0 (build 33), closed testing, 32 testers.**
  Production access is granted but rollout is blocked on crash-data coverage
  (~9% of testers on the newest Play build). Promoting a newer build to Play
  is Tapiwa's call.
- **Version split is public-facing:** Play 0.7.0 vs GitHub v0.20.0. Landing
  chip discloses it ("On Play: v0.7.0 · newest builds on GitHub").

## Notes for the build side

1. README wording: Play is **closed testing**, not "public early access" —
   a non-tester tapping the Play link gets a dead end. Suggest wording like
   "Google Play (early access, tester list)" or just pointing the Play
   mention at the landing page.
2. Keep shipping to `releases/latest` — the landing links it un-versioned,
   so nothing on the marketing side goes stale when you release.
3. Release notes (e.g. v0.20.0 "The Living Ladder") are strong material;
   marketing may quote them in Reddit/LinkedIn posts verbatim.

## FLAGGED GAP — sideload users cannot buy the Forge (2026-08-16)

Verified in code (`lib/meta/store_service.dart`, `lib/ui/forge_sheet.dart`):
the Ember Forge unlock is Play-billing-only. A GitHub-APK user hits
`ForgeStoreState.unavailable` forever and sees *"Google Play isn't reachable
right now. The Forge will be here when it is"* — which is never true for a
sideload. Two consequences:

1. **Misleading copy** for the exact audience the Watchtower feature courts.
   Suggest an honest sideload variant, e.g. "This build came from GitHub —
   the Forge unlock currently needs the Google Play version."
2. **No revenue path from GitHub distribution.** Proposal for discussion
   (Tapiwa decides): offline **signed unlock codes** — app embeds a public
   key, a code signed with the private key flips `forgeUnlocked`. Fits the
   offline-first/no-account ethos; sales can run person-to-person (email +
   Paynow, the one rail that works from Zimbabwe) with zero server.
   Until something like this exists, marketing will not promise sideloaders
   any way to buy the Forge.

## Notes for the marketing side (state)

- Reddit drafts live in the `everything` repo, `ACTIONS-ON-PHONE.md`; they
  route through the landing, not the bare Play link.
- Play store listing copy (`docs/store/play-listing.md`) describes 0.7.0 —
  correct while Play ships 0.7.0. Refresh it only when a newer build is
  promoted on Play.
- Signing (checked 2026-08-16): the v0.20.0 GitHub APK's signer cert SHA-256
  is `031acb42566a51d5b59ffd5deb173f1b0e817a9edff1bb6979f68564d44b7a0d` —
  identical to the Tsoro Studios upload keystore (VERIFIED by parsing the
  APK's v2 signature block). Whether Play App Signing re-signs Play installs
  with a different key is UNVERIFIED (needs Play Console). Until confirmed,
  don't tell users sideload ↔ Play installs update over each other.

## 2026-08-16 — AI Studio observation (Viktor, for the game agent / Tapiwa)
Live read of Google AI Studio (project "Emberdelve", Free tier, 28-day window):
- An **Android API key (auto-created by Firebase)** is issuing Gemini API requests
  (~10/day peaks) with recurring **403 Forbidden spikes** (Jul 30 biggest, Aug 6, Aug 13),
  and "Generate content" token charts show **No data** — i.e. zero successful generation.
- If some in-app/companion Gemini feature is supposed to work, it is silently failing
  (likely key restriction / API-not-enabled / free-tier scope). If nothing is meant to
  call Gemini from the app, consider deleting/restricting that Firebase key.
- Viktor has AI Studio + Play Console + Gmail browser access now; ask if a live check is needed.
