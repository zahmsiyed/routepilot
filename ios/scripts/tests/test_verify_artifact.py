import importlib.util
import json
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
import warnings
import zipfile


spec = importlib.util.spec_from_file_location("verify_artifact", Path(__file__).parents[1] / "verify-artifact.py")
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class ArtifactValidationTests(unittest.TestCase):
    def valid_files(self, platform="device"):
        settings = verify.release_settings()
        major, minor = map(int, settings["IPHONEOS_DEPLOYMENT_TARGET"].split("."))
        binary = struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 2, 1, 24, 0, 0)
        binary += struct.pack("<6I", 0x32, 24, 7 if platform == "simulator" else 2, major << 16 | minor << 8, 0, 0)
        info = {
            "CFBundleExecutable": "RoutePilot", "CFBundleIdentifier": settings["PRODUCT_BUNDLE_IDENTIFIER"],
            "CFBundleShortVersionString": settings["MARKETING_VERSION"], "CFBundleVersion": settings["CURRENT_PROJECT_VERSION"],
            "MinimumOSVersion": settings["IPHONEOS_DEPLOYMENT_TARGET"],
            "CFBundleSupportedPlatforms": ["iPhoneSimulator" if platform == "simulator" else "iPhoneOS"],
            "NSLocationWhenInUseUsageDescription": "Active route playback.", "NSLocalNetworkUsageDescription": "Local developer connection.",
            "UIBackgroundModes": ["location"],
            "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False, "UISceneConfigurations": {}},
            "NSBonjourServices": ["_remotepairing._tcp"],
        }
        metadata = {"version": settings["MARKETING_VERSION"], "build": settings["CURRENT_PROJECT_VERSION"], "bundleIdentifier": settings["PRODUCT_BUNDLE_IDENTIFIER"], "platform": platform, "sourceSHA256": "a" * 64}
        icons = {name: b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">2I", size, size) + b"\0" * 9 for name, size in zip(verify.ICONS, (120, 180, 152, 167))}
        return {"Info.plist": plistlib.dumps(info), "RoutePilot": binary, "BuildInfo.json": json.dumps(metadata).encode(), **{name: b"License notice " * 20 for name in verify.LICENSES}, **icons}

    def test_current_release_is_shared_and_valid(self):
        settings = verify.validate_metadata()
        metadata = verify.validate_files(self.valid_files(), "device", settings)
        self.assertEqual(metadata["build"], settings["CURRENT_PROJECT_VERSION"])

    def test_stale_bundle_and_wrong_binary_platform_are_rejected(self):
        for mutation in ("version", "platform", "icon"):
            with self.subTest(mutation=mutation):
                files = self.valid_files()
                if mutation == "version":
                    info = plistlib.loads(files["Info.plist"]); info["CFBundleVersion"] = "0"; files["Info.plist"] = plistlib.dumps(info)
                elif mutation == "platform":
                    files["RoutePilot"] = self.valid_files("simulator")["RoutePilot"]
                else:
                    del files[verify.ICONS[0]]
                with self.assertRaises(ValueError):
                    verify.validate_files(files, "device", verify.release_settings())

    def test_pairing_credentials_and_signed_device_artifact_are_rejected(self):
        for filename, data in (("rppairing.plist", b"secret"), ("innocent.plist", plistlib.dumps({"private_key": b"secret"})), ("_CodeSignature/CodeResources", b"signed")):
            with self.subTest(filename=filename):
                files = self.valid_files(); files[filename] = data
                with self.assertRaises(ValueError):
                    verify.validate_files(files, "device", verify.release_settings())

    def test_scene_lifecycle_cannot_be_omitted_from_the_bundle(self):
        for scene in (None, {}, {"UIApplicationSupportsMultipleScenes": True, "UISceneConfigurations": {}}, {"UIApplicationSupportsMultipleScenes": False}):
            with self.subTest(scene=scene):
                files = self.valid_files()
                info = plistlib.loads(files["Info.plist"])
                if scene is None: info.pop("UIApplicationSceneManifest")
                else: info["UIApplicationSceneManifest"] = scene
                files["Info.plist"] = plistlib.dumps(info)
                with self.assertRaises(ValueError):
                    verify.validate_files(files, "device", verify.release_settings())

    def test_ipa_duplicate_and_outside_paths_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            for names in (("Payload/RoutePilot.app/Info.plist",) * 2, ("unexpected.txt",)):
                path = Path(temporary) / "bad.ipa"
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore", UserWarning)
                    with zipfile.ZipFile(path, "w") as archive:
                        for name in names:
                            archive.writestr(name, b"test")
                with self.assertRaises(ValueError):
                    verify.read_artifact(path)


if __name__ == "__main__":
    unittest.main()
