"""Capture actual, unmodified Emberdelve APK using UI taps on a disposable AVD.

This is review tooling, not a gameplay test or visual-quality oracle. It never
changes the application, game save format, simulation, progression or checks.
pm clear resets ONLY this newly created emulator profile between scenarios.
"""
import hashlib
import json
import pathlib
import re
import subprocess
import time
import xml.etree.ElementTree as ET

import uiautomator2 as u2

PACKAGE = "com.tsorostudios.emberdelve"
OUT = pathlib.Path("build/combat-visual-evidence")
OUT.mkdir(parents=True, exist_ok=True)
TRACE = []
START = time.monotonic()
device = None
SCENARIOS = [
    ("kindler", "DELVE-100000000A", [5, 1, 3]),
    ("warden", "DELVE-100000200C", [5, 1, 2]),
    ("gambler", "DELVE-100000400E", [5, 1, 1]),
    ("runesmith", "DELVE-100000E00Z", [5, 1, 1]),
]


def adb(*args, **kwargs):
    return subprocess.run(
        ["adb", *args], check=True, capture_output=True, **kwargs
    ).stdout


def log(event, **data):
    record = {"t": round(time.monotonic() - START, 3), "event": event, **data}
    TRACE.append(record)
    print(json.dumps(record), flush=True)
    (OUT / "actions.json").write_text(json.dumps(TRACE, indent=2))


def nodes():
    xml = device.dump_hierarchy(compressed=False)
    root = ET.fromstring(xml)
    found = []
    for n in root.iter("node"):
        label = n.attrib.get("content-desc", "") or n.attrib.get("text", "")
        bounds = list(map(int, re.findall(r"\d+", n.attrib.get("bounds", ""))))
        if len(bounds) == 4 and bounds[2] > bounds[0] and bounds[3] > bounds[1]:
            found.append({"label": label, "bounds": bounds, **n.attrib})
    return xml, found


def shot(tag):
    xml, found = nodes()
    (OUT / f"{tag}.xml").write_text(xml)
    (OUT / f"{tag}.png").write_bytes(adb("exec-out", "screencap", "-p"))
    log("snapshot", tag=tag, labels=[n["label"] for n in found if n["label"]])


def match(pattern, attempts=12, exact=False):
    for _ in range(attempts):
        _, found = nodes()
        for n in found:
            label = n["label"].strip()
            yes = label.casefold() == pattern.casefold() if exact else re.search(
                pattern, label, re.I
            )
            if yes:
                return n
        time.sleep(0.5)
    return None


def tap_node(n):
    x1, y1, x2, y2 = n["bounds"]
    log("tap", label=n["label"], x=(x1+x2)//2, y=(y1+y2)//2)
    adb("shell", "input", "tap", str((x1+x2)//2), str((y1+y2)//2))
    time.sleep(0.5)


def tap(pattern, exact=False, attempts=12):
    n = match(pattern, attempts=attempts, exact=exact)
    if n is None:
        shot("missing-" + str(len(TRACE)))
        raise RuntimeError(f"Required visible control missing: {pattern!r}")
    tap_node(n)


def dismiss_tips():
    for _ in range(5):
        _, found = nodes()
        skip = next(
            (n for n in found if n["label"].strip().casefold() in
             {"skip tour", "skip", "got it", "no thanks", "keep analytics off"}),
            None,
        )
        if skip:
            tap_node(skip)
            continue
        tip = next((n for n in found if n["label"].strip().upper() in {
            "THIS IS A DELVE", "ROLL, THEN SPEND", "MATCHING FACES PAY",
            "BLOCK FADES FAST", "THE DARK FIGHTS FAIR",
        }), None)
        if tip:
            tap_node(tip)
            continue
        break


def capture(character, code, expected):
    log("scenario", character=character, code=code, expected_roll=expected)
    adb("shell", "am", "force-stop", PACKAGE)
    adb("shell", "pm", "clear", PACKAGE)
    adb("shell", "monkey", "-p", PACKAGE, "-c",
        "android.intent.category.LAUNCHER", "1")
    assert match("Delve", attempts=40), "Android app did not reach title"
    dismiss_tips()
    shot(character + "-title")
    for _ in range(6):
        seed = match("Delve a seed", exact=True, attempts=1)
        if seed:
            tap_node(seed)
            break
        adb("shell", "input", "swipe", "350", "1000", "350", "400", "400")
        time.sleep(0.6)
    else:
        raise RuntimeError("Seed link did not become visible")
    editor = device(className="android.widget.EditText")
    assert editor.wait(timeout=10), "Seed editor not shown"
    editor.click()
    adb("shell", "input", "text", code)
    adb("shell", "input", "keyevent", "KEYCODE_BACK")
    tap("Delve", exact=True)
    tap("Skip — delve unaided", exact=True)
    dismiss_tips()
    shot(character + "-map")
    tap(r"^Fight, floor \d+, reachable")
    time.sleep(1)
    dismiss_tips()
    tap("Roll", exact=True)
    time.sleep(1.2)
    dismiss_tips()
    shot(character + "-rolled")
    _, found = nodes()
    dice = [n for n in found if re.search(r"d\d+ die, rolled \d+", n["label"])]
    values = [int(re.search(r"rolled (\d+)", n["label"])[1]) for n in dice]
    assert values == expected, (character, values, expected)
    assert match("Flue Crawler", attempts=1), "Unexpected first enemy"

    remote = f"/sdcard/{character}-combat.mp4"
    recorder = subprocess.Popen([
        "adb", "shell", "screenrecord", "--bit-rate", "4000000",
        "--time-limit", "28", remote,
    ])
    video_start = time.monotonic()
    try:
        time.sleep(1.5)
        for label, value in [("low", 1), ("high", 5)]:
            node = match(rf"d\d+ die, rolled {value}(?:,|$)", attempts=1)
            assert node and "spent" not in node["label"], (label, node)
            tap_node(node)
            time.sleep(0.6)
            shot(character + "-" + label + "-selected")
            log("attack", character=character, face=value,
                video_t=round(time.monotonic()-video_start, 3))
            tap("Attack", exact=True, attempts=1)
            time.sleep(2.5)
            dismiss_tips()
            shot(character + "-" + label + "-resolved")
        tap("End turn", exact=True)
        time.sleep(3)
        shot(character + "-enemy-turn")
    finally:
        recorder.wait(timeout=35)
        adb("pull", remote, str(OUT / f"{character}-combat.mp4"))
        log("video", character=character,
            duration_seconds=round(time.monotonic()-video_start, 3))


try:
    adb("shell", "wm", "size", "720x1280")
    adb("shell", "wm", "density", "320")
    adb("install", "-r", "build/review.apk")
    log("apk", sha256=hashlib.sha256(pathlib.Path("build/review.apk").read_bytes()).hexdigest(),
        package_dump=adb("shell", "dumpsys", "package", PACKAGE).decode())
    device = u2.connect()
    for scenario in SCENARIOS:
        capture(*scenario)
    (OUT / "result.json").write_text(json.dumps({
        "complete": True, "scenarios": [s[0] for s in SCENARIOS],
        "method": "Unmodified release APK; UIAutomator hierarchy + actual coordinate taps",
        "environment": "Android API34 emulator, SwiftShader, 720x1280, density320",
        "not_verified": ["owner installed version", "physical performance", "audio", "subjective quality"],
    }, indent=2))
except Exception as error:
    log("failure", error=f"{type(error).__name__}: {error}")
    if device is not None:
        shot("failure")
    raise
finally:
    (OUT / "logcat.txt").write_bytes(adb("logcat", "-d", "-v", "brief"))
