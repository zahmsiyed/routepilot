# Verification

Verified on this Mac on September 13, 2026.

- 37 Python tests passed: route distance/interpolation, date-line crossing, loop continuity, input validation, GPX round trips and timestamps, XML entity rejection, pause/resume, speed changes, route completion, device disconnect failures, restore errors, orderly shutdown, and API request protection.
- JavaScript syntax checked with Node.
- Real-browser tests passed for preview running, stationary, and driving sessions; pause/resume; changing speed; and stopping.
- Public FOSSGIS pedestrian and car routing both returned playable geometry.
- A driving route was exported through the browser and re-imported successfully (188 points), and the draft persisted across reload.
- Desktop and 390-pixel mobile layouts were inspected. Mobile had no horizontal overflow.
- Browser console contained no errors or warnings during the tested flows.
- USB discovery identified a paired iPhone 15 Plus on iOS 26.6.2. Opening the developer location service was blocked by Developer Mode being disabled.

At the initial build, hardware location injection, location clear, and behavior in individual iPhone apps remained unverified. The tests do not claim otherwise. No test coordinates were sent to the real phone.

## Simplified interface update

- The main interface now contains only movement mode, speed, checkpoints, and playback. Coordinates, looping, reversal, and GPX tools are under More options.
- Seven route-planner tests cover automatic pedestrian/car profile selection, stale response rejection, rapid edit coalescing, route failures, checkpoint removal during a pending request, and routed loop closure.
- Browser checks passed for automatic pedestrian and driving routing, speed adjustment, stationary preview, pause/resume, remove checkpoint, undo removal, undo addition, and undo clear. Start remained disabled until the correct route was ready.
- Browser tests used a separate preview server on port 8766. No phone location changes were made. The old paused preview on the main server was stopped after the update, leaving the user's checkpoints intact and editing enabled.
- The updated interface was visually inspected in the in-app browser, and its automatic pedestrian route was ready.

## Checkpoint, units, and motion update

- 53 Python tests passed on both Python 3.14.2 and the refreshed app runtime, Python 3.13.12. Added deterministic tests for smooth bounded noise, speed limits and integration, perpendicular lateral offsets, exact vertices/endpoints, date-line crossing, stationary behavior, pause, disabling variation, and atomic validation of live API updates.
- 9 JavaScript tests passed, including exact unit conversions and round trips plus the existing route planner tests.
- Browser checks used a separate preview server on port 8766. Visible checkpoint addition, dragging without deletion, direct single-click removal, and Undo for addition, dragging, and removal passed.
- Repeated Metric/Imperial switching preserved the underlying speed and drift ranges exactly. Live imperial speed edits and enabling/disabling both variation options passed. Oversized drift was rejected.
- Preview playback produced changing speeds and lateral offsets inside their configured bounds. Pause held the exact position; Stop ended the preview. Stationary held one point with movement settings hidden.
- Pedestrian and driving routing both succeeded after the UI changes. Desktop playback controls remained visible. The 390-pixel layout had no horizontal overflow.
- These motion tests did not send test coordinates to the user's iPhone.

- The main controller was restarted with a refreshed copy of the pinned Python dependencies. The previous idle iPhone connection accepted a restore command. USB discovery returned no devices before and after the restart; the updated app was left idle in preview mode. No new route was started on the real phone during this update.

## Reliability hardening — September 14, 2026

- 82 Python tests and 17 JavaScript tests passed. New coverage includes repeated Start/Pause, session-ID conflicts, cancelled first writes, slow writes and paused disconnects, failed cleanup/restore, numeric overflow, malformed and unavailable routing providers, maximum loop size, exact GPX endpoints, bounded browser requests, stale status rejection, source-cache staging, and existing-controller detection.
- Browser fault checks verified rejection/rollback of a failed speed update, recovery of active geometry/checkpoints/mode/speed after reload with a different saved draft, network failure and recovery, and Stop after reconnection. No test route was applied to a real iPhone.
- Runtime dependencies and a versioned application copy now live in the local RoutePilot cache. The launcher was exercised against a preview server, and a repeated launch reused the existing instance successfully. This avoids the filesystem timeouts observed while reading environment files inside Documents.
- The main controller was restarted using the cache launcher. Its status/session endpoints and current frontend files were verified on port 8765; it is idle in preview mode. Actual behavior in individual iPhone apps remains outside these automated and preview checks.

