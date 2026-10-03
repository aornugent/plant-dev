#!/bin/bash
# The per-row component table at the cut for both builds: callgrind
# instructions (cg/guard5, cg/spread5) and the tapestats shim's phase times
# (out/tape5_guard.tsv, out/tape5_spread.tsv, summarised by tape_summary.R).
SPD=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sweep_profile
cd $SPD
Rscript tape_summary.R out/tape5_guard.tsv out/tape5_spread.tsv > out/tape5_summary.txt
phases() {
  Rscript -e "s <- readRDS('$1'); x <- readRDS('$2'); t <- as.list(s\$totals); t\$wall <- s\$tape_wall; t\$cpu <- x\$sweep\$cpu[['user']]; cat(jsonlite::toJSON(t, auto_unbox = TRUE, digits = 10))"
}
PG=$(phases out/tape5_guard_summary.rds out/tape5_guard.rds)
PS=$(phases out/tape5_spread_summary.rds out/tape5_spread.rds)
python3 final_table.py 40073 "[{\"name\":\"baseline lib_guard\",\"stem\":\"cg/guard5\",\"phases\":$PG},{\"name\":\"spread lib3 SPREAD=8\",\"stem\":\"cg/spread5\",\"phases\":$PS}]" | tee out/final_table_cut.txt
