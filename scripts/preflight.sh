#!/usr/bin/env bash
# Exposure checks before a push or a release. The script fails if the repo
# tracks a local working document or if gitleaks finds a secret in history.
set -euo pipefail
cd "$(dirname "$0")/.."

status=0

forbidden='^(SPEC\.md$|tasks/|\.claude/|dist/|build/|Skylight\.xcodeproj/)|\.xcuserdata|\.env'
tracked_forbidden="$(git ls-files | grep -E "$forbidden" || true)"
if [ -n "$tracked_forbidden" ]; then
  echo "error: these local working artifacts are tracked:" >&2
  echo "$tracked_forbidden" >&2
  status=1
fi

if command -v gitleaks >/dev/null 2>&1; then
  if ! gitleaks git --no-banner --redact .; then
    echo "error: gitleaks found a possible secret. Remove it before you push." >&2
    status=1
  fi
else
  echo "error: gitleaks is not installed. Run: brew install gitleaks" >&2
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "preflight: OK"
fi
exit "$status"
