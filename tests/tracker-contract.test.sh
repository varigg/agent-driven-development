#!/usr/bin/env bash
# Contract: skills/lib/tracker/tracker.sh contract — the effective-contract
# read (#251, spec #243).
#
# `contract <n>` prints a ticket's body plus its live, blessed amendments, the
# amendments a later body edit retired, and its unmarked comments, then the
# same block for the parent spec the body names. The gh stub answers the body
# read, the lastEditedAt GraphQL read, and the paginated REST comments read
# from per-issue fixture files, running the caller's own --jq filter over
# each comment page so the trusted-author filter and pagination are exercised
# rather than bypassed.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
TRACKER="$REPO/skills/lib/tracker/tracker.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin" "$work/stub"
cat > "$work/bin/gh" <<'SH'
#!/usr/bin/env bash
# Fixtures in $STUB: body-<n>.md, edited-<n> (absent = never edited), and
# comments-<n>-p<k>.json pages. Without --paginate only page 1 is served.
args="$*"
filter="" number="" paginate=0 path=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --jq) filter=$2; shift ;;
    --paginate) paginate=1 ;;
    -F|-f) case "$2" in number=*) number=${2#number=} ;; esac; shift ;;
    repos/*/comments) path=$1 ;;
  esac
  shift
done
case "$args" in
  "issue view "*"--json body"*)
    n=${args#issue view }; n=${n%% *}
    cat "$STUB/body-$n.md" ;;
  "api graphql"*)
    if [ -f "$STUB/edited-$number" ]; then edited="\"$(cat "$STUB/edited-$number")\""; else edited=null; fi
    printf '{"data":{"repository":{"issue":{"lastEditedAt":%s}}}}' "$edited" \
      | if [ -n "$filter" ]; then jq -r "$filter"; else cat; fi ;;
  "api repos/"*)
    [ -z "${STUB_FAIL_COMMENTS:-}" ] || { echo "gh stub: comments read failed" >&2; exit 1; }
    n=${path%/comments}; n=${n##*/}
    for page in "$STUB/comments-$n-p"*.json; do
      [ -e "$page" ] || continue
      jq -r "$filter" "$page"
      [ "$paginate" -eq 1 ] || break
    done ;;
  *) echo "gh stub: unexpected call: $args" >&2; exit 97 ;;
esac
SH
chmod +x "$work/bin/gh"
PATH="$work/bin:$PATH"
export PATH STUB="$work/stub"

