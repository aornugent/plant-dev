# q2_phys.R: what happens to cohorts born in a closing edge's last days (traj_map_dry.rds).
# Per edge, for births at c - {36, 21, 12, 3, 0} d and gap probes c + {2, 7, 12} d: ln nrr; the
# cumulative mortality reached by calendar dates c + 15 d, the gap's end a', a' + 30 d, c + 1 yr
# and c + 3 yr; height and storage at the same dates; and the soil's top-layer water by day.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
x <- readRDS(file.path(CL, "runs", "traj_map_dry.rds")); et <- edge_table("dry"); op <- et$b[et$opening]
for (k in names(x$per_edge)) { e <- x$per_edge[[k]]; c0 <- as.numeric(k); a1 <- min(op[op > c0]); gap <- (a1 - c0) * 365
  cat(sprintf("\n== edge %.3f: gap %.0f d (rain > 1 mm in the 30 d before c: %s)\n", c0, gap, paste(which(rain_rec("dry")[floor(c0 * 365) - 29:0] > 1) - 30, collapse = " ")))
  want <- c(-36, -21, -12, -3, 0, 2, 7, 12); dates <- c(c0 + 15 / 365, a1, a1 + 30 / 365, c0 + 1, c0 + 3)
  rows <- lapply(want, function(o) { j <- which(abs(e$birth - (c0 + o / 365)) < 0.6 / 365); if (!length(j)) return(NULL); j <- j[1]; b <- e$birth[j]
    at <- function(m, t) { i <- which.min(abs(x$tau - (t - b))); if (t < b) NA else m[i, j] }
    data.frame(off = o, lnrr = log(x$nrr[e$j[j]]), w = x$w[e$j[j]], t(sapply(dates, function(t) at(e$mortality, t))), t(sapply(dates, function(t) at(e$height, t))), t(sapply(dates, function(t) at(e$storage, t)))) })
  R <- do.call(rbind, rows); names(R) <- c("off", "lnrr", "w", paste0("mort_", c("c15", "gapend", "gap30", "1y", "3y")), paste0("h_", c("c15", "gapend", "gap30", "1y", "3y")), paste0("st_", c("c15", "gapend", "gap30", "1y", "3y")))
  print(format(R, digits = 3), row.names = FALSE)
  th <- e$theta[, 1]; cat(sprintf("top-layer water at c - 60, -30, -10, 0, +10, +30, gap end, +120 d: %s\n", paste(sprintf("%.3f", th[pmax(1, pmin(181, 61 + round(c(-60, -30, -10, 0, 10, 30, gap, 120))))]), collapse = " "))) }
