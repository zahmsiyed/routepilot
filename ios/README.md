# RoutePilot for iPhone

RoutePilot 1.1.1 (build 3) is a native SwiftUI app with Apple Maps, pedestrian and driving routes,
stationary locations, draggable/removable checkpoints, Undo, speed controls,
metric/imperial units, bounded speed/lateral variation, preview, and local GPX
creation/import. It runs on the iPhone without the Mac controller or Vercel.

Location simulation uses the iPhone's developer service over an external
LocalDevVPN tunnel. A one-time Mac setup is required. This is a developer app
for personal installation, not an App Store release. iOS 17.4 or later is the
build target; the intended device is the user's iOS 26.6.2 iPhone. Actual
location writes have not yet been tested on that hardware.

## Install

An unsigned app is generated at `ios/build/device/RoutePilot-unsigned.ipa`.
It must be signed before iOS will install it. Use either of these paths:

### Xcode

1. Open `ios/RoutePilot.xcodeproj` in Xcode 26 or later.
2. Select the RoutePilot target, then **Signing & Capabilities**. Choose your
   Apple development team. If Xcode requests a unique bundle identifier, edit
   `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Version.xcconfig` so all build paths use it.
3. Connect and unlock the iPhone. Trust the Mac if asked. Choose the phone as
   the Run destination and press **Run**.
4. Enable **Settings → Privacy & Security → Developer Mode**, restart, and
   confirm if prompted. Trust your development identity under **Settings →
   General → VPN & Device Management** if iOS asks.

The idevice framework is already downloaded on this workspace. From a fresh Git
checkout, fetch the pinned, SHA-verified library first:

```sh
bash ios/scripts/fetch-idevice.sh
```

If Xcode reports a missing iOS platform, install the required component under
**Settings → Components**. An unsigned build verifies compilation and packaging;
it does not provision or install the app on a physical iPhone.

### SideStore or AltStore

Import `RoutePilot-unsigned.ipa` into an already configured SideStore or AltStore
and sign it with your own Apple identity. Follow that tool's current setup and
refresh instructions. RoutePilot does not collect Apple credentials or renew
signing automatically. Merely opening an unsigned IPA in Safari/Files cannot
install it.

## Connect with the fewest steps

The normal connection screen has one **Connect** button. Port discovery is on
by default; leave Advanced connection settings closed unless connection fails.

One time on the Mac:

1. Install/sign RoutePilot using one of the paths above. Connect this iPhone by
   USB, unlock it, accept **Trust This Computer**, and enable Developer Mode.
2. In **Finder → your iPhone → General**, enable **Show this iPhone when on
   Wi-Fi**, then **Apply**. This enables the developer network service used by
   the local tunnel; the setting's name is not an app-enforced Wi-Fi gate.
3. From the repository folder, create an RPPairing file:

   ```sh
   bash ios/scripts/make-pairing.sh ~/Downloads/RoutePilot-pairing.plist
   ```

   The script downloads a pinned, SHA-verified official idevice tools release,
   chooses exactly one USB iPhone, and creates an identity named `RoutePilot`.
   It refuses to overwrite an existing file. If several phones are connected,
   disconnect the others or pass the intended UDID as the second argument.
4. AirDrop that `.plist` to the same iPhone and save it in Files. In RoutePilot,
   open **iPhone connection → Import pairing file**. It contains private device
   credentials: keep it private and remove transfer copies after import.
   RoutePilot protects its stored copy and excludes it from backup. A normal
   lockdown pairing plist is not compatible.

On the iPhone for each session:

