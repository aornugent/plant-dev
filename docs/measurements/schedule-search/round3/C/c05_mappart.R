# The committed run carries J's map; the check bisects, within each region (founders,
# b1-20, after 20), the intervals with the largest mapped error until they hold PHI of the
# region's. The check contains the committed schedule; s is the map's shrink.
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/round3/C/base.R", environment())
PHI <- ev("PHI", 0.75)
algorithm <- function(ctx) { p <- ctx$pilot; h <- hfun_of(p); Sc <- build_graded(p, h); n <- length(Sc)
  c <- ctx$run(Sc, drop = 2:(n - 1)); k <- names(c$q); j <- 2:(n - 1)
  h1 <- Sc[j] - Sc[j - 1]; h2 <- Sc[j + 1] - Sc[j]; dn <- abs(c$map$move) / ((h1 + h2)^3 - h1^3 - h2^3)
  dnode <- c(dn[1], dn, dn[length(dn)]); lo <- head(Sc, -1); hi <- Sc[-1]; m <- (lo + hi) / 2
  e <- (dnode[-n] + dnode[-1]) / 2 * (hi - lo)^3; e[p$shut(m) > 0.5] <- 0
  reg <- cut(m, c(0, p$b1, 20, 40), right = FALSE); sel <- rep(FALSE, length(e))
  for (r in levels(reg)) { i <- which(reg == r & e > 0); if (!length(i)) next; o <- i[order(-e[i])]
    sel[o[seq_len(which(cumsum(e[o]) >= PHI * sum(e[i]))[1])]] <- TRUE }
  Sk <- sort(unique(round(c(Sc, m[sel]), 10))); s <- sum(e * ifelse(sel, 1 / 4, 1)) / sum(e)
  f <- ctx$run(Sk); d <- c$q[k] - f$q[k]
  if (all(abs(d / (1 - s) / ctx$eps(k)) < TAU)) return(list(use = list(Sc), answer = c$q[k], estimate = d / (1 - s)))
  list(use = list(Sk), answer = f$q[k], estimate = d * s / (1 - s)) }
