# Emberdelve — App Store listing draft (iOS)

Prepared 2026-08-22, matching the 0.7.0 feature set (same rule as the Play
listing: do NOT mention 0.8–0.12 GitHub-only features). Screenshots:
`docs/store/screenshots/ios/` — five 1290×2796 PNGs (iPhone 6.7", accepted for
all iPhone slots), rendered from real screens via
`tool/appstore_screenshots_test.dart` (rerun any time the UI changes).
iPhone-only for launch (no iPad slots needed if iPad support is unchecked in
App Store Connect).

## App name (30 chars max)

Emberdelve: Dice Roguelite

*(26 chars — same as Play.)*

## Subtitle (30 chars max)

Fair dice. Offline. No ads.

*(27 chars.)*

## Promotional text (170 chars max, editable without review)

Every death is fair: telegraphed enemies, learnable dice rules, seeded runs.
Full game free, offline, zero ads. One honest unlock opens HARD + Ascension.

*(~156 chars.)*

## Keywords (100 chars max, comma-separated, no spaces needed)

dice,roguelike,roguelite,dungeon,turn based,deck builder,offline,rpg,tabletop,slice,strategy,solo

*(97 chars. "slice" covers Dicey-Dungeons-adjacent "slice & dice" searches.)*

## Description (4000 chars max)

Use the Play full description verbatim (`play-listing.md` → Full description,
0.7.0 refresh). It is platform-neutral except one required tweak:

- The FAIR BY DESIGN bullet "One honest one-time unlock (the Ember Forge)…"
  stays as-is — App Store allows referencing IAP by name.
- Remove any sentence mentioning Google Play / Play Games if present in the
  pasted revision (the 0.7.0 refresh has none — verified 2026-08-22).

## Support URL

https://github.com/tapiwamakandigona/emberdelve/issues

## Privacy policy URL

Same as Play (privacy-policy.html hosting URL — see Play Console listing).

## App Privacy (nutrition label answers)

Baseline build: analytics only if the user opts in (Firebase gated behind the
in-app toggle, no-op if unconfigured). If Firebase is NOT configured for iOS
at submission time, answer **"Data Not Collected"** across the board — that is
the truthful answer for a build with no Firebase plist. If Firebase Analytics
IS configured: declare "Product Interaction" + "Crash Data", not linked to
identity, not used for tracking; App Tracking Transparency NOT required (no
cross-app tracking, no IDFA).

## Age rating questionnaire

Infrequent/Mild Cartoon or Fantasy Violence → expect 9+. Everything else "No".

## Pricing & IAP

- App: Free.
- One IAP: **ember_forge_unlock**, non-consumable, $3.99 USD tier,
  display name "The Ember Forge", description "Unlocks HARD mode and the
  Ascension ladder. One purchase, forever." Product id MUST match
  `forgeProductId` in `lib/meta/store_service.dart`.
- "Restore Purchases" is already surfaced by the in_app_purchase plugin flow —
  verify visible on iOS before submission (App Review requires it for
  non-consumables).

## Review notes (App Review information box)

"Single-player offline dice roguelite. No account or login. The only IAP is a
one-time unlock (ember_forge_unlock) opening HARD difficulty and the Ascension
ladder; the full base game is free and playable start-to-finish without it.
No ads, no tracking."

## Checklist to submission (blocked on Apple Developer Program enrollment)

1. Tapiwa enrolls: developer.apple.com/programs/enroll ($99/yr).
2. App Store Connect: create app record, bundle id com.tsorostudios.emberdelve.
3. Signing: create distribution cert + provisioning profile (or Xcode-managed
   via a macOS CI signing step / codemagic-style flow).
4. Create ember_forge_unlock IAP product (must be "Ready to Submit" and
   attached to the first version submission).
5. Upload build (CI produces unsigned Runner.app today; signed IPA export step
   to be added to ios.yml once certs exist).
6. Paste this listing, upload docs/store/screenshots/ios/, answer privacy +
   age rating, submit with review notes above.
