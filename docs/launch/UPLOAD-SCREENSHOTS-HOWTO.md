# How to upload the improved screenshots (manual, ~60 sec)

**Why manual:** Play Console's screenshot upload uses a custom asset-picker modal (not a
standard OS file dialog), which is fragile to automate and risks leaving the live listing
in a messy draft. The exact path is verified but not auto-uploaded — safer by hand.

**The improved, upload-ready files (1080×1920, Play-compliant):**
`emberdelve/docs/store/screenshots/framed/` on the `legacy/dice-builder` branch:
- `01-combat-roll.png` — "Every death is fair."
- `02-boon-pick.png` — "Real choices, every run."
- `03-map.png` — "Branching paths."
- `04-title.png` — "Fair dice. No ads."
- `05-ledger.png` — "Die forward."
(Download them from GitHub.)

## Steps
1. Play Console → **Emberdelve** → left nav **Grow users → Store presence → Store listings**.
   (Direct: the app's `…/main-store-listing` page.)
2. Scroll to **Phone screenshots**.
3. **Delete the 5 current shots** (hover each → trash/delete icon).
4. Click **Add assets** under Phone → upload the 5 framed PNGs **in order 01→05**
   (order matters — Play shows them left-to-right; 01 "Every death is fair" must be first).
5. Click **Save as draft** first to sanity-check, then **Save** to publish the listing.
6. Metadata-only changes like screenshots usually go live fast; if it asks to submit for
   review, that's normal and fine.

## Do this BEFORE the Reddit post
So the first wave of visitors from r/roguelites hits the stronger, captioned listing that
leads with the actual hook instead of a stats screen.

## If you'd rather automate it
The modal automation is possible but fragile — better to spend that
risk budget elsewhere. Your call.
