# mk_sched.R: E6's two schedules for each held-out case from its pilot, built exactly as
# the bank's were: a09's graded build (late edges left out), each edge node inset 12 d
# (committed, c); a09's check fill at h/1.6, edge nodes inset 7.5 d (check, f).
# Guard: the same code reproduces the bank's saved insc_ and ins75f_ schedules on dry and
# episodic-lma.
Sys.setenv(BG = 90, R = 1.6)
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R"))
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/heldout/cases.R")
XS <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out/sched"
r <- 1.6; stopifnot(alg$R == r, alg$BG == 90)
late_out <- function(S, p) { late <- round(p$edges[p$edges > 25], 10); S[!(round(S, 10) %in% late)] }
e6 <- function(cs) { p <- pilot_of(cs); h <- alg$hfun_of(p)
  Sc <- late_out(build_graded(p, h), p); Sf <- late_out(alg$fill(p, h, build_graded(p, h), build_graded(p, function(b) h(b) / r)), p)
  list(c = as.numeric(inset_rule(Sc, cs, d = 12)), f = as.numeric(inset_rule(Sf, cs, d = 12 / r)), p = p) }
args <- commandArgs(TRUE); todo <- if (length(args)) args else names(HO)
if (!length(args)) for (cs in c("dry", "episodic-lma")) { z <- e6(cs)
  a <- readRDS(file.path(POUT, "sched", sprintf("insc_%s.rds", cs))); b <- readRDS(file.path(XS, sprintf("ins75f_%s.rds", cs)))
  cat(sprintf("guard %-13s c %d/%d max diff %.1e | f %d/%d max diff %.1e\n", cs, length(z$c), length(a), max(abs(z$c - a)), length(z$f), length(b), max(abs(z$f - b))))
  stopifnot(length(z$c) == length(a), max(abs(z$c - a)) < 1e-12, length(z$f) == length(b), max(abs(z$f - b)) < 1e-12) }
for (cs in todo) { if (!file.exists(file.path(HO_OUT, "runs", paste0("pilot_", cs, ".rds")))) { cat(cs, ": no pilot\n"); next }
  z <- e6(cs); saveRDS(z$c, file.path(HO_OUT, "sched", sprintf("c_%s.rds", cs))); saveRDS(z$f, file.path(HO_OUT, "sched", sprintf("f_%s.rds", cs)))
  s <- alg$proxy_err(z$p, z$f) / alg$proxy_err(z$p, z$c)
  cat(sprintf("%-14s b1 %.2f edges<25 %d | c %d nodes, f %d nodes (%.2f) | a09 shrink s %.3f | max open gap c %.0f d\n", cs, z$p$b1, sum(z$p$edges < 25),
    length(z$c), length(z$f), length(z$f) / length(z$c), s, max(diff(z$c[z$c < 25])) * 365)) }
