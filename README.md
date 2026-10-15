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

English is the source language. `SwiftyDMG/Localizable.xcstrings` is included in the
app target, with string extraction enabled for Debug and Release. Xcode populates
the catalog on build. Keep SwiftUI text as localized literals and use
`String(localized:)` for model messages and AppKit controls. Translate complete
sentences, preserving interpolated file names and paths as user content.

## Features

- Select an App, drag it into the window, or open it through a Finder service.
- Customize background, disk icon, Finder window size and draggable icon positions.
- Add files and an Applications link to the image.
- Save independent `.swiftydmg` workspaces and import or export JSON presets.
- Browse image contents and appearance assets in a sidebar, with settings in the inspector.
- Observe packaging progress, inspect errors and reveal the completed DMG.
- Optionally sign the generated DMG without modifying the input App's signature.
- Check for updates through Sparkle and GitHub Releases once release signing is configured.

Packaging first creates a temporary image beside the destination. It replaces an
existing output only after confirmation and a successful build. Failed jobs clean
up their own mounts and leave the previous output intact.

## Workspaces

Each document window owns its App, output destination, layout, assets and build log.
Use **File → New** for an empty workspace, **Open** (⌘O) for a saved `.swiftydmg`
document, or **New Workspace from App…** (⇧⌘O) to start another workspace from an App.
The welcome window's Open button fills that same window. To replace an App in an
existing workspace, use **Change…** beside the App in the inspector; layout and asset
settings are preserved.

Save a workspace with ⌘S and reopen it for subsequent releases. Automatic output
naming follows the App's current name and version while preserving the output
directory. Selecting a custom output filename disables automatic naming until
the inspector option is re-enabled.

Workspace documents store configuration and local file references, including
bookmarks for moved files. They do not embed the App or asset contents. Missing
references can be repaired in the inspector. Document saving is separate from
exporting a DMG. Builds share a single execution gate while the AppDMG backend
uses shared mutable state; other document windows remain editable.

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

The app declares a Finder service named **Create DMG with SwiftyDMG**. After installing it
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
