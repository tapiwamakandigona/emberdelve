# Emberdelve 0.184.0 — itch.io publication package

**VERIFIED preparation, NOT a published itch.io update.**

Public readback on September 19 still lists `emberdelve-v0.179.0.apk`,
version 0.179.0, 69 MB. Authentication is blocked by Cloudflare before the
password form; the ordinary session and one permitted proxy fallback both
stopped there. No password was tested, reset requested or page saved.

## Ready to publish

- `page.html`: replacement description, preserving the game's actual
  mechanics and fair-play promises; adds the current release and precise
  download link. Use the existing itch theme, not a new visual identity.
- `devlog.html`: one meaningful catch-up post from the current itch build.
  Title: **The Whole Company — Emberdelve 0.184.0**.
- `screenshots/`: three unchanged, source-matched 720×1280 game captures.
  Use Kindler, Warden and Hedger in that order; alt text is in `page.html`.
- `manifest.json`: release identity, byte counts, source and file hashes.
- The private delivery ZIP also includes `emberdelve-v0.184.0.apk`, the
  exact verified universal APK renamed for itch, plus its SHA-256 sidecar.
  The APK is not committed to Git.

The same verified APK is available at this exact-release URL:

https://github.com/tapiwamakandigona/emberdelve/releases/download/v0.184.0/app-release.apk

SHA-256:
`a882b12c4a1e127fef78ec0b12ca0d64005653f20807a329b1bf5bf906c2766f`

75,707,508 bytes. Package `com.tsorostudios.emberdelve`, version0.184.0,
code211, Android7.0+, permanent upload certificate unchanged. Use the
universal APK for this download, not the AAB or a mixture of split APKs.

## Publish only through a working authorised route

1. Confirm the account is **tsorostudios** and the existing game is
   **4903556**, `https://tsorostudios.itch.io/emberdelve`. Do not create
   another project.
2. Update the existing Android download/channel to the verified APK and
   user version `0.184.0`; keep the project free and existing paid-unlock
   arrangement unchanged. A provisioned Butler API key can unblock the APK
   upload, but is not proof of access to the page editor.
3. Apply `page.html` to the existing description. Keep working Play,
   project-site, credits and privacy links. In this prepared HTML the
   screenshots use immutable source-commit URLs; upload the provided PNGs
   to itch's media storage if using its gallery instead.
4. Set the AI disclosure truthfully: AI-assisted **Code, Graphics and Text**
   (use the current editor's equivalent graphics/art label). Current delver
   source illustrations are generated; do not retain Code/Text-only
   disclosure for the updated art, or describe it as commissioned human art.
5. Create one devlog in the existing game:
   `https://itch.io/dashboard/game/4903556/new-devlog`.
   Select the appropriate update classification, apply the prepared title
   and body, then inspect all fields before publishing.
6. Read the public page and devlog without authentication. Verify version,
   links, image URLs/captions, disclosures and the downloadable APK bytes
   against this manifest. Only then mark `REL-ITCH` passing.

## Evidence limits

These are actual headless Flutter encounter-entry captures from the game
renderer, with test-selected delvers, not painted mockups or phone
photographs. Capture render source is unchanged in release commit
`84f973f3a28b043effefb6d0b0a9b6ea9a13e4b9`. No resampling, compositing or
generated replacement imagery has been added here.

Mechanical checks do not establish an aesthetic “best” grade, physical
phone touch/FPS, naturally earned end-to-end play or real Play purchases.
Those existing gates remain open. Play approval/live availability must be
read back separately; the prepared page does not claim this version is
already live on Play.

**ASSUMED editorial choice:** one consolidated catch-up devlog is more
useful than recreating every intervening GitHub release on itch.
