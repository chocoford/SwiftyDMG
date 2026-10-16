# SwiftyDMG

A native macOS app for creating customized DMG installers.

## Development

Open `SwiftyDMG.xcodeproj`, select the **SwiftyDMG** scheme and **My Mac**.
The app requires macOS 14 or later. All application code is compiled by the Xcode
app target; external dependencies are configured in the project's Package Dependencies.

```text
SwiftyDMG.xcodeproj/      Native app project and shared scheme
SwiftyDMG/
  SwiftyDMGApp.swift     App entry and scene wiring
  AppDelegate.swift     Native app lifecycle and Finder services
  ContentView.swift     Root window presentation and transitions
  Workspace/            Workspace views, state, documents, commands and window sizing
  Inspector/            Settings, build logs and inspector controls
  Packaging/            Build model, requests, disk-image engine and process execution
  Preview/              Finder layout preview and canvas controls
  Updates/              Sparkle controller and update settings
  Resources/            DMG background
  AppIcon.icon/          Icon Composer app icon
  Assets.xcassets/       Asset catalog
  Localizable.xcstrings Manually maintained string catalog
  Info.plist            App metadata and Finder service registration
  Debug.entitlements    Development signing entitlements
  Release.xcconfig      Version, optional features and Sparkle update settings
SwiftyDMGTests/          Xcode packaging regression tests
Scripts/                 Native release preparation
Docs/                    Release instructions
```

The project directly references these sibling packages for local development:
`../AppDMG`, `../hdiutil` and `../DSStoreKit`. Sparkle 2.10.0 is configured directly
as a remote package dependency. AppDMG performs disk-image creation and Finder
layout decoration; hdiutil and DSStoreKit support those operations.

English is the source language. `SwiftyDMG/Localizable.xcstrings` is maintained
manually with lowerCamelCase semantic keys and complete English source values.
The `XCStringsToolPlugin` build tool generates typed accessors for both the app
and the standalone packaging test target. Generated Swift files stay in DerivedData.

Use `Text(.localizable(.welcomeTitle))` for SwiftUI text and
`String(localizable: .dialogOpenApp)` for model messages and AppKit controls.
Custom labels use the generated `LocalizedStringKey.localizable(_:)` or
`LocalizedStringResource.localizable(_:)` accessors. Add new keys to the catalog
explicitly and keep their `extractionState` set to `manual`. Translate complete
sentences, preserving parameterized file names, paths and errors as user content.
The catalog includes the same 18 languages as ExcalidrawZ. Non-English entries
start with the English source value and `state: new` inside a `stringUnit` object;
they remain untranslated until their translations are filled in.

`SWIFT_EMIT_LOC_STRINGS` and `LOCALIZED_STRING_SWIFTUI_SUPPORT` are disabled in
Debug and Release, following ExcalidrawZ's localization setup. Automatic Xcode
string-symbol generation is disabled as well; the plugin owns the typed API.
Commands, raw tool output, paths, filenames and numeric dimensions remain ordinary
strings and use `Text(verbatim:)` when displayed directly. Diagnostic log messages
are not added to the catalog.

## Features

- Select an App, drag it into the window, or open it through a Finder service.
- Customize volume name, background, disk icon, Finder window size and draggable icon positions.
- Configure the Applications link in the image.
- Open independent packaging windows, with layout and appearance settings in the inspector.
- Preview System, Light and Dark appearances from the canvas appearance menu.
- Observe packaging progress, inspect errors and reveal the completed DMG.
- Check for updates through Sparkle and GitHub Releases once release signing is configured.

Packaging first creates a temporary image beside the destination. It replaces an
existing output only after confirmation and a successful build. Failed jobs clean
up their own mounts and leave the previous output intact.

## Packaging windows

Each window owns its App, output destination, layout, assets and build log for the
current session. Use **File → New Window** (⌘N) for an empty window or **Open App…**
(⌘O) to select an App. The welcome window's Open button fills that same window.
To package another App, close the current window and open another one.

Set **Volume Name** under **Finder Window** to change the mounted disk's name and
preview title. Leave it blank to use the App's name. The volume name is independent
of the output `.dmg` filename.

The appearance menu beside preview zoom offers **System**, **Light** and **Dark**.
It changes only the preview. Picture backgrounds keep their original colors;
**No Background** uses the native Finder appearance.

Automatic output naming follows the App's current name and version while preserving the output
directory. Edit the output filename directly in the inspector; the `.dmg` suffix
is kept automatically. Custom filenames are preserved until the reset button next
to **File Name** restores the App's name and version. Changing only the output
directory preserves the current naming mode.

Builds share a single execution gate while the AppDMG backend uses shared mutable
state; other windows remain editable.

## Optional features

The first release disables the sidebar and workspace saving, and hides the
Additional Files and DMG Signing inspector sections. Their gates live in
`SwiftyDMG/Release.xcconfig` and apply to Debug and Release. Empty values disable
them; enable each independently by setting its value to the matching token:

```xcconfig
SWIFTYDMG_SIDEBAR = SWIFTYDMG_SIDEBAR
SWIFTYDMG_WORKSPACE_SAVING = SWIFTYDMG_WORKSPACE_SAVING
SWIFTYDMG_ADDITIONAL_FILES = SWIFTYDMG_ADDITIONAL_FILES
SWIFTYDMG_DMG_SIGNING = SWIFTYDMG_DMG_SIGNING
```

The sidebar gate moves file management from the inspector into a contents sidebar.
The saving gate switches from a regular WindowGroup to DocumentGroup, enables
New/Open/Save/Recent and the Presets menu, and registers `.swiftydmg` documents.
With saving disabled, there is no document edited state or save prompt on close.
Info.plist preprocessing shares the same saving gate so document registration
matches the active scene.

The additional-files gate shows its inspector section when the sidebar is off.
The signing gate shows DMG signing settings. Their packaging implementations remain
available, including support for previously configured options.

When saving is enabled, use ⌘S to save settings for subsequent releases. Documents
store configuration and local file references, including bookmarks for moved files;
they do not embed the App or asset contents. JSON presets can also be imported or
exported. When the sidebar is enabled, use its context menus to change an App, rename
or replace additional files, and select an item to edit its position in the inspector.

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

`SwiftyDMG/Release.xcconfig` supplies the version, numeric build, GitHub Releases
feed and Sparkle public key. The public key is configured for the
`com.chocoford.SwiftyDMG` Keychain account. Publish `appcast.xml` and the update ZIP
as GitHub Release assets to make updates available. See [release instructions](Docs/Release.md).

App Store sandboxing is disabled because the packaging engine needs disk-image
and mount access. Hardened Runtime is enabled, with library validation disabled
only in Debug for development. Release signing and notarization are explicit steps.

## License

MIT. See [LICENSE](LICENSE).
