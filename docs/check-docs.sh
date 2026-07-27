#!/usr/bin/env bash
# Enforces the mechanical rules in docs/DOC-DISCIPLINE.md. Run before ending a session.
#   ./docs/check-docs.sh
# Checks what a script can check: that links and citations point at things that exist,
# and that there is only one to-do list. It CANNOT check that a cited script still
# runs -- rule 4 is on you.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
fail=0
note() { printf '  %s\n' "$1"; fail=1; }

echo "1. relative links in docs/*.md resolve"
for f in docs/*.md; do
  grep -oE '\]\(\.?/?[A-Za-z0-9._/-]+\.(md|R|cpp|sh)\)' "$f" 2>/dev/null \
  | sed 's/^](//;s/)$//' | sort -u | while read -r t; do
      case "$t" in /*) p=".$t" ;; ./*) p="docs/${t#./}" ;; *) p="docs/$t" ;; esac
      [ -e "$p" ] || echo "  BROKEN $f -> $t"
    done
done | tee /tmp/cd-links.$$ ; [ -s /tmp/cd-links.$$ ] && fail=1 ; rm -f /tmp/cd-links.$$

echo "2. every docs/reference path cited in a doc exists"
grep -rhoE 'docs/reference/[A-Za-z0-9._-]+' docs/*.md | sort -u | while read -r t; do
  # citations often name a {cpp,R} pair via brace expansion; check the stem
  case "$t" in
    # a `{cpp,R}` pair citation; the brace is outside the match, so the stem ends in "."
    *.) for e in cpp R; do [ -e "$t$e" ] || echo "  MISSING $t$e"; done ;;
    *)  [ -e "$t" ] || echo "  MISSING $t" ;;
  esac
done | tee /tmp/cd-ref.$$ ; [ -s /tmp/cd-ref.$$ ] && fail=1 ; rm -f /tmp/cd-ref.$$

echo "3. every docs/reference/*.cpp has a .R driver"
for c in docs/reference/*.cpp; do
  [ -e "${c%.cpp}.R" ] || note "NO DRIVER for $c (rule 4: a citation must be runnable)"
done

echo "4. exactly one to-do list in HANDOFF.md"
n=$(grep -cE '^#+ (OPEN, in priority order|SIGNPOSTS|What to do next|NEXT STEPS, in order)' docs/HANDOFF.md)
if [ "$n" -ne 1 ]; then
  note "found $n to-do-list headings in HANDOFF.md, expected 1 (rule 2)"
  grep -nE '^#+ (OPEN, in priority order|SIGNPOSTS|What to do next|NEXT STEPS, in order)' docs/HANDOFF.md | sed 's/^/    /'
fi

echo "5. HANDOFF.md points at the discipline and the runbook"
grep -q 'DOC-DISCIPLINE.md' docs/HANDOFF.md || note "HANDOFF.md does not link DOC-DISCIPLINE.md"
grep -q 'REBUILD CONTEXT' docs/HANDOFF.md   || note "HANDOFF.md has lost its rebuild runbook"
grep -q 'DOC-DISCIPLINE.md' AGENTS.md       || note "AGENTS.md does not link DOC-DISCIPLINE.md"

echo "6. no unpushed or dirty state in any repo"
for r in . plant odelia; do
  d=$(git -C "$r" status --porcelain | wc -l)
  u=$(git -C "$r" log --oneline '@{u}..HEAD' 2>/dev/null | wc -l)
  [ "$d" -eq 0 ] || note "$r has $d dirty paths"
  [ "$u" -eq 0 ] || note "$r has $u unpushed commits"
done

if [ "$fail" -eq 0 ]; then echo; echo "DOCS IN SYNC"; else echo; echo "DOCS OUT OF SYNC -- fix before ending the session"; fi
exit "$fail"
