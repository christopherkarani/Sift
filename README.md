# Sift

Semantic git history search CLI powered by Wax.

`Sift` installs a single binary named `wax` with two primary flows:

- `wax tui` for interactive terminal UI search
- `wax <question>` for one-shot natural-language semantic search

Examples:

```bash
wax tui
wax when did we add notifications feature
wax index --repo-path ~/Coding/my-repo
wax stats --repo-path ~/Coding/my-repo
```

## Install (Homebrew)

```bash
brew tap christopherkarani/sift
brew install sift
```

## Build From Source

```bash
git clone git@github.com:christopherkarani/Sift.git
cd Sift
swift build -c release
.build/release/wax --help
```

## First Run Behavior

- Sift stores search index files in `<repo>/.wax-repo/`.
- If no index exists, `wax tui` and `wax <query>` auto-index by default.
- Disable auto-index with `--no-auto-index`.

## Commands

```bash
wax tui [--repo-path PATH] [--top-k N] [--text-only]
wax index [--repo-path PATH] [--full] [--max-commits N] [--text-only]
wax stats [--repo-path PATH]
wax <query...> [--repo-path PATH] [--top-k N] [--text-only]
```

## Homebrew Formula

A tap-ready formula template is in `Formula/sift.rb`.

Before tagging a release:

1. Update `url` to the release tarball URL.
2. Replace `sha256` with the tarball checksum.
3. Push formula to `homebrew-sift` tap.
