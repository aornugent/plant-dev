#!/usr/bin/env bash
# Domain-leak gate for OUTBOUND Oracle consultation docs.
# The consultations must be reconstructable as pure math yet un-guessable as to
# application (oracle-consultation-guide.md §3). This catches LEXICAL leaks; it
# cannot catch conceptual ones (a recognizable combination of neutral terms) —
# a human read is still required for those. Accumulated from every leak found so
# far (shades, co-limitation, drainage, census, physiology, …).
#
# Usage: scripts/domain-leak-scan.sh [file ...]   (defaults to the outbound set)
set -u
docs=("$@")
if [ ${#docs[@]} -eq 0 ]; then
  docs=(docs/oracle-ad-design-consultation.md
        docs/oracle-followup-1-structure-hunt.md
        docs/oracle-followup-2-targeted-probes.md
        docs/oracle-consultation-tf24-coupled.md
        docs/oracle-consultation-soil-subsystem.md)
fi
# Word-boundaried where the term is a common substring (rain⊂constraint,
# root⊂root-find, net⊂network, layer⊂AD-layer, stand⊂understand, leaf, age, cost).
# NB: 'patch' and 'root' omitted (homonyms: a software patch, a root of an equation); watch conceptually.
pat='plant|tree|cohort|canopy|crown|\bleaf\b|light|shad|photosynth|stomat|soil|water|moist|\brain|transpir|hydraul|collar|xylem|ecolog|biolog|physiolog|organism|species|\btrait\b|biomass|mortal|demograph|offspring|fecund|forest|dbh|seedling|basal|extinction|census|\bstand\b|vulnerab|acclim|assimil|resident|\bmutant\b|invasion|\bselection\b|regnans|nutrient|\bcarbon\b|nitrogen|drought|evapo|weibull|conductiv|reservoir|turgor|osmotic|clapp|hornberger|sperry|anderegg|drainage|infiltrat|runoff|\bstem\b|tissue'
rc=0
for f in "${docs[@]}"; do
  [ -f "$f" ] || { echo "MISSING: $f"; rc=1; continue; }
  hits=$(grep -niE "$pat" "$f" | grep -viE 'root-find|constrain' || true)
  if [ -n "$hits" ]; then echo "LEAK in $f:"; echo "$hits"; rc=1; else echo "CLEAN: $f"; fi
done
exit $rc
