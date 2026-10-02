# What share of J is still to be earned after each time, R(t), against where the
# forward's cost falls: the share of its accepted steps, and of its member-steps
# (each step counted once per node it carries), that start after that time.
# A step or a node born after t can change J only through what is earned after
# t, so R(t) bounds the weight of the errors made there.
#
# R(t) comes from harness/layer_heights.R run with BORN_BEFORE past the last
# introduction, and the cost from the saved run on the same schedule: uniform
# 108, and on the constant record, where uniform nodes lump the founders, its
# resolved grid const_Gbf16 (docs/measurements/creation-grid.md).
#
# Then the test on the driver (harness/ark_prototype.R), from its logs in
# DRIVER: the tied baseline at 3e-5, and the same with every tolerance weight
# x100 on steps after t = 25 (LATE_FROM). Each gives J against the reference,
# the steps, the member evaluations, and J's elasticity in the trait lma by
# central differences at 1e-5 on the run's own accepted steps, replayed
# (PROGRAM with THETA). That moves lma through TF24's hyperparameterisation, so
# it is not stand_gradient's lma.
#
#   PLANT_LIB=... [OUT=window.rds] [DRIVER=docs/measurements/grid-dynamics] \
#     Rscript harness/j_window.R long-drought=a.rds [constant=b.rds ...]
#
# A file on another schedule than the saved run's, such as a pilot's, gets R(t)
# and no cost.
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
runs <- c("long-drought" = "spot-check/ld_3e-5.rds", "long-wet" = "spot-check/wet_base.rds",
          dry = "spot-check/dry_base.rds", episodic = "spot-check/epi_base.rds",
          constant = "creation-grid/const_Gbf16_full.rds")
patches <- Weibull_Disturbance_Regime(LIFETIME)
at <- c(15, 20, 25, 30, 35)
bands <- c(0, 3.6, 10, 20, 25, LIFETIME)

args <- commandArgs(TRUE)
files <- sub("^[^=]*=", "", args)
names(files) <- sub("=.*$", "", args)
out <- list()
for (i in seq_along(files)) {
  r <- names(files)[i]
  x <- readRDS(files[[i]])
  stopifnot(length(x$times) == length(x$nrr))
  d <- x$w * vapply(x$times, patches$density, 0)
  earned <- apply(x$offspring, 1, function(o) sum(d * o, na.rm = TRUE)) / sum(d * x$nrr)
  R <- 1 - earned
  run <- readRDS(file.path("docs", "measurements", runs[[r]]))
  share <- tapply(d * x$nrr, cut(x$times, bands, right = FALSE), sum) / sum(d * x$nrr)
  cost <- ""
  if (isTRUE(all.equal(run$node_times, x$times))) {
    t0 <- head(run$stand$times, -1)
    carried <- findInterval(t0, run$node_times)
    cost <- sprintf(" | steps after t: %s | member-steps: %s",
                    paste(sprintf("%.0f%%", 100 * vapply(at, function(t) mean(t0 >= t), 0)), collapse = " "),
                    paste(sprintf("%.0f%%", 100 * vapply(at, function(t) sum(carried[t0 >= t]) / sum(carried), 0)),
                          collapse = " "))
  }
  cat(sprintf("%-12s %d nodes, J %.5g | R(t) at t = %s: %s%s\n",
              r, length(x$times), x$J, paste(at, collapse = "/"),
              paste(sprintf("%.3g%%", 100 * R[match(at, round(x$grid, 2))]), collapse = " "), cost))
  by <- vapply(c(0.99, 0.5, 0.01), function(p) x$grid[which(R <= p)[1]], 0)
  cat(sprintf("%-12s 1%%, 50%% and 99%% of J earned by t = %s | J's share by birth date in %s: %s\n", "",
              paste(sprintf("%.2f", by), collapse = ", "), paste(names(share), collapse = " "),
              paste(signif(share, 3), collapse = " ")))
  out[[basename(files[[i]])]] <- list(record = r, grid = x$grid, R = R, share = share)
}
if (nzchar(Sys.getenv("OUT"))) saveRDS(out, Sys.getenv("OUT"))

driver_dir <- Sys.getenv("DRIVER", file.path("docs", "measurements", "grid-dynamics"))
# Long drought's reference is Cash-Karp at 1e-8 (docs/design-grid-controller.md);
# the constant record's is the driver's tied run at 1e-8.
tests <- list("long-drought" = c(base = "tied_3e-5_soil1", late = "tied_3e-5_late25"),
              constant = c(base = "ck_const_Gbf16_3e-5", late = "ck_const_Gbf16_3e-5_late25",
                           ref = "ck_const_Gbf16_1e-8"))
logged <- function(f, pattern) {
  l <- paste(readLines(file.path(driver_dir, paste0(f, ".log"))), collapse = "\n")
  as.numeric(regmatches(l, regexec(pattern, l))[[1]][2])
}
J_of <- function(f) logged(f, "J ([0-9.]+),")
elasticity <- function(prog) {
  u <- 1e-5
  log(J_of(sprintf("frozen_%s_1e-5", prog)) / J_of(sprintf("frozen_%s_-1e-5", prog))) /
    (log1p(u) - log1p(-u))
}
for (r in names(tests)) {
  f <- tests[[r]]
  need <- c(f, sprintf("frozen_%s_%s", rep(f[c("base", "late")], each = 2), c("1e-5", "-1e-5")))
  if (!all(file.exists(file.path(driver_dir, paste0(need, ".log"))))) next
  ref <- if (is.na(f["ref"])) 12.6687135 else J_of(f[["ref"]])
  for (k in c("base", "late"))
    cat(sprintf("%-12s %-4s %5d accepted, %.3g member evaluations | J - J* %+.3g relative | lma trait elasticity on its own steps %.5f\n",
                r, k, logged(f[[k]], "([0-9]+) accepted"), logged(f[[k]], "member evaluations ([0-9]+)"),
                J_of(f[[k]]) / ref - 1, elasticity(f[[k]])))
}
