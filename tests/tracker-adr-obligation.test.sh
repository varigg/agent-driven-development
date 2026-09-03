#!/usr/bin/env bash
# Contract: skills/lib/tracker/tracker.sh's live orchestration of the
# ADR-obligation completeness verdict — the seam this ticket adds around
# resolve.sh's pure logic (already covered by tests/tracker-resolve.test.sh
# against prebuilt deliveries files). This test exercises the real path:
# tracker.sh enumerating open obligated specs, gathering each one's children
# through child_delivery (a stubbed gh plus a real git fixture, in
# tracker-child-delivery.test.sh's style), and handing the result to
# resolve.sh — for `specs`, `spec-complete`, and `frontier` alike.
#
# It also covers the one thing a fixture-fed resolve.sh test cannot: that
# `spec-complete <n>`'s delivery gather is scoped to <n> alone, so an
# unrelated obligated spec's unresolvable merge commit (a shallow or stale
# clone) never fails a query about a spec that has nothing to do with it —
# while `specs`/`frontier`, which answer for every open spec at once,
# correctly do refuse when that unresolvable spec is among them.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
TRACKER="$REPO/skills/lib/tracker/tracker.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- git fixture: one ADR-touching delivery, one that doesn't ---------------

repo="$work/repo"
git init -q "$repo"
mkdir -p "$repo/docs"
printf 'ADDW_MAIN_BRANCH="master"\nADDW_ADR_DIR="docs/adr"\n' > "$repo/docs/addw.env"

commit() { # subject
  git -C "$repo" -c user.name=t -c user.email=t@t \
    commit -q --allow-empty -m "$1"
}
head_sha() { git -C "$repo" rev-parse HEAD; }

commit "chore: bootstrap"
git -C "$repo" tag v1.0.0

# Spec 200's child: delivered, but never touches the ADR directory.
commit "feat: deliver child 201 (no ADR)"
SHA_201="$(head_sha)"

# Spec 100's child: delivered and adds the ADR the spec promised.
mkdir -p "$repo/docs/adr"
printf '# ADR 0001: decide something\n' > "$repo/docs/adr/0001-decide.md"
git -C "$repo" add docs/adr/0001-decide.md
git -C "$repo" -c user.name=t -c user.email=t@t \
  commit -q -m "docs(adr): decide 101's approach"
SHA_101="$(head_sha)"

export SHA_101 SHA_201

# --- gh stub: the issue snapshot, plus one closedByPullRequestsReferences
#     lookup per completed child --------------------------------------------

issue() { # number state reason parent-or-empty labels-csv title body-extra
  jq -nc --arg n "$1" --arg s "$2" --arg r "$3" --arg p "$4" --arg l "$5" \
      --arg t "$6" --arg extra "${7:-}" '
    {number: ($n | tonumber), title: $t, state: $s,
     stateReason: (if $r == "" then null else $r end),
     labels: ($l | if . == "" then [] else split(",") end | map({name: .})),
     assignees: [],
     body: (if $p == "" then ("No parent.\n" + $extra)
            else ("## Parent\n\n- #" + $p + "\n" + $extra) end)}'
}

OBLIGATION_BODY='
## Implementation Decisions

- One ADR records the decision.
'

# Two snapshots: the base one answers the ordinary satisfied/unmet cases
# cleanly; the wider one adds spec 300, whose child's merge commit this
# checkout cannot resolve, so that failure can be exercised in isolation
# rather than poisoning every other assertion's `specs`/`frontier` call.
issues_base="$work/issues-base.json"
{
  printf '[\n'
  issue 100 OPEN "" "" spec "Spec: satisfied obligation" "$OBLIGATION_BODY"
  printf ',\n'
  issue 101 CLOSED COMPLETED 100 ready-for-agent "Deliver 100's ADR"
  printf ',\n'
  issue 200 OPEN "" "" spec "Spec: unmet obligation" "$OBLIGATION_BODY"
  printf ',\n'
  issue 201 CLOSED COMPLETED 200 ready-for-agent "Deliver 200, no ADR"
  printf '\n]\n'
} > "$issues_base"

