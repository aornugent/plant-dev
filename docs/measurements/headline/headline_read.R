# The headline's table (prereg.txt here), from headline.sh's runs.
#   DEV=... Rscript docs/measurements/headline/headline_read.R   # from plant-dev's root
O <- file.path(Sys.getenv("DEV"), "headline", "runs")
eps <- read.csv("docs/measurements/eps.csv")
eps_of <- function(trait) {
  e <- eps$eps[eps$role == "resident" & eps$trait == trait & eps$unit != "curvature in lma"]
  max(if (length(e)) e[1] else NA, 0.01, na.rm = TRUE)
}
run <- function(c, r) { f <- file.path(O, sprintf("%s_%s.rds", c, r)); if (file.exists(f)) readRDS(f) }
for (rec in c("long-drought", "episodic")) {
  d <- run("develop", rec); f <- run("floor", rec); s <- run("stack", rec)
  cat("==", rec, "\n")
  if (is.null(f)) { cat("   the floor has not run\n"); next }
  n <- length(f$elasticity)
  if (!is.null(d)) cat(sprintf("   develop: forward %.1f s, %d steps; ln J %+.3f eps from the floor; its gradient by central differences would be %d forwards, %.0f s\n",
                               d$forward_secs, d$steps, (log(d$J) - log(f$J)) / 0.025, 2 * n, 2 * n * d$forward_secs))
  else cat("   develop: did not finish (see its log)\n")
  cat(sprintf("   floor:   forward %.1f s, gradient %.1f s, total %.1f s, %d steps\n",
              f$forward_secs, f$gradient_secs, f$forward_secs + f$gradient_secs, f$steps))
  if (!is.null(s)) {
    tr <- sub("^1\\.", "", names(s$elasticity))
    m <- abs(s$elasticity - f$elasticity[names(s$elasticity)]) / vapply(tr, eps_of, 0)
    tot <- s$pilot_secs + s$forward_secs + s$gradient_secs
    cat(sprintf("   stack:   pilot %.1f s, forward %.1f s, gradient %.1f s, total %.1f s (%.2f of the floor's), %d steps\n",
                s$pilot_secs, s$forward_secs, s$gradient_secs, tot,
                tot / (f$forward_secs + f$gradient_secs), s$steps))
    cat(sprintf("            ln J %+.3f eps from the floor; elasticities: median %.3f eps, largest %.3f eps (%s), %d of %d over eps/3\n",
                (log(s$J) - log(f$J)) / 0.025, median(m), max(m), tr[which.max(m)], sum(m > 1 / 3), length(m)))
  }
}
# The amendment: against the spread's two-rung answer on long drought.
s1 <- run("stack", "long-drought"); s2 <- run("stack_u215", "long-drought"); f <- run("floor", "long-drought")
ds <- run("develop-settings", "long-drought")
if (!is.null(s2)) {
  k <- names(s1$elasticity); tr <- sub("^1\\.", "", k); e <- vapply(tr, eps_of, 0)
  ref <- s2$elasticity[k] + (s2$elasticity[k] - s1$elasticity[k]) / 3
  lref <- log(s2$J) + (log(s2$J) - log(s1$J)) / 3
  cat("== long drought against the two-rung answer (J", format(exp(lref), digits = 8), ")\n")
  for (x in list(list("stack u108", s1), list("stack u215", s2), list("floor", f))) {
    m <- abs(x[[2]]$elasticity[k] - ref) / e
    cat(sprintf("   %-10s ln J %+.3f eps; elasticities median %.3f eps, largest %.3f eps (%s), %d of %d over eps/3\n",
                x[[1]], (log(x[[2]]$J) - lref) / 0.025, median(m), max(m), tr[which.max(m)], sum(m > 1 / 3), length(m)))
  }
  cat(sprintf("   stack at u215: pilot %.1f s, forward %.1f s, gradient %.1f s, total %.1f s (%.2f of the floor's)\n",
              s2$pilot_secs, s2$forward_secs, s2$gradient_secs, s2$pilot_secs + s2$forward_secs + s2$gradient_secs,
              (s2$pilot_secs + s2$forward_secs + s2$gradient_secs) / (f$forward_secs + f$gradient_secs)))
}
if (!is.null(ds)) cat(sprintf("== develop's settings on the stack's build, long drought: J %.4g (develop %.4g, the floor %.4g), %d steps\n",
                              ds$J, run("develop", "long-drought")$J, f$J, ds$steps))
