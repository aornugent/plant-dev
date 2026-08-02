#!/bin/sh
# Mechanical style check over one branch's diff against develop. Catches what
# AGENTS.md forbids in comments and what the design forbids in plant source.
# Usage: style-sweep.sh <worktree> [<base>]
#
# It reports candidates, not verdicts: a hit in a pre-existing line that the diff
# merely moved is not a violation. Every hit still needs reading.

wt="$1"
base="${2:-origin/develop}"
cd "$wt" || exit 1

added() { git diff -U0 "$base"...HEAD -- 'inst/**' 'src/**' | grep '^+' | grep -v '^+++'; }

echo "=== files touched"
git diff --stat "$base"...HEAD

echo
echo "=== doc-section references, issue tags, process history"
added | grep -nE '§|\bRIF-|\bODELIA-|\bPLANT-|#[0-9]{3}|renamed from|successor to|formerly|used to be'

echo
echo "=== decorative nouns and borrowed mechanism words"
added | grep -niE '\b(contract|surface|oracle|harness|framework|pipeline|flush|frozen|mutant|live|stale|clean)\b'

echo
echo "=== banners and negative definitions"
added | grep -nE '^\+\s*//\s*-{4,}|^\+\s*//\s*={4,}|is not a|rather than a'

echo
echo "=== xad:: in plant, which no plant file may spell"
grep -rn 'xad::' inst src 2>/dev/null

echo
echo "=== deduced return types on lambdas (must declare the scalar return type)"
added | grep -nE '\[[^]]*\]\s*\([^)]*\)\s*\{' | grep -v '\->'

echo
echo "=== lambdas and helpers declared -> double in scalar-generic code, which passivates"
# The inverse of the check above, and the more dangerous one: an explicitly
# double-returning lambda reads as compliant and severs the derivative silently.
added | grep -nE '\->\s*double' 

echo
echo "=== comment runs longer than two lines"
git diff -U0 "$base"...HEAD -- 'inst/**' 'src/**' \
  | awk '/^\+.*\/\//{n++; if (n==3) print "  3+ consecutive added comment lines near: " $0; next} {n=0}'

echo
echo "=== baselines and generated files, which a task may not touch"
git diff --name-only "$base"...HEAD \
  | grep -E 'FF16_reference/|RcppR6\.(R|cpp)|RcppExports|NAMESPACE|^man/|RcppR6_pre|RcppR6_post' \
  || echo "  none"
