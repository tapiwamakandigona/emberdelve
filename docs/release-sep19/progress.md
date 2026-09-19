# September 19 release progress — append only

## Iteration 1/8 — audit and plan

- VERIFIED canonical harness cloned/read at main/v3.0.1. Existing AGENTS.md
  already derives from it; scoped PROJECT/features/loop copied from the
  fresh canonical templates, not reconstructed from memory.
- VERIFIED primary source: shipping741b439, latest release0.183.0+210;
  PR104/105/106 already merged; PR102 remains an open historical critique.
- VERIFIED authenticated Play210 is Available on Google Play, full rollout,
 177/177 countries; internal/Alpha209. No unpublished changes initially.
- VERIFIED fresh primary merged-head CI35327651857 analyzer clean,
  1526 passed; signed job skipped. This is not a new signed build.
- VERIFIED Google login via user-supplied password/TOTP succeeded.
  itch Cloudflare verification blocks both normal and one proxy fallback
  before password input. No recovery, password test or store edit.
- Setup failure: password post-step wait used a broad selector and reported
  `strict mode violation: locator("input[type=password]") resolved to 2 elements`.
  Single corrected continuation used observed name=Passwd; login verified.
- Setup failure: incorrectly assumed official SDK index path returned
  `404 Not Found` and `NoSuchKey`; one identical-path retry stopped.
  Official Flutter archive documentation revealed the correct index.
  Download3.44.9/Dart3.12.2 matched official SHA256
  a9120fa4a01048bdef438ddc3a2d4b7389662ea98a95db86eeaf10382bc4efcb.
- Extraction failed `command timed out after 20000 milliseconds`; one
  adequately timed extraction of the checksum-verified archive succeeded.
- ASSUMED release choice: package integrated visuals as0.184.0+211, no
  speculative new art or simulation/billing changes. Open physical-device,
  purchase/restore and inherited keystone UI-tool gates remain false.
