"""Play the exported game with phone touch input. Requires Playwright.

First generate coordinates with:
godot --headless --path . --script tests/mobile_ui_smoke.gd -- --geometry
Then run: python tools/check_mobile_web.py [--browser webkit]
"""
import argparse
import json
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--browser", choices=["chromium", "webkit"], default="chromium")
parser.add_argument("--executable")
args = parser.parse_args()
geometry = json.loads((ROOT / "builds/mobile-controls.json").read_text())


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def log_message(self, *_args):
        pass


server = ThreadingHTTPServer(("127.0.0.1", 0), partial(Handler, directory=str(ROOT / "builds/web")))
Thread(target=server.serve_forever, daemon=True).start()
READ_PROGRESS = """async () => {
 const request = r => new Promise((resolve, reject) => {
  r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error);
 });
 for (const info of await indexedDB.databases()) {
  const db = await request(indexedDB.open(info.name));
  try {
   for (const name of db.objectStoreNames) {
    const store = db.transaction(name, 'readonly').objectStore(name);
    const [keys, values] = await Promise.all([request(store.getAllKeys()), request(store.getAll())]);
    for (let i = 0; i < keys.length; i++) {
     if (typeof keys[i] === 'string' && keys[i].endsWith('/progress.json'))
      return JSON.parse(new TextDecoder().decode(values[i].contents));
    }
   }
  } finally { db.close(); }
 }
 return null;
}"""

try:
    with sync_playwright() as playwright:
        options = {"headless": True}
        if args.executable:
            options["executable_path"] = args.executable
        if args.browser == "chromium":
            options["args"] = ["--mute-audio", "--autoplay-policy=user-gesture-required"]
        browser = getattr(playwright, args.browser).launch(**options)
        page = browser.new_page(
            viewport={"width": 390, "height": 664}, device_scale_factor=3,
            is_mobile=True, has_touch=True,
            user_agent=playwright.devices["iPhone 13"]["user_agent"],
        )
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("console", lambda msg: errors.append(msg.text) if "SCRIPT ERROR" in msg.text else None)
        # Exercise the unsupported orientation-lock path used on iPhone.
        page.add_init_script("Object.defineProperty(screen.orientation, 'lock', {value: undefined, configurable: true})")
        page.goto(f"http://127.0.0.1:{server.server_port}/", wait_until="domcontentloaded")
        assert page.title() == "ANNIHILATION"
        assert page.locator("#status h1").inner_text() == "ANNIHILATION"
        assert page.locator("#status img").count() == 0
        page.screenshot(path=str(ROOT / f"builds/mobile-{args.browser}-loading.png"), scale="css")
        page.wait_for_function('document.querySelector("#status") === null', timeout=120000)
        page.wait_for_timeout(600)
        dimensions = page.evaluate("[canvas.clientWidth, canvas.clientHeight, canvas.width, canvas.height]")
        assert dimensions == [390, 664, 1170, 1992], dimensions
        page.screenshot(path=str(ROOT / f"builds/mobile-{args.browser}-home.png"), scale="css")

        def tap(control, size="390x664"):
            point = geometry[size][control]
            offset = page.locator("#canvas").bounding_box()
            page.touchscreen.tap(point["x"] + offset["x"], point["y"] + offset["y"])

        tap("start")
        page.wait_for_timeout(700)
        page.screenshot(path=str(ROOT / f"builds/mobile-{args.browser}-campaign.png"), scale="css")
        tap("level")
        page.wait_for_timeout(2300)
        tap("source")
        page.wait_for_timeout(200)
        page.screenshot(path=str(ROOT / f"builds/mobile-{args.browser}-selected.png"), scale="css")
        page.set_viewport_size({"width": 844, "height": 300})
        page.wait_for_timeout(800)
        page.screenshot(path=str(ROOT / f"builds/mobile-{args.browser}-landscape.png"), scale="css")
        page.evaluate("document.getElementById('game').style.inset = '0px 47px 21px'")
        page.wait_for_timeout(700)
        assert page.evaluate("[canvas.clientWidth, canvas.clientHeight, canvas.width, canvas.height]") == [750, 279, 2250, 837]
        tap("target", "750x279")
        page.wait_for_timeout(700)
        page.evaluate("window.readProgress = " + READ_PROGRESS)
        page.wait_for_function("async () => (await readProgress())?.records?.['01']?.easy === true", timeout=15000)
        assert page.evaluate("readProgress()")["records"]["01"]["best"] == 1
        page.evaluate("document.getElementById('game').style.inset = ''")
        page.wait_for_timeout(500)
        tap("pause", "844x300")
        page.wait_for_timeout(250)
        page.screenshot(path=str(ROOT / f"builds/mobile-{args.browser}-pause.png"), scale="css")
        tap("pause_settings", "844x300")
        page.wait_for_timeout(500)
        page.set_viewport_size({"width": 390, "height": 664})
        page.wait_for_timeout(700)
        page.screenshot(path=str(ROOT / f"builds/mobile-{args.browser}-settings.png"), scale="css")
        tap("settings_tabs")
        page.wait_for_timeout(250)
        page.screenshot(path=str(ROOT / f"builds/mobile-{args.browser}-settings-tabs.png"), scale="css")
        page.reload(wait_until="load")
        page.wait_for_function('document.querySelector("#status") === null', timeout=120000)
        page.evaluate("window.readProgress = " + READ_PROGRESS)
        assert page.evaluate("readProgress()")["records"]["01"]["easy"] is True
        assert not errors, errors
        page.evaluate("""async () => {
          window.orientationRequests = [];
          document.documentElement.requestFullscreen = async () => orientationRequests.push('fullscreen');
          Object.defineProperty(screen.orientation, 'lock', {configurable: true, value: async value => orientationRequests.push(value)});
          await annihilationPlay();
        }""")
        assert page.evaluate("orientationRequests") == ["fullscreen", "landscape"]
        offline = browser.new_page(viewport={"width": 390, "height": 664})
        offline.route("**/index.js", lambda route: route.abort())
        offline.goto(f"http://127.0.0.1:{server.server_port}/", wait_until="load")
        assert offline.locator("#retry").is_visible()
        assert "Unable to load" in offline.locator("#status-notice").inner_text()
        offline.close()
        browser.close()
        print(f"{args.browser}: phone loading, high-DPI canvas, safe areas, taps, rotation, completion, pause/settings, saved progress and loader retry passed.")
finally:
    server.shutdown()
