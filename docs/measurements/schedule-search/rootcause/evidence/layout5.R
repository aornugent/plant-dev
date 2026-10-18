# layout5.R: layout Bga with the grading's width from the parameters. The grade is dry's
# measured one, g = max(root_P50's, the storage offset's) kappa^(1/3) by days before the
# shutting (R13, R15), stretched by t_r(case) / t_r(dry), t_r = o ln(a_st3 a_dG2); each
# replayed spell gets two more intervals. Ages from T(t): the bank's committed runs; for a
# held-out case its record's bank case (episodic for epi-adG208). Writes the schedule, its
# odd replay and its short-spell bisection for each case.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/layoutB.R")
EV <- file.path(SC, "evidence"); R5 <- file.path(EV, "r5")
gp <- readRDS(file.path(EV, "grade.rds"))$profile; gp <- gp[gp$case == "dry", ]
tw <- readRDS(file.path(EV, "twin_analyze.rds"))$prof; ts <- aggregate(r ~ d, tw[tw$q == "sro", ], median); ts <- ts[order(ts$d), ]
ks <- stats::runmed(ts$r, 3); ks[ts$d >= 30] <- 1
g_p50 <- approxfun(gp$d, gp$g, rule = 2); g_sro <- approxfun(ts$d, pmax(1, ks)^(1 / 3), rule = 2)
g_dry <- function(d) pmax(g_p50(d), g_sro(d))
t_r <- function(a_dG2 = 20, a_st3 = 0.8, o = 7) o * log(a_st3 * a_dG2)
TR <- c(dry = t_r(), `long-wet` = t_r(), `episodic-lma` = t_r(), `dry-flat` = t_r(), `epi-adG208` = t_r(a_dG2 = 16))
AGE_OF <- c(`epi-adG208` = "episodic")
ages_of <- function(cs) { r <- TW[TW$case == (if (cs %in% names(AGE_OF)) AGE_OF[[cs]] else cs), ]; c(t50 = r$t50, t90 = r$t10) }
if (sys.nframe() == 0) {
  # the reconstruction reproduces Bga on dry
  Lc <- layout_B("dry", gfun = g_dry, add = 2); Lo <- readRDS(file.path(EV, "layoutBga_dry.rds"))
  cat(sprintf("dry check: %d nodes against Bga's %d, max |dS| %.2e\n", length(Lc$S), length(Lo$S), if (length(Lc$S) == length(Lo$S)) max(abs(Lc$S - Lo$S)) else NA))
  dir.create(file.path(R5, "sched"), showWarnings = FALSE, recursive = TRUE)
  for (cs in names(TR)) { s <- TR[[cs]] / TR[["dry"]]; L <- layout_B(cs, gfun = function(d) g_dry(d / s), add = 2); B <- layout_B(cs)
    e6 <- E6_c(cs); px <- pilot_run(cs); st <- px$times
    saveRDS(L, file.path(R5, sprintf("layout5_%s.rds", cs)))
    saveRDS(L$S, file.path(R5, "sched", sprintf("G5_%s.rds", cs))); saveRDS(L$odd, file.path(R5, "sched", sprintf("G5o_%s.rds", cs))); saveRDS(L$bis, file.path(R5, "sched", sprintf("G5b_%s.rds", cs)))
    P <- L$panels; rep <- P$n_int >= 2
    cat(sprintf("%-13s t_r %.1f d | nodes %d (B %d, E6 c %d) | replayed spells %d, short %d | odd removal %d | rows model x%.2f E6 c | ages %.1f/%.1f\n", cs, TR[[cs]],
      length(L$S), length(B$S), length(e6), sum(rep), sum(P$n_int == 1), length(L$odd), rows_model(L$S, st) / rows_model(e6, st), L$ages[1], L$ages[2])) } }
