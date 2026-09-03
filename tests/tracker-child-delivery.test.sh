#!/usr/bin/env bash
# Contract: skills/lib/tracker/tracker.sh child-delivery <n> — the live
# per-spec closed-child delivery lookup (#146). Unlike resolve.sh's pure
# queries, this one is git-backed: the child-to-PR edge comes from a stubbed
# gh (both the issue snapshot and the closedByPullRequestsReferences
# GraphQL lookup), while the merge commit's ADR-touch and first-tag facts
# come from a real git fixture repository — nothing about those two facts
# can be faked without exercising the real git plumbing.
#
# One line per closed child of the given spec, ascending by issue number:
#   #<child>\tabandoned                     closed not-planned
#   #<child>\tno-pr                         closed completed, no tracked PR
#   #<child>\tcompleted\t#<PR>\t<sha>\t<adr:yes|no>\t<tag|unreleased>
# Open children and children of a different spec are silent. A spec number
# with no "spec" label in the snapshot exits 2.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
TRACKER="$REPO/skills/lib/tracker/tracker.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- git fixture: three delivered children, one unreleased, one ADR-touching,
#     one tagged ------------------------------------------------------------

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

commit "feat: deliver child 101"
SHA_101="$(head_sha)"
git -C "$repo" tag v1.1.0 # 101's merge commit is exactly tagged

mkdir -p "$repo/docs/adr"
printf '# ADR 0001: decide something\n' > "$repo/docs/adr/0001-decide.md"
git -C "$repo" add docs/adr/0001-decide.md
git -C "$repo" -c user.name=t -c user.email=t@t \
  commit -q -m "docs(adr): decide 103's approach"
SHA_103="$(head_sha)"
git -C "$repo" tag v1.2.0

# Last commit, no tag after it — nothing can contain it. Placed after every
# tag in this fixture, since an earlier commit would be swept up by a later
# tag on a descendant (git describe --contains follows the graph forward).
commit "feat: deliver child 102 (stays unreleased)"
SHA_102="$(head_sha)"

export SHA_101 SHA_102 SHA_103

# --- gh stub: the issue snapshot, plus one closedByPullRequestsReferences
#     lookup per completed child ---------------------------------------------

issue() { # number state reason parent-or-empty labels-csv title
  jq -nc --arg n "$1" --arg s "$2" --arg r "$3" --arg p "$4" --arg l "$5" --arg t "$6" '
    {number: ($n | tonumber), title: $t, state: $s,
     stateReason: (if $r == "" then null else $r end),
     labels: ($l | if . == "" then [] else split(",") end | map({name: .})),
     assignees: [],
     body: (if $p == "" then "No parent.\n" else "## Parent\n\n- #" + $p + "\n" end)}'
}

issues="$work/issues.json"
{
  printf '[\n'
  issue 100 OPEN "" "" spec "Spec: worktree per ticket"
  printf ',\n'
  issue 101 CLOSED COMPLETED 100 ready-for-agent "Tagged child"
  printf ',\n'
  issue 102 CLOSED COMPLETED 100 ready-for-agent "Unreleased child"
  printf ',\n'
  issue 103 CLOSED COMPLETED 100 ready-for-agent "ADR-touching child"
  printf ',\n'
  issue 104 CLOSED NOT_PLANNED 100 ready-for-agent "Abandoned child"
  printf ',\n'
  issue 105 CLOSED COMPLETED 100 ready-for-agent "Closed by hand, no PR"
  printf ',\n'
  issue 106 OPEN "" 100 ready-for-agent "Still open, silent"
  printf ',\n'
  issue 107 CLOSED COMPLETED 200 ready-for-agent "Child of a different spec"
  printf ',\n'
  issue 200 OPEN "" "" spec "Spec: a different spec"
  printf ',\n'
  issue 300 OPEN "" "" spec "Spec: an unfetched merge commit"
  printf ',\n'
  issue 301 CLOSED COMPLETED 300 ready-for-agent "Delivered, but this checkout lacks the commit"
  printf '\n]\n'
} > "$issues"
export STUB_ISSUES="$issues"

mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"issue list "*"--state all"*) cat "$STUB_ISSUES" ;;
  *"number=101"*) printf '201\t%s\n' "$SHA_101" ;;
  *"number=102"*) printf '202\t%s\n' "$SHA_102" ;;
  *"number=103"*) printf '203\t%s\n' "$SHA_103" ;;
  *"number=105"*) printf '' ;;
  *"number=301"*) printf '401\tdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef\n' ;;
  *) echo "gh stub: unexpected call: $*" >&2; exit 97 ;;
