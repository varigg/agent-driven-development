#!/usr/bin/env bash
# Exercise native dependency reads through the live frontier seam.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh
REPO="$(cd .. && pwd)"
TRACKER="$REPO/skills/lib/tracker/tracker.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/project/docs"
printf 'ADDW_MAIN_BRANCH=master\n' >"$work/project/docs/addw.env"
cat >"$work/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$CALLS"
case "$1 $2" in
  'issue list') cat "$ISSUES" ;;
  'issue view') cat "$QUEUE" ;;
  'api --paginate')
    [ "${API_FAIL:-no}" = no ] || exit 1
    cat "$DEPENDENCIES"
    [ "${API_PARTIAL_FAIL:-no}" = no ] || exit 1
    ;;
  *) printf 'unexpected gh call: %s\n' "$*" >&2; exit 1 ;;
esac
SH
printf '#!/usr/bin/env bash\nexit 0\n' >"$work/bin/git"
chmod +x "$work/bin/gh" "$work/bin/git"
export PATH="$work/bin:$PATH" CALLS="$work/calls" ISSUES="$work/issues.json" DEPENDENCIES="$work/deps.json"
printf '[]\n' >"$DEPENDENCIES"
jq -n '[{number:1,title:"Native dependent",state:"OPEN",stateReason:null,
  labels:[{name:"ready-for-agent"}],assignees:[],body:""}]' >"$ISSUES"
frontier() { (cd "$work/project" && bash "$TRACKER" frontier); }
# Blocker deliberately absent from the ordinary snapshot.
printf '[{"number":99,"title":"Native blocker","state":"open","state_reason":null,"html_url":"https://github.com/other/repo/issues/99"}]\n' >"$DEPENDENCIES"
out="$(frontier)"
assert_not_contains "$out" "$(printf '#1\tNative dependent')" \
  'native-only open blocker prevents pickup even outside snapshot'
assert_contains "$(cat "$CALLS")" 'repos/{owner}/{repo}/issues/1/dependencies/blocked_by' \
  'reads blocked-by endpoint'
assert_contains "$(cat "$CALLS")" '--paginate' 'all dependency pages requested'

printf '[{"number":99,"title":"Native blocker","state":"closed","state_reason":"completed","html_url":"https://github.com/other/repo/issues/99"}]\n' >"$DEPENDENCIES"
out="$(frontier)"
assert_contains "$out" "$(printf '#1\tNative dependent')" 'completed native blocker permits pickup'
printf '[{"number":99,"title":"Native blocker","state":"closed","state_reason":"not_planned","html_url":"https://github.com/other/repo/issues/99"}]\n' >"$DEPENDENCIES"
out="$(frontier)"
section="$(sed -n '/^needs-rescoping:$/,/^unknown-blockers:$/p' <<<"$out")"
assert_contains "$section" 'https://github.com/other/repo/issues/99' 'abandoned native blocker linked for rescoping'

export API_FAIL=yes
status=0
out="$(frontier 2>"$work/error")" || status=$?
assert_eq 1 "$status" 'dependency API failure refuses frontier'
assert_eq '' "$out" 'dependency API failure prints no actionable sections'
assert_contains "$(cat "$work/error")" '#1' 'dependency API diagnostic identifies ticket'
unset API_FAIL

# Paginated gh output is a stream of arrays; a blocker on page two counts.
printf '[]\n[{"number":99,"title":"Native blocker","state":"open","html_url":"https://github.com/other/repo/issues/99"}]\n' >"$DEPENDENCIES"
out="$(frontier)"
assert_not_contains "$out" "$(printf '#1\tNative dependent')" 'open blocker on later page prevents pickup'

# A failed later page must not use the successful page's partial response.
export API_PARTIAL_FAIL=yes
status=0
out="$(frontier 2>/dev/null)" || status=$?
assert_eq 1 "$status" 'later API page failure refuses frontier'
assert_eq '' "$out" 'partial dependency read produces no frontier'
unset API_PARTIAL_FAIL

# Body edges remain effective even when native dependencies are all completed.
printf '[{"number":99,"title":"Native blocker","state":"closed","state_reason":"completed","html_url":"https://github.com/other/repo/issues/99"}]\n' >"$DEPENDENCIES"
jq '.[0].body = "## Blocked by\n\n- #2" |
  . + [{number:2,title:"Body blocker",state:"OPEN",stateReason:null,
    labels:[],assignees:[],body:""}]' "$ISSUES" >"$work/next.json"
mv "$work/next.json" "$ISSUES"
out="$(frontier)"
assert_not_contains "$out" "$(printf '#1\tNative dependent')" 'body blocker still prevents pickup'

# A native blocker wins even when the body blocker is completed. The native
# issue also shares its number with a completed local issue: URLs keep them
# distinct instead of accidentally satisfying the external blocker.
jq '.[1].state = "CLOSED" | .[1].stateReason = "COMPLETED"' "$ISSUES" >"$work/next.json"
mv "$work/next.json" "$ISSUES"
printf '[{"number":2,"title":"Native blocker","state":"open","html_url":"https://github.com/other/repo/issues/2"}]\n' >"$DEPENDENCIES"
out="$(frontier)"
assert_not_contains "$out" "$(printf '#1\tNative dependent')" 'native open blocker wins over completed local issue with same number'

