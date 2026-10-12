# Fate (nrr), its root_P50 derivative and mortality by birth date before closings, on Hocw.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs")
p <- readRDS(file.path(Q, "rp_Hocw_0.02_dry.rds"))$stand$nodes; m <- readRDS(file.path(Q, "rp_Hocw_-0.02_dry.rds"))$stand$nodes
b <- p$birth; dn <- (log(p$nrr) - log(m$nrr)) / 0.04; dm <- (p$mortality - m$mortality) / 0.04
est <- head(p$establishment, -1)
ed <- readRDS(file.path(S, "rp50/Ho_edges_dry.rds")); cr <- as.data.frame(readRDS(file.path(Q, "rp_Ho_0.02_dry.rds"))$stand$creation); pos <- cr$rate > 0
openat <- function(z) pos[pmax(findInterval(z, cr$start), 1)]
isclose <- vapply(ed, function(z) { d <- seq(0.05, 10, by = 0.05) / 365; fa <- which(!vapply(z + d, openat, TRUE))[1]; ba <- which(!vapply(z - d, openat, TRUE))[1]
  if (is.na(ba)) TRUE else if (is.na(fa)) FALSE else fa < ba }, TRUE)
cl <- ed[isclose]
show <- function(z) { k <- which(b > z - 60 / 365 & b <= z + 1e-9)
  cat(sprintf("\nclosing node at b = %.3f (day %.1f)\n", z, z * 365)); print(round(data.frame(before_d = (z - b[k]) * 365, est = est[k], nrr = p$nrr[k], dlnnrr = dn[k], mort = p$mortality[k], dmort = dm[k]), 3)) }
for (z in cl[c(5, 20, 35)]) show(z)
