"""Two factual defects in published/near-published Emberdelve docs.

(1) docs/store/play-listing.md — the file a human pastes into Play Console —
    claims "no internet permission" and "zero tracking". Both are FALSE of the
    shipped build: emberdelve-v0.59.0.apk declares android.permission.INTERNET
    and carries opt-in Firebase Analytics. The live listing does NOT contain
    these lines (verified against a capture of the public store page today), so
    this is stale drift — but it is primed to be pasted live on the next update.

(2) docs/store/privacy-policy.html — the LIVE policy linked from the Play
    listing. Its body is accurate and carefully qualified, but:
      - the <meta description> still asserts a flat "No ads, no tracking";
      - the Permissions bullet enumerates only WAKE_LOCK + install-referrer,
        while the shipped APK also declares RECEIVE_BOOT_COMPLETED,
        BIND_JOB_SERVICE, POST_NOTIFICATIONS and DUMP. A policy that purports
        to list permissions must list them all, or a player reading Play's
        "run at startup" line catches it out.

Permission facts are VERIFIED from the shipped artefact, not assumed:
  manifest of emberdelve-v0.59.0.apk =
  INTERNET, ACCESS_NETWORK_STATE, VIBRATE, WAKE_LOCK, POST_NOTIFICATIONS,
  RECEIVE_BOOT_COMPLETED, BIND_JOB_SERVICE, DUMP,
  com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE.
  AD_ID and the AdServices permissions are absent (force-removed in-manifest).
"""
import subprocess

ROOT = "/work/temp/ed"

LISTING = f"{ROOT}/docs/store/play-listing.md"
POLICY = f"{ROOT}/docs/store/privacy-policy.html"

WARN = """> ⚠️ **The live Play listing is canonical, not this file.** This copy drifted from
> what is actually published. Verified against the public store page on 2026-09-01:
> the live short description is *"Fair dice, real choices. A pocket dice roguelite
> with zero ads, played offline."* and the live full description is the newer
> "BUILD YOUR POOL / TEMPER A FACE / CHOOSE A KEYSTONE" copy.
>
> **Diff against the live listing before pasting anything from here.** Never restate
> a data or permission claim without checking it against the shipped binary: the app
> declares `INTERNET` and ships opt-in Firebase Analytics, so "no internet permission"
> and "zero tracking" are false and were removed below.

"""

EDITS_MD = [
    ("Fair dice, real choices. A pocket roguelite with zero ads and zero tracking.",
     "Fair dice, real choices. A pocket dice roguelite with zero ads, played offline."),
    ("• Zero ads, zero tracking, no internet permission — fully offline",
     "• Zero ads, no third-party trackers — analytics only if you switch it on"),
]

OLD_PERMS = """The Google Analytics library also adds <code>WAKE_LOCK</code>
      and a Play Store install-referrer binding of its own; the advertising-ID
      permissions it would normally add are removed from our build. No
      permission requires a runtime prompt."""

NEW_PERMS = """The Google Analytics
      library also merges in several permissions of its own:
      <code>WAKE_LOCK</code>, <code>RECEIVE_BOOT_COMPLETED</code> (shown by
      Google Play as &ldquo;run at startup&rdquo;), <code>BIND_JOB_SERVICE</code>,
      <code>POST_NOTIFICATIONS</code>, <code>DUMP</code> and a Play Store
      install-referrer binding. They are used by that library to schedule and
      batch uploads; the game itself sends no notifications and starts nothing
      at boot, and if you never opt in, nothing is transmitted at all. The
      advertising-ID permissions the library would normally add are removed
      from our build. No permission requires a runtime prompt."""

OLD_META = ("Optional, opt-in anonymous gameplay analytics only — off by default. "
            "No ads, no tracking.")
NEW_META = ("Optional, opt-in anonymous gameplay analytics only — off by default. "
            "No ads, no third-party trackers, no data sales.")


def main():
    md = open(LISTING, encoding="utf-8").read()
    assert not md.lstrip().startswith(">"), "warning banner already present"
    for old, new in EDITS_MD:
        assert old in md, f"anchor missing in play-listing.md: {old[:50]}"
        md = md.replace(old, new)
    lines = md.split("\n")
    for i, ln in enumerate(lines):
        if ln.startswith("# "):
            lines.insert(i + 1, "\n" + WARN.rstrip())
            break
    else:
        lines.insert(0, WARN.rstrip())
    md = "\n".join(lines)
    for bad in ["zero tracking", "no internet permission"]:
        assert bad not in md.lower().replace(WARN.lower(), ""), f"still present: {bad}"
    open(LISTING, "w", encoding="utf-8").write(md)
    print(f"play-listing.md: patched ({len(md)} chars)")

    pol = open(POLICY, encoding="utf-8").read()
    before = len(pol)
    assert OLD_META in pol, "meta anchor missing"
    assert OLD_PERMS in pol, "permissions anchor missing"
    pol = pol.replace(OLD_META, NEW_META).replace(OLD_PERMS, NEW_PERMS)
    for must in ["com.tsorostudios.emberdelve", "com.tsorostudios.pyregrove",
                 "com.tsorostudios.emberwood", "Nothing is sent unless you",
                 "never accesses the advertising ID", "Google Play data-safety summary"]:
        assert must in pol, f"lost from policy: {must}"
    assert "RECEIVE_BOOT_COMPLETED" in pol and "DUMP" in pol
    open(POLICY, "w", encoding="utf-8").write(pol)
    print(f"privacy-policy.html: {before} -> {len(pol)} chars")

    subprocess.run(["git", "-C", ROOT, "add", "-A"], check=True)
    subprocess.run(
        ["git", "-C", ROOT, "-c", "user.name=Tapiwa Makandigona",
         "-c", "user.email=tapiwamakandigoner@gmail.com", "commit", "-q", "-m",
         "docs(store): remove two false claims from the paste-ready listing copy "
         "(the app does declare INTERNET and does ship opt-in analytics) and "
         "complete the policy's permission list with the ones the Analytics "
         "library actually merges in, verified from the shipped v0.59.0 APK"],
        check=True)
    print(subprocess.run(["git", "-C", ROOT, "log", "--oneline", "-1"],
                         capture_output=True, text=True).stdout.strip())


if __name__ == "__main__":
    main()
