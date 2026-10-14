# The cost of a commit margin for the radius: commit coarse only if every estimate is under TAU.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/F/lib.R")
L <- lapply(ALL, pair); names(L) <- ALL
for (tau in c(1, 0.8, 0.65, 0.5)) { T <- 0; Tt <- 0; nf <- c(); worstf <- 0
  for (cs in ALL) { P <- L[[cs]]; m <- max(abs(P$d / (1 - P$s))); fine <- m >= tau; t <- P$Tc + P$Tf + 2 * (if (fine) P$Tf else P$Tc)
    T <- T + t; if (cs %in% names(CASES)) Tt <- Tt + t; if (fine) nf <- c(nf, sprintf("%s(%.2f)", cs, m)) }
  cat(sprintf("TAU %.2f: T all ten %.0f, training %.0f; commit fine: %s\n", tau, T, Tt, paste(nf, collapse = " "))) }