## Live connection progress — September 14, 2026

- 91 Python tests and 17 JavaScript tests passed. New tests verify status responses while Connect remains pending, recovery of the same attempt through the session endpoint, step timing, failed-step preservation, fresh retry IDs, early Developer Mode rejection, reuse of an already-mounted image, and termination of the image worker after cancellation or timeout.
- A separate browser fixture used a fake phone transport and controlled delays. Checks passed for live milestones and elapsed time, disabled duplicate Connect, reload recovery including the selected device, interrupted status updates and recovery, closing/reopening the dialog, failure details, retry, success, and return to preview. The success history remains visible for review.
- Desktop and 390-pixel mobile progress layouts were visually inspected. The mobile page had no horizontal overflow. Expected injected request failures were used to verify the recovery UI.
- These checks did not connect to or change the location of a real iPhone.
- The cached controller on port 8765 was restarted while idle in preview. The current progress markup/script and the status/session progress payloads were verified. A later simulated USB error also correctly replaces the previous connection-success message.

## Location search — September 14, 2026

- 111 Python tests and 21 JavaScript tests passed. New coverage includes query validation, provider response validation, caching of concurrent duplicate queries, rate limiting, service failures and recovery, stale-response rejection, and searches independent of device-operation locks.
- Live Photon queries returned both Golden Gate Park and the street address 1600 Amphitheatre Parkway, Mountain View. Browser checks verified keyboard selection, map preview before mutation, checkpoint addition and Undo, stationary replacement and Undo, searching during preview playback with edits blocked, empty results, service errors, and discarded responses after editing the query.
- Desktop and 390-pixel mobile layouts were inspected. The selected location remained visible below the search panel, and the mobile page had no horizontal overflow.
- Search tests used the separate controller on port 8767 and did not apply coordinates to an iPhone. The original controller on port 8765 had an idle saved iPhone connection; its restore attempt found no matching USB device. That controller was retained with its recovery-required state pending USB reconnection.

## Vercel deployment — September 15, 2026

- Production: https://routepilot-zeta.vercel.app (project `zahmsiyeds-projects/routepilot`, deployment `dpl_4nrLchZYwGubR39aTPpeC35292i8`, Ready). Vercel built the stateless API using Python 3.12. The Mac controller remains local; no USB runtime or device session is hosted.
- 111 existing Python tests passed, plus 5 hosted API tests and all 27 JavaScript tests. The new preview tests cover session isolation, stale commands, pause/resume, atomic validation, stationary mode, completion, repeated loops, long timer gaps, dateline interpolation, antipodes, polar coordinates, bounded speed variation, and lateral drift fading at vertices.
- Live production checks verified all 10 referenced static assets, Photon search, pedestrian (`foot`) and driving (`car`) routes with different geometry, GPX export/import round-trip, rejection of device endpoints and cross-origin requests, and a working Mac ZIP download. The ZIP's integrity was checked locally. A missing preview script in the first upload was corrected and verified after redeployment.
- Browser checks on production verified search, selecting and adding a result, building the sample pedestrian route, preview playback with both variations enabled, Pause/Resume/Stop, metric-to-imperial conversion, and the Mac controller handoff dialog. Preview state is per tab and ends on reload; hidden tabs pause playback.
- No real iPhone was connected or given test coordinates during deployment. Existing local controllers were left running. Hosted GPX import selects checkpoints and reroutes; it does not promise exact geometry/timing transfer. Provider availability and global rate limits remain external constraints.

## Xcode and launcher setup update — September 15, 2026

