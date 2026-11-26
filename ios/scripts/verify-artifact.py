#!/usr/bin/env python3
"""Resolve shared release settings and validate an unsigned RoutePilot bundle/IPA."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import re
import stat
import struct
import subprocess
import sys
import zipfile

IOS = Path(__file__).resolve().parents[1]
KEYS = ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION", "IPHONEOS_DEPLOYMENT_TARGET", "PRODUCT_BUNDLE_IDENTIFIER")
LICENSES = ("RoutePilot-LICENSE.txt", "LocSim-LICENSE.txt", "idevice-LICENSE.txt", "IDevice-THIRD-PARTY-LICENSES.md")
ICONS = ("AppIcon60x60@2x.png", "AppIcon60x60@3x.png", "AppIcon76x76@2x~ipad.png", "AppIcon83.5x83.5@2x~ipad.png")


def release_settings(root: Path = IOS) -> dict[str, str]:
    settings = {}
    for line in (root / "Version.xcconfig").read_text().splitlines():
        line = line.split("//", 1)[0].strip()
        if not line:
            continue
        match = re.fullmatch(r"([A-Z_]+)\s*=\s*([^\s]+)", line)
        if not match or match[1] not in KEYS or match[1] in settings:
            raise ValueError("Version.xcconfig must contain each supported setting exactly once.")
        settings[match[1]] = match[2]
    if set(settings) != set(KEYS):
        raise ValueError("Version.xcconfig is missing release settings.")
    if not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", settings["MARKETING_VERSION"]):
        raise ValueError("Use a numeric release version, such as 1.1.")
    if not re.fullmatch(r"[1-9]\d{0,8}", settings["CURRENT_PROJECT_VERSION"]):
        raise ValueError("Use a positive numeric build number.")
    if not re.fullmatch(r"\d+\.\d+", settings["IPHONEOS_DEPLOYMENT_TARGET"]):
        raise ValueError("Use a major.minor deployment target.")
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+){2,}", settings["PRODUCT_BUNDLE_IDENTIFIER"]):
        raise ValueError("Use a valid reverse-domain bundle identifier.")
    return settings


def validate_metadata(root: Path = IOS) -> dict[str, str]:
    settings = release_settings(root)
    project = (root / "RoutePilot.xcodeproj/project.pbxproj").read_text()
    if project.count("baseConfigurationReference = B10000000000000000000001") != 2:
        raise ValueError("Both app configurations must use Version.xcconfig.")
    for key in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION"):
        if re.search(rf"\b{key}\s*=", project):
            raise ValueError(f"Remove {key} overrides from the Xcode project; use Version.xcconfig.")
    with (root / "RoutePilot/Info.plist").open("rb") as file:
        info = plistlib.load(file)
    expected = {"CFBundleShortVersionString": "$(MARKETING_VERSION)", "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)", "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)"}
    if any(info.get(key) != value for key, value in expected.items()):
        raise ValueError("Info.plist must resolve version, build, and identity from shared release settings.")
    return settings


def source_metadata(settings: dict[str, str], platform: str) -> dict:
    digest = hashlib.sha256()
    paths = [IOS / "Version.xcconfig", IOS / "RoutePilot/Info.plist"]
    for directory in (IOS / "RoutePilot", IOS / "Packages/RoutePilotCore/Sources"):
        paths.extend(path for path in directory.rglob("*") if path.is_file() and path.suffix in (".swift", ".png", ".txt", ".md"))
    for path in sorted(set(paths)):
        digest.update(path.relative_to(IOS).as_posix().encode() + b"\0" + path.read_bytes() + b"\0")
    def git(*args):
        result = subprocess.run(["git", "-C", str(IOS.parent), *args], capture_output=True, text=True)
        return result.stdout.strip() if result.returncode == 0 else ""
    def tool(*args):
        result = subprocess.run(args, capture_output=True, text=True)
        return result.stdout.strip() if result.returncode == 0 else "unavailable"
    return {
        "schema": 1,
        "version": settings["MARKETING_VERSION"],
        "build": settings["CURRENT_PROJECT_VERSION"],
        "bundleIdentifier": settings["PRODUCT_BUNDLE_IDENTIFIER"],
        "platform": platform,
        "sourceSHA256": digest.hexdigest(),
        "gitCommit": git("rev-parse", "HEAD") or None,
        "workingTreeDirty": bool(git("status", "--porcelain", "--", "ios")),
        "signing": "unsigned" if platform == "device" else "ad-hoc-simulator",
        "ideviceVersion": "0.1.68",
        "swiftCompiler": tool("xcrun", "swiftc", "--version"),
        "sdkVersion": tool("xcrun", "--sdk", "iphonesimulator" if platform == "simulator" else "iphoneos", "--show-sdk-version"),
    }


def write_bundle_metadata(app: Path, platform: str) -> None:
    settings = validate_metadata()
    with (IOS / "RoutePilot/Info.plist").open("rb") as file:
        info = plistlib.load(file)
    info.update(
        CFBundleExecutable="RoutePilot", CFBundleIdentifier=settings["PRODUCT_BUNDLE_IDENTIFIER"],
        CFBundleName="RoutePilot", CFBundleShortVersionString=settings["MARKETING_VERSION"],
        CFBundleVersion=settings["CURRENT_PROJECT_VERSION"], MinimumOSVersion=settings["IPHONEOS_DEPLOYMENT_TARGET"],
        UIDeviceFamily=[1, 2], CFBundleSupportedPlatforms=["iPhoneSimulator" if platform == "simulator" else "iPhoneOS"],
    )
    (app / "Info.plist").write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_BINARY))
    (app / "BuildInfo.json").write_text(json.dumps(source_metadata(settings, platform), sort_keys=True, indent=2) + "\n")


def macho_info(binary: bytes) -> dict:
    if len(binary) < 32 or binary[:4] != b"\xcf\xfa\xed\xfe":
        raise ValueError("The app executable is not a 64-bit Mach-O binary.")
    _, cpu, _, kind, commands, command_bytes, _, _ = struct.unpack_from("<8I", binary)
    if cpu not in (0x0100000C, 0x01000007) or kind != 2 or command_bytes > len(binary) - 32:
        raise ValueError("The app executable has an invalid architecture or Mach-O header.")
    offset = 32
    result = {"cpu": cpu, "signed": False}
    for _ in range(commands):
        if offset + 8 > 32 + command_bytes:
            raise ValueError("The executable has a truncated load command.")
        command, size = struct.unpack_from("<2I", binary, offset)
        if size < 8 or offset + size > 32 + command_bytes:
            raise ValueError("The executable has an invalid load command size.")
        if command == 0x32:
            if size < 24:
                raise ValueError("The executable has an invalid build-version command.")
            result["platform"], minimum = struct.unpack_from("<2I", binary, offset + 8)
            result["minimumOS"] = f"{minimum >> 16}.{minimum >> 8 & 255}"
        if command == 0x1D:
            result["signed"] = True
        if command in (0x21, 0x2C) and size >= 20 and struct.unpack_from("<I", binary, offset + 16)[0]:
            raise ValueError("The executable must not contain encrypted application code.")
        offset += size
    return result


def validate_files(files: dict[str, bytes], platform: str, settings: dict[str, str]) -> dict:
    required = {"Info.plist", "RoutePilot", "BuildInfo.json", *LICENSES, *ICONS}
    if missing := required - files.keys():
        raise ValueError("Missing app files: " + ", ".join(sorted(missing)))
    for name, data in files.items():
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts:
            raise ValueError("The app contains an unsafe file path.")
        lowered = name.lower()
        if any(part in lowered for part in ("rppairing", "mobiledevicepairing", "pairing.plist", "embedded.mobileprovision", ".ds_store")) or (platform == "device" and "_codesignature" in lowered) or path.suffix.lower() in (".p12", ".pem", ".key", ".a", ".swiftmodule"):
            raise ValueError(f"The unsigned app contains a private, signed, or build-only file: {name}")
        if path.suffix == ".plist":
            try:
                parsed = plistlib.loads(data)
                if isinstance(parsed, dict) and any(key in parsed for key in ("private_key", "HostPrivateKey", "RootPrivateKey")):
                    raise ValueError("The app contains pairing credentials.")
            except plistlib.InvalidFileException:
                raise ValueError(f"The app contains an invalid property list: {name}") from None
    info = plistlib.loads(files["Info.plist"])
    if not isinstance(info, dict):
        raise ValueError("The app's Info.plist must be a dictionary.")
    expected = {
        "CFBundleExecutable": "RoutePilot", "CFBundleIdentifier": settings["PRODUCT_BUNDLE_IDENTIFIER"],
        "CFBundleShortVersionString": settings["MARKETING_VERSION"], "CFBundleVersion": settings["CURRENT_PROJECT_VERSION"],
        "MinimumOSVersion": settings["IPHONEOS_DEPLOYMENT_TARGET"],
        "CFBundleSupportedPlatforms": ["iPhoneSimulator" if platform == "simulator" else "iPhoneOS"],
    }
    if any(info.get(key) != value for key, value in expected.items()):
        raise ValueError("The bundled version, build, identity, deployment target, or platform does not match Version.xcconfig.")
    scene = info.get("UIApplicationSceneManifest")
    if not isinstance(scene, dict) or scene.get("UIApplicationSupportsMultipleScenes") is not False or not isinstance(scene.get("UISceneConfigurations"), dict):
        raise ValueError("The app must declare its single-scene SwiftUI lifecycle.")
    for key in ("NSLocationWhenInUseUsageDescription", "NSLocalNetworkUsageDescription"):
        if not isinstance(info.get(key), str) or not info[key].strip():
            raise ValueError(f"The app is missing its {key} explanation.")
    if "location" not in info.get("UIBackgroundModes", []):
        raise ValueError("The app is missing its background location declaration.")
    if "_remotepairing._tcp" not in info.get("NSBonjourServices", []):
        raise ValueError("The app is missing its developer-service discovery declaration.")
    binary = macho_info(files["RoutePilot"])
    if binary.get("platform") != (7 if platform == "simulator" else 2) or binary.get("minimumOS") != settings["IPHONEOS_DEPLOYMENT_TARGET"]:
        raise ValueError("The executable was compiled for a different platform or minimum iOS version.")
    if platform == "device" and (binary["cpu"] != 0x0100000C or binary["signed"]):
        raise ValueError("The device artifact must be an unsigned arm64 app.")
    metadata = json.loads(files["BuildInfo.json"])
    if not isinstance(metadata, dict):
        raise ValueError("BuildInfo.json must be an object.")
    if any(metadata.get(key) != value for key, value in {"version": settings["MARKETING_VERSION"], "build": settings["CURRENT_PROJECT_VERSION"], "bundleIdentifier": settings["PRODUCT_BUNDLE_IDENTIFIER"], "platform": platform}.items()):
        raise ValueError("BuildInfo.json does not match the app's release settings.")
    if not re.fullmatch(r"[0-9a-f]{64}", metadata.get("sourceSHA256", "")):
        raise ValueError("BuildInfo.json is missing its native source digest.")
    for icon, size in zip(ICONS, (120, 180, 152, 167)):
        image = files[icon]
        if len(image) < 33 or not image.startswith(b"\x89PNG\r\n\x1a\n") or image[12:16] != b"IHDR" or struct.unpack_from(">2I", image, 16) != (size, size):
            raise ValueError(f"Invalid app icon: {icon}")
    for license in LICENSES:
        if len(files[license]) < 100:
            raise ValueError(f"The app is missing a complete license notice: {license}")
    return metadata


def read_artifact(path: Path) -> dict[str, bytes]:
    if path.is_dir():
        files = {}
        for item in path.rglob("*"):
            if item.is_symlink():
                raise ValueError("Symlinks are not expected in this app bundle.")
            if item.is_file():
                files[item.relative_to(path).as_posix()] = item.read_bytes()
        return files
    with zipfile.ZipFile(path) as archive:
        entries = [entry for entry in archive.infolist() if not entry.is_dir()]
        if len(entries) > 200 or sum(entry.file_size for entry in entries) > 100_000_000:
            raise ValueError("This IPA is unexpectedly large or contains too many files.")
        names = [entry.filename for entry in entries]
        if len(set(names)) != len(names):
            raise ValueError("The IPA contains duplicate entries.")
        prefix = "Payload/RoutePilot.app/"
        if any(not name.startswith(prefix) for name in names):
            raise ValueError("The IPA must contain only Payload/RoutePilot.app.")
        for entry in entries:
            if stat.S_ISLNK(entry.external_attr >> 16):
                raise ValueError("The IPA must not contain symlinks.")
        return {entry.filename[len(prefix):]: archive.read(entry) for entry in entries}


def package_app(app: Path, ipa: Path) -> None:
    metadata = validate_files(read_artifact(app), "device", validate_metadata())
    ipa.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(ipa, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(item for item in app.rglob("*") if item.is_file()):
            info = zipfile.ZipInfo("Payload/RoutePilot.app/" + path.relative_to(app).as_posix(), date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | (0o755 if path.name == "RoutePilot" else 0o644)) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes(), compresslevel=9)
    validate_files(read_artifact(ipa), "device", release_settings())
    checksum = hashlib.sha256(ipa.read_bytes()).hexdigest()
    ipa.with_suffix(ipa.suffix + ".sha256").write_text(f"{checksum}  {ipa.name}\n")
    # Use the source/compiler record stored with this exact bundle, rather than
    # re-reading a working tree which may have changed after compilation.
    manifest = dict(metadata)
    manifest.update(artifact=ipa.name, artifactSHA256=checksum, artifactBytes=ipa.stat().st_size)
    ipa.with_suffix(".json").write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", nargs="?", type=Path)
    parser.add_argument("--platform", choices=("device", "simulator"), default="device")
    parser.add_argument("--metadata-only", action="store_true")
    parser.add_argument("--setting", choices=KEYS)
    parser.add_argument("--write-bundle-metadata", type=Path)
    parser.add_argument("--package", type=Path, metavar="IPA")
    args = parser.parse_args()
    try:
        settings = validate_metadata()
        if args.setting:
            print(settings[args.setting])
        elif args.write_bundle_metadata:
            write_bundle_metadata(args.write_bundle_metadata, args.platform)
        elif args.package:
            if not args.artifact or not args.artifact.is_dir():
                parser.error("--package needs a built .app directory")
            package_app(args.artifact, args.package)
            print(f"Verified unsigned IPA: {args.package}")
        elif args.artifact:
            metadata = validate_files(read_artifact(args.artifact), args.platform, settings)
            checksum_path = args.artifact.with_suffix(args.artifact.suffix + ".sha256")
            if args.artifact.is_file() and checksum_path.is_file():
                expected = checksum_path.read_text().split()
                actual = hashlib.sha256(args.artifact.read_bytes()).hexdigest()
                if len(expected) != 2 or expected != [actual, args.artifact.name]:
                    raise ValueError("The artifact checksum does not match its .sha256 file.")
            print(f"Verified RoutePilot {metadata['version']} ({metadata['build']}) · {args.platform} · {metadata['sourceSHA256'][:12]}")
        elif args.metadata_only:
            print(f"Release settings verified: {settings['MARKETING_VERSION']} ({settings['CURRENT_PROJECT_VERSION']})")
        else:
            parser.error("provide an artifact, --metadata-only, or --setting")
    except (ValueError, OSError, zipfile.BadZipFile, KeyError, TypeError, struct.error) as error:
        parser.exit(1, f"Artifact verification failed: {error}\n")


if __name__ == "__main__":
    main()
