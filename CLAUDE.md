# Skylight repo rules

- This repository is public. Never commit secrets, tokens, or personal data.
- `SPEC.md`, `tasks/`, and `.claude/` are local working documents. They stay
  untracked and ignored. Never commit them, and never reference them in
  tracked files.
- XcodeGen owns `Skylight.xcodeproj`. Edit `project.yml`, then run
  `xcodegen generate`. Never hand-edit or commit the project file.
- Run `scripts/preflight.sh` before each push. The pre-push hook runs it
  automatically. See `docs/RELEASING.md` for setup and the release process.

## Build and test

- `scripts/run.sh` — Debug build and launch.
- `scripts/release.sh` — Release build, install to `/Applications`, zip to
  `dist/`.
- `scripts/publish.sh` — semver release: tag, GitHub release, Homebrew tap
  update. Run only when the user asks for a release.
- Tests: `xcodegen generate && xcodebuild -project Skylight.xcodeproj -scheme Skylight -destination 'platform=macOS' test`
