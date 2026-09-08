# September 8 quality pass

Source: Android dice-builder shipping branch `legacy/dice-builder`, baseline
`4bfb08e` / 0.181.0+208. Main is a different game; do not build it by mistake.
Canonical harness main `4fe6eb4` contains v3.0.1 and was read in full.
Single agent; maximum 12 engineering iterations across this studio pass.
Existing tests, sim goldens, signing pins and earlier progress stay read-only.

## Iteration 9 — signed quality release candidate

- Candidate `0.182.0+209`, after primary Play read confirmed highest uploaded
  bundle 208 / 0.181.0 in full production. Recheck before upload.
- Player-facing release/news notes accurately describe existing-owner
  Keepers, replacement models and partial translations; no new permissions,
  premium product, public supporter names or simulation changes.
- Run unchanged analyzer, full suite, SFX true-peak and character asset
  reproducibility checks; prepare PR against `legacy/dice-builder`.
- Use existing active public CI on explicit quality branch, no main build,
  secret enumeration, key generation, paid runner or workflow weakening.
  Existing frame-trace dispatch can provide emulator evidence, not 2GB-phone
  FPS or a Play-billed purchase. Preserve all original checks.
- Verify downloadable APK/AAB hashes, package, version and signer. Do not
  replace a Play production build with an untested candidate; prefer existing
  internal testers while new visuals and physical purchase remain unverified.

## Iteration 3 — Keepers of the Flame

Owner approved the recommendation on September 8: thank existing and new
Ember Forge owners with an optional private title inscription and crest,
not a public list, account system or gameplay advantage.

### Definition of done

- At the title (never combat), offer a one-time, non-blocking thank-you with
  a personalisation action and an equally clear skip action.
- Ownership comes from the same persisted Forge entitlement / confirmed Play
  restore used by the existing game. Do not inspect customer order records,
  invent a new paid product, weaken purchase checks or require a second payment.
  Existing valid offline unlock-code owners are eligible on the same basis.
- Optional nickname, at most 24 grapheme clusters; remove control/bidi
  overrides, trim/collapse whitespace. No email, real name or network required.
- A static gold Forge crest and title inscription; editable, hideable and
  removable in Settings. No added animation, asset downloads or splash delay.
- A separate local-only file, excluded from the existing explicit Android
  backup/transfer allowlists, Play Games cloud saves and manual save codes.
  No name in analytics, diagnostics or public credits. Restoring a purchase
  on a fresh install may offer a fresh nickname; don't promise cross-device
  name synchronization.
- Load asynchronously after first frame; writes queued and atomic. Corrupt
  data safely defaults, persistence failure surfaced without logging the name.
- Additive tests: old-save eligibility, free/pending/cancel/error cases,
  confirmed restore, once-only invitation, safe name handling, save/load,
  edit/hide/remove, small screen/large text, no changes to original tests.
- Full analyzer and suite green. Device/Play purchase evidence remains a
  separate unpassed release gate, never inferred from fake-gateway tests.

### Later scoped work

Distinct character silhouettes and measured low-end rendering improvements;
release/version/signature/Play validation after this feature and tests.

## Iteration 5 — the roster, not a row of recolours

- Replace the 22 existing character sheets in place; stable character IDs,
  order, unlock costs, kits, save codes, simulation and enemy sheets.
- Original pixel-art models distinguish body shape, headgear, carried
  tools and poses: not an HSV remap of the four old source silhouettes.
- Generate source atlases with two idle and two walking poses per model;
  keep source art and an exact mechanical conversion recipe outside the
  runtime asset bundle, with honest provenance.
- Native 32x40 pixel frames, nearest-neighbour drawing, no extra textures,
  shaders, tickers or runtime dependency. Whole-character decoded footprint
  <=1.5 MiB; total shipped character PNG <=100 KiB.
- Validate alpha margins, frame geometry, unique monochrome silhouettes,
  reproducibility and every existing engine decode/asset/widget/sim test.
  Automated asset checks are not a substitute for device visual review.

## Iteration 6 — statistics-led first-session translations

Play device-language snapshot for September 1 (retrieved September 8):
55 installed audience; English variants 33, French 5, Spanish 4, pt-BR 1.
Eight are grouped "other"; German/Arabic are not separately reported.
Ship French/Spanish and Brazilian Portuguese UI support, not a claim
that every lore entry or dynamic content string is translated.

- Device-locale selection plus persisted manual System/English/Français/
  Español/Português (Brasil); unsupported languages fall back to English.
- First-session navigation, five-page manual, primary combat actions,
  comfort settings and complete Keeper privacy/editor copy.
- English source fallback for untouched codex/story/dynamic content;
  show an honest scope note alongside the language picker.
- No network translation SDK, runtime fetch, translated IDs/seed codes,
  simulation changes or personal-name translation.
- Catalog parity and placeholder checks; actual French/Spanish/Portuguese
  narrow-screen UI tests, current save round-trip and unchanged full suite.

### Descope after the single retry

The new inline language panel displaced existing Settings controls. The
full-suite retry failed at `Expected: 'on' / Actual: 'system'` (motion
control) and `Found 0 widgets with text "UPDATES": []` (lazy-list reach).
All new translation tests and analyzer passed. Remove the inline panel
from the settings list: a 48px app-bar globe opens a scrollable language
sheet. The settings list retains its previous content positions. No
original test, assertion, scroll helper or cache extent changes.
