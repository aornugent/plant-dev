# Initial-state tangent vs replay secant along theta1 from each zero-size stop in a window.
Sys.setenv(SWEEP = "0", TANGENT = "")
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/D/probe.R")
rows <- scm$store_trajectory()
tt <- vapply(rows, `[[`, 0, "time")
starts <- which(c(FALSE, diff(tt) == 0))
want <- as.numeric(strsplit(Sys.getenv("STARTS"), ",")[[1]])
res <- NULL
for (t0 in want) {
  j <- which.min(abs(tt[starts] - t0)); start <- starts[j]
  base <- rows[[start]]$state; w <- length(base); i <- w - 9
  rep1 <- function(s) tail(plant:::ladder_census_initial_state_replay_tf24(scm, s, j), 1)
  d <- numeric(w); d[i] <- 1
  tan <- tail(plant:::ladder_census_initial_state_tangent_tf24(scm, d, j)$tangent, 1)
  sec <- sapply(c(1e-3, 1e-4), function(del) { up <- base; dn <- base; up[i] <- up[i] + del; dn[i] <- dn[i] - del
    (rep1(up) - rep1(dn)) / (2 * del) })
  r <- data.frame(t = tt[start], range = j, theta1 = base[i], tangent = tan, sec3 = sec[1], sec4 = sec[2])
  print(r, digits = 6); res <- rbind(res, r); out$e11 <- res; sv()
}
