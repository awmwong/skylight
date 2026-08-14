# Release Process

This document tells you how to keep sensitive content out of the repo and
how to cut a release.

## Exposure rules

This repository is public. These paths are local working artifacts. They
stay untracked, and `.gitignore` lists them:

- `SPEC.md` and `tasks/` — local planning documents
- `.claude/` — local session tooling
- `build/`, `dist/`, `Skylight.xcodeproj/` — generated output

Never commit secrets, tokens, or personal data. Never weaken `.gitignore`
without a check of what becomes trackable.

## Preflight checks

`scripts/preflight.sh` makes sure that no working artifact is tracked and
that gitleaks finds no secret in the full history.

One-time setup on each clone:

1. Run `brew install gitleaks`.
2. Install the pre-push hook:

```sh
ln -sf ../../scripts/preflight.sh .git/hooks/pre-push
```

The `secret-scan` GitHub Actions workflow runs gitleaks on every push as a
backstop for pushes from a machine without the hook.

## Versioning

Releases follow Semantic Versioning with `vMAJOR.MINOR.PATCH` tags. The
Conventional Commits since the last tag select the bump:

- A `!` type suffix or a `BREAKING CHANGE:` footer bumps MAJOR.
- A `feat` commit bumps MINOR.
- All other commits bump PATCH.

The first release is `v0.1.0`. Before `v1.0.0`, any release can change
behavior. The release build stamps the tag into `CFBundleShortVersionString`.

## Cut a release

1. Do a manual smoke test: start a share, move the region, stop the share.
2. Run `scripts/publish.sh`. Pass `--major`, `--minor`, or `--patch` to
   override the computed bump.

The script refuses a dirty tree, a branch other than `main`, an out-of-sync
`main`, or a private repo. Then it:

1. Runs `scripts/preflight.sh` and the test suite.
2. Computes the next version and pushes the annotated tag.
3. Builds the zip with `scripts/release.sh --no-install`.
4. Creates the GitHub release with generated notes and the zip.
5. Writes `Casks/skylight.rb` in [awmwong/homebrew-tap] with the new
   version and SHA-256, then pushes the tap.

[awmwong/homebrew-tap]: https://github.com/awmwong/homebrew-tap

Users then install with:

```sh
brew install --cask --no-quarantine awmwong/tap/skylight
```

NOTE: The zip is signed with a development identity and is not notarized.
Without `--no-quarantine`, Gatekeeper blocks the first launch and the user
must right-click the app and select Open. Notarization is future work.

## One-time: flip the repository to public

1. Run `scripts/preflight.sh` and make sure that it passes.
2. Run `gh repo edit awmwong/skylight --visibility public --accept-visibility-change-consequences`.
3. In GitHub, open Settings → Advanced Security. Turn on secret scanning
   and push protection (free for public repos).
