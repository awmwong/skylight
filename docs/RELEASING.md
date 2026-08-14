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

## Cut a release

1. Make sure that the working tree is clean and that `main` is up to date.
2. Run `scripts/preflight.sh`.
3. Run the tests:

   ```sh
   xcodegen generate
   xcodebuild -project Skylight.xcodeproj -scheme Skylight \
     -destination 'platform=macOS' test
   ```

4. Do a manual smoke test: start a share, move the region, stop the share.
5. Tag the release and push the tag:

   ```sh
   git tag v0.1.0
   git push origin main v0.1.0
   ```

6. Build the zip: `scripts/release.sh --no-install`. The zip lands in
   `dist/Skylight-v0.1.0.zip`.
7. Publish the release:

   ```sh
   gh release create v0.1.0 dist/Skylight-v0.1.0.zip \
     --title "Skylight v0.1.0" --notes "<what changed>"
   ```

NOTE: The zip is signed with a development identity and is not notarized.
Gatekeeper blocks it on other machines. Users must build from source, or
right-click the app and select Open. Notarization is future work.

## One-time: flip the repository to public

1. Run `scripts/preflight.sh` and make sure that it passes.
2. Add a `LICENSE` file.
3. Run `gh repo edit awmwong/skylight --visibility public --accept-visibility-change-consequences`.
4. In GitHub, open Settings → Advanced Security. Turn on secret scanning
   and push protection (free for public repos).
