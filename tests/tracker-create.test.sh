#!/usr/bin/env bash
# Contract: skills/lib/tracker/tracker.sh create — the seam's issue-creation
# operation.
#
# Creation is the one tracker operation ADDW's happy path does not perform:
# to-spec publishes the spec issue and to-tickets publishes the tickets, and
# the seam otherwise only reads, annotates, assigns, and closes what those
# skills authored. It is in the seam anyway because ADDW has one creation path
# of its own — addw-maintain routing a substantive audit finding to a
# `backlog`-labeled issue — and the schema-4 backlog migration is a second.
#
# The layer's thin gh wrappers are dogfood-verified rather than unit-tested,
# but this one is tested: it shapes an outbound write to an external service
# from variadic arguments, which is the critical-path floor rather than
# passthrough. The stub records the argv it was called with, so the assertions
# are about the request shape and nothing reaches the network.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
TRACKER="$REPO/skills/lib/tracker/tracker.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The stub writes one NUL-free line per argument to $ARGV_LOG, so a label
# containing a space stays one argument in the assertions below.
mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'SH'
#!/usr/bin/env bash
: > "$ARGV_LOG"
for a in "$@"; do printf '%s\n' "$a" >> "$ARGV_LOG"; done
printf '%s\n' "${STUB_GH_STDOUT:-https://github.com/o/r/issues/99}"
SH
chmod +x "$work/bin/gh"
PATH="$work/bin:$PATH"
export PATH

printf 'A body from a file.\n' > "$work/body.md"

ARGV_LOG="$work/argv.txt"
export ARGV_LOG

# argv_has <arg> — true when the recorded argv contains exactly this argument.
argv_has() { grep -Fqx -- "$1" "$ARGV_LOG"; }

# argv_after <flag> — echoes the argument following the flag's first use.
argv_after() {
  awk -v f="$1" 'prev==f{print;exit}{prev=$0}' "$ARGV_LOG"
}

# --- title and body ---------------------------------------------------------

out="$(bash "$TRACKER" create "feat: a new thing" "$work/body.md")"

argv_has "issue" || fail "create: does not address the issue command"
argv_has "create" || fail "create: does not create"
assert_eq "feat: a new thing" "$(argv_after --title)" \
  "create: the title is passed as one argument, spaces and colon intact"
assert_eq "$work/body.md" "$(argv_after --body-file)" \
  "create: the body is passed as a file, never interpolated into the argv"

# The seam's callers need the new issue's identity, so whatever the CLI prints
# must reach stdout unswallowed.
assert_contains "$out" "https://github.com/o/r/issues/99" \
  "create: the created issue's URL reaches stdout"

# --- labels are variadic ----------------------------------------------------

# addw-maintain files one `backlog` label; the migration may want more. Each
# must arrive as its own --label rather than a single comma-joined string,
# which gh would read as one label name containing a comma.
bash "$TRACKER" create "chore: two labels" "$work/body.md" backlog needs-triage \
  >/dev/null
assert_eq 2 "$(grep -Fxc -- --label "$ARGV_LOG")" \
  "create: each label gets its own --label flag"
argv_has "backlog" || fail "create: the first label is passed"
argv_has "needs-triage" || fail "create: the second label is passed"

# No labels is the plain case and must not emit an empty --label.
bash "$TRACKER" create "chore: no labels" "$work/body.md" >/dev/null
assert_eq 0 "$(grep -Fxc -- --label "$ARGV_LOG" || true)" \
  "create: no labels means no --label flag at all"

# --- argument validation ----------------------------------------------------

# A body file that does not exist must stop the call, not create an issue with
# whatever gh makes of a missing path.
: > "$ARGV_LOG"
status=0
bash "$TRACKER" create "feat: missing body" "$work/nope.md" >/dev/null 2>&1 \
  || status=$?
[ "$status" -ne 0 ] || fail "create: a missing body file must not succeed"
assert_eq 0 "$(wc -c < "$ARGV_LOG")" \
  "create: a missing body file is caught before the tracker CLI is invoked"

assert_exit 2 "create: too few arguments is a usage error" \
  bash "$TRACKER" create "feat: no body"

echo "tracker-create: all contract assertions passed"
