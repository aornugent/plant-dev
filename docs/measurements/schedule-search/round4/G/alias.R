# alias.R: does an RK step that spans rainfall knots see the rain? For each accepted step,
# the Cash-Karp 5th- and 4th-order quadratures of the floored rainfall spline against its
# exact integral (fine grid). If stages straddle a rain day without landing on it, both
# orders miss the same water and their difference (the error estimate) is ~0.
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
suppressMessages(source("/home/user/plant-dev/harness/long_drought.R"))
scen <- "dry, seed 31"; RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[["dry"]], list(seed = 31L))
days <- seq(0, RAIN_DAYS); y <- rep(rain_record(scen), length.out = length(days))
e <- mkenv(scen); rf <- function(t) pmax(0, e$extrinsic_drivers_evaluate_range("rainfall", t))
cc <- c(0, 1/5, 3/10, 3/5, 1, 7/8); b5 <- c(37/378, 0, 250/621, 125/594, 0, 512/1771); b4 <- c(2825/27648, 0, 18575/48384, 13525/55296, 277/14336, 1/4)
exact_cum <- local({ g <- seq(25, 40, by = 1 / 365 / 64); r <- rf(g); cs <- c(0, cumsum((r[-1] + r[-length(r)]) / 2 * diff(g))); approxfun(g, cs) })
for (n in c("G_out/runs/G_k25_c_dry", "G_out/runs/G_k25w10_c_dry", "adjmap/runs/val_a09_c_dry")) {
  t <- readRDS(file.path(O, paste0(n, ".rds")))$stand$times; i <- which(t[-length(t)] >= 25.2 & t[-1] <= 39.5); a <- t[i]; h <- t[i + 1] - a
  q5 <- q4 <- numeric(length(a)); for (j in seq_along(a)) { r <- rf(a[j] + cc * h[j]); q5[j] <- h[j] * sum(b5 * r); q4[j] <- h[j] * sum(b4 * r) }
  ex <- exact_cum(a + h) - exact_cum(a)
  cat(sprintf("%-26s steps %4d | rain over [%.1f, %.1f]: exact %.4f, RK5 %.4f (%.1f%%), sum |RK5 - exact| %.4f, sum |RK5 - RK4| %.4f\n",
    basename(n), length(a), min(a), max(a + h), sum(ex), sum(q5), 100 * (sum(q5) / sum(ex) - 1), sum(abs(q5 - ex)), sum(abs(q5 - q4)))) }