1. Enable [LocalDevVPN](https://github.com/StikDebug/StikDebug#requirements)'s
   local tunnel.
2. Plan your route and tap **Start on iPhone**. After pairing, this connects
   automatically when needed, shows live progress, and starts the route once ready.
   The Mac can be unplugged. Keep LocalDevVPN enabled through playback and restoration.

Use **iPhone connection → Connect** when you only want to check the developer
connection without applying a location.

Connecting applies no coordinates. Live messages show tunnel discovery,
developer support preparation, mounting, and the location service. The first
connection downloads about 16 MB of verified support files if needed. Cancel
stops that attempt; technical details and **Copy diagnostics** are available
under Connection details. Diagnostics exclude pairing contents.

### Wi-Fi and cellular

RoutePilot tries its saved endpoint first, then Bonjour discovery when the saved
connection fails. It does not refuse a connection merely because Wi-Fi is off.
An already available developer service may be reachable over the local tunnel
while cellular is active. A fresh connection can still be restricted by iOS;
cellular-only connection and sustained playback have not been verified on the
user's iPhone. If connection fails, join Wi-Fi and tap Connect again.

If the log finds an advertised port but every TCP check fails, discovery worked;
the local developer connection has not reached pairing authentication. Open
LocalDevVPN's main screen using **Open LocalDevVPN** and confirm **Connected**
(its settings screen alone does not confirm this). Check **Settings → Privacy &
Security → Local Network →
RoutePilot**, then retry on Wi-Fi without changing the IPs or turning off
automatic port selection. There is no reason to replace the pairing file based
on a TCP timeout alone. Copy diagnostics if Wi-Fi also fails; these include the
iOS/app versions, every candidate's TCP error, and network-path categories,
without pairing keys, Wi-Fi names, or network-interface identifiers.

Automatic discovery requires Local Network permission. Under **Advanced
connection settings**, Device address must match LocalDevVPN's **Device IP**,
not Tunnel IP. The default is `10.7.0.1`; a `/32` suffix is accepted. Turn off
**Find port automatically** only when entering a known developer port. An iOS
update or pairing reset can require a new RPPairing file.

RoutePilot does not install a VPN profile or send pairing credentials to Vercel
or a RoutePilot server. The external LocalDevVPN app owns the local tunnel.
Developer support files come from a pinned GitHub source with SHA-256 checks;
mounting may contact Apple's signing service.

## Use

- Tap the map or search for a place to add a checkpoint. Hold and drag a pin to
  move it; tap a pin or its minus button to remove it. Undo reverses one edit.
- Running requests Apple Maps walking routes; Driving requests automobile
  routes. Routing failures do not fall back to straight lines. Loops calculate
  the return leg; reversing recalculates road direction restrictions.
- Preview animates inside RoutePilot without affecting the phone's location.
  It pauses while the app is hidden.
- **Start on iPhone** applies the route through Apple's developer service.
  Allow the contextual location prompt to support playback while another app
  is open; iOS displays its location indicator. If permission is off, keep
  RoutePilot visible. Background execution can still be suspended/terminated
  by iOS, force quit, reboot, VPN loss, or expired signing.
- Pause holds the current simulated coordinate. A finished route holds its
  endpoint until **Restore real location** succeeds.
- Always use **Restore real location** when finished and verify your position
  in Maps. A lost/timed-out developer command preserves a recovery notice,
  including after reopening the app. Re-enable the VPN and retry Restore. A
  still-running timed-out write keeps recovery required until it finishes;
  if the service remains stuck, restart the iPhone and verify the real position.
- Other apps can see Apple's simulated-location flag. This does not establish
  compatibility with Strava recording or a Virtual Run integration.

GPX creation is available through the share button beside playback. Choose
**Timed track**, **Planned route**, or **Xcode waypoints**, set timing when needed,
then **Create GPX → Save to Files or share GPX**. Files contain the complete
route, one lap when looping, and constant timing. Live random variations are
not included. Tracks identify themselves as simulated and invent no elevation,
heart rate, or calories. Import selects up to 24 checkpoints and recalculates
them for the selected movement mode.

Drafts and calculated geometry are stored on the iPhone. A saved route and GPX
creation can work without a network connection. New searches/routes and map
tiles use Apple Maps and need connectivity. The iPhone app uses no RoutePilot
account, hosted API, Python runtime, or Mac server.

## Build and verify

```sh
# Device IPA; signing is intentionally left to your own development identity.
bash ios/scripts/build-app.sh device

# Simulator app (Apple Silicon Mac).
bash ios/scripts/build-app.sh simulator

# Portable native core tests.
swift test --package-path ios/Packages/RoutePilotCore

# Connection orchestration, using fake transports rather than a phone.
bash ios/scripts/test-device-connection.sh
```

`build-app.sh` directly uses Apple's installed Swift compiler and SDK, with
ordinary PNG icons, so unsigned packaging also works when Xcode's scheme
destination registration is unavailable. The Xcode project remains the normal signed
install path. Neither build script pairs with an iPhone, installs a profile,
or changes its location.

The release version, build number, deployment target, and bundle identifier are
shared in `ios/Version.xcconfig`. Edit that file for a release; Setup displays the
bundled version and build. Before packaging, the script checks both Xcode app
configurations and `Info.plist` against those settings.

Each device build produces:

- `RoutePilot-unsigned.ipa`: an unsigned arm64 app for personal signing.
- `RoutePilot-unsigned.ipa.sha256`: checksum of that exact archive.
- `RoutePilot-unsigned.json`: version/build, native source digest, Git state,
  compiler/SDK versions, and artifact hash/size.

The build uses an empty staging folder and fixed ZIP entry timestamps. Compiler
and SDK versions remain inputs; byte-identical output across different Apple
toolchains is not promised. Verify a downloaded or copied artifact with:

```sh
python3 ios/scripts/verify-artifact.py ios/build/device/RoutePilot-unsigned.ipa
```

Verification checks bundle version, executable architecture/platform/minimum iOS,
icons and license notices, unsigned state, archive paths, and accidental pairing
or build-only files. When its checksum file is present, that checksum is checked
too. This is packaging validation, not a substitute for Apple code signing.

Run packaging regression checks and native UI tests with:

```sh
python3 -m unittest discover -s ios/scripts/tests -p 'test_*.py'
xcodebuild -project ios/RoutePilot.xcodeproj -scheme RoutePilot -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/RoutePilotTests CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES test
```

The shared scheme contains `RoutePilotUITests`. Its test-only launch fixtures
exercise preview controls, GPX validation/export, connection settings, malformed
coordinate input, checkpoint drag/removal/Undo, accessibility text size, and dark landscape layout without applying device coordinates.

`.github/workflows/native-ios.yml` runs native checks for iOS pull requests and
can also be started from GitHub Actions. It uses a read-only token and pinned
GitHub actions, runs core/packaging/UI checks, and builds an unsigned IPA. Only
manual runs retain the IPA, checksum, and manifest as a 14-day Actions artifact;
no release or public download is published automatically. It needs no Apple
account, certificate, provisioning profile, or phone.

The core tests cover geometry, date-line crossing, loop closure, pause/resume,
bounded variations, timestamp ordering, exact GPX corners, malformed XML,
single-segment import, point limits, and checkpoint sampling. They do not
establish physical device compatibility. Dependency sources, pinned versions,
hashes, and notices are documented in [Vendor/README.md](Vendor/README.md) and
are also bundled in the app.
