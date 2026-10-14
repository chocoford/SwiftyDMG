#!/usr/bin/env python3
"""Create signed Sparkle release assets locally; does not publish to GitHub."""
import argparse
import json
from pathlib import Path
import plistlib
import subprocess

ROOT = Path(__file__).resolve().parent.parent
DERIVED_DATA = ROOT / "DerivedData"


def run(arguments, **kwargs):
    return subprocess.run(arguments, cwd=ROOT, check=True, **kwargs)


def read_configuration():
    values = {}
    for line in (ROOT / "Configuration/Release.xcconfig").read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("//") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().replace("$()", "")
    return {"version": values["MARKETING_VERSION"], "build": values["CURRENT_PROJECT_VERSION"], "feedURL": values["SPARKLE_FEED_URL"], "publicEDKey": values["SPARKLE_PUBLIC_ED_KEY"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sign-identity", required=True)
    parser.add_argument("--notary-profile", required=True, help="Existing notarytool Keychain profile")
    parser.add_argument("--key-account", default="com.chocoford.SwiftyDMG")
    args = parser.parse_args()
    config = read_configuration()
    public_key = config["publicEDKey"]
    import base64
    try:
        valid_key = len(base64.b64decode(public_key, validate=True)) == 32
    except ValueError:
        valid_key = False
    if not valid_key:
        parser.error("Configure SPARKLE_PUBLIC_ED_KEY before preparing a release.")
    project = ["xcodebuild", "-project", "SwiftyDMG.xcodeproj", "-scheme", "SwiftyDMG", "-destination", "platform=macOS", "-derivedDataPath", str(DERIVED_DATA)]
    run(project + ["-configuration", "Debug", "CODE_SIGNING_ALLOWED=NO", "-only-testing:SwiftyDMGTests/PackagingTests", "test"])
    run(project + ["-configuration", "Release", "ARCHS=arm64 x86_64", "ONLY_ACTIVE_ARCH=NO", "CODE_SIGN_STYLE=Manual", "CODE_SIGN_IDENTITY=" + args.sign_identity, "build"])
    app = DERIVED_DATA / "Build/Products/Release/SwiftyDMG.app"
    tools = DERIVED_DATA / "SourcePackages/artifacts/sparkle/Sparkle/bin"
    public_key = run([str(tools / "generate_keys"), "--account", args.key_account, "-p"], capture_output=True, text=True).stdout.strip()
    app_info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if public_key != app_info["SUPublicEDKey"]:
        parser.error("The release publicEDKey does not match the selected Sparkle Keychain account.")
    tag = "v" + config["version"]
    release = DERIVED_DATA / "ReleaseAssets" / tag
    release.mkdir(parents=True, exist_ok=True)
    archive = release / ("SwiftyDMG-" + config["version"] + ".zip")
    run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(archive)])
    notarization = json.loads(run(["xcrun", "notarytool", "submit", str(archive), "--keychain-profile", args.notary_profile, "--wait", "--output-format", "json"], capture_output=True, text=True).stdout)
    if notarization.get("status") != "Accepted":
        raise RuntimeError("Notarization was not accepted: " + str(notarization.get("id")))
    run(["xcrun", "stapler", "staple", str(app)])
    run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(archive)])
    prefix = "https://github.com/chocoford/SwiftyDMG/releases/download/" + tag + "/"
    run([str(tools / "generate_appcast"), "--account", args.key_account, "--download-url-prefix", prefix, str(release)])
    print("Prepared locally:", release)
    print("Review appcast.xml and the signed archive, then attach both to GitHub Release", tag)


if __name__ == "__main__":
    main()
