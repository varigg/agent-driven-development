#!/usr/bin/env bash
# Retire a document to the tracker: its bytes travel from the tree to a closed,
# labeled issue without passing through any agent's context. Why this is a
# script rather than an agent step, and what the archive is for: ../README.md.
#
# Usage: archive-doc.sh <path> <adr|proposal> <reason>   (run from the repo root)
#
# <path> is repo-relative and must be tracked and unmodified. <reason> is why
# the document stopped being true; it lands in the archive's provenance block.
# Prints the new issue number as soon as it exists, then a one-line summary.
# It prints no document content at any point — not the body, not the title.
#
# Exit 0 on success; 2 for usage errors; 1 for a refusal or a failure.
#
# The deletion is left staged, not committed: archival runs inside a ticket's
# PR, so the reviewer sees it alongside the change that made the document
# untrue.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRACKER="$here/../tracker/tracker.sh"

usage() {
  sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | sed -n '/^Usage:/,/^$/p' >&2
  exit 2
}

say() { printf 'archive-doc.sh: %s\n' "$1"; }
err() { printf 'archive-doc.sh: %s\n' "$1" >&2; }

# An ADR Origin line cites what a decision came from and is expected to outlive
# it, so it is never a live pointer. The maintenance sweep grants the same
# exemption to its dead-link check; without it, provenance would block a
# deletion forever. Matched against `git grep -n` output: file:line:content.
ORIGIN_LINE='^[^:]*:[0-9]+:[[:space:]]*[-*][[:space:]]*\*\*Origin\*\*:'

[ "$#" -eq 3 ] || usage
path=$1
kind=$2
reason=$3

case "$kind" in
  adr | proposal) ;;
  *)
    err "unknown kind: $kind (expected adr or proposal)"
    exit 2
    ;;
esac

[ -n "$reason" ] || { err "a reason is required — it is what the archive records"; exit 2; }

case "$path" in
  /*)
    err "path must be repo-relative, got: $path"
    exit 2
    ;;
esac
[ -f "$path" ] || { err "not a file: $path"; exit 2; }

# An untracked file has no committed version, so the recovery command below
# would have nothing to reconstruct from.
if ! git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
  err "not tracked by git: $path"
  exit 2
fi

# The H1 is the issue title. For ADRs the template already guarantees this
# yields `ADR NNNN: <title>`; no convention is imposed on other kinds, because
# no consumer parses them. Inventing a title from a document without one would
# put its first line somewhere no reader expects it.
title="$(awk '/^# /{ sub(/^# */, ""); print; exit }' "$path")"
if [ -z "$title" ]; then
  err "no H1 heading in $path — there is no title to archive it under"
  exit 2
fi

# --- surviving references refuse --------------------------------------------
#
# Two surfaces, two verdicts. A deletion that strands a pointer has moved the
# defect rather than fixed it, so a live reference refuses; a closed issue's
# mention is history, and history must not deadlock the tool permanently.

tree_hits="$(git grep -n -F -e "$path" -- . ":(exclude)$path" 2>/dev/null | grep -Ev "$ORIGIN_LINE" || true)"
if [ -n "$tree_hits" ]; then
  err "the tree still points at $path:"
  printf '%s\n' "$tree_hits" >&2
  err "re-aim these first — a deletion that strands a pointer moves the defect"
  exit 1
fi

# The snapshot refuses when its fetch reached the limit, and that refusal is
# inherited here rather than re-implemented: a reference check over a snapshot
# that cannot vouch for itself might miss an older open reference. Archived
# issues are already dropped by the seam, so a closed hit below is a
# non-archive one and every hit is worth reporting.
snapshot="$(bash "$TRACKER" snapshot)"

hits_in_state() { # OPEN | CLOSED
  printf '%s' "$snapshot" | jq -r --arg p "$path" --arg s "$1" \
    '.[] | select(.state == $s) | select((.body // "") | contains($p)) | .number'
}

as_issue_list() { sed 's/^/#/' | tr '\n' ' '; }

open_hits="$(hits_in_state OPEN)"
if [ -n "$open_hits" ]; then
  err "open issues still point at $path: $(printf '%s\n' "$open_hits" | as_issue_list)"
  err "revise them first — live text nobody has revised must not outlive its target"
  exit 1
fi

closed_hits="$(hits_in_state CLOSED)"
if [ -n "$closed_hits" ]; then
  say "note: closed issues mention this path and are left alone: $(printf '%s\n' "$closed_hits" | as_issue_list)"
fi

# --- the target must match what the recovery command reconstructs ------------
#
# Refusing is cheaper than picking a winner: archiving working-tree text no
# commit contains would make the recovery command a lie, and archiving the
# committed version instead would silently discard edits the operator holds.

if ! git diff --quiet -- "$path" || ! git diff --cached --quiet -- "$path"; then
  err "$path has uncommitted changes; commit or discard them first"
  exit 1
fi

# The last commit in which the file existed, captured before the deletion — not
# the deleting commit, which cannot be named yet, since the issue number must
# exist before the deletion commit can cite it.
sha="$(git log -1 --format=%H -- "$path")"
if [ -z "$sha" ]; then
  err "no commit contains $path"
  exit 1
fi

# --- the archive --------------------------------------------------------------

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
body="$tmp/body.md"
{
  printf '**Archived from**: `%s`\n' "$path"
  printf '**Commit**: %s\n' "$sha"
  printf '**Reason**: %s\n' "$reason"
  # The mkdir is not decoration: `git rm` prunes a parent directory left empty,
  # and retiring a directory's last document is the ordinary case here. Without
  # it the command fails on the redirect, which is a lie about retrievability.
  printf '**Retrieve**: `mkdir -p %s && git show %s:%s > %s`\n' \
    "$(dirname "$path")" "$sha" "$path" "$path"
  printf '\n---\n\n'
  cat "$path"
} >"$body"

# Lazily, at first use: a project that never archives anything never grows a
# label for an artifact it does not have. Under lazy creation "label absent"
# and "nothing archived yet" are the same state, which is why doctor checks
# neither.
bash "$TRACKER" create-label archived >/dev/null
bash "$TRACKER" create-label "$kind" >/dev/null

# From here the steps are irreversible in order: the issue exists, then it is
# closed, then the file goes. Everything above leaves the tree untouched on
# failure; everything below reports what it left behind.
url="$(bash "$TRACKER" create "$title" "$body" archived "$kind")"
number="${url##*/}"
case "$number" in
  '' | *[!0-9]*)
    err "could not read an issue number from the tracker's reply: $url"
    exit 1
    ;;
esac
say "created issue #$number"

if ! bash "$TRACKER" close "$number" completed >/dev/null; then
  err "issue #$number exists but could not be closed; $path is untouched."
  err "finish by hand: close #$number as completed, then re-run this command."
  exit 1
fi

if ! git rm -q -- "$path"; then
  err "issue #$number is closed but $path could not be removed; remove it by hand."
  exit 1
fi

say "archived $path to #$number (closed as completed, deletion staged)"
