# Where a partitioned run's coupling error sits, from its STEP_LOG: per member
# step, the stages' quadrature of the uptake each member stage evaluated (its
# leaves re-solved) less the held uptake the soil used at the same moisture.
#   PLANT_LIB=... Rscript defects.R out/run.rds
Sys.setenv(NODES = "108", TOL = "3e-5")
suppressMessages(source("/home/user/plant-dev/.claude/worktrees/agent-a4e5afe75b72479f0/harness/long_drought.R"))
f <- commandArgs(TRUE)[1]
r <- readRDS(f)
regime <- if (is.null(r$regime)) Sys.getenv("REGIME", "long-drought") else r$regime
L <- r$steplog
b <- c(37 / 378, 0, 250 / 621, 125 / 594, 0, 512 / 1771)
t0 <- vapply(L, `[[`, 0, "t0")
h <- vapply(L, `[[`, 0, "h")
D <- t(vapply(L, function(x) x$h * colSums(b * x$defect), numeric(5)))
U <- t(vapply(L, function(x) x$h * colSums(b * x$true_up), numeric(5)))
env <- mkenv(regime)
rain <- function(t) pmax(0, env$extrinsic_drivers_evaluate_range("rainfall", t))
knots <- sort(unique(active_knots(regime)))
wet <- rain(t0 + h / 2) > 0
# the last onset of rain at or before each step's start
mid <- (knots[-1] + knots[-length(knots)]) / 2
iw <- rain(mid) > 0
onsets <- knots[-length(knots)][iw & !c(FALSE, iw[-length(iw)])]
last_on <- vapply(t0, function(x) { o <- onsets[onsets <= x + 1e-12]; if (length(o)) max(o) else -Inf }, 0)
since <- (t0 - last_on) * 365
band <- cut(since, c(-Inf, 1, 3, 10, 30, Inf), labels = c("<1 d", "1-3 d", "3-10 d", "10-30 d", ">30 d"), right = FALSE)
cat(sprintf("%s: %d steps; total uptake by layer %s (sum %.4g); held - true... the stages' defect (true - held) by layer %s (sum %.4g, %.3g of the uptake)\n",
            basename(f), length(h), paste(sprintf("%.4g", colSums(U)), collapse = " "), sum(U),
            paste(sprintf("%.4g", colSums(D)), collapse = " "), sum(D), sum(D) / sum(U)))
agg <- function(g) {
  data.frame(steps = as.vector(table(g)), days = tapply(h, g, sum) * 365,
             uptake = tapply(rowSums(U), g, sum), defect = tapply(rowSums(D), g, sum),
             abs_defect = tapply(abs(rowSums(D)), g, sum),
             defect_l1 = tapply(D[, 1], g, sum), defect_l5 = tapply(D[, 5], g, sum))
}
cat("by rain at the step's middle:\n"); print(agg(ifelse(wet, "rain", "dry")), digits = 3)
cat("by time since the last rain onset:\n"); print(agg(band), digits = 3)
cat("by five-year window:\n"); print(agg(cut(t0, seq(0, 40, 5), right = FALSE)), digits = 3)
cat(sprintf("step length: median %.3g d, mean %.3g d; defect per step / uptake per step: median %.3g\n",
            median(h) * 365, mean(h) * 365, median(rowSums(D) / pmax(rowSums(U), 1e-300))))
