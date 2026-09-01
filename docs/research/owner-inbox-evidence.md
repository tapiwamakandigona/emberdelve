# Primary-source evidence from the owner's mailbox

Relayed because these are things you cannot reach from inside the repo. Each
entry carries its provenance. Treat the quoted text as the authority and do not
paraphrase it into a checkmark.

## Google Play: two NEW app quality requirements
Source: email from Google Play <googleplay-noreply@google.com>, subject
"Tsoro Studios: Elevate your app with new quality requirements", Wed 26 Aug
2026. Read 2026-09-01. Sent to the developer account directly, so it applies to
`com.tsorostudios.emberdelve` and to anything else we put on Play.

Verbatim, both bullets:

> **Reducing app memory usage and optimizing code:** We are establishing
> performance thresholds across dynamic memory usage, bitmap usage, and code
> optimization to prevent unexpected on-device terminations on Android.
> Recognizing the distinct technical needs and user behavior for apps and games,
> we have tailored specific criteria for each.

> **Providing a secure & seamless device migration experience:** As part of our
> broader commitment to elevate app quality across the ecosystem, we're also
> introducing a new onboarding standard for app developers to give users a
> secure way to upgrade devices.

Also stated: tools are "already begun rolling out" in Play Console, and there is
"a comprehensive technical guide detailing the performance thresholds for each,
apps and games", plus an announcement blog covering "the upcoming enforcement
timelines".

### What is NOT in the email — do not invent it
The email gives **no dates and no numeric thresholds**. Enforcement timelines
and the actual numbers live in the linked blog and technical guide. If you write
a threshold into a checklist, it must come with a source; otherwise mark it
`unknown`.

### Why this matters to us specifically
- These are **memory** thresholds, not download-size thresholds. Our download
  size is already healthy (20.6 MB on Play against a peer median of 52.7 MB) and
  is a settled question — do not re-open it. Memory is a **separate and
  genuinely unknown** risk for a Flutter game with a large asset set, and it is
  the kind of thing that produces "unexpected on-device terminations", i.e.
  crashes on low-RAM devices. That is exactly our audience: the store listing is
  aimed at people who do not hold a flagship phone.
- "Games" have tailored criteria distinct from apps. Whatever numbers you find,
  make sure you are reading the **games** column.
- Device-migration onboarding is a new compliance surface neither repo has
  looked at at all. Currently `unknown`, and should be recorded as `unknown`
  rather than assumed fine.

### Suggested handling
For `docs/PLAY-QUALITY-2027.md`: add these two requirements as first-class rows,
each marked verified-met / verified-unmet / unknown per the existing rule. Right
now the honest mark for both is **unknown**, because we have neither the
thresholds nor a memory profile. A measured memory profile on a low-RAM device
would move the first one off `unknown` — that is a real, cheap experiment and it
needs no new tracking in the app.

Nothing here lifts any freeze. It is research input only.
