# Where a run's accepted steps go against its rainfall record: the rain days and
# the dry intervals between the record's knots, steps against each rain day's
# depth and each dry interval's length, and the steps, rejections and phase times
# against the node count. Reads saved runs only.
#
#   Rscript harness/step_program.R
here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
runs_dir <- file.path(here, "..", "docs", "measurements", "spot-check")
grid_dir <- file.path(here, "..", "docs", "measurements", "creation-grid")
DAY <- 1 / 365

# Each interval between knots, the steps that start in it, and whether rain falls
# in it (the record is daily and piecewise constant).
intervals <- function(x) {
  s <- x$stand
  t0 <- s$times[-length(s$times)]
  k <- sort(unique(c(0, x$knots)))
  depth <- x$rain[pmin(floor(k / DAY + 0.5) + 1, length(x$rain))]
  data.frame(start = k, length = diff(c(k, x$setting$lifetime)) / DAY, depth = depth,
             steps = tabulate(findInterval(t0 + 1e-12, k), nbins = length(k)))
}

cat("== Accepted steps on rain days and in the dry intervals, at 3e-5 on 108 nodes\n")
for (r in c("ld_3e-5", "wet_base", "dry_base", "dry_1e-5", "epi_base", "const_base")) {
  x <- readRDS(file.path(runs_dir, paste0(r, ".rds")))
  a <- x$stand$attempts
  steps <- a[["accepted"]]
  if (length(x$knots) == 0) {
    cat(sprintf("%-10s tol %.0e: %5d steps, %2.0f%% of attempts rejected; no knots\n", r, x$setting$tol,
                steps, 100 * a[["rejected_inaccurate"]] / (steps + a[["rejected_inaccurate"]])))
    next
  }
  d <- intervals(x); rain <- d$depth > 0
  cat(sprintf("%-10s tol %.0e: %5d steps, %2.0f%% of attempts rejected | %4d rain days hold %2.0f%%, %.1f each | %4d dry intervals %.1f each\n",
              r, x$setting$tol, steps, 100 * a[["rejected_inaccurate"]] / (steps + a[["rejected_inaccurate"]]),
              sum(rain), 100 * sum(d$steps[rain]) / sum(d$steps), mean(d$steps[rain]),
              sum(!rain), mean(d$steps[!rain])))
}

x <- readRDS(file.path(runs_dir, "ld_3e-5.rds")); d <- intervals(x)
day <- d$depth > 0 & d$length <= 1.5
q <- cut(d$depth[day], quantile(d$depth[day], 0:4 / 4), include.lowest = TRUE)
cat("long drought, steps per rain day by its depth (mm) quartile:",
    paste(sprintf("%s %.1f", levels(q), tapply(d$steps[day], q, mean)), collapse = "; "), "\n")
dry <- d$depth == 0
fit <- lm(steps ~ log(length), data = d[dry, ])
cat(sprintf("long drought, a dry interval's steps: %.2f + %.2f ln(its length in days), R2 %.2f\n",
            coef(fit)[1], coef(fit)[2], summary(fit)$r.squared))

cat("\n== Long drought at 3e-5: steps, rejections and phase seconds against the node count\n")
ladder <- c(u54 = file.path(grid_dir, "ld_u54.rds"), u108 = file.path(runs_dir, "ld_3e-5.rds"),
            u215 = file.path(runs_dir, "ld_n215.rds"), u429 = file.path(grid_dir, "ld_u429_full.rds"),
            G1 = file.path(grid_dir, "ld_G1_full.rds"), G3 = file.path(grid_dir, "ld_G3_full.rds"))
for (g in names(ladder)) {
  x <- readRDS(ladder[[g]]); a <- x$stand$attempts
  ph <- if (length(x$phases)) paste(sprintf("%s %.0f", names(x$phases), vapply(x$phases, `[[`, 0, "secs")), collapse = ", ") else ""
  cat(sprintf("%-5s %4d nodes: %5d steps, %4d rejected | %s\n", g, length(x$node_times), a[["accepted"]],
              a[["rejected_inaccurate"]], ph))
}
