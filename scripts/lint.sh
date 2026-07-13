#!/usr/bin/env bash
#
# Blocking lint (ratchet). Runs `tl check` (strict type-checking) over an
# allowlist of files that are known to be clean, and FAILS if any of them
# regresses. The full-project residual is printed for visibility but is not
# (yet) blocking — clean a file and its require-tree, add it to
# scripts/lint-allowlist.txt, and the ratchet tightens.
#
# Why a ratchet: `tl gen` (the build) does not type-check; only `tl check` does,
# and the codebase carries a backlog of dynamic (`as any`) type errors. Rather
# than block everything (impossible today) or nothing (the status quo), we block
# regressions on the clean set and grow it over time.
#
# Platform globals (game/ngx/love/...) are supplied via teal-types.d.tl using
# tl's --global-env-def, so `tl gen` (which does not read it) is unaffected.

set -uo pipefail

cd "$(dirname "$0")/.."

DEF_ARGS=(-I . --global-env-def teal-types)
ALLOWLIST="scripts/lint-allowlist.txt"

fail=0
checked=0
while IFS= read -r f; do
   case "$f" in
      ''|\#*) continue ;;
   esac
   checked=$((checked + 1))
   errors="$(tl "${DEF_ARGS[@]}" check "$f" 2>&1 | grep -E "\.tl:[0-9]+:[0-9]+:" || true)"
   if [ -n "$errors" ]; then
      echo "❌ lint regression in $f:"
      echo "$errors" | sed 's/^/    /'
      fail=1
   fi
done < "$ALLOWLIST"

# Informational: total residual across the whole project.
residual="$(tl "${DEF_ARGS[@]}" check $(find src/sentry -name '*.tl' | tr '\n' ' ') 2>&1 | grep -cE '\.tl:[0-9]+:[0-9]+:' || true)"
total="$(find src/sentry -name '*.tl' | wc -l | tr -d ' ')"

echo ""
echo "Lint (blocking): $checked allowlisted files checked."
echo "Migration status: $checked/$total files tl-check-clean; $residual residual errors project-wide."

if [ "$fail" -ne 0 ]; then
   echo "❌ Blocking lint failed: an allowlisted file regressed."
   exit 1
fi
echo "✅ Blocking lint passed."
