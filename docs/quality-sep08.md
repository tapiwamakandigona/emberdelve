# September 8 quality pass

Source: Android dice-builder shipping branch `legacy/dice-builder`, baseline
`4bfb08e` / 0.181.0+208. Main is a different game; do not build it by mistake.
Canonical harness main `4fe6eb4` contains v3.0.1 and was read in full.
Single agent; maximum 12 engineering iterations across this studio pass.
Existing tests, sim goldens, signing pins and earlier progress stay read-only.

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
