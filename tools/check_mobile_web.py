"""Play the exported game with phone touch input. Requires Playwright.

First generate coordinates with:
godot --headless --path . --script tests/mobile_ui_smoke.gd -- --geometry
Then run: python tools/check_mobile_web.py [--browser webkit]
"""
import argparse
import json
from itertools import count
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--browser", choices=["chromium", "webkit"], default="chromium")
parser.add_argument("--executable")
parser.add_argument("--input", choices=["touch", "mouse"], default="touch")
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
        dialogs = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("dialog", lambda dialog: (dialogs.append(dialog.message), dialog.dismiss()))
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
        page.evaluate("window.touchIdentifiers = []; canvas.addEventListener('touchstart', event => touchIdentifiers.push(event.changedTouches[0].identifier))")
        cdp = page.context.new_cdp_session(page) if args.browser == "chromium" else None
        finger_ids = count(41)
        dimensions = page.evaluate("[canvas.clientWidth, canvas.clientHeight, canvas.width, canvas.height]")
        assert dimensions == [390, 664, 585, 996], dimensions
        # Safari's address bar can issue many resize notifications in one motion.
        revision = page.evaluate("annihilationViewport.revision")
        for height in range(645, 665):
            page.set_viewport_size({"width": 390, "height": height})
        page.wait_for_timeout(700)
        assert page.evaluate("annihilationViewport.revision") <= revision + 2
        assert page.evaluate("[canvas.width, canvas.height]") == [585, 996]
        page.screenshot(path=str(ROOT / f"builds/mobile-{args.browser}-home.png"), scale="css")

        def location(control, size="390x664", shift=(0, 0)):
            point = geometry[size][control]
            offset = page.locator("#canvas").bounding_box()
            return point["x"] + offset["x"] + shift[0], point["y"] + offset["y"] + shift[1]

        def gesture(control, size="390x664", shift=(0, 0), movement=(0, 0)):
            finger_id = next(finger_ids)
            x, y = location(control, size, shift)
            if args.input == "mouse":
                page.mouse.click(x, y)
            elif cdp:
                cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [{"x": x, "y": y, "id": finger_id}]})
                if movement != (0, 0):
                    for step in range(1, 5):
                        cdp.send("Input.dispatchTouchEvent", {"type": "touchMove", "touchPoints": [{"x": x + movement[0] * step / 4, "y": y + movement[1] * step / 4, "id": finger_id}]})
                cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
            else:
                page.touchscreen.tap(x, y)

        def tap(control, size="390x664"):
            gesture(control, size)

        tap("start")
        page.wait_for_timeout(700)
        page.screenshot(path=str(ROOT / f"builds/mobile-{args.browser}-campaign.png"), scale="css")
        tap("level")
        page.wait_for_timeout(2300)
        # Missing the particle slightly, repeated taps, and finger jitter must not clear it.
        if args.input == "touch":
            gesture("source", shift=(-geometry["390x664"]["cell_size"] / 2 - 7, 0))
            tap("source")
            tap("source")
            gesture("source", movement=(10, 8))
        else:
            tap("source")
        page.wait_for_timeout(200)
        page.screenshot(path=str(ROOT / f"builds/mobile-{args.browser}-selected.png"), scale="css")
        page.set_viewport_size({"width": 844, "height": 300})
        page.wait_for_timeout(800)
        page.screenshot(path=str(ROOT / f"builds/mobile-{args.browser}-landscape.png"), scale="css")
        page.evaluate("document.getElementById('game').style.inset = '0px 47px 21px'")
        page.wait_for_timeout(700)
        assert page.evaluate("[canvas.clientWidth, canvas.clientHeight, canvas.width, canvas.height]") == [750, 279, 1125, 418]
        if cdp and args.input == "touch":
            gesture("source", "750x279", movement=(80, 3))
        else:
            tap("target", "750x279")
        page.wait_for_timeout(700)
        page.evaluate("window.readProgress = " + READ_PROGRESS)
        page.wait_for_function("async () => (await readProgress())?.records?.['01']?.easy === true", timeout=15000)
        assert page.evaluate("readProgress()")["records"]["01"]["best"] == 1
        if cdp and args.input == "touch":
            ids = page.evaluate("touchIdentifiers")
            assert min(ids) >= 41 and len(set(ids)) >= 5, ids
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
        assert not dialogs, dialogs
        page.evaluate("""async () => {
          window.orientationRequests = [];
          document.documentElement.requestFullscreen = async () => orientationRequests.push('fullscreen');
          Object.defineProperty(screen.orientation, 'lock', {configurable: true, value: async value => orientationRequests.push(value)});
          await annihilationPlay();
        }""")
        assert page.evaluate("orientationRequests") == ["fullscreen", "landscape"]
        # Lose a real GPU context after startup. Recovery must replace the modal
        # engine alert, lower the buffer, preserve saves, and accept input again.
        assert page.evaluate("""() => {
          const gl = canvas.getContext('webgl2');
          const extension = gl.getExtension('WEBGL_lose_context');
          if (!extension) return false;
          extension.loseContext();
          return true;
        }""")
        page.wait_for_function("document.querySelector('#retry')?.hidden === false")
        assert "graphics session stopped" in page.locator("#status-notice").inner_text()
        assert not dialogs, dialogs
        page.locator("#retry").click()
        page.wait_for_url("**/?render=compat")
        page.wait_for_function('document.querySelector("#status") === null', timeout=120000)
        page.wait_for_timeout(600)
        assert page.evaluate("[canvas.clientWidth, canvas.clientHeight, canvas.width, canvas.height]") == [390, 664, 390, 664]
        page.evaluate("window.readProgress = " + READ_PROGRESS)
        assert page.evaluate("readProgress()")["records"]["01"]["easy"] is True
        tap("start")
        page.wait_for_timeout(500)
        tap("level")
        page.wait_for_timeout(2300)
        page.wait_for_function("async () => (await readProgress())?.resume?.level_id === '01'", timeout=15000)
        tap("source")
        tap("target")
        page.wait_for_timeout(600)
        page.wait_for_function("async () => Object.keys((await readProgress()).resume).length === 0", timeout=15000)
        page.screenshot(path=str(ROOT / f"builds/mobile-{args.browser}-{args.input}-recovered.png"), scale="css")
        assert not errors, errors
        startup = browser.new_page(viewport={"width": 390, "height": 664}, device_scale_factor=3, is_mobile=True, has_touch=True)
        startup.on("dialog", lambda dialog: (dialogs.append(dialog.message), dialog.dismiss()))
        startup.add_init_script("""(() => {
          const getContext = HTMLCanvasElement.prototype.getContext;
          let scheduled = false;
          HTMLCanvasElement.prototype.getContext = function (...args) {
            const context = getContext.apply(this, args);
            if (this.id === 'canvas' && args[0] === 'webgl2' && context && !scheduled) {
              scheduled = true;
              setTimeout(() => context.getExtension('WEBGL_lose_context').loseContext(), 50);
            }
            return context;
          };
        })();""")
        startup.goto(f"http://127.0.0.1:{server.server_port}/", wait_until="load")
        startup.wait_for_function("document.querySelector('#retry')?.hidden === false", timeout=120000)
        assert "graphics session stopped" in startup.locator("#status-notice").inner_text()
        startup.wait_for_timeout(1000)
        assert startup.locator("#retry").is_visible()
        assert not dialogs, dialogs
        startup.close()
        offline = browser.new_page(viewport={"width": 390, "height": 664})
        offline.route("**/index.js", lambda route: route.abort())
        offline.goto(f"http://127.0.0.1:{server.server_port}/", wait_until="load")
        assert offline.locator("#retry").is_visible()
        assert "Unable to load" in offline.locator("#status-notice").inner_text()
        offline.close()
        browser.close()
        print(f"{args.browser}/{args.input}: bounded rendering, resize debounce, safe areas, input, completion, pause/settings, saved progress, GPU loss recovery and loader retry passed.")
finally:
    server.shutdown()
