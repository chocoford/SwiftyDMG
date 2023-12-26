# SwiftyDMG

![X (formerly Twitter) Follow](https://img.shields.io/twitter/follow/dove_zachary?label=Chocoford) ![GitHub License](https://img.shields.io/github/license/chocoford/SwiftyDMG)

A tool help you create DMG for your app, with many customizable options.

> This is a by-product of my development of some Swift packages, 
> providing everyone with an easy-to-use tool to create DMG in Swift.

## Installation

Install with [Homebrew](https://brew.sh/)

```shell
brew install chocoford/repo/swifty-dmg
```

## Usage

```shell
OVERVIEW: A tool help you create dmg for your app.

USAGE: create-dmg <app-url> [--output <output>] [--background <background>] [--noBackground] [--skip-codesign] [--verbose]

ARGUMENTS:
  <app-url>               The url of your app.

OPTIONS:
  -o, --output <output>   The destination of the dmg.
  -b, --background <background>
                          The background image of the dmg.
  --noBackground          Remove the background of the dmg.
  --skip-codesign         Skip codesign for the dmg.
  --verbose               Print progress updates when creating dmg.
  -h, --help              Show help information.
```

## Roadmap

- [x] Create DMG
- [ ] Customizable options (Ongoing...)

## See also

* [AppDMG](https://github.com/chocoford/AppDMG) - A swift package that enables creating DMG files programmatically.
* [DSStoreKit](https://github.com/chocoford/DSStoreKit) - A swift package that help you customize `.DS_Store` file of your folders.

## Acknowledgment

* [sindresorhus/*create-dmg*](https://github.com/sindresorhus/create-dmg)
* [create-dmg/*create-dmg*](https://github.com/create-dmg/create-dmg)
