#!/usr/bin/env bash
# Contract: skills/lib/release/adr-check.sh — release-readiness verification
# that a spec-declared ADR obligation was actually fulfilled in the commit
# range derive.sh will project (#137).
#
#   adr-check.sh [spec-body-file]
#
# Reads the spec body and looks for an ADR obligation in its
# "## Implementation Decisions" section (parse.sh adr-obligation — a list
# item mentioning ADR, not a phrase match anywhere in the body). No
# obligation: silent, exit 0. An obligation: checks derive.sh's own range
# (derive.sh range) for a commit that added or modified a file under
# docs/adr/ — found: "adr-check: satisfied: <path>", exit 0; not found:
# "adr-check: not-release-ready: ..." naming the obligation, exit 1.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
ADR_CHECK="$REPO/skills/lib/release/adr-check.sh"
SPEC_FIX="$REPO/tests/fixtures/spec"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

new_repo() { # dir
  git init -q "$1"
}

c() { # dir subject
  git -C "$1" -c user.name=t -c user.email=t@t \
    commit -q --allow-empty -m "$2"
}

add_adr() { # dir number-and-slug
  mkdir -p "$1/docs/adr"
  printf '# ADR %s\n' "$2" > "$1/docs/adr/$2.md"
  git -C "$1" add "docs/adr/$2.md"
  git -C "$1" -c user.name=t -c user.email=t@t \
    commit -q -m "docs(adr): add $2"
}

# --- no obligation: silent, exit 0, regardless of range ---------------------

no_obligation="$work/no-obligation"
new_repo "$no_obligation"
c "$no_obligation" "chore: bootstrap"
git -C "$no_obligation" tag v1.0.0
c "$no_obligation" "feat: ship the thing"
out="$(cd "$no_obligation" && bash "$ADR_CHECK" "$SPEC_FIX/no-adr-obligation.md" 2>&1)"
assert_eq "" "$out" "no-obligation: silent when the spec declares nothing"
assert_exit 0 "no-obligation: exits zero" \
  bash -c "cd '$no_obligation' && bash '$ADR_CHECK' '$SPEC_FIX/no-adr-obligation.md'"

# --- obligation satisfied: a new ADR file lands in the range ----------------

satisfied="$work/satisfied"
new_repo "$satisfied"
c "$satisfied" "chore: bootstrap"
git -C "$satisfied" tag v1.0.0
add_adr "$satisfied" "0001-precedence"
out="$(cd "$satisfied" && bash "$ADR_CHECK" "$SPEC_FIX/adr-obligation.md" 2>&1)"
assert_contains "$out" "satisfied: docs/adr/0001-precedence.md" \
  "satisfied: names the ADR file it found"
assert_exit 0 "satisfied: exits zero" \
  bash -c "cd '$satisfied' && bash '$ADR_CHECK' '$SPEC_FIX/adr-obligation.md'"

# --- obligation unmet: the range has no new/modified ADR file ---------------

unmet="$work/unmet"
new_repo "$unmet"
c "$unmet" "chore: bootstrap"
add_adr "$unmet" "0001-existing"
git -C "$unmet" tag v1.0.0
c "$unmet" "feat: ship the thing, no adr this time"
status=0
out="$(cd "$unmet" && bash "$ADR_CHECK" "$SPEC_FIX/adr-obligation.md" 2>&1)" || status=$?
assert_eq 1 "$status" "unmet: exits 1"
assert_contains "$out" "not-release-ready" "unmet: reports not-release-ready"
assert_contains "$out" "One ADR for the positive decision" \
  "unmet: names the unmet obligation from the spec body"

# --- obligation satisfied by a modified (not just added) ADR ---------------

modified="$work/modified"
new_repo "$modified"
c "$modified" "chore: bootstrap"
add_adr "$modified" "0001-existing"
git -C "$modified" tag v1.0.0
printf '# ADR 0001 (revised)\n' > "$modified/docs/adr/0001-existing.md"
git -C "$modified" add docs/adr/0001-existing.md
git -C "$modified" -c user.name=t -c user.email=t@t \
  commit -q -m "docs(adr): revise 0001 per review"
out="$(cd "$modified" && bash "$ADR_CHECK" "$SPEC_FIX/adr-obligation.md" 2>&1)"
assert_contains "$out" "satisfied: docs/adr/0001-existing.md" \
  "modified: a revised ADR in range also satisfies the obligation"
assert_exit 0 "modified: exits zero" \
  bash -c "cd '$modified' && bash '$ADR_CHECK' '$SPEC_FIX/adr-obligation.md'"

# --- stdin ------------------------------------------------------------------

out="$(cd "$satisfied" && bash "$ADR_CHECK" < "$SPEC_FIX/adr-obligation.md" 2>&1)"
assert_contains "$out" "satisfied:" "stdin: spec body on stdin is read too"

echo "release-adr-check: all assertions passed"
