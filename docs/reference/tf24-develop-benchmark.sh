#!/usr/bin/env bash
# TF24 forward-run benchmark: `develop` baseline vs this branch. Cited by v3-facts.md 3c.
#   ./docs/reference/tf24-develop-benchmark.sh        (~15 min: two package installs)
# Measured session 22: develop 49.57 s / 2621 steps, branch 50.31 s / 2599 steps.
# TF24 forward-run benchmark: develop baseline vs this branch.
# Installs develop's plant (and odelia@master, which it LinkingTo) into a SEPARATE
# library so the workspace's installed plant/odelia are never touched.
set -x
SC="${BENCH_SCRATCH:-${TMPDIR:-/tmp}/tf24-bench}"; mkdir -p "$SC"
DEV=$SC/dev-worktrees
LIB=$SC/devlib
rm -rf "$LIB"; mkdir -p "$LIB" "$DEV"
cd /home/user/plant-dev || exit 2

git -C plant  worktree add -f "$DEV/plant-develop" develop      || exit 3
git -C odelia worktree add -f "$DEV/odelia-master" master       || exit 4

R_LIBS_USER="$LIB" R CMD INSTALL -l "$LIB" "$DEV/odelia-master" --no-multiarch --no-docs || exit 5
R_LIBS_USER="$LIB" R CMD INSTALL -l "$LIB" "$DEV/plant-develop" --no-multiarch --no-docs || exit 6

# Same default TF24 forward run on each side. No AD, no gradient.
cat > "$SC/bench_run.R" <<'RS'
lib <- Sys.getenv("BENCH_LIB"); if (nzchar(lib)) .libPaths(c(lib, .libPaths()))
suppressMessages(library(plant))
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- 105.32
p <- expand_parameters(trait_matrix(0.0825, "lma"), p, birth_rate_list = 20)
t0 <- Sys.time()
res <- run_scm(p, use_ode_times = FALSE)
el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("BENCH %s wall=%.2fs steps=%d\n", Sys.getenv("BENCH_TAG"), el,
            length(res$ode_times)))
RS
echo "--- develop"
BENCH_LIB="$LIB" BENCH_TAG=develop Rscript "$SC/bench_run.R"
echo "--- branch"
BENCH_TAG=branch Rscript "$SC/bench_run.R"
