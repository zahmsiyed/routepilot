# iOS transport dependencies

`RoutePilot/Device/DeviceLink.swift`, `DeviceError.swift`, `DDIMethod.swift`, and
`DDIStore.swift` are adapted from [LocSim](https://github.com/Rockykln/locsim),
commit `359e423824d8c236a343c871ba696ba08fd3bec1` (MIT, copyright 2026 rockykln).
The upstream license is retained in `LocSim-LICENSE.txt`.

The static `IDevice.xcframework` comes from
[jkcoxson/idevice v0.1.68](https://github.com/jkcoxson/idevice/releases/tag/v0.1.68)
(MIT, copyright 2026 Jackson Coxson). Run `../scripts/fetch-idevice.sh` from this
folder or `ios/scripts/fetch-idevice.sh` from the repository root. The script checks
the release archive's pinned SHA-256 before extracting it. The generated framework
is excluded from Git. The library and its dependencies' notices are retained in
`idevice-LICENSE.txt` and `IDevice-THIRD-PARTY-LICENSES.md`; bundle these notices with
the app.

No StikDebug source is included. RoutePilot uses an external LocalDevVPN tunnel,
so it does not request a Network Extension entitlement or install a VPN profile.

Developer Disk Images download only during an explicit connection attempt when
required, from `doronz88/DeveloperDiskImage` commit
`d2d3e18b695e0e0bec3051f13e7ca6e0a50241e9`, and every file is hash verified.
They are cached in app support, excluded from backup, and never checked into Git.
