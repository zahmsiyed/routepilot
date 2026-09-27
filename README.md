# RoutePilot

A local Mac program for planning routes and applying developer-simulated locations to a USB-connected iPhone. Includes stationary, running, and driving modes. No account or API key required.

Source: [zahmsiyed/routepilot](https://github.com/zahmsiyed/routepilot) (private). Live planner: [routepilot-zeta.vercel.app](https://routepilot-zeta.vercel.app).

## Hosted planner on Vercel

The hosted version supports location search, pedestrian/driving routes, draggable checkpoints, units, speed and variation controls, GPX import/export, and browser preview. Playback is isolated to each tab, pauses while the tab is hidden, and ends on reload or close. Drafts remain in that browser's local storage. The Mac playback/recovery behavior described below applies to the local controller.

Choose **Use with iPhone** on the website to download the Mac controller or open an already running controller at `http://127.0.0.1:8765/`. Vercel cannot connect to a Mac's USB device. Export GPX from the website, import it locally, choose the same movement mode, review the recalculated route, and set speed/variation again before starting on the iPhone. GPX transfer uses up to 24 checkpoints; it does not preserve arbitrary track geometry or random variations exactly.

The cloud function only handles search, route calculation, and GPX conversion; it has no device commands or shared playback sessions. Search queries and routing coordinates pass through Vercel to Photon/FOSSGIS. GPX conversion sends the file or route to Vercel. Warm instances retain small provider-response caches for up to one hour; provider pacing is per instance, not a global rate limit. This build is intended for personal, modest use. Hosted GPX imports allow 3.5 MB before JSON encoding; requests and exports are limited to 4 MB.

To build and check locally (Python with the root dependencies, plus Node/npm):

```sh
python3 -B cloud/build.py
node --test tests/*.test.cjs cloud/tests/*.test.cjs
python3 -B -m pytest -q tests cloud/tests/test_api.py
```

Vercel uses `cloud` as the project's Root Directory with **Include source files outside of the Root Directory in the Build Step** enabled. The build command `python3 build.py` copies an allowlist of stateless Python helpers, static assets, and a Mac source download from the repository. The output directory is `public`. Generated files are intentionally excluded from source control; each deployment rebuilds them. Only the stateless cloud API and generated public files are served. Device environments, pairing records, local tokens, and Python virtual environments are excluded from the repository.

Push to the repository's default branch to deploy production through the connected Vercel project. For a manual deployment, run `npx vercel link --project routepilot --scope zahmsiyeds-projects` from the repository root once, then `npx vercel --prod --scope zahmsiyeds-projects` from that same root. This includes the Mac sources needed by the build while Vercel runs the app from `cloud`.

## Launch

Unzip the downloaded Mac controller so its **RoutePilot** folder is inside **Downloads**. Open **Terminal** and paste these two commands to allow the downloaded launcher to run:

```sh
xattr -dr com.apple.quarantine ~/Downloads/RoutePilot
chmod +x ~/Downloads/RoutePilot/"Launch RoutePilot.command"
```

The first command removes the folder’s download quarantine flag; the second makes the launcher executable. Use `~` without a backslash so the shell expands your home directory. Adjust the path if you saved the folder somewhere else.

Double-click **Launch RoutePilot.command**. Keep its Terminal window open, then use the browser page at **http://127.0.0.1:8765**.

The launcher installs the pinned dependencies and a versioned copy of the app in `~/Library/Caches/RoutePilot`. This keeps runtime files out of synced project folders. An interrupted installation is repaired on the next launch. Set `ROUTEPILOT_CACHE_DIR` to choose another local cache folder. Install Python 3.10+ (3.13 recommended) or [uv](https://docs.astral.sh/uv/) first if neither is available.

From Terminal:

```sh
cd /path/to/RoutePilot
python3 -B launch.py
```

If another application uses port 8765, add `--port 8766`. Repeated launches reopen an existing RoutePilot controller without interrupting its session. Add `--no-open` to keep the browser closed.

## Connect your iPhone

1. For first-time Developer Mode setup, download [Xcode from Apple](https://developer.apple.com/xcode/), open it, and complete its first-launch setup. Keep Xcode open while pairing your iPhone and enabling Developer Mode.
2. Connect the iPhone to the Mac with a data-capable USB cable, unlock it, and tap **Trust This Computer**. Enter the passcode on the phone if requested.
3. Select the iPhone in Xcode’s **Device Hub** (or **Window → Devices and Simulators** in older versions) and follow its pairing prompts. Developer Mode appears after pairing begins; see [Apple’s setup guide](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).
4. On iPhone, open **Settings → Privacy & Security → Developer Mode**. Enable it, restart, and confirm after restarting, entering your passcode when prompted.
5. Click **Connect iPhone** in RoutePilot, select the USB device, and click **Connect** in the dialog. The first connection may download and mount the matching Apple developer disk image.
6. Choose your location or route, then click **Apply location** or **Start on iPhone**.

Connection alone does not set a location. Preview mode never sends location changes to an iPhone.

The connection dialog shows live milestones for USB/Trust, Developer Mode, developer-image preparation, the secure connection, and location control. Each step shows its elapsed time; completed and failed steps remain visible. Close the dialog and use **View connection progress** to reopen it, or reload the page to recover the same attempt. If status updates are interrupted, the dialog labels the last confirmed step until updates resume. Connection commands are not retried automatically.

Developer Mode is checked before downloading an image. An already-mounted image is reused. For iOS 17+, image preparation runs separately so its synchronous download does not freeze the controller; it has a two-minute deadline within the overall connection deadline. A failed attempt shows the step and suggested next action, then enables **Try again** once cleanup finishes.

**Hardware verification:** an iPhone 15 Plus connection on iOS 26.6.2 and a successful restore were observed during development. The motion options were tested in preview; their appearance in individual iPhone apps has not been verified. The app uses the pinned pymobiledevice3 11.12.5 implementation; iOS updates can affect compatibility.

## Create a location or route

Choose a movement mode, click the map to add checkpoints, adjust speed, and press Start.

Use **Search places or addresses** above the map to find a destination. Press Enter or Search, select a match to preview it, then click **Add checkpoint** (running/driving) or **Use this location** (stationary). Adding a search result supports Undo. Search remains available during playback, with checkpoint edits disabled until you stop or restore the session. Add a city to narrow ambiguous names. Escape dismisses results; the × button clears the search.

- **Stationary:** selects and holds one location. Speed is hidden because there is no movement.
- **Running:** automatically calculates a pedestrian route between checkpoints.
- **Driving:** automatically calculates a driving route between checkpoints.
- Every checkpoint has a **Remove** button. **Undo** reverses the last checkpoint addition, move, removal, clear, import, or reversal. ⌘Z / Ctrl+Z also works outside text fields. Undo history lasts for the current page session.
- Drag a numbered marker to move it, or click it to remove it immediately. Markers appear as soon as you add a checkpoint, while its route is calculating. Add up to 24 checkpoints.
- Routes recalculate automatically after edits and mode changes. Start is disabled while a route is being calculated or if routing fails. There is no straight-line fallback. Retry the route or move a checkpoint if the service cannot find a route.
- Speed defaults to 10 km/h for running and 50 km/h for driving. The numeric field accepts 0.1–250 km/h, including during playback.
- **Metric / Imperial** switches speed, distance, and variation units. The underlying values stay unchanged, including during playback.
- **Vary speed** adds smooth changes within your selected ± range (up to 50 km/h / 31.07 mph), bounded to the overall speed limits. The current speed is shown during playback.
- **Lateral drift** adds an optional, smooth side-to-side offset. The default range is ±0.75 m / 2.46 ft; the maximum is ±2 m / 6.56 ft. Drift fades to zero at route vertices and endpoints. It approximates small coordinate variation; it does not model lane width or guarantee that every offset remains inside a mapped path.
- Both variation options are off by default, work only in running/driving modes, and can be adjusted during playback. Stationary remains fixed.
- **Pause** holds the current position and freezes variation; **Resume** continues. Use **Restore real location** to end a phone simulation. The endpoint remains applied when a route finishes.

The main screen contains mode, units, speed, optional variation, checkpoints, and playback controls. On desktop, Start/Stop remains visible while settings and the checkpoint list scroll. **More options** contains coordinate entry, loops, reversal, and GPX tools. Looping automatically routes the return leg to the first checkpoint. Reversing a trip recalculates it for the selected mode, including one-way road restrictions.

The route draft is saved in this browser. Reloading during playback recovers the active route, mode, checkpoints, and speed from the controller, while retaining your local checkpoint draft. A storage failure is reported instead of silently promising persistence. Playback runs in the Mac process and continues if the tab closes. Positions update approximately every half second. The selected speed controls coordinate timing; individual apps may derive speed differently. This does not directly set Core Location altitude/heading/speed fields, model traffic, or simulate traffic-aware acceleration/braking. Speed variation uses smooth random targets over 6–12 seconds, and lateral variation uses 8–16-second targets.

## Recovery behavior

- Requests have deadlines. A timed-out Start, Pause, or Restore is never retried automatically, because the device action may already have completed. The interface checks the controller status before enabling further actions.
- Status responses carry revisions; a late response cannot overwrite a newer state. Browser control requests also include a session ID, so a delayed action from an old session is rejected.
- A second Start cannot replace an active session. Pause/Resume requests specify the intended state, so duplicate requests do not toggle it twice.
- Pause waits for the current device write to finish and keeps applying the held coordinate. A lost connection is reported without claiming that real GPS was restored.
- Restore is available independently of queued speed changes. A failed restore preserves the recovery-required state. Device cleanup has time limits, and cleanup errors do not hide the original connection error.
- Routing includes a queue deadline, response-size limits, and geometry validation. Provider failures, rate limits, malformed responses, and zero-length routes produce actionable errors without falling back to a straight line.
- Large GPX parsing/export work runs outside the playback loop. Loop closure respects the point limit, and exports retain exact route endpoints.

These protections cannot guarantee recovery after a forced process kill, Mac shutdown, or a physically disconnected phone. Reconnect and Restore; restart the iPhone if restoration cannot be confirmed.

## GPX

Open **More options → Import GPX checkpoints** to import a single GPX track segment, route, or waypoint list (up to 30,000 source points and 4 MB). The interface selects up to 24 evenly spaced checkpoints from the file, retaining the endpoints, then calculates a pedestrian or driving route through them. This intentionally does not replay the original GPX geometry or timestamps exactly. Multi-segment tracks must be split first.

**Export GPX** saves the calculated route with timing from your base speed. Random speed variation and lateral drift are not included in the export. It includes track points for ordinary GPX tools and waypoints for Xcode. Exports preserve route turns and add timed samples, subject to a 30,000-point cap. Some tools may display both representations; RoutePilot reads the track when both exist. Very long exports may exceed the 4 MB import limit.

## Stop and recover

Use **Restore real location** while the phone is still connected. The app sends the developer service's clear command, then stops applying coordinates. Check the phone's Maps app for its real position; location consumers may cache a previous reading.

Closing the browser does **not** stop the Mac server or an active simulation. Keep the Mac awake and USB connected during playback. After sleep, playback resumes near the last simulated position rather than jumping far ahead.

Control-C in the Terminal attempts a GPS restore before closing the device connection. Forced termination, cable loss, or a device service error can prevent that. Reconnect the same phone and use **Restore real location**; the app attempts to reopen that phone's service if needed. If restore still fails, restart the iPhone. The interface preserves an error state when a clear command fails; it does not falsely report success.

## Network and privacy

The controller listens only on `127.0.0.1`. Device-control API calls require a per-process token, and cross-site requests are rejected. There is no cloud account, telemetry, or saved location history. The current route exists in browser local storage and server memory. Clear site data to remove the saved draft.

Map tiles load directly from OpenStreetMap. Adding or editing checkpoints in Running or Driving mode automatically sends the selected coordinates to the public FOSSGIS/OSRM routing service. That service logs requests; see its [privacy and usage information](https://routing.openstreetmap.de/about.html). Requests are rate-limited locally to at most one per second. Map tiles and routing require an internet connection; stationary positioning and an already calculated route can run without those services once dependencies/device resources are available. New or edited moving routes require routing access.

Submitted place/address queries are sent through the local controller to [Photon](https://github.com/komoot/photon#demo-server), using OpenStreetMap data. Typing alone sends no search requests. The controller spaces searches at least 1.1 seconds apart and keeps up to 128 query/result pairs in memory for 24 hours; these are cleared when the controller exits. Search has a 25-second deadline including queue time and does not block device commands. The public service is intended for modest use and has no availability guarantee. Set `ROUTEPILOT_GEOCODER_URL` to the full `/api/` URL of another compatible Photon instance before launching to change the provider.

## Compatibility and limits

This is a Mac controller for iOS developer location simulation. It does not install an ordinary iPhone app, alter your IP address, or guarantee that every app will accept the simulated location. Apple exposes an [`isSimulatedBySoftware`](https://developer.apple.com/documentation/corelocation/cllocationsourceinformation/issimulatedbysoftware) flag, and apps can use it. The Mac must remain connected and running for route playback.

The connector opens a persistent DVT service over the current library's automatically selected no-root tunnel for iOS 17+. It also includes the library's legacy connection path for earlier iOS versions, which was not tested on hardware. No jailbreak or privileged tunnel daemon is configured by this app.

## Development and verification

```sh
uv pip install --python .venv/bin/python -r requirements-dev.txt
.venv/bin/python -m pytest -q
node --test tests/*.test.cjs
```

Pytest is configured to load only the required asyncio plugin, avoiding unrelated plugins from device dependencies. Tests cover distance/interpolation (including the date line), loop continuity, speed/coordinate validation, GPX timing and XML handling, playback/pause/restore, disconnect errors, shutdown cleanup, and local API access checks. Fake-device tests validate command flow; they do not establish hardware compatibility.

Source layout:

- `launch.py`: cached runtime setup and atomic source staging.
- `routepilot/routes.py`: validated geometry and GPX.
- `routepilot/routing.py`: validation of external routing responses.
- `routepilot/geocoding.py`: place/address search, provider validation, caching, and request limits.
- `routepilot/engine.py`: playback lifecycle.
- `routepilot/motion.py`: smooth bounded speed and lateral variation.
- `routepilot/device.py`: real iPhone transport and preview adapter.
- `routepilot/connection.py`: connection milestones, elapsed times, and failure recovery status.
- `routepilot/server.py`: local HTTP API.
- `routepilot/static/`: simple browser interface, automatic route planner, map, and locally vendored Leaflet.

## Sources and third-party code

- [pymobiledevice3 Python API](https://doronz88.github.io/pymobiledevice3/guides/python-api/) and [iOS tunnel documentation](https://doronz88.github.io/pymobiledevice3/guides/ios17-tunnels/).
- [Apple: enabling Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).
- [Apple: simulating locations](https://developer.apple.com/documentation/xcode/simulating-location-in-tests).
- [OSRM API](https://project-osrm.org/docs/v5.24.0/api/).

pymobiledevice3 is GPL-3.0 licensed. RoutePilot's source is supplied under GPL-3.0-or-later; see `LICENSE`. Vendored Leaflet 1.9.4 is BSD-2-Clause licensed; its notice is included in `routepilot/static/vendor/LEAFLET-LICENSE`. Map data is © OpenStreetMap contributors, under ODbL. Other installed Python packages retain their own licenses.
