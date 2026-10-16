# Contributing to SwiftyDMG

Contributions can include bug reports, feature ideas, Swift code, documentation,
and translations. The project is developing its 2.0 desktop app; check the
[roadmap](README.md#roadmap) when planning a change.

## Getting started

The current project is developed with **Xcode 27** and targets **macOS 14 or later**.

The Xcode project references three sibling repositories. Clone all four into the same parent directory:

```sh
git clone https://github.com/chocoford/SwiftyDMG.git
git clone https://github.com/chocoford/AppDMG.git
git clone https://github.com/chocoford/hdiutil.git
git clone https://github.com/chocoford/DSStoreKit.git
open SwiftyDMG/SwiftyDMG.xcodeproj
```

Let Xcode resolve the package dependencies, select the **SwiftyDMG** scheme and **My Mac**, then run the app.

The app is a native Xcode project. Its package dependencies are configured in
Xcode, and the local AppDMG, hdiutil, and DSStoreKit checkouts sit beside it. If a
change touches one of those libraries, describe the required library change and
link its issue or pull request alongside the SwiftyDMG change.

## Build and test

From the SwiftyDMG repository root, build without signing:

```sh
xcodebuild -project SwiftyDMG.xcodeproj -scheme SwiftyDMG \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

Run the packaging tests with **Product → Test** in Xcode, or:

```sh
xcodebuild -project SwiftyDMG.xcodeproj -scheme SwiftyDMG \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:SwiftyDMGTests/PackagingTests test
```

The test target compiles the packaging engine independently, so tests do not launch the GUI. Tests cover settings validation, process output, overwrite protection, image contents, and cleanup after failures. Integration tests create and mount disk images and require disk-image device access on the host.

The optional sidebar, workspace saving, additional-file controls, and DMG signing are configured in [`SwiftyDMG/Release.xcconfig`](SwiftyDMG/Release.xcconfig). Each feature is disabled by default; enable it by setting its value to its matching token. When changing a gated feature, verify both its enabled behavior and the default experience with it disabled.

## Report a bug

Open an [issue](https://github.com/chocoford/SwiftyDMG/issues) with:

- The app version or source commit, macOS version, and Xcode version if relevant.
- Steps to reproduce the problem, what you expected, and what actually happened.
- The complete Build inspector log for packaging failures. The copy button
  includes output from collapsed steps.
- A screenshot or recording when the problem concerns layout or interaction.

For preview differences, describe both the preview and the Finder window from
the generated DMG. Include the relevant window dimensions, icon positions, and
background or disk-icon settings.

## Propose a feature

Explain the packaging workflow you want to improve and the result you need.
Check existing issues and the roadmap first. For a larger change, open an issue
to discuss the approach before investing in an implementation.

Some features are implemented behind development flags. When reporting or
changing one, include which flags were enabled.

## Submit a pull request

Keep each pull request focused on one problem or feature. Describe the resulting
behavior, why it is useful, and how you verified it. Include screenshots or a
short recording for visible UI changes.

When changing code:

- Follow the existing feature folders and keep the app entry files focused on
  scene wiring and window presentation.
- Add new source files and resources to the appropriate Xcode target. Keep the
  project navigator consistent with their paths on disk.
- Use native macOS controls and preserve behavior on the macOS deployment target.
- Keep packaging diagnostics available in the Build inspector. Preserve command
  output verbatim and maintain cleanup and overwrite behavior.
- Add or update regression coverage when changing packaging, validation, process
  handling, or persistence behavior.

Run the checks relevant to the change and record the result in the pull request.
If a check could not run, say which one and why. Documentation-only changes do
not require building the app. Packaging integration tests need a macOS host that
can create and mount disk images; commands are in [Build and test](#build-and-test).

Keep generated build products and user-specific Xcode settings out of commits.

## Improve localization

English is the source language. User-facing copy belongs in
[`SwiftyDMG/Localizable.xcstrings`](SwiftyDMG/Localizable.xcstrings), which declares
18 locales. The build plugin generates typed accessors from manually maintained
semantic keys.

For new UI text:

1. Add a descriptive lowerCamelCase key with a complete English value and
   `extractionState` set to `manual`.
2. Use the generated accessor in SwiftUI or AppKit code:

   ```swift
   Text(.localizable(.welcomeTitle))
   String(localizable: .dialogOpenApp)
   ```

3. Preserve format placeholders such as `%1$@` and `%2$lld` in translations. A
   translation may reorder placeholders, but must preserve their meaning and
   argument types.
4. Mark translations as translated only when they have actually been translated
   and reviewed. English placeholders for unfinished locales use
   `stringUnit: { "state": "new", "value": "…" }`.

Custom controls can use the generated `LocalizedStringKey.localizable(_:)` or
`LocalizedStringResource.localizable(_:)` accessors. Paths, filenames, command
output, and other user data use `Text(verbatim:)` when displayed directly.

Automatic string extraction and Xcode's own string-symbol generation are disabled
intentionally. Keep those settings intact so the catalog remains manually
maintained and the plugin is the single source of generated accessors.

## Release changes

Version numbers, the update feed, and the public Sparkle key are configured in [`SwiftyDMG/Release.xcconfig`](SwiftyDMG/Release.xcconfig). Release assets are prepared by [`Scripts/prepare_release.py`](Scripts/prepare_release.py). Changes to update signing, feed URLs, or archive generation should explain their effect on existing installations.