- Added first-time Xcode installation, opening, USB pairing, and Developer Mode restart/confirmation instructions, following Apple’s Developer Mode documentation. Added the requested scoped `xattr` and `chmod` commands with working, unescaped home-directory paths to the hosted setup dialog, local app Help, and README.
- Rebuilt the Mac download and confirmed its README and UI contain the same commands. Checked shell syntax without executing either command, validated ZIP integrity, and inspected the live setup dialog at a compact viewport. The taller setup dialogs scroll and command text wraps within the panel.
- Published production deployment `dpl_AriNdDBSpR58k34SUK5hFzWXSRgc` at https://routepilot-zeta.vercel.app. This change updates setup documentation and styling; no device commands or playback behavior changed.

## Git repository setup — September 26, 2026

- Created private repository https://github.com/zahmsiyed/routepilot with default branch `codex/main` and connected it to the existing Vercel `routepilot` project. Source control is rooted at the RoutePilot app folder; no enclosing folders are included.
- Reviewed 52 initial source files. Local environments, deployment credentials, generated cloud output, and cache files are excluded. Exported the committed files into a clean directory, built the hosted app and Mac download successfully, and passed all 116 Python and 27 JavaScript checks from that clean directory.
- Vercel's Root Directory is `cloud`, access to source files outside that directory is enabled for the build, and `python3 build.py` now generates the hosted assets and stateless helpers on each deployment. Python 3.12 is pinned to match the existing hosted runtime.

## GPX creator — September 27, 2026

- All 137 Python tests and 31 JavaScript tests passed. Added checks for UTC conversion, strictly increasing timestamps, exact route corners/endpoints, loops, stationary exports, separate track/route/waypoint formats, XML escaping, invalid dates and speeds, one-year duration limits, 30,000-point limits, metric/imperial pace, safe filenames, and exports that leave an active session unchanged.
- Built the hosted assets, stateless GPX helper, and Mac download successfully. Browser checks on an isolated preview controller verified timed-track downloads using total duration, untimed-route downloads, imperial pace, invalid-pace rejection, exports during active playback, and stationary Xcode downloads. The creator was visually inspected at the existing desktop viewport, and no browser console errors were reported.
- Strava's upload, timestamp, and virtual-activity documentation was reviewed. The interface distinguishes planned routes from timestamped simulated tracks and includes manual upload guidance. No Strava account import or real iPhone/Strava recording was performed; Virtual Run classification and acceptance of simulated iPhone locations are not claimed.
- Existing local iPhone controllers were left untouched. The separate test controller used only the preview adapter.

## Native iPhone release tooling — November 25, 2026

- Added a shared `ios/Version.xcconfig` for RoutePilot 1.1 (build 2), its bundle identifier, and minimum iOS version. Metadata checks confirm that Debug and Release app configurations use the shared file and that the bundled property list resolves version/build values from it.
- Four artifact-validation regression tests passed. They exercise stale versions, wrong executable platforms, missing icons, accidental pairing credentials, signed device files, duplicate archive entries, and unexpected archive paths. Native packaging uses a fresh staging directory and generates an unsigned IPA, SHA-256 checksum, and source/compiler/artifact manifest.
- Added the `RoutePilotUITests` target to the shared Xcode scheme and confirmed it appears in `xcodebuild -list`. The target uses Simulator fixtures to exercise app controls without device location writes. Simulator execution results are recorded separately after running the suite.
- Added native GitHub Actions checks for pull requests and manual runs. The workflow uses pinned official actions and read-only repository access. Only a manual run retains unsigned build artifacts; it does not publish a release, sign an app, or access an Apple account. Remote workflow execution has not yet been verified.
- Native setup documentation describes the normal single-Connect flow, saved-endpoint and Bonjour discovery, and manual settings under Advanced. The app has no Wi-Fi-only gate; fresh cellular-only developer connection, sustained background playback, physical iPhone location writes, and Strava recording compatibility remain hardware checks.


