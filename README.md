# ChainPad

ChainPad is a macOS menu bar utility that captures copied crypto objects (tokens, wallets, txs), enriches metadata, and keeps a searchable scratchpad.

## Install

### Homebrew (recommended)

```bash
brew tap nhestrompia/chainpad https://github.com/nhestrompia/chainpad
brew install --cask nhestrompia/chainpad/chainpad
```

Launch:

```bash
open -a ChainPad
```

Update:

```bash
brew update
brew upgrade --cask nhestrompia/chainpad/chainpad
```

Uninstall:

```bash
brew uninstall --cask nhestrompia/chainpad/chainpad
```

### Direct download

Download the latest release asset from GitHub Releases:

<https://github.com/nhestrompia/chainpad/releases/latest>

### Local package build

Build installable artifacts locally:

```bash
./scripts/package-macos-app.sh --version 0.1.0 --github-repo <owner>/<repo>
```

Artifacts are written to `dist/`:

- `ChainPad.app`
- `ChainPad-<version>.app.zip`
- `ChainPad-<version>.pkg`
- `checksums.txt`

You can install the `.pkg` directly on macOS, or distribute the `.app.zip` for Homebrew cask installs.

## Maintainer notes

### One-command release pipeline

Use the release script to build, sign, notarize, staple, repack, and update cask SHA/version in one run:

```bash
./scripts/release-macos.sh --version 0.1.3
```

Optional flags:

```bash
./scripts/release-macos.sh \
  --version 0.1.3 \
  --create-tag \
  --push-tag \
  --upload-release
```

Notes:

- `--upload-release` requires GitHub CLI (`brew install gh` + `gh auth login`).
- Script expects a valid `Developer ID Application` cert and `notarytool` profile (default: `chainpad-notary`).
- It updates `Casks/chainpad.rb` automatically with the final notarized ZIP SHA.

## Development

```bash
swift run ChainPad
swift test
```

## Release workflow

Tag and push a version to trigger the CI release workflow:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow builds release artifacts and uploads them to the GitHub release.
