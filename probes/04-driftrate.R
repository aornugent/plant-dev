# Does the conservation drift behave like a quadrature error (rate proportional
# to the gap width) or like a missing term (rate independent of it)?  Drift
# accumulated between recorded times is divided by the elapsed time to give a
# rate, because recorded intervals span 1e-5 to 2 years.
suppressMessages({library(plant); library(dplyr)})
setwd("/home/user/plant-dev")

rate_table <- function(nm) {
  r <- readRDS(sprintf("probes/out/baseline-%s.rds", nm))
  d <- r$species |> arrange(time, node) |> group_by(time) |>
    mutate(h_below = c(height[-1], r$height_0),
           lowest = node == max(node),
           dh = height - h_below, N = density * dh) |> ungroup() |>
    filter(!lowest, is.finite(log_density), N > 0) |>
    arrange(node, time) |> group_by(node) |>
    mutate(drift = log(N) - lag(log(N)) + (mortality - lag(mortality)),
           dt = time - lag(time)) |> ungroup() |>
    filter(is.finite(drift), dt > 0)
  d$rate <- d$drift / d$dt
  d
}

for (nm in c("TF24", "FF16", "K93")) {
  d <- rate_table(nm)
  d$bin <- cut(d$dh, 10^c(-Inf, -5, -4, -3, -2, -1, Inf))
  tab <- d |> group_by(bin) |> summarise(n = n(), med_dh = median(dh),
          med_rate = median(rate), mean_rate = mean(rate), .groups = "drop")
  cat("\n===", nm, "=== drift RATE (per year) by gap width\n")
  print(as.data.frame(tab), digits = 3)
  ok <- is.finite(log(d$dh)) & is.finite(log(abs(d$rate))) & d$dh > 0 & d$rate != 0
  if (sum(ok) > 30) {
    fit <- lm(log(abs(rate)) ~ log(dh), data = d[ok, ])
    cat(sprintf("  slope of log|rate| on log(dh): %.3f   (1 = quadrature error, 0 = missing term)   R2=%.3f\n",
                coef(fit)[2], summary(fit)$r.squared))
  }
}