# Skip closed issues, specs, backlog and tickets without the readiness label.
jq '.[0].labels += [{name:"backlog"}] |
  . + [(.[0] | .number=3 | .labels=[{name:"spec"},{name:"ready-for-agent"}]),
        (.[0] | .number=4 | .state="CLOSED" | .stateReason="COMPLETED")]' \
  "$ISSUES" >"$work/next.json"
mv "$work/next.json" "$ISSUES"
: >"$CALLS"
out="$(frontier)"
assert_not_contains "$(cat "$CALLS")" 'dependencies/blocked_by' 'no native reads for ineligible issues'
# Snapshot and completion queries also need no native reads.
(cd "$work/project" && bash "$TRACKER" snapshot >/dev/null)
(cd "$work/project" && bash "$TRACKER" specs >/dev/null)
assert_not_contains "$(cat "$CALLS")" 'dependencies/blocked_by' 'snapshot and specs stay independent of dependency API'

jq '.[0].labels = [{name:"ready-for-agent"}]' "$ISSUES" >"$work/next.json"
mv "$work/next.json" "$ISSUES"
printf '{}\n' >"$DEPENDENCIES"
assert_exit 1 'malformed dependency response refuses frontier' frontier
: >"$DEPENDENCIES"
assert_exit 1 'empty dependency response refuses frontier' frontier
printf '[{"number":99,"title":"Native blocker","state":"closed","state_reason":null,"html_url":"https://github.com/other/repo/issues/99"}]\n' >"$DEPENDENCIES"
assert_exit 1 'unknown closed reason refuses frontier' frontier

# Human-ready tickets are pickable too, so their native blockers are read.
section() { # <name> <frontier-output> -> that section's lines
  awk -v h="$1:" '$0 == h {on=1; next} /^[a-z-]+:$/ {on=0} on' <<<"$2"
}
jq -n '[{number:5,title:"Human dependent",state:"OPEN",stateReason:null,
  labels:[{name:"ready-for-human"}],assignees:[],body:""}]' >"$ISSUES"
printf '[{"number":99,"title":"Native blocker","state":"open","html_url":"https://github.com/other/repo/issues/99"}]\n' >"$DEPENDENCIES"
: >"$CALLS"
out="$(frontier)"
assert_contains "$(cat "$CALLS")" 'issues/5/dependencies/blocked_by' 'reads native blockers for human-ready tickets'
assert_not_contains "$(section human-ready "$out")" '#5' 'native open blocker keeps a human-ready ticket off the list'

# A blocked high-severity bug waits with its native blocker linked.
jq -n '[{number:6,title:"Blocked bug",state:"OPEN",stateReason:null,
  labels:[{name:"ready-for-agent"},{name:"bug"},{name:"priority:high"}],assignees:[],body:""}]' >"$ISSUES"
out="$(frontier)"
assert_contains "$(section high-severity-bugs-waiting "$out")" \
  "$(printf '#6\tBlocked bug\t[99: Native blocker](https://github.com/other/repo/issues/99)')" \
  'blocked high-severity bug waits with its native blocker linked'

# Queue diagnostics must use the effective blockers too, not body edges alone.
export QUEUE="$work/queue.md"
printf '## Ordered bugs\n\n## Waiting\n\n- [Blocked bug](https://github.com/o/r/issues/6)\n' >"$QUEUE"
printf 'ADDW_MAIN_BRANCH=master\nADDW_HIGH_SEVERITY_BUG_QUEUE=100\n' >"$work/project/docs/addw.env"
out="$(frontier)"
assert_not_contains "$(section label-corrections "$out")" 'missing from ordered bug queue' \
  'native-blocked bug in Waiting needs no ordered entry'

pickup() { (cd "$work/project" && bash "$TRACKER" eligible "$@"); }
status=0
out="$(pickup 6)" || status=$?
assert_eq 1 "$status" 'explicit pickup refuses native-only open blocker'
assert_contains "$out" 'https://github.com/other/repo/issues/99' 'explicit pickup links native open blocker'

# The explicit read enriches only the named issue, once, even with more candidates.
jq '. + [(.[0] | .number=7 | .title="Other candidate")]' "$ISSUES" >"$work/next.json"
mv "$work/next.json" "$ISSUES"
printf '[{"number":99,"title":"Native blocker","state":"closed","state_reason":"completed","html_url":"https://github.com/other/repo/issues/99"}]\n' >"$DEPENDENCIES"
printf '## Ordered bugs\n\n1. [Bug](https://github.com/o/r/issues/6)\n' >"$QUEUE"
: >"$CALLS"
out="$(pickup 6)"
assert_eq eligible "$out" 'explicit pickup accepts completed native blocker'
assert_eq 1 "$(grep -c 'api --paginate' "$CALLS")" 'explicit pickup fetches dependencies exactly once'
assert_not_contains "$(cat "$CALLS")" 'issues/7/dependencies' 'explicit pickup does not enrich unrelated tickets'
assert_not_contains "$(cat "$CALLS")" 'graphql' 'explicit pickup needs no delivery enrichment'
export API_FAIL=yes
status=0
out="$(pickup 6 2>"$work/error")" || status=$?
assert_eq 1 "$status" 'explicit pickup refuses failed dependency lookup'
assert_eq '' "$out" 'failed explicit read never prints eligible'
unset API_FAIL
printf '{}\n' >"$DEPENDENCIES"
assert_exit 1 'explicit pickup refuses malformed dependencies' pickup 6

printf 'tracker-native-dependencies: all contract assertions passed\n' 
