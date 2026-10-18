# The pinned runner is harness/schedule/refine_run.R at commit 200d847, copied to scratchpad/epi/run1.R.
# Region-mixed pinned replays: a saved run of level k on its own steps, with one region's
# panels at level k - 1.  Rscript mixed.R LIB BASE_DIR BASE_NAME SCHED(s05|s1) K REGION OUTNAME
LIFETIME <- 40; source("/home/user/plant-dev/harness/schedule/refine.R")
E <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/epi"
DEV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
REG <- list(A = c(0, 3.2), B = c(3.2, 6.6), C = c(6.6, 12.6), D = c(12.6, 17.7),
            E = c(17.7, 24.5), F = c(24.5, 40))
mix <- function(sch, k, R) {
  S <- unlist(lapply(sch$panels, function(p) { inR <- !is.null(R) && p$lo >= REG[[R]][1] - 1e-6 && p$lo < REG[[R]][2] - 1e-6
    n <- p$n * 2^(if (inR) k - 1 else k); if (n < 2) return(p$lo)
    c(p$lo, approx(p$mass / tail(p$mass, 1), p$at, seq(0, 1, length.out = n + 1)[2:n], ties = "ordered")$y) }))
  sort(unique(round(S, 10))) }
if (sys.nframe() == 0) {
  a <- commandArgs(TRUE); lib <- a[1]; base <- file.path(a[2], paste0(a[3], ".rds")); sch <- readRDS(file.path(E, "schedules.rds"))[[a[4]]]
  k <- as.numeric(a[5]); R <- a[6]; out <- file.path(E, "runs", paste0(a[7], ".rds"))
  S <- mix(sch, k, R); B <- readRDS(base)$node_times
  stopifnot(all(round(S, 10) %in% round(B, 10)), isTRUE(all.equal(sort(mix(sch, k, NULL)), sort(B))))
  cat(a[7], ": ", length(B) - length(S), " of ", length(B), " nodes removed in ", R, "\n", sep = "")
  tf <- file.path(E, "runs", paste0(a[7], "_times.rds")); saveRDS(S, tf)
  env <- c(TOL = "1e-4", ATOL = "1e-4", WEIGHT_SOIL = "10", WEIGHT_MAX = "100", HMAX = "15", SHARE = "0.1", SPLIT = "1",
           REGIME = "episodic", SEED = "31", TRAIT_REL = "a_dG2=-0.2", WEIGHT = file.path(DEV, "window/rule_A/weight_episodic.rds"),
           LIB = lib, TIMES = tf, OUT = out, PIN = base, FORWARD = "", FIRST = "")
  st <- system2("Rscript", file.path(E, "run1.R"), env = paste0(names(env), "=", env),
                stdout = file.path(E, "runs", paste0(a[7], ".log")), stderr = file.path(E, "runs", paste0(a[7], ".log")))
  cat(readLines(file.path(E, "runs", paste0(a[7], ".log"))), sep = "\n"); quit(status = st)
}
