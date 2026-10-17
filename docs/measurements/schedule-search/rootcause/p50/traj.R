# traj.R: one forward stand run (adj_run_nk.R, FORWARD=1, its environment) that also keeps,
# at every recorded step up to TMAX (thinned to NKEEP), the environment states (soil) and, for
# the nodes born in [BLO, BHI), height, mortality integral and storage.
Sys.setenv(FORWARD = "1")
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/adj_run_nk.R")
blo <- as.numeric(Sys.getenv("BLO", "0")); bhi <- as.numeric(Sys.getenv("BHI", "25")); tmax <- as.numeric(Sys.getenv("TMAX", "40")); nkeep <- as.integer(Sys.getenv("NKEEP", "1200"))
rows <- scm$store_trajectory()
tt <- vapply(rows, function(r) r$time, 0); len <- vapply(rows, function(r) length(r$state), 0)
nm <- scm$patch$species[[1]]$new_node$ode_names; k <- length(nm); N <- length(times)
extra <- tail(len, 1) - k * N; nt <- (len - extra) / k; stopifnot(all(abs(nt - round(nt)) < 1e-9))
fi <- which(times >= blo & times < bhi); keep <- which(tt <= tmax)
keep <- keep[unique(round(seq(1, length(keep), length.out = min(nkeep, length(keep)))))]
pick <- function(v) t(vapply(keep, function(i) { s <- rows[[i]]$state; n <- nt[i]; m <- matrix(s[seq_len(k * n)], nrow = k, dimnames = list(nm))
  r <- rep(NA_real_, length(fi)); j <- fi[fi <= n]; r[match(j, fi)] <- m[v, j]; r }, numeric(length(fi))))
out$traj <- list(time = tt[keep], birth = times[fi], height = pick("height"), mortality = pick("mortality"), storage = pick("storage"),
  soil = t(vapply(keep, function(i) tail(rows[[i]]$state, extra), numeric(extra))), extra = extra)
rm(rows); save()
cat(sprintf("trajectory: %d rows kept, %d nodes in [%g, %g), extra %d\n", length(keep), length(fi), blo, bhi, extra))
