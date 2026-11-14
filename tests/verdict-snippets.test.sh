#!/usr/bin/env bash
# Contract: the verdict-comment snippets the two review loops run (#297) —
# codex-spec-review's verdict step and addw-implement's code-review step.
# Each snippet is lifted from its SKILL.md, its placeholders filled, and run
# against a stub tracker that records what would be posted. Only an APPROVED
# verdict may post an Approved-body marker; a refused APPROVED (no hash) must
# post nothing at all.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
PARSE="$REPO/skills/lib/tracker/parse.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The fenced block in <skill.md> that calls verdict-comment, fences dropped.
snippet() {
  awk '
    /^[[:space:]]*```/ {
      if (inside) { if (buf ~ /verdict-comment/) { printf "%s", buf; exit } inside = 0; buf = "" }
      else inside = 1
      next
    }
    inside { buf = buf $0 "\n" }
  ' "$1"
}

# run_snippet <skill> <tag> <hash-for-implement> : prints what was posted,
# or NOTHING-POSTED, so an empty comment is told apart from no comment.
run_snippet() {
  local skill=$1 tag=$2 hash=$3 root="$work/install-$1-$2"
  rm -rf "$root"
  mkdir -p "$root/.claude/skills/lib/tracker" "$root/.claude/skills/codex-spec-review/state"
  cp "$PARSE" "$root/.claude/skills/lib/tracker/parse.sh"
  cat > "$root/.claude/skills/lib/tracker/tracker.sh" <<'SH'
#!/usr/bin/env bash
[ "$1" = comment ] || { echo "tracker stub: unexpected $*" >&2; exit 97; }
cp "$3" "$POSTED"
SH
  # An empty <hash> also withholds the spec state buffer, so spec review's own
  # body-hash capture comes back empty too.
  [ -z "$hash" ] || printf 'The spec body.\n' > "$root/.claude/skills/codex-spec-review/state/issue-7.md"
  local code
  code="$(snippet "$REPO/skills/$skill/SKILL.md" \
    | sed "s/<TAG>/$tag/g; s/<R>/3/g; s/<N>/7/g; s/<issue-number>/7/g")"
  [ -n "$code" ] || fail "$skill: no verdict-comment snippet found"
  ( cd "$root" && export POSTED="$root/posted" hash && bash -c "$code" ) >/dev/null 2>&1 || true
  if [ -f "$root/posted" ]; then cat "$root/posted"; else echo NOTHING-POSTED; fi
}

spec_hash="$(printf 'The spec body.\n' | bash "$PARSE" body-hash)"
for skill in codex-spec-review addw-implement; do
  if [ "$skill" = codex-spec-review ]; then want_hash=$spec_hash; kind=spec; else want_hash=sha256:0123456789ab; kind=code; fi
  for tag in APPROVED REQUEST_CHANGES NEEDS_REWORK; do
    posted="$(run_snippet "$skill" "$tag" sha256:0123456789ab)"
    assert_eq "Codex $kind review: $tag after 3 round(s)." "$(printf '%s\n' "$posted" | head -n 1)" \
      "$skill $tag: the posted headline names the final verdict"
    if [ "$tag" = APPROVED ]; then want=$want_hash; else want=""; fi
    assert_eq "$want" "$(printf '%s\n' "$posted" | bash "$PARSE" approval-hash)" \
      "$skill $tag: Approved-body posted iff APPROVED"
  done
done

for skill in codex-spec-review addw-implement; do
  assert_eq NOTHING-POSTED "$(run_snippet "$skill" APPROVED "")" \
    "$skill: an APPROVED verdict with no captured hash posts nothing"
done

echo "verdict-snippets: all assertions passed"