# comment <id> <created-at> <login> <association> <type> <body>: one JSON object.
comment() {
  jq -n --argjson id "$1" --arg c "$2" --arg l "$3" --arg a "$4" --arg t "$5" --arg b "$6" \
    '{id:$id, created_at:$c, author_association:$a, user:{login:$l, type:$t}, body:$b}'
}
# page <issue> <k> <comment-json>...: write one REST page.
page() {
  local n=$1 k=$2
  shift 2
  if [ "$#" -eq 0 ]; then echo '[]'; else printf '%s\n' "$@" | jq -s .; fi \
    > "$STUB/comments-$n-p$k.json"
}
reset() { rm -f "$STUB"/*; }

# --- full schema: a ticket with a parent spec, empty sections included ---
reset
printf '## Parent\n\n- #3\n\n## What to build\n\nThe ticket body.\n' > "$STUB/body-7.md"
printf 'The spec body.\n' > "$STUB/body-3.md"
page 7 1 "$(comment 101 2026-01-02T00:00:00Z alice OWNER User \
  "$(printf 'Amends-contract: use the v2 endpoint\nDetails here.')")"
page 3 1
expected="$(cat <<'EOF'
== TICKET #7 ==
## Parent

- #3

## What to build

The ticket body.
== AMENDMENTS #7 ==
-- 101 2026-01-02T00:00:00Z alice --
Amends-contract: use the v2 endpoint
Details here.
== PRESUMED FOLDED #7 ==
(none)
== UNMARKED #7 ==
(none)
== PARENT #3 ==
The spec body.
== AMENDMENTS #3 ==
(none)
== PRESUMED FOLDED #3 ==
(none)
== UNMARKED #3 ==
(none)
EOF
)"
assert_eq "$expected" "$(bash "$TRACKER" contract 7)" \
  "contract: prints the ticket block, then the parent block, in schema order"

# --- standalone ticket: no parent block ---
reset
printf 'A standalone ticket.\n' > "$STUB/body-8.md"
page 8 1
out="$(bash "$TRACKER" contract 8)"
assert_contains "$out" "== UNMARKED #8 ==" "contract: standalone ticket prints its own block"
assert_not_contains "$out" "== PARENT" "contract: standalone ticket prints no parent block"

# --- trust: who may amend, and an untrusted marker is in no list ---
reset
printf 'Body.\n' > "$STUB/body-9.md"
page 9 1 \
  "$(comment 1 2026-01-01T00:00:01Z owner-u OWNER User 'Amends-contract: from owner')" \
  "$(comment 2 2026-01-01T00:00:02Z member-u MEMBER User 'Amends-contract: from member')" \
  "$(comment 3 2026-01-01T00:00:03Z collab-u COLLABORATOR User 'Amends-contract: from collaborator')" \
  "$(comment 4 2026-01-01T00:00:04Z ci-bot MEMBER Bot 'Amends-contract: from a bot')" \
  "$(comment 5 2026-01-01T00:00:05Z stranger CONTRIBUTOR User 'Amends-contract: from a stranger')" \
  "$(comment 6 2026-01-01T00:00:06Z drive-by NONE User 'Amends-contract: from nobody')" \
  "$(comment 7 2026-01-01T00:00:07Z ci-bot MEMBER Bot 'A bot chatting.')" \
  "$(comment 8 2026-01-01T00:00:08Z drive-by NONE User 'A stranger chatting.')"
out="$(bash "$TRACKER" contract 9)"
for who in owner member collaborator; do
  assert_contains "$out" "Amends-contract: from $who" "contract: $who amendment counts"
done
for who in "a bot" "a stranger" "nobody"; do
  assert_not_contains "$out" "Amends-contract: from $who" \
    "contract: an amendment from $who appears in no list"
done
assert_not_contains "$out" "A bot chatting." "contract: a bot's comment is not unmarked"
assert_not_contains "$out" "A stranger chatting." "contract: a stranger's comment is not unmarked"

# --- ordering: creation time, id tie-break, an edit never moves a comment ---
reset
printf 'Body.\n' > "$STUB/body-10.md"
# Served out of order; 31 and 30 share a creation time; 20 was edited later
# (updated_at is newest) but keeps its creation-time position.
page 10 1 \
  "$(comment 31 2026-01-01T00:00:03Z a OWNER User 'Amends-contract: third')" \
  "$(comment 20 2026-01-01T00:00:01Z a OWNER User 'Amends-contract: first' | jq '.updated_at="2026-06-01T00:00:00Z"')" \
  "$(comment 30 2026-01-01T00:00:03Z a OWNER User 'Amends-contract: second')"
out="$(bash "$TRACKER" contract 10 | command grep '^-- ')"
assert_eq "$(printf -- '-- 20 2026-01-01T00:00:01Z a --\n-- 30 2026-01-01T00:00:03Z a --\n-- 31 2026-01-01T00:00:03Z a --')" \
  "$out" "contract: creation-time order, id tie-break, edit keeps position"

# --- retirement: amendments before the body's last edit are presumed folded ---
reset
printf 'Body, edited.\n' > "$STUB/body-11.md"
printf '2026-03-01T00:00:00Z' > "$STUB/edited-11"
page 11 1 \
  "$(comment 40 2026-02-01T00:00:00Z a OWNER User 'Amends-contract: folded in')" \
  "$(comment 41 2026-04-01T00:00:00Z a OWNER User 'Amends-contract: still live')"
out="$(bash "$TRACKER" contract 11)"
folded="$(printf '%s\n' "$out" | sed -n '/^== PRESUMED FOLDED #11 ==$/,/^== UNMARKED/p')"
live="$(printf '%s\n' "$out" | sed -n '/^== AMENDMENTS #11 ==$/,/^== PRESUMED/p')"
assert_contains "$folded" "folded in" "contract: an amendment older than the body edit is presumed folded"
assert_not_contains "$live" "folded in" "contract: a presumed-folded amendment is not live"
assert_contains "$live" "still live" "contract: an amendment after the body edit stays live"
assert_not_contains "$folded" "still live" "contract: a live amendment is not presumed folded"

# --- unmarked: trusted chatter only, never the shipped skills' grammars ---
reset
printf 'Body.\n' > "$STUB/body-12.md"
page 12 1 \
  "$(comment 50 2026-01-01T00:00:01Z a OWNER User 'Please also handle the empty case.')" \
  "$(comment 51 2026-01-01T00:00:02Z a OWNER User "$(printf 'Codex code review: APPROVED after 1 round(s).\nApproved-body: sha256:0123456789ab')")" \
  "$(comment 52 2026-01-01T00:00:03Z a OWNER User 'Codex spec review: APPROVED after 2 round(s).')" \
  "$(comment 53 2026-01-01T00:00:04Z a OWNER User "$(printf 'Re-approved by hand.\nApproved-body: sha256:0123456789ab')")"
out="$(bash "$TRACKER" contract 12)"
unmarked="$(printf '%s\n' "$out" | sed -n '/^== UNMARKED #12 ==$/,$p')"
assert_contains "$unmarked" "-- 50 " "contract: trusted chatter is unmarked"
for id in 51 52 53; do
  assert_not_contains "$out" "-- $id " "contract: comment $id carries a skill grammar and is not listed"
done

# --- pagination: every comment page is read ---
reset
printf 'Body.\n' > "$STUB/body-13.md"
page 13 1 "$(comment 60 2026-01-01T00:00:01Z a OWNER User 'Amends-contract: on page one')"
page 13 2 "$(comment 61 2026-01-01T00:00:02Z a OWNER User 'Amends-contract: on page two')"
out="$(bash "$TRACKER" contract 13)"
assert_contains "$out" "on page one" "contract: the first comment page is read"
assert_contains "$out" "on page two" "contract: later comment pages are read"

# --- a failed comments read fails loudly, never renders an empty contract ---
reset
printf 'Body.\n' > "$STUB/body-14.md"
assert_exit 1 "contract: a failed comments read exits non-zero" \
  env STUB_FAIL_COMMENTS=1 bash "$TRACKER" contract 14

# --- CLI seam hygiene ---
assert_exit 2 "contract: missing issue number refuses loudly" bash "$TRACKER" contract
assert_exit 2 "contract: non-numeric issue refuses loudly" bash "$TRACKER" contract abc

echo "tracker-contract: all assertions passed"
