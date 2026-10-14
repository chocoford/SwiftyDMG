# SwiftyDMG

A native macOS app for creating customized DMG installers.

## Development

Open `SwiftyDMG.xcodeproj`, select the **SwiftyDMG** scheme and **My Mac**.
The app requires macOS 14 or later. All application code is compiled by the Xcode
app target; external dependencies are configured in the project's Package Dependencies.

```text
SwiftyDMG.xcodeproj/      Native app project and shared scheme
SwiftyDMG/               SwiftUI app, settings, services and packaging code
SwiftyDMGTests/          Xcode packaging regression tests
Configuration/           App version and Sparkle update settings
Scripts/                 Native release preparation
Docs/                    Release instructions
```

The project directly references these sibling packages for local development:
`../AppDMG`, `../hdiutil` and `../DSStoreKit`. Sparkle 2.10.0 is configured directly
as a remote package dependency. AppDMG performs disk-image creation and Finder
layout decoration; hdiutil and DSStoreKit support those operations.

## Features

- Select an App, drag it into the window, or open it through a Finder service.
- Customize background, disk icon, Finder window size and draggable icon positions.
- Add files and an Applications link to the image.
- Save settings and import or export JSON presets.
- Observe packaging progress, inspect errors and reveal the completed DMG.
- Optionally sign the generated DMG without modifying the input App's signature.
- Check for updates through Sparkle and GitHub Releases once release signing is configured.

Packaging first creates a temporary image beside the destination. It replaces an
existing output only after confirmation and a successful build. Failed jobs clean
up their own mounts and leave the previous output intact.

## Build and test

For compilation without signing:

```sh
xcodebuild -project SwiftyDMG.xcodeproj -scheme SwiftyDMG \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

Run the packaging tests from Xcode with **Product → Test**, or:

```sh
xcodebuild -project SwiftyDMG.xcodeproj -scheme SwiftyDMG \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:SwiftyDMGTests/PackagingTests test
```

The test target compiles the application's packaging source files independently
so tests do not launch the GUI. It checks settings, overwrite confirmation, paths
with spaces, additional files, mounted image contents, image checksums and cleanup
following signing failures. Integration tests require disk-image device access.

The app declares a Finder service named **用 SwiftyDMG 打包**. After installing it
in Applications and launching it once, enable the service in System Settings if
Finder does not show it. The service opens a selected App for settings review.

## Updates and distribution

`Configuration/Release.xcconfig` supplies the version, numeric build, GitHub Releases
feed and Sparkle public key. The public key is blank during development, so the
updater remains inactive. See [release instructions](Docs/Release.md).

App Store sandboxing is disabled because the packaging engine needs disk-image
and mount access. Hardened Runtime is enabled, with library validation disabled
only in Debug for development. Release signing and notarization are explicit steps.

## License

MIT. See [LICENSE](LICENSE).