issues_wide="$work/issues-wide.json"
{
  printf '[\n'
  issue 100 OPEN "" "" spec "Spec: satisfied obligation" "$OBLIGATION_BODY"
  printf ',\n'
  issue 101 CLOSED COMPLETED 100 ready-for-agent "Deliver 100's ADR"
  printf ',\n'
  issue 200 OPEN "" "" spec "Spec: unmet obligation" "$OBLIGATION_BODY"
  printf ',\n'
  issue 201 CLOSED COMPLETED 200 ready-for-agent "Deliver 200, no ADR"
  printf ',\n'
  issue 300 OPEN "" "" spec "Spec: unresolvable commit" "$OBLIGATION_BODY"
  printf ',\n'
  issue 301 CLOSED COMPLETED 300 ready-for-agent "Delivered, but this checkout lacks the commit"
  printf '\n]\n'
} > "$issues_wide"

export STUB_ISSUES="$issues_base"

mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"issue list "*"--state all"*) cat "$STUB_ISSUES" ;;
  *"number=101"*) printf '201\t%s\n' "$SHA_101" ;;
  *"number=201"*) printf '301\t%s\n' "$SHA_201" ;;
  *"number=301"*) printf '401\tdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef\n' ;;
  *) echo "gh stub: unexpected call: $*" >&2; exit 97 ;;
esac
SH
# `frontier` also calls `branches()`, which runs `git ls-remote --heads
# origin` — this fixture repo has no remote, and its result is irrelevant to
# this test, so ls-remote is stubbed empty while every other git subcommand
# (show, describe, cat-file — child_delivery's real reads) passes through to
# the real binary, captured before PATH is shadowed below.
REAL_GIT="$(command -v git)"
cat > "$work/bin/git" <<GITSH
#!/usr/bin/env bash
[ "\$1" = "ls-remote" ] && exit 0
exec "$REAL_GIT" "\$@"
GITSH
chmod +x "$work/bin/gh" "$work/bin/git"
PATH="$work/bin:$PATH"
export PATH

# --- specs: both obligated specs answered in one call -----------------------

specs_out="$(cd "$repo" && bash "$TRACKER" specs)"
assert_contains "$specs_out" "$(printf '#100\tcomplete\tSpec: satisfied obligation')" \
  "specs: an ADR-touching delivery satisfies the obligation"
assert_contains "$specs_out" "$(printf '#200\tpartial\tSpec: unmet obligation')" \
  "specs: a delivery that never touches the ADR directory stays partial"

# --- frontier: complete-specs reflects the same verdicts --------------------

frontier_out="$(cd "$repo" && bash "$TRACKER" frontier)"
assert_contains "$frontier_out" "$(printf '#100\tSpec: satisfied obligation')" \
  "frontier: satisfied-obligation spec surfaced in complete-specs"
assert_not_contains "$frontier_out" "$(printf '#200\t')" \
  "frontier: unmet-obligation spec not surfaced in complete-specs"

# --- spec-complete: single-spec queries agree -------------------------------

assert_exit 0 "spec-complete: satisfied obligation is complete" \
  bash -c "cd '$repo' && bash '$TRACKER' spec-complete 100"
assert_exit 1 "spec-complete: unmet obligation is not complete" \
  bash -c "cd '$repo' && bash '$TRACKER' spec-complete 200"
verdict_200="$(cd "$repo" && bash "$TRACKER" spec-complete 200 || true)"
assert_eq "partial" "$(head -n 1 <<<"$verdict_200")" \
  "spec-complete: unmet-obligation verdict line"

# --- isolation: spec 300's unresolvable commit only breaks queries that
#     actually need it -------------------------------------------------------

export STUB_ISSUES="$issues_wide"

assert_exit 1 "specs: an unresolvable commit among the obligated specs refuses the whole listing" \
  bash -c "cd '$repo' && bash '$TRACKER' specs"
assert_exit 1 "frontier: same refusal reaches frontier" \
  bash -c "cd '$repo' && bash '$TRACKER' frontier"

assert_exit 0 "spec-complete: an unrelated spec's unresolvable commit never reaches this query" \
  bash -c "cd '$repo' && bash '$TRACKER' spec-complete 100"
assert_exit 1 "spec-complete: the target spec's own unresolvable commit still refuses" \
  bash -c "cd '$repo' && bash '$TRACKER' spec-complete 300"

echo "tracker-adr-obligation: all assertions passed"
