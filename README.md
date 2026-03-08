# ChainPad

ChainPad is a macOS menu bar utility that captures copied crypto objects (tokens, wallets, txs), enriches metadata, and keeps a searchable scratchpad.

## Install

### Homebrew (recommended)

ChainPad should be distributed as a Homebrew **cask** (standard for GUI/menu bar apps).

1. Create a GitHub release artifact (`ChainPad-<version>.app.zip`) using the packaging script below.
2. Generate/update your cask file:

```bash
./scripts/generate-homebrew-cask.sh \
  --version 0.1.0 \
  --sha256 <zip_sha256> \
  --repo <owner>/<repo>
```

3. Commit the generated `Casks/chainpad.rb` to your tap repo.
4. Install:

```bash
brew tap <owner>/<tap-repo>
brew install --cask chainpad
```

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

## Development

```bash
swift run ChainPad
swift test
```

## Release workflow

Tag and push a version to trigger the macOS release build workflow:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow builds release artifacts and uploads them to the GitHub release.
