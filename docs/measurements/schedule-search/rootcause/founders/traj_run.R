# traj_run.R: one forward stand run (adj_run_nk.R, FORWARD=1, its environment) that also
# keeps the founders' per-node trajectories: height, mortality integral, storage,
# survival-weighted offspring and lifetime seed output for every node born before B1,
# and the soil's top five layers, at every recorded step up to TMAX (thinned to NKEEP).
Sys.setenv(FORWARD = "1")
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/adj_run_nk.R")
b1 <- as.numeric(Sys.getenv("B1")); tmax <- as.numeric(Sys.getenv("TMAX", "30")); nkeep <- as.integer(Sys.getenv("NKEEP", "1500"))
rows <- scm$store_trajectory()
tt <- vapply(rows, function(r) r$time, 0); len <- vapply(rows, function(r) length(r$state), 0)
nm <- scm$patch$species[[1]]$new_node$ode_names; k <- length(nm); N <- length(times)
extra <- tail(len, 1) - k * N
nt <- (len - extra) / k; stopifnot(all(abs(nt - round(nt)) < 1e-9))
fi <- which(times < b1); keep <- which(tt <= tmax & nt >= 1)
keep <- keep[unique(round(seq(1, length(keep), length.out = min(nkeep, length(keep)))))]
pick <- function(v) t(vapply(keep, function(i) { s <- rows[[i]]$state; n <- nt[i]; m <- matrix(s[seq_len(k * n)], nrow = k, dimnames = list(nm))
  r <- rep(NA_real_, length(fi)); j <- fi[fi <= n]; r[seq_along(j)] <- m[v, j]; r }, numeric(length(fi))))
out$traj <- list(time = tt[keep], birth = times[fi], height = pick("height"), mortality = pick("mortality"),
  storage = pick("storage"), offspring = pick("offspring_produced_survival_weighted"), fecundity = pick("fecundity"),
  soil = t(vapply(keep, function(i) head(tail(rows[[i]]$state, 10), 5), numeric(5))), extra = extra)
save()
cat(sprintf("trajectory: %d rows kept of %d, %d founders' nodes, extra %d\n", length(keep), length(rows), length(fi), extra))
