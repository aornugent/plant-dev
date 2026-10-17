source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/lib.R")
late_out <- function(S, p) { late <- round(p$edges[p$edges > 25], 10); S[!(round(S, 10) %in% late)] }
for (cs in ALL) { p <- pilot_of(cs); a <- sched(cs, "c"); g <- h5_sched(cs, 1, "raw", close = FALSE)
  stopifnot(length(g) == length(a), max(abs(g - a)) < 1e-9)
  Ic <- readRDS(file.path(POUT, "sched", sprintf("insc_%s.rds", cs)))
  n <- sapply(c(1.6, 1, 1/1.6), function(s) length(h5_sched(cs, s, "node"))); ni <- sapply(c(1.6, 1, 1/1.6), function(s) length(h5_sched(cs, s, "inset")))
  pr <- sapply(c(1.6, 1, 1/1.6), function(s) proxy(cs, h5_sched(cs, s, "node")))
  md <- min(diff(h5_sched(cs, 1, "node")))*365; cat(sprintf("min sep node %.2f d | ", md)); cat(sprintf("%-13s E6 c %d | H5 node x/c/f %d/%d/%d | H5 inset12 %d/%d/%d | proxy shrink x->c %.3f c->f %.3f (1/r^2 %.3f)\n", cs, length(Ic), n[1], n[2], n[3], ni[1], ni[2], ni[3], pr[2]/pr[1], pr[3]/pr[2], 1/1.6^2)) }
cat("guard: raw mode reproduces a09 c on all ten\n")