## Native connection, reliability, and interface — November 25, 2026

- 60 local checks passed: 32 Swift core tests, 16 fake-device connection scenarios, 5 packaging tests, and 7 XCUITest flows on iPhone 17 Pro Simulator / iOS 26.5. The final complete UI run passed all seven cases with no failures.
- Connection now probes the remembered local endpoint before bounded Bonjour discovery, matches advertisements to this device, supports an explicit manual override, accepts `/32` input, and has no Wi-Fi-only gate. Tests cover saved-endpoint cellular attempts without discovery, changed ports, cancellation, permission/error categories, and pending native-operation quarantine. Authenticated setup and GPS mutations are not automatically retried.
- Portable lifecycle tests cover duplicate Start/Restore, Stop during first and later writes, Pause holding the acknowledged location, interrupted writes, and persistent recovery. Routing tests cover cancellation, stale provider callbacks, incomplete loops, and input-bound offline caches. Draft saves coalesce for 250 ms on a background actor, flush on backgrounding, reject stale generations, and preserve the previous file on failure.
- Simulator checks exercised real checkpoint hold/drag/removal/Undo, automatic/manual port controls, malformed coordinates, GPX validation and creation of a shareable file, Preview/Pause/Resume/Stop, dark landscape, and accessibility text-size controls. Fixed marker hit testing with stable custom circles, isolated independent buttons inside Form rows, and declared the SwiftUI scene lifecycle for rotation and sheet settings inheritance.
- The interface now offers Start on iPhone with automatic connection after pairing, one Connect button in setup, Advanced settings collapsed by default, live stages/cancellation, copyable diagnostics, readable dark controls, explicit GPX actions, keyboard dismissal, and signing-expiry information when a provisioning profile is available.
- No physical iPhone location commands, VPN changes, or Strava uploads were used for QA. Fresh cellular-only connection, sustained background playback, battery/RAM consumption, and hardware restoration remain unverified. The build is unsigned and requires the user's own installer/signing identity.

- GitHub's clean macOS build also passed the core, connection, packaging, dependency-fetch, and unsigned-artifact verification steps: https://github.com/zahmsiyed/routepilot/actions/runs/45762771544. UI execution was disabled for that manual run because all seven flows had already passed locally. A follow-up landscape assertion confirmed every primary control remains within the 874×402 app window.

## Native TCP failure diagnostics — November 27, 2026

- The user's cellular screenshots show discovery of developer port 63501 followed by failed TCP probes of the saved, advertised, and default ports. These failures occur before pairing authentication. The LocalDevVPN settings screenshot shows Device IP `10.7.0.1/32` and Tunnel IP `10.7.1.1/32`; it does not show the VPN's connected state. Successful cellular startup is still unconfirmed.
- RoutePilot 1.1.1 (build 3) preserves each candidate's TCP error instead of overwriting the advertised-port failure with the default-port failure. Advertised candidates receive a three-second TCP deadline. The recovery text distinguishes LocalDevVPN's main-screen Connected status from its settings, and copied diagnostics include the iOS version.
- All 18 connection orchestration scenarios and five packaging tests passed locally. The added scenarios reproduce the screenshot's three-port timeout and permission denial after discovery. They verify the bounded deadlines, retained errors, and absence of any native handshake on unreachable or denied sockets.
- The probe now recognizes Apple's documented `NWPath.localNetworkDenied` and DNS PolicyDenied signals as permission failures. Ten additional scenarios passed, covering categorical timeout context, privacy classification, loopback TCP success/refusal, and cancellation races. Timeout diagnostics contain no SSIDs or interface identifiers. The existing connection test script includes these checks for CI.
- The focused Simulator setup-screen test passed, including automatic/manual port controls and first-time setup guidance. The arm64 unsigned iPhone IPA built and passed artifact verification. The 34 checks in this update did not change the physical iPhone's VPN settings or location; a working Wi-Fi/cellular connection still requires the user's hardware check.
