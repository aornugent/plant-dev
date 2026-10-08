# The waterfall's table (prereg.txt here), from waterfall.sh's runs, scored
# against the headline's two-rung answer from the stack at 108 and 215.
#   DEV=... Rscript docs/measurements/waterfall/waterfall_read.R   # from plant-dev's root
D <- Sys.getenv("DEV")
O <- file.path(D, "waterfall", "runs")
eps <- read.csv("docs/measurements/eps.csv")
eps_of <- function(trait) {
  e <- eps$eps[eps$role == "resident" & eps$trait == trait & eps$unit != "curvature in lma"]
  max(if (length(e)) e[1] else NA, 0.01, na.rm = TRUE)
}
h <- function(n) readRDS(file.path(D, "headline", "runs", n))
q108 <- h("stack_long-drought.rds"); q215 <- h("stack_u215_long-drought.rds")
ref_lnJ <- log(q215$J) + (log(q215$J) - log(q108$J)) / 3
ref_el <- q215$elasticity + (q215$elasticity - q108$elasticity) / 3
prev <- NA
for (c in c("brute", "halved", "cut", "preset", "alone", "window")) {
  f <- file.path(O, paste0(c, ".rds"))
  if (!file.exists(f)) { cat(c, "not run\n"); next }
  x <- readRDS(f)
  tot <- x$forward_secs + x$gradient_secs
  tr <- sub("^1\\.", "", names(x$elasticity))
  m <- abs(x$elasticity - ref_el[names(x$elasticity)]) / vapply(tr, eps_of, 0)
  cat(sprintf("%-7s forward %6.1f s, gradient %6.1f s, total %6.1f s (change %+7.1f), %5d steps; ln J %+.3f eps; elasticities median %.3f, largest %.3f eps\n",
              c, x$forward_secs, x$gradient_secs, tot, tot - prev, x$steps,
              (log(x$J) - ref_lnJ) / 0.025, median(m), max(m)))
  if (!is.null(x$pilot_secs))
    cat(sprintf("        pilot %.1f s; window + pilot %.1f s; J against the headline stack's: %s\n",
                x$pilot_secs, tot + x$pilot_secs, if (identical(x$J, q108$J)) "identical" else sprintf("%.3g", x$J / q108$J - 1)))
  prev <- tot
}
