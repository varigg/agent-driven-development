#!/usr/bin/env bash
# Ticket signals: ordering respects body blockers; lifecycle writes preserve
# priority and membership invariants without requiring optional config.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh
REPO="$(cd .. && pwd)"
TRACKER="$REPO/skills/lib/tracker/tracker.sh"
RESOLVE="$REPO/skills/lib/tracker/resolve.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/docs" "$work/bin"
printf 'ADDW_SPEC_LABELS=\n' > "$work/docs/addw.env"
printf '## Parent\n\n- #100\n' > "$work/body"
cat > "$work/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$GH_LOG"
case "$*" in
  'issue view 100 --json state,labels'*) printf '%s\ttrue\n' "${PARENT_STATE:-OPEN}" ;;
  *'--json state,body,labels'*) cat "$ISSUE_JSON" ;;
  *'--json labels'*) [ -z "${FAIL_LABELS:-}" ] || exit 1; printf '%s\n' ready-for-human priority:low ;;
  'issue create '*|'issue edit '*) ;;
  *) echo "Unexpected gh call: $*" >&2; exit 97 ;;
esac
STUB
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH" GH_LOG="$work/log" ISSUE_JSON="$work/issue.json"
run() { (cd "$work" && bash "$TRACKER" "$@"); }
: > "$GH_LOG"
run create Ticket "$work/body" ready-for-agent
assert_contains "$(cat "$GH_LOG")" '--label priority:normal' 'create: default priority'
assert_not_contains "$(cat "$GH_LOG")" 'issue view' 'disabled membership needs no parent read'
printf "ADDW_SPEC_LABELS='100=spec:search'\n" > "$work/docs/addw.env"
: > "$GH_LOG"
run create Ticket "$work/body" ready-for-agent
assert_contains "$(cat "$GH_LOG")" '--label spec:search' 'create: mapped parent'
: > "$GH_LOG"
PARENT_STATE=CLOSED run create Ticket "$work/body" ready-for-agent
assert_not_contains "$(cat "$GH_LOG")" '--label spec:' 'closed parent has no active membership'
: > "$GH_LOG"
assert_exit 1 'create: conflicting priority refuses' run create Ticket "$work/body" ready-for-agent priority:low priority:high
assert_not_contains "$(cat "$GH_LOG")" 'issue create' 'invalid creation does not write'
printf '%s\n' '{"state":"OPEN","body":"## Parent\n\n- #100\n","labels":[{"name":"backlog"},{"name":"spec:old"}]}' > "$ISSUE_JSON"
run label 9 ready-for-agent
assert_contains "$(cat "$GH_LOG")" '--remove-label spec:old' 'promotion replaces stale membership'
assert_contains "$(cat "$GH_LOG")" '--remove-label backlog' 'promotion removes backlog'
assert_contains "$(cat "$GH_LOG")" '--add-label spec:search' 'promotion mirrors parent'
run label 9 priority:high
assert_contains "$(cat "$GH_LOG")" '--remove-label priority:low' 'priority replaces previous value'
for label in spec wayfinder:task; do
  jq -n --arg label "$label" '{state:"OPEN",body:"",labels:[{name:$label}]}' > "$ISSUE_JSON"
  : > "$GH_LOG"
  assert_exit 1 'promotion excludes specs and decisions' run label 9 ready-for-agent
  assert_not_contains "$(cat "$GH_LOG")" 'issue edit' 'excluded issue is not edited'
done
cat > "$work/issues.json" <<'JSON'
[
 {"number":100,"title":"Spec","state":"OPEN","labels":[{"name":"spec"}],"assignees":[],"body":""},
 {"number":1,"title":"High","state":"OPEN","labels":[{"name":"ready-for-agent"},{"name":"priority:high"}],"assignees":[],"body":""},
 {"number":2,"title":"High focus","state":"OPEN","labels":[{"name":"ready-for-agent"},{"name":"priority:high"}],"assignees":[],"body":"## Parent\n\n- #100\n"},
 {"number":3,"title":"Normal","state":"OPEN","labels":[{"name":"ready-for-agent"},{"name":"priority:normal"}],"assignees":[],"body":""},
 {"number":4,"title":"Normal focus","state":"OPEN","labels":[{"name":"ready-for-agent"},{"name":"priority:normal"}],"assignees":[],"body":"## Parent\n\n- #100\n"},
 {"number":5,"title":"Blocked bug","url":"https://example.org/5","state":"OPEN","labels":[{"name":"ready-for-agent"},{"name":"priority:high"},{"name":"bug"}],"assignees":[],"body":"## Blocked by\n\n- #6\n"},
 {"number":6,"title":"Human","url":"https://example.org/6","state":"OPEN","labels":[{"name":"ready-for-human"},{"name":"priority:normal"}],"assignees":[],"body":""},
 {"number":7,"title":"Bug","state":"OPEN","labels":[{"name":"ready-for-agent"},{"name":"priority:high"},{"name":"bug"}],"assignees":[],"body":""}
]
JSON
printf '## Ordered bugs\n\n1. [Bug](https://example.org/issues/7)\n' > "$work/queue"
out="$(ADDW_FOCUS_SPEC=100 bash "$RESOLVE" frontier "$work/issues.json" '' '' "$work/queue")"
agent="$(sed -n '/^frontier:$/,/^human-ready:$/p' <<< "$out")"
assert_eq '7,1,2,4,3' "$(cut -f2 <<< "$agent" | grep -o '^#[0-9]*' | tr -d '#' | paste -sd,)" 'queue leads high bugs; focus only affects normal'
assert_not_contains "$agent" '#5' 'body-blocked bug excluded'
assert_contains "$out" '[6: Human](https://example.org/6)' 'waiting links open blocker'
assert_contains "$out" "$(printf '#6\tHuman')" 'human readiness visible'
# A missing priority is diagnosed, without inventing a priority label.
jq '.[1].labels = [{name:"ready-for-agent"}]' "$work/issues.json" > "$work/missing.json"
out="$(bash "$RESOLVE" frontier "$work/missing.json")"
assert_contains "$out" "$(printf '#1\tpriority labels: 0')" 'missing priority diagnosed'
printf "ADDW_SPEC_LABELS='101=spec:other'\n" > "$work/docs/addw.env"
: > "$GH_LOG"
assert_exit 1 'unmapped open parent refuses' run create Ticket "$work/body" ready-for-agent
assert_not_contains "$(cat "$GH_LOG")" 'issue create' 'unmapped parent never creates'
# Configuration errors must stop ready creation before any outbound write.
printf 'export BAD=value\n' > "$work/docs/addw.env"
: > "$GH_LOG"
assert_exit 78 'malformed config fails closed' run create Ticket "$work/body" ready-for-agent
assert_not_contains "$(cat "$GH_LOG")" 'issue create' 'bad config never creates'
jq '.[1].labels += [{name:"wayfinder:research"}]' "$work/issues.json" > "$work/wayfinder.json"
out="$(bash "$RESOLVE" frontier "$work/wayfinder.json")"
assert_not_contains "$out" "$(printf '#1\tHigh')" 'all wayfinder labels excluded'
printf 'tracker-signals: all assertions passed\n' 
