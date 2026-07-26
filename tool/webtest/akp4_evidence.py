"""AKP-4 evidence capture: per-weapon idle + mid-swing screenshots, plus the
held-throw apple arc preview (docs/ak-parity-plan.md §4 DoD).

Usage: build & serve the harness (docs/web_testing.md), then
`python tool/webtest/akp4_evidence.py`. Screenshots go to $WEBTEST_OUT
(default docs/ak-parity/evidence/akp4).
"""
import asyncio
import os

from playwright.async_api import async_playwright

OUT = os.environ.get("WEBTEST_OUT", "docs/ak-parity/evidence/akp4")
BASE = "http://localhost:8123/?level=w1_l1&seed=42"
WEAPONS = ["squire_blade", "woodsman_axe", "ember_fang", "warden_blade",
           "skypiercer", "wind_gods_hammer"]


async def tel(page):
    return await page.evaluate("window.__emberdelve || {loaded:false}")


async def fresh(page, url):
    await page.goto(url, wait_until="load")
    for _ in range(60):
        if (await tel(page)).get("loaded"):
            break
        await asyncio.sleep(0.5)
    await asyncio.sleep(1.5)  # spawn fade + sign intro settle


async def main():
    os.makedirs(OUT, exist_ok=True)
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        ctx = await browser.new_context(
            viewport={"width": 1280, "height": 720}, has_touch=True)
        page = await ctx.new_page()
        for wid in WEAPONS:
            await fresh(page, f"{BASE}&weapon={wid}")
            await page.screenshot(path=f"{OUT}/{wid}_idle.png")
            # Mid-swing: J = attack; swing lasts 0.22s, shoot at ~0.1s.
            await page.keyboard.press("j")
            await asyncio.sleep(0.1)
            await page.screenshot(path=f"{OUT}/{wid}_swing.png")
            print(f"{wid}: idle + swing captured")
        # Arc preview: hold K (throw) with a pre-filled pouch. The first
        # press-edge throws one apple; the preview stays up while held.
        await fresh(page, f"{BASE}&weapon=squire_blade&apples=5")
        await page.keyboard.down("k")
        await asyncio.sleep(0.25)
        await page.screenshot(path=f"{OUT}/apple_arc_preview.png")
        await page.keyboard.up("k")
        print("apple arc preview captured")
        await browser.close()


if __name__ == "__main__":
    asyncio.run(main())
