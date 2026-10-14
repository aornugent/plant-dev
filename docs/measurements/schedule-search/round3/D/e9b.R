# Replay differences along theta1 from the last introduction before the pulse, larger steps.
Sys.setenv(SWEEP = "0", TANGENT = "")
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/D/probe.R")
rows <- scm$store_trajectory()
tt <- vapply(rows, `[[`, 0, "time")
starts <- which(c(FALSE, diff(tt) == 0))
j <- which.min(abs(tt[starts] - 36.92129)); start <- starts[j]
base <- rows[[start]]$state; w <- length(base); i <- w - 9
rep1 <- function(s) tail(plant:::ladder_census_initial_state_replay_tf24(scm, s, j), 1)
J0 <- rep1(base)
for (del in as.numeric(strsplit(Sys.getenv("DELTAS", "1e-3,1e-4,1e-5"), ",")[[1]])) {
  up <- base; dn <- base; up[i] <- up[i] + del; dn[i] <- dn[i] - del
  Ju <- rep1(up); Jd <- rep1(dn)
  cat(sprintf("delta %.0e: central %.6g  up %.6g  down %.6g\n", del, (Ju - Jd) / (2 * del), (Ju - J0) / del, (J0 - Jd) / del))
}
