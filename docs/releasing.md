# Releasing Seemless

The release assets are an Apple Silicon app ZIP, signed Sparkle `appcast.xml`, and `SHA256SUMS`. GitHub's latest-release asset URL is the stable feed embedded in the app. Every release carries its own feed entry pointing to its immutable versioned archive.

## Requirements

- macOS, Swift 6, and an installed macOS SDK.
- GitHub CLI authenticated with access to `etphli/seemless`.
- The matching Ed25519 private key in the login Keychain, account `com.etphli.seemless`.

The public key lives in `config/app.sh`. Preserve the private Keychain item and back it up securely; an unrelated replacement key cannot update existing installations. Never export it to the repository. `package_release.sh` checks that the Keychain key matches the embedded public key before generating assets.

## Prepare and publish

1. Increase `APP_VERSION` and the numeric `BUILD_NUMBER` in `config/app.sh`. Each published version and build number must be new.
2. Add `docs/releases/<version>.md` describing the changes and verification limits.
3. Run `./script/test.sh` and `./script/build_and_run.sh --diagnostics`. Review all six native captures and the report.
4. Commit the source, version, and release notes.
5. Run `./script/package_release.sh`. This performs an optimized build, embeds Sparkle, verifies the bundle, creates a ZIP, signs the archive and feed, and records SHA-256 checksums in `dist/releases/v<version>`.
6. Run `./script/verify_update.sh`. It installs the release into a disposable older-version app, then confirms that a modified archive is rejected and the old app is preserved. Logs stay under `.build/update-check-<timestamp>`. It needs the release Keychain key to sign its local fixture feeds.
7. Run `./script/publish_release.sh`. It requires a clean source tree, checks asset checksums, pushes the source and annotated version tag, and publishes the three GitHub release assets.
8. Download the published assets, check `SHA256SUMS`, and install the downloaded ZIP with `./script/install.sh /absolute/path/to/archive.zip`.

Packaging always generates the feed in a new staging directory, preventing an older same-version feed signature from being reused after a development rebuild. Do not overwrite a published version; publish a new version instead. The publish script rejects a tag that points to different source.

## Native update checks

Normal builds check the signed GitHub feed at launch and daily. The Update control appears only for a compatible newer version. Clicking it invokes Sparkle's native install and relaunch flow; there is no Git checkout or shell command run from the installed app.

Diagnostics normally skip network checks. Add `--check-updates` when launching a staged app with `--diagnostics /absolute/output/path` to capture availability as well. Diagnostic settings and clipboard examples stay separate from personal data.

The lower-level `script/verify_update.swift` driver accepts only a staged `Seemless.app` inside `.build`, with `--probe` or `--install`. The integration script compiles it against the packaged Sparkle framework. It cannot target the installed Applications bundle.

## Signing and installation

The release update feed and archive use Sparkle Ed25519 signing. The app bundle uses local ad-hoc code signing. These provide update authenticity and bundle integrity, but do not provide Apple's Developer ID trust or notarisation. No Developer ID identity is configured on this machine yet.

The installation script verifies the bundle before replacing the local app, backs up an existing Seemless bundle, clears only its quarantine attribute, and checks that the process runs from `/Applications/Seemless.app`. It does not disable Gatekeeper globally. Settings and clipboard history are stored separately and preserved.
