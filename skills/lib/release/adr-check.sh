#!/usr/bin/env bash
# Verifies a spec-declared ADR obligation was actually fulfilled in the
# commit range this release will project. Nothing else in the readiness path
# reads spec prose or looks for it in history, so a spec could pass every
# other check, release, and close while a promised ADR never happened (#137).
#
# Usage: adr-check.sh [spec-body-file]
#
# Reads the spec body (file or stdin) and looks for an ADR obligation in its
# "## Implementation Decisions" section (parse.sh adr-obligation — the
# durable structural signal, a list item mentioning ADR, rather than
# matching a phrase anywhere in the body). No obligation declared: silent,
# exit 0 — most specs never touch this check. An obligation declared: checks
# the same commit range derive.sh projects (derive.sh range) for a commit
# that added or modified a file under docs/adr/.
#
#   satisfied  stdout: "adr-check: satisfied: <path>"     exit 0
#   unmet      stderr: "adr-check: not-release-ready: <obligation>"   exit 1
#
# Run from a project's repo root, same as derive.sh, whose range this reuses
# rather than recomputing which tag bounds the release.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DERIVE="$here/derive.sh"
PARSE="$here/../tracker/parse.sh"

ADR_DIR=docs/adr

obligation="$(bash "$PARSE" adr-obligation "$@")"
[ -n "$obligation" ] || exit 0

range="$(bash "$DERIVE" range)"

adr_file="$(git log --name-status --format='' "$range" -- "$ADR_DIR" \
  | awk '$1 == "A" || $1 == "M" { print $2; exit }')"

if [ -n "$adr_file" ]; then
  printf 'adr-check: satisfied: %s\n' "$adr_file"
  exit 0
fi

printf 'adr-check: not-release-ready: spec declares an ADR obligation with no matching ADR in range:\n%s\n' \
  "$obligation" >&2
exit 1
