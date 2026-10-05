#!/bin/bash
# Item 4's rows: chords of split gradients on one grid (prereg.txt, sixteenth
# extension). LIB holds the build (odelia 1e5a2d7, plant 91098156). Runs four at
# a time; nothing here is timed.
#   LIB=lib OUTD=dir bash curvature_rows.sh
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
mkdir -p "$OUTD"
run() {  # name, then run_record.R's environment
  local name=$1; shift
  [ -f "$OUTD/$name.done" ] && return 0
  env PLANT_LIB="$LIB" SPLIT=1 ATOL=1e-4 NODES=108 "$@" OUT="$OUTD/$name.rds" \
    Rscript "$H/run_record.R" > "$OUTD/$name.log" 2>&1 && touch "$OUTD/$name.done"
}
queue() {  # each argument one job, at most four at a time
  for j in "$@"; do
    while [ "$(jobs -rp | wc -l)" -ge 4 ]; do sleep 5; done
    eval "$j" &
  done
  wait
}
rel() { awk -v d="$1" 'BEGIN { printf "%.17g", exp(d) - 1 }'; }
P1=$(rel 0.01); M1=$(rel -0.01); P3=$(rel 0.03); M3=$(rel -0.03)

# The grids: the build's own adaptive split runs at 1e-4 and nudged 5% either way.
queue "run grid_g0 TOL=1e-4 FORWARD=1 STAND_ONLY=1" \
      "run grid_gm TOL=0.95e-4 FORWARD=1 STAND_ONLY=1" \
      "run grid_gp TOL=1.05e-4 FORWARD=1 STAND_ONLY=1"
for g in g0 gm gp; do
  Rscript -e 's <- readRDS(commandArgs(TRUE)[1])$stand
    saveRDS(list(st = data.frame(time = s$times[-1], h = s$sizes[-1])), commandArgs(TRUE)[2])' \
    "$OUTD/grid_$g.rds" "$OUTD/program_$g.rds"
done

# The stand at theta0 hosting the invaders, and the stands moved, each with its own
# invader; on the nudged grids at D = 1e-2 only.
queue "run s0_g0 TOL=1e-4 PROGRAM=$OUTD/program_g0.rds STAND_GRADIENT=0 INVADER_GRADIENTS=1 INVADERS_REL=lma=$P1,lma=$M1,lma=$P3,lma=$M3" \
      "run m_g0_p1 TOL=1e-4 PROGRAM=$OUTD/program_g0.rds LMA_REL=$P1" \
      "run m_g0_m1 TOL=1e-4 PROGRAM=$OUTD/program_g0.rds LMA_REL=$M1" \
      "run m_g0_p3 TOL=1e-4 PROGRAM=$OUTD/program_g0.rds LMA_REL=$P3" \
      "run m_g0_m3 TOL=1e-4 PROGRAM=$OUTD/program_g0.rds LMA_REL=$M3" \
      "run s0_gm TOL=0.95e-4 PROGRAM=$OUTD/program_gm.rds STAND_GRADIENT=0 INVADER_GRADIENTS=1 INVADERS_REL=lma=$P1,lma=$M1" \
      "run s0_gp TOL=1.05e-4 PROGRAM=$OUTD/program_gp.rds STAND_GRADIENT=0 INVADER_GRADIENTS=1 INVADERS_REL=lma=$P1,lma=$M1" \
      "run m_gm_p1 TOL=0.95e-4 PROGRAM=$OUTD/program_gm.rds LMA_REL=$P1" \
      "run m_gm_m1 TOL=0.95e-4 PROGRAM=$OUTD/program_gm.rds LMA_REL=$M1" \
      "run m_gp_p1 TOL=1.05e-4 PROGRAM=$OUTD/program_gp.rds LMA_REL=$P1" \
      "run m_gp_m1 TOL=1.05e-4 PROGRAM=$OUTD/program_gp.rds LMA_REL=$M1"
echo "JOB DONE curvature_rows $(date +%T)"
