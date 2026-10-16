# h1_mkcoarse.R: H1's coarse companion. a09's builder at R x the committed spacing
# (the check's h/R, taken the other way: h*R, with the builder's cap scaled by R too, so
# every interval is R x the committed one), late edges left out as a09_late does, then
# P's inset_rule at 12 x R = 19.2 d. Reproduces a09's c and f first as a guard.
Sys.setenv(BG = 90, R = 1.6)
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R"))
H1 <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/h1"
dir.create(file.path(H1, "sched"), recursive = TRUE, showWarnings = FALSE)
XS <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out/sched"
r <- 1.6; stopifnot(alg$R == r, alg$BG == 90)
cap0 <- cap_of
late_out <- function(S, p) { late <- round(p$edges[p$edges > 25], 10); S[!(round(S, 10) %in% late)] }
rows <- list()
for (cs in ALL) { p <- pilot_of(cs); h <- alg$hfun_of(p)
  Sc <- late_out(build_graded(p, h), p); Sk <- late_out(alg$fill(p, h, build_graded(p, h), build_graded(p, function(b) h(b) / r)), p)
  a <- sched(cs, "c"); b <- sched(cs, "f")
  stopifnot(length(Sc) == length(a), max(abs(Sc - a)) < 1e-9, length(Sk) == length(b), max(abs(Sk - b)) < 1e-9)
  # The coarse direction: spacing R x h everywhere, the cap included.
  cap_of <- function(p, lo, hi) r * cap0(p, lo, hi)
  Sx <- late_out(build_graded(p, function(b) r * h(b)), p)
  cap_of <- cap0
  Sx_capped <- late_out(build_graded(p, function(b) r * h(b)), p)   # cap left at the committed range, for the record
  Ix <- inset_rule(Sx, cs, d = 12 * r); stopifnot(!any(is_edge(Ix, edge_table(cs)$b)))
  saveRDS(as.numeric(Ix), file.path(H1, "sched", sprintf("insx_%s.rds", cs)))
  Ic <- readRDS(file.path(POUT, "sched", sprintf("insc_%s.rds", cs))); stopifnot(max(abs(as.numeric(inset_rule(a, cs)) - Ic)) < 1e-12)
  If <- readRDS(file.path(XS, sprintf("ins75f_%s.rds", cs)))
  pc <- proxy(cs, Ic); px <- proxy(cs, Ix); pf <- proxy(cs, If)
  rows[[cs]] <- data.frame(case = cs, n_a09c = length(a), n_coarse_raw = length(Sx), n_coarse_capped = length(Sx_capped),
    n_c = length(Ic), n_x = length(Ix), n_f = length(If), x_over_c = length(Ix) / length(Ic), f_over_c = length(If) / length(Ic),
    n_x_lt25 = sum(Ix < 25), n_c_lt25 = sum(Ic < 25), dropped_strip = attr(Ix, "dropped_interior"),
    s_c = pc / px, s_f = pf / pc, max_gap_x_d = max(diff(Ix[Ix < 25])) * 365, max_gap_c_d = max(diff(Ic[Ic < 25])) * 365) }
T <- do.call(rbind, rows); rownames(T) <- NULL
print(T, digits = 3)
cat(sprintf("all ten: committed %d nodes, coarse %d (%.2f), check %d (%.2f); s_c median %.3f (1/R^2 = %.3f)\n",
  sum(T$n_c), sum(T$n_x), sum(T$n_x) / sum(T$n_c), sum(T$n_f), sum(T$n_f) / sum(T$n_c), median(T$s_c), 1 / r^2))
saveRDS(T, file.path(H1, "sched_counts.rds"))
