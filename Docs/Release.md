# Releasing SwiftyDMG

## Configuration

Edit `Configuration/Release.xcconfig`:

- `MARKETING_VERSION`: user-visible version.
- `CURRENT_PROJECT_VERSION`: increasing numeric build number.
- `SPARKLE_FEED_URL`: stable HTTPS appcast URL.
- `SPARKLE_PUBLIC_ED_KEY`: public Ed25519 key associated with the release signing account.

The default feed is:

```text
https://github.com/chocoford/SwiftyDMG/releases/latest/download/appcast.xml
```

The `$()` in the xcconfig URL prevents its slashes from being interpreted as a
comment. Xcode expands the correct HTTPS URL into the app's Info.plist.

The public key is intentionally blank until a release signing key is selected.
Without it, the app does not start the updater. Store only the public key in this
file; private keys and notarization credentials belong in the login Keychain.

## Prepare release assets

The native Xcode project manages all application dependencies and embeds Sparkle.
Its tools are downloaded under
`DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/` after dependency resolution.

1. Use Sparkle's `generate_keys` tool to create or select an Ed25519 key account.
   A dedicated account such as `com.chocoford.SwiftyDMG` is supported. Add the public
   key to the xcconfig and preserve access to its private key in the login Keychain.
2. Ensure the hdiutil dependency contains the macOS 27 process-exit fix and run
   the Xcode packaging regressions.
3. Supply a Developer ID Application identity and a configured notarytool Keychain
   profile to `Scripts/prepare_release.py`.

```sh
python3 Scripts/prepare_release.py \
  --sign-identity 'Developer ID Application: Your Name (TEAMID)' \
  --notary-profile 'your-notary-profile' \
  --key-account 'com.chocoford.SwiftyDMG'
```

The script runs the Xcode test target without launching the GUI, builds a universal
native Release app with explicit signing, checks the Sparkle key account, submits
for notarization, staples the accepted app and creates a signed appcast with a zip
archive. Local assets are written under `DerivedData/ReleaseAssets/v<version>/`.

Review and test the archive and appcast before attaching both to the corresponding
GitHub Release. The script prepares local assets and does not publish them.

Release signing, notarization, Finder interaction and actual update installation
remain to be verified before public distribution. No release keys or GitHub assets
have been created during development.

References: [Sparkle setup](https://sparkle-project.org/documentation/),
[programmatic setup](https://sparkle-project.org/documentation/programmatic-setup/),
[publishing updates](https://sparkle-project.org/documentation/publishing/).