esac
SH
chmod +x "$work/bin/gh"
PATH="$work/bin:$PATH"
export PATH

# --- run ----------------------------------------------------------------

out="$(cd "$repo" && bash "$TRACKER" child-delivery 100)"

# --- tagged child -----------------------------------------------------------

assert_contains "$out" "$(printf '#101\tcompleted\t#201\t%s\tno\tv1.1.0' "$SHA_101")" \
  "tagged: completed line names the PR, commit, no-ADR, and its exact tag"

# --- unreleased child --------------------------------------------------------

assert_contains "$out" "$(printf '#102\tcompleted\t#202\t%s\tno\tunreleased' "$SHA_102")" \
  "unreleased: no tag contains the commit yet"

# --- ADR-touching child -------------------------------------------------------

assert_contains "$out" "$(printf '#103\tcompleted\t#203\t%s\tyes\tv1.2.0' "$SHA_103")" \
  "adr-touching: adr flag is yes, and the child is tagged too"

# --- abandoned child ----------------------------------------------------------

assert_contains "$out" "$(printf '#104\tabandoned')" \
  "abandoned: not-planned child carries no delivery fields"
assert_not_contains "$out" "#104	completed" \
  "abandoned: never guesses a completed status"

# --- closed by hand, no tracked PR --------------------------------------------

assert_contains "$out" "$(printf '#105\tno-pr')" \
  "no-pr: distinct status rather than a guessed PR"

# --- exclusions ---------------------------------------------------------------

assert_not_contains "$out" "#106	" "open child of the spec is silent"
assert_not_contains "$out" "#107	" "closed child of a different spec is silent"

# --- ordering -------------------------------------------------------------

assert_eq "101,102,103,104,105" \
  "$(grep -o '^#[0-9]*' <<<"$out" | tr -d '#' | paste -sd,)" \
  "entries ascend by issue number"

# --- a number that is not a spec-labeled issue refuses loudly ---------------

assert_exit 2 "non-spec number refuses" \
  bash -c "cd '$repo' && bash '$TRACKER' child-delivery 106"
err="$(cd "$repo" && bash "$TRACKER" child-delivery 999 2>&1 >/dev/null || true)"
assert_contains "$err" "not a spec-labeled issue" \
  "unknown number: refusal names why"

# --- a closing PR's merge commit that this checkout cannot resolve refuses,
#     rather than reporting a quiet "no" / "unreleased" it never checked -----

assert_exit 1 "unresolvable merge commit refuses the whole command" \
  bash -c "cd '$repo' && bash '$TRACKER' child-delivery 300"
err="$(cd "$repo" && bash "$TRACKER" child-delivery 300 2>&1 >/dev/null || true)"
assert_contains "$err" "#301" "unresolvable commit: refusal names the child"
assert_contains "$err" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" \
  "unresolvable commit: refusal names the sha"
assert_contains "$err" "#401" "unresolvable commit: refusal names the PR"
out_300="$(cd "$repo" && bash "$TRACKER" child-delivery 300 2>/dev/null || true)"
assert_eq "" "$out_300" \
  "unresolvable commit: nothing partial reaches stdout"

# --- ADDW_ADR_DIR unset or empty refuses rather than guessing docs/adr -----

unconfigured="$work/unconfigured"
mkdir -p "$unconfigured/docs"
printf 'ADDW_MAIN_BRANCH="master"\n' > "$unconfigured/docs/addw.env"
assert_exit 78 "unset ADDW_ADR_DIR refuses" \
  bash -c "cd '$unconfigured' && bash '$TRACKER' child-delivery 100"
err="$(cd "$unconfigured" && bash "$TRACKER" child-delivery 100 2>&1 >/dev/null || true)"
assert_contains "$err" "ADDW_ADR_DIR" \
  "unset ADDW_ADR_DIR: refusal names the key"

# --- CLI hygiene --------------------------------------------------------------

assert_exit 2 "missing spec number refuses loudly" \
  bash "$TRACKER" child-delivery
assert_exit 2 "non-numeric spec number refuses loudly" \
  bash "$TRACKER" child-delivery abc

echo "tracker-child-delivery: all assertions passed"
