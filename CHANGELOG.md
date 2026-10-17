# Changelog

Notable changes to SwiftyDMG, with the newest release first.

## [1.1.0] - 2026-10-16

### Added

- A native macOS app with a compact drag-and-drop welcome window that expands into the editor, plus independent windows for separate packaging sessions.
- A live Finder layout preview with draggable app and Applications icons, zoom controls, and light and dark preview appearances.
- An inspector for customizing the DMG filename, save location, mounted volume name, Finder window dimensions, and icon positions. Numeric controls support dragging, typing, and resetting values.
- Custom background images, optional Applications shortcuts, and automatic or custom disk icons with a preview.
- Two localized Finder services: **Create DMG with SwiftyDMG** packages the selected app with default settings; **Configure DMG with SwiftyDMG…** opens the editor first.
- A floating glass progress panel for quick creation from Finder, with an animated percentage, a progress bar, and the current step. It does not activate SwiftyDMG or open the main editor.
- Detailed build activity with collapsible steps, streamed command output, complete log copying, and a shortcut to reveal the finished DMG in Finder.
- Confirmation before replacing an existing DMG.
- Sparkle integration for automatic update checks, manual update checks, and update preferences.
- App and Finder service localization for 18 languages, and a new app icon.

### Changed

- Replaced the command-line interface with a native app and graphical packaging controls.
- SwiftyDMG now requires macOS 14 or later. Liquid Glass is used on macOS 26 and later, with material fallbacks on earlier supported systems.

## [1.0.4] - 2024-02-20

### Fixed

- Resolve relative app, output, and background-image paths against the current working directory.

## [1.0.3] - 2023-12-26

### Changed

- Standardized the command-line flags for omitting the background (`--nobackground` or `--nobg`) and skipping DMG signing (`--skipcodesign`).

## [1.0.2] - 2023-12-26

### Added

- Command-line options for choosing the output path, selecting or omitting a background image, and skipping DMG signing.

## [1.0.1] - 2023-12-26

### Fixed

- Corrected the executable target name to `swifty-dmg`.

## [1.0.0] - 2023-12-25

### Added

- Initial command-line release for creating disk images from macOS apps.

[1.1.0]: https://github.com/chocoford/SwiftyDMG/compare/v1.0.4...v1.1.0
[1.0.4]: https://github.com/chocoford/SwiftyDMG/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/chocoford/SwiftyDMG/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/chocoford/SwiftyDMG/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/chocoford/SwiftyDMG/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/chocoford/SwiftyDMG/tree/v1.0.0
