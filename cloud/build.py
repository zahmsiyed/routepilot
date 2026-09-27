"""Build a small, allowlisted Vercel app and downloadable Mac controller."""
from pathlib import Path
import shutil
import zipfile

CLOUD = Path(__file__).resolve().parent
ROOT = CLOUD.parent
PUBLIC = CLOUD / 'public'


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise RuntimeError(f'The cloud template changed; review this replacement: {old[:80]}')
    return text.replace(old, new, 1)


def build():
    if PUBLIC.exists():
        shutil.rmtree(PUBLIC)
    PUBLIC.mkdir()
    shutil.copytree(ROOT / 'routepilot/static', PUBLIC / 'static')
    shutil.copy2(CLOUD / 'browser-engine.js', PUBLIC / 'static/browser-engine.js')
    html = (PUBLIC / 'static/index.html').read_text()
    html = replace_once(html, '__SESSION_TOKEN__', 'hosted-planner')
    html = replace_once(html, '<script defer src="/static/app.js"></script>', '<script defer src="/static/browser-engine.js"></script><script defer src="/static/app.js"></script>')
    html = replace_once(html, '<p>Adjust speed, then press Start. Pause holds the current position. The endpoint stays applied until you press <strong>Restore real location</strong>.</p>', '<p>Adjust speed, then press <strong>Start preview</strong>. The marker moves in this browser only. Pause holds the preview position; Stop preview resets playback.</p>')
    html = replace_once(html, '<p>Keep the Mac running and USB connected. Closing this tab does not stop an active simulation. If the phone disconnects, reconnect and Restore. If that fails, restart the iPhone.</p>', '<p>Keep this tab visible for browser playback. Preview pauses in the background and ends when you reload or close the tab. Draft checkpoints are saved in this browser. To change iPhone location, choose <strong>Use with iPhone</strong> and run the Mac controller with USB connected.</p>')
    dialog = '''<dialog id="macDialog">
  <div class="dialog-heading"><h2>Use with iPhone</h2><button class="close-dialog button" aria-label="Close Mac controller help">×</button></div>
  <p>This website plans routes and previews movement. Applying locations to an iPhone requires the Mac controller and a USB connection.</p>
  <ol class="setup-steps">
    <li><strong>Install and open Xcode.</strong> Download <a href="https://developer.apple.com/xcode/" target="_blank" rel="noopener noreferrer">Xcode from Apple</a>, finish its first-launch setup, and keep it open while setting up Developer Mode.</li>
    <li><strong>Pair and enable Developer Mode.</strong> Connect your iPhone by USB, unlock it, and tap <strong>Trust This Computer</strong>. Select the iPhone in Xcode’s <strong>Device Hub</strong> (or <strong>Window → Devices and Simulators</strong> in older versions) and follow its pairing prompts. Developer Mode appears after pairing begins. On iPhone, open <strong>Settings → Privacy &amp; Security → Developer Mode</strong>, turn it on, restart, then confirm and enter your passcode. <a href="https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device" target="_blank" rel="noopener noreferrer">Apple’s setup guide</a></li>
    <li><strong>Download and allow the launcher.</strong> Download the Mac controller below and unzip it so the <strong>RoutePilot</strong> folder is inside <strong>Downloads</strong>. Open <strong>Terminal</strong> and paste these two commands:
      <pre class="setup-commands" aria-label="Terminal commands to allow the RoutePilot launcher"><code>xattr -dr com.apple.quarantine ~/Downloads/RoutePilot
chmod +x ~/Downloads/RoutePilot/"Launch RoutePilot.command"</code></pre>
      <p class="micro">These commands remove the folder’s download quarantine flag and make the launcher executable. Adjust the path if you put RoutePilot somewhere else.</p>
    </li>
    <li><strong>Launch and connect.</strong> Double-click <strong>Launch RoutePilot.command</strong> and keep its Terminal window open. The first launch installs dependencies and may take a few minutes. In the local app, select <strong>Connect iPhone</strong>. Live messages show each connection step.</li>
  </ol>
  <p>To transfer this route, export GPX under <strong>More options</strong>, then import it in the Mac controller. Imported checkpoints are routed again for your selected movement mode; choose the same mode and review the route. Set speed and variation again on the Mac.</p>
  <div class="dialog-actions"><a class="button" href="http://127.0.0.1:8765/" target="_blank" rel="noopener noreferrer">Open Mac controller</a><a class="button primary" href="/downloads/RoutePilot-Mac.zip" download>Download for Mac</a></div>
  <p class="micro">Open Mac controller works after launching the app on this Mac. The hosted website cannot access your USB devices.</p>
</dialog>
'''
    html = replace_once(html, '</body></html>', dialog + '</body></html>')
    (PUBLIC / 'index.html').write_text(html)
    (PUBLIC / 'static/index.html').unlink()
    runtime = CLOUD / 'routepilot_cloud'
    runtime.mkdir(exist_ok=True)
    (runtime / '__init__.py').write_text('"""Shared stateless planner helpers; no device access."""\n')
    for name in ('routes.py', 'routing.py', 'geocoding.py'):
        shutil.copy2(ROOT / 'routepilot' / name, runtime / name)
    downloads = PUBLIC / 'downloads'
    downloads.mkdir()
    with zipfile.ZipFile(downloads / 'RoutePilot-Mac.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for name in ('launch.py', 'Launch RoutePilot.command', 'requirements.txt', 'README.md', 'LICENSE'):
            archive.write(ROOT / name, 'RoutePilot/' + name)
        for directory in ('routepilot', 'examples'):
            for item in sorted((ROOT / directory).rglob('*')):
                if item.is_file() and '__pycache__' not in item.parts and not any(part.startswith('.') for part in item.relative_to(ROOT).parts) and item.suffix != '.pyc':
                    archive.write(item, 'RoutePilot/' + str(item.relative_to(ROOT)))
    print('Built hosted planner, stateless API helpers, and Mac controller download.')


if __name__ == '__main__':
    build()
