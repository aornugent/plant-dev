# Initial-state tangent vs replay difference from the last introduction before the pulse.
Sys.setenv(SWEEP = "0", TANGENT = "")
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/D/probe.R")
rows <- scm$store_trajectory()
cat("row fields:", paste(names(rows[[1]]), collapse = " "), "\n")
tt <- vapply(rows, `[[`, 0, "time")
ins <- if (!is.null(rows[[2]]$insertion)) vapply(rows, function(r) isTRUE(r$insertion), FALSE) else c(FALSE, diff(tt) == 0)
t_ins <- as.numeric(Sys.getenv("T_INS", "36.92129"))
starts <- which(ins)
j <- which.min(abs(tt[starts] - t_ins)); start <- starts[j]
cat(sprintf("range %d at row %d, t = %.6f, width %d\n", j, start, tt[start], length(rows[[start]]$state)))
base <- rows[[start]]$state
w <- length(base)
J0 <- tail(plant:::ladder_census_initial_state_replay_tf24(scm, base, j), 1)
cat(sprintf("replay J %.12g vs run J %.12g\n", J0, out$J))
dirs <- list(theta1 = w - 9, theta2 = w - 8, height_n1 = 1, storage_n140 = 9 * 139 + 6)
res <- list()
for (nmd in names(dirs)) {
  i <- dirs[[nmd]]; d <- numeric(w); d[i] <- 1
  c0 <- cpu()
  tg <- plant:::ladder_census_initial_state_tangent_tf24(scm, d, j)
  tan <- tail(tg$tangent, 1)
  fd <- sapply(c(1e-6, 1e-8), function(del) {
    up <- base; dn <- base; s <- del * max(1, abs(base[i])); up[i] <- up[i] + s; dn[i] <- dn[i] - s
    (tail(plant:::ladder_census_initial_state_replay_tf24(scm, up, j), 1) -
       tail(plant:::ladder_census_initial_state_replay_tf24(scm, dn, j), 1)) / (2 * s)
  })
  res[[nmd]] <- c(state = base[i], tangent = tan, fd6 = fd[1], fd8 = fd[2], cpu = cpu() - c0)
  cat(sprintf("%-14s state %.6g tangent %.6g  fd(1e-6) %.6g  fd(1e-8) %.6g  [%.0f s]\n", nmd, base[i], tan, fd[1], fd[2], cpu() - c0))
  out$e9 <- res; sv()
}
