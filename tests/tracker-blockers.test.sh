#!/usr/bin/env bash
# Effective blockers are shared by both frontier roles and explicit pickup.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh
REPO="$(cd .. && pwd)"
RESOLVE="$REPO/skills/lib/tracker/resolve.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
section() {
  awk -v h="$1:" '$0 == h {on=1; next} /^[a-z-]+:$/ {on=0} on' <<<"$2"
}
fixture() { # role source state reason
  jq -n --arg role "$1" --arg source "$2" --arg state "$3" --arg reason "$4" '
    {number:2,title:"Blocker",url:"https://github.com/o/r/issues/2",
      state:$state,stateReason:$reason,labels:[],assignees:[],body:""} as $blocker |
    [{number:1,title:"Dependent",url:"https://github.com/o/r/issues/1",state:"OPEN",
      labels:[{name:$role},{name:"bug"},{name:"priority:high"}],assignees:[],
      body:(if $source == "native" then "" else "## Blocked by\n\n- #2\n- #2" end),
      nativeBlockers:(if $source == "body" then [] else
        [{number:2,title:"Blocker",html_url:$blocker.url,state:($state|ascii_downcase),
          state_reason:($reason|ascii_downcase)}] | . + . end)},$blocker]' >"$work/issues.json"
}
for role in ready-for-agent ready-for-human; do
  for source in body native mixed; do
    fixture "$role" "$source" OPEN ''
    out="$(ADDW_HIGH_SEVERITY_BUG_QUEUE=100 bash "$RESOLVE" frontier "$work/issues.json")"
    for view in frontier human-ready; do
      assert_not_contains "$(section "$view" "$out")" '#1' "$role $source: no ready verdict"
    done
    waiting="$(section high-severity-bugs-waiting "$out")"
    assert_eq "$(printf '#1\tDependent\t[2: Blocker](https://github.com/o/r/issues/2)')" "$waiting" \
      "$role $source: Waiting links each effective blocker once"
    assert_not_contains "$(section label-corrections "$out")" 'missing from ordered bug queue' \
      "$role $source: blocked bug needs no ordered-queue entry"
    assert_exit 1 "$role $source: explicit pickup refuses open blocker" \
      bash "$RESOLVE" eligible 1 "$work/issues.json"

    fixture "$role" "$source" CLOSED COMPLETED
    out="$(bash "$RESOLVE" frontier "$work/issues.json")"
    if [ "$role" = ready-for-agent ]; then view=frontier; else view=human-ready; fi
    assert_contains "$(section "$view" "$out")" '#1' "$role $source: completed blocker unlocks"
    if [ "$role" = ready-for-agent ]; then
      assert_exit 0 "$source: explicit pickup accepts completed blockers" \
        bash "$RESOLVE" eligible 1 "$work/issues.json"
    else
      assert_exit 1 "$source: human ticket cannot be implemented by agent" \
        bash "$RESOLVE" eligible 1 "$work/issues.json"
    fi

    fixture "$role" "$source" CLOSED NOT_PLANNED
    out="$(bash "$RESOLVE" frontier "$work/issues.json")"
    assert_contains "$(section needs-rescoping "$out")" '#1' "$role $source: abandoned blocker needs rescoping"
    assert_exit 1 "$role $source: explicit pickup refuses abandoned blocker" \
      bash "$RESOLVE" eligible 1 "$work/issues.json"
  done
done

fixture ready-for-agent body OPEN ''
jq 'map(select(.number != 2))' "$work/issues.json" >"$work/unknown.json"
out="$(bash "$RESOLVE" frontier "$work/unknown.json")"
assert_contains "$(section unknown-blockers "$out")" 'blocker #2 not in snapshot' 'unknown body blocker diagnosed'
assert_exit 1 'explicit pickup refuses unknown body blocker' bash "$RESOLVE" eligible 1 "$work/unknown.json"
fixture ready-for-agent native OPEN ''
jq '.[0].nativeBlockers[0].state = "unknown" | .[0].nativeBlockers |= .[:1]' \
  "$work/issues.json" >"$work/unknown.json"
out="$(bash "$RESOLVE" frontier "$work/unknown.json")"
assert_contains "$(section unknown-blockers "$out")" 'https://github.com/o/r/issues/2' 'unknown native state diagnosed'
assert_exit 1 'explicit pickup refuses unknown native blocker' bash "$RESOLVE" eligible 1 "$work/unknown.json"

# A native record supplies the state of a duplicate body edge outside the snapshot.
fixture ready-for-agent mixed CLOSED COMPLETED
jq 'map(select(.number != 2))' "$work/issues.json" >"$work/outside.json"
assert_exit 0 'known native state resolves duplicate body edge outside snapshot' \
  bash "$RESOLVE" eligible 1 "$work/outside.json"

# Eligibility retains the readiness, priority, membership and excluded-label rules.
fixture ready-for-agent native CLOSED COMPLETED
for label in ready-for-human spec backlog wayfinder:task; do
  jq --arg label "$label" '.[0].labels += [{name:$label}]' "$work/issues.json" >"$work/invalid.json"
  assert_exit 1 "explicit pickup excludes $label" bash "$RESOLVE" eligible 1 "$work/invalid.json"
done
jq '.[0].labels |= map(select(.name != "priority:high"))' "$work/issues.json" >"$work/invalid.json"
assert_exit 1 'explicit pickup requires priority' bash "$RESOLVE" eligible 1 "$work/invalid.json"
jq '.[0].body = "## Parent\n\n- #2" | .[1].state="OPEN" | .[1].labels=[{name:"spec"}]' \
  "$work/issues.json" >"$work/invalid.json"
assert_exit 1 'explicit pickup requires configured membership' \
  env ADDW_SPEC_LABELS=2=spec:feature bash "$RESOLVE" eligible 1 "$work/invalid.json"

printf 'tracker-blockers: all contract assertions passed\n'
