#!/bin/bash
# The split finished in the forward step (prereg.txt, ninth extension). FINAL
# holds the final build; NOSEARCH the split on PLANT-101 without the search
# (odelia 6a6ce45); PROBE the final build with scan2_probe.patch. The registered
# run's odelia was d08db1a (final_scan.log), the re-test's 6335877 (final.log).
#   DEV=... SC=... FINAL=lib NOSEARCH=lib PROBE=lib OUTD=dir bash final.sh
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
one() {  # library, output path, program, split, LMA_REL, [log]
  [ -f "$2.rds" ] && return 0
  env PLANT_LIB="$1" FORWARD=1 ATOL=1e-4 NODES=108 TOL=1e-4 PROGRAM="$3" SPLIT="$4" \
    LMA_REL="$5" ${6:+ODELIA_SPLIT_LOG=$6 ODELIA_SPLIT_SCAN=1} OUT="$2.rds" \
    Rscript "$H/run_record.R" > "$2.log" 2>&1
}
mkdir -p "$OUTD"
PLAIN=$SC/runs/program_plain.rds
SPLIT=$SC/runs/program_split.rds
# The scans and the build without the search, three at a time.
one "$PROBE" "$OUTD/scan_0" "$SPLIT" 1 0 "$OUTD/scan_0.txt" &
one "$PROBE" "$OUTD/scan_-1e-3" "$SPLIT" 1 -1e-3 "$OUTD/scan_-1e-3.txt" &
one "$NOSEARCH" "$OUTD/nosearch_0" "$SPLIT" 1 0 &
wait
echo "=== scans done $(date +%T)"
# Alone, alternating: plain's replay and the split's, two each.
for i in 1 2; do
  one "$FINAL" "$OUTD/plain_$i" "$PLAIN" 0 0
  one "$FINAL" "$OUTD/split_$i" "$SPLIT" 1 0
done
echo "JOB DONE final $(date +%T)"
