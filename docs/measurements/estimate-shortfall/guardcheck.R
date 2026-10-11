# The elasticity guard on round 2's saved passes: largest resident elasticity move
# between passes, in eps.
source("../adjmap/lib.R")
eps_tab <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
eps_res <- function(q) { e <- eps_tab$eps[eps_tab$role == "resident" & eps_tab$trait == q & eps_tab$unit != "curvature in lma"]; max(if (length(e)) e[1] else NA, 0.01, na.rm = TRUE) }
el <- function(x) { e <- x$stand$elasticity; names(e) <- sub("^1\\.", "", names(e)); e[!names(e) %in% c("S_D", "a_f3", "recruitment_decay")] }
for (nm in c("th0b_episodic", "th0b_dry", "th0b_long-wet", "lma125b_episodic", "th0_dry", "th0_episodic")) {
  k <- 0; prev <- NULL
  while (!is.null(x <- run(sprintf("ref_%s_p%d", nm, k)))) { e <- el(x)
    if (!is.null(prev)) { m <- abs(e - prev[names(e)]) / vapply(names(e), eps_res, 0); cat(sprintf("%-18s p%d-p%d: max %.3f eps (%s), > 1/4: %d\n", nm, k - 1, k, max(m), names(which.max(m)), sum(m > 0.25))) }
    prev <- e; k <- k + 1 }
}
