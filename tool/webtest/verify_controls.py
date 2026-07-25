"""End-to-end control verification for the web test harness (see docs/web_testing.md).

Usage: build & serve the harness (docs/web_testing.md), `pip install playwright && playwright install chromium`,
then `python tool/webtest/verify_controls.py`. Screenshots go to $WEBTEST_OUT (default cwd)."""
import asyncio
from playwright.async_api import async_playwright

import os
OUT = os.environ.get("WEBTEST_OUT", ".")
URL = "http://localhost:8123/?level=w1_l1&seed=42"
RIGHT = (245.3, 629.3)
LEFT = (90.7, 629.3)
JUMP = (1189.3, 629.3)

async def tel(page):
    return await page.evaluate("window.__emberdelve || {loaded:false}")

async def fresh(page):
    await page.goto(URL, wait_until="load")
    for _ in range(60):
        if (await tel(page)).get("loaded"):
            break
        await asyncio.sleep(0.5)
    await asyncio.sleep(1.2)
    return await tel(page)

async def main():
    results = {}
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        ctx = await browser.new_context(viewport={"width": 1280, "height": 720}, has_touch=True)
        page = await ctx.new_page()
        cdp = None

        # 1. touch hold RIGHT
        t0 = await fresh(page)
        cdp = await ctx.new_cdp_session(page)
        await cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [{"x": RIGHT[0], "y": RIGHT[1], "id": 1}]})
        await asyncio.sleep(0.5)
        mid = await tel(page)
        await page.screenshot(path=f"{OUT}/f1_hold_right.png")
        await cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
        await asyncio.sleep(0.3)
        after = await tel(page)
        results["touch_hold_right"] = dict(
            x0=t0["x"], mid_x=mid["x"], flag_mid=mid["touchRight"], flag_after=after["touchRight"],
            PASS=mid["touchRight"] and mid["x"] > t0["x"] + 15 and not after["touchRight"])

        # 2. touch hold RIGHT with thumb drift (alpha.1 regression)
        t0 = await fresh(page)
        await cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [{"x": RIGHT[0], "y": RIGHT[1], "id": 2}]})
        for i in range(6):
            await cdp.send("Input.dispatchTouchEvent", {"type": "touchMove", "touchPoints": [{"x": RIGHT[0] + 4 * i, "y": RIGHT[1] + 3 * i, "id": 2}]})
            await asyncio.sleep(0.08)
        mid = await tel(page)
        await page.screenshot(path=f"{OUT}/f2_drift_right.png")
        await cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
        await asyncio.sleep(0.3)
        after = await tel(page)
        results["touch_drift_right"] = dict(
            x0=t0["x"], mid_x=mid["x"], flag_mid=mid["touchRight"], flag_after=after["touchRight"],
            PASS=mid["touchRight"] and mid["x"] > t0["x"] + 15 and not after["touchRight"])

        # 3. touch hold LEFT (walk right a bit first via keyboard, then left)
        t0 = await fresh(page)
        await page.mouse.click(640, 200)
        await page.keyboard.down("ArrowRight"); await asyncio.sleep(0.45); await page.keyboard.up("ArrowRight")
        await asyncio.sleep(0.3)
        x1 = (await tel(page))["x"]
        await cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [{"x": LEFT[0], "y": LEFT[1], "id": 3}]})
        await asyncio.sleep(0.5)
        mid = await tel(page)
        await page.screenshot(path=f"{OUT}/f3_hold_left.png")
        await cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
        await asyncio.sleep(0.3)
        after = await tel(page)
        results["touch_hold_left"] = dict(
            x_start=x1, mid_x=mid["x"], flag_mid=mid["touchLeft"], flag_after=after["touchLeft"],
            PASS=mid["touchLeft"] and mid["x"] < x1 - 15 and not after["touchLeft"])

        # 4. keyboard left/right
        t0 = await fresh(page)
        await page.mouse.click(640, 200)
        await page.keyboard.down("ArrowRight"); await asyncio.sleep(0.5); await page.keyboard.up("ArrowRight")
        await asyncio.sleep(0.2)
        xr = (await tel(page))["x"]
        await page.keyboard.down("ArrowLeft"); await asyncio.sleep(0.4); await page.keyboard.up("ArrowLeft")
        await asyncio.sleep(0.2)
        xl = (await tel(page))["x"]
        results["keyboard"] = dict(x0=t0["x"], after_right=xr, after_left=xl,
                                   PASS=xr > t0["x"] + 15 and xl < xr - 10)

        # 5. touch jump button
        t0 = await fresh(page)
        await cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [{"x": JUMP[0], "y": JUMP[1], "id": 4}]})
        await asyncio.sleep(0.3)
        mid = await tel(page)
        await page.screenshot(path=f"{OUT}/f5_jump.png")
        await cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
        results["touch_jump"] = dict(y_ground=t0["y"], y_air=mid["y"], PASS=mid["y"] < t0["y"] - 5)

        await browser.close()

    ok = True
    for name, r in results.items():
        print(f"{name}: {'PASS' if r['PASS'] else 'FAIL'}  {r}")
        ok = ok and r["PASS"]
    print("OVERALL:", "PASS" if ok else "FAIL")

asyncio.run(main())
