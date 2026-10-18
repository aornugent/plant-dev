# extra.R: layout D's wide intervals (> 160 d: where they sit, their J share, their own
# error on the five model cases) and the own error in panels whose count does not move
# when rho is scaled by 1.25.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/own_model.R")
for (cs in c(BANK, HELD)) { D <- readRDS(file.path(SC, "evidence", sprintf("layoutD_%s.rds", cs))); S <- D$S; px <- pilot_run(cs)
  lo <- head(S, -1); hi <- S[-1]; wd <- (hi - lo) * 365; g <- seq(0, H, length.out = 40001); gm <- head(g, -1) + diff(g)[1] / 2; jd <- jdens(px, gm)
  k <- which(wd > 160); js <- sum(sapply(k, function(i) sum(jd$J[gm >= lo[i] & gm < hi[i]]))) / sum(jd$J)
  cat(sprintf("%-14s intervals > 160 d: %2d (first at %.1f y; %d before b = 20), J share %.4f\n", cs, length(k), if (length(k)) lo[k[1]] else NA, sum(lo[k] < 20), js)) }
for (cs in names(REFS)) { M <- model_of(cs); D <- readRDS(file.path(SC, "evidence", sprintf("layoutD_%s.rds", cs)))
  p <- pilot_of(cs); px <- pilot_run(cs); D2 <- layout_D(cs, 1.25, p, px, alg$hfun_of(p))
  oi <- own_by_interval(M, D$S); oi$panel <- findInterval(oi$lo, D$breaks); P <- D$panels
  own_p <- tapply(oi$err, factor(oi$panel, levels = seq_len(nrow(P))), sum, default = 0); stuck <- D2$panels$n_int == P$n_int
  wide <- c(diff(sort(unique(c(D$S, H)))) * 365 > 160, FALSE)
  cat(sprintf("%-12s own: total %+.3f; in panels stuck at x1.25 %+.4f (|.| share %.3f); in intervals > 160 d %+.4f (|.| share %.3f)\n", cs, sum(own_p),
    sum(own_p[stuck]), sum(abs(own_p[stuck])) / sum(abs(own_p)), sum(oi$err[wide]), sum(abs(oi$err[wide])) / sum(abs(oi$err)))) }
