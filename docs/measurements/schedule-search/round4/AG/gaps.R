# gaps.R CASE: establishment in the intervals that span a g-gap (no g establishment
# inside them on the instant gate), on a09's c and f and P's inset c and f, under the
# instant gate g and under E (g filtered on w): share of all establishment, and
# whether c and f share those intervals exactly (a check that never refines them).
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
cs <- commandArgs(TRUE)[1]; cr <- creation_of(cs); w <- 0.05
crE <- cr; e <- cr$rate[1]; for (i in seq_len(nrow(cr))) { h <- cr$end[i] - cr$start[i]; e <- cr$rate[i] + (e - cr$rate[i]) * exp(-h / w); crE$rate[i] <- e }
et <- edge_table(cs); cl <- et$b[!et$opening]
gapint <- function(S) { S <- sort(S[S >= et$b[1] - 1e-9 & S < 25]); lo <- S[-length(S)]; hi <- S[-1]
  k <- vapply(seq_along(lo), function(i) any(cl > lo[i] - 1e-9 & cl < hi[i] - 1e-9), TRUE); cbind(lo[k], hi[k]) }
estab <- function(I, c) { tot <- sum(c$rate[c$end < 25 & c$start > et$b[1]] * (c$end - c$start)[c$end < 25 & c$start > et$b[1]])
  s <- sum(apply(I, 1, function(r) { z <- c$start >= r[1] & c$end <= r[2]; sum(c$rate[z] * (c$end - c$start)[z]) })); s / tot }
for (v in c("a09", "ins")) { Sc <- if (v == "a09") sched(cs, "c") else readRDS(file.path(POUT, "sched", sprintf("insc_%s.rds", cs))); Sf <- if (v == "a09") sched(cs, "f") else readRDS(file.path(POUT, "sched", sprintf("insf_%s.rds", cs)))
  Ic <- gapint(Sc); If <- gapint(Sf); same <- nrow(Ic) == nrow(If) && isTRUE(all.equal(Ic, If))
  shared <- sum(apply(Ic, 1, function(r) any(abs(If[, 1] - r[1]) < 1e-8 & abs(If[, 2] - r[2]) < 1e-8)))
  cat(sprintf("%-13s %s: gap-spanning intervals c %d, f %d, identical in f %d of %d | establishment in them: g c %.3f f %.3f, E c %.3f f %.3f | median length c %.0f d\n", cs, v, nrow(Ic), nrow(If), shared, nrow(Ic),
    estab(Ic, cr), estab(If, cr), estab(Ic, crE), estab(If, crE), median(Ic[, 2] - Ic[, 1]) * 365)) }
