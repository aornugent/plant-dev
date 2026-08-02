# Conservation, done carefully.  The lowest cohort's interval is bounded below
# by the fixed inflow boundary, not by a characteristic, so plants flow into it:
# it is excluded.  Interior intervals lie between two characteristics and no
# plant can cross either, so log N + mortality must be constant.
suppressMessages({library(plant); library(dplyr)})
setwd("/home/user/plant-dev")

prep <- function(r) {
  s <- r$species |> arrange(time, node)
  s |> group_by(time) |> mutate(
        h_below = c(height[-1], r$height_0),
        lowest  = node == max(node),
        dh      = height - h_below,
        N       = density * dh) |> ungroup()
}

audit <- function(r, label) {
  d <- prep(r) |> filter(!lowest, is.finite(log_density), N > 0) |>
    arrange(node, time) |> group_by(node) |>
    mutate(drift = log(N) - lag(log(N)) + (mortality - lag(mortality))) |>
    ungroup() |> filter(is.finite(drift))
  per <- d |> group_by(node) |> summarise(tot = sum(drift), .groups = "drop")
  cat(sprintf("%-5s interior: summed=%+9.4g  worst cohort=%8.4gx (node %d)  pairs=%d\n",
              label, sum(per$tot), exp(max(abs(per$tot))),
              per$node[which.max(abs(per$tot))], nrow(d)))
  invisible(d)
}

dd <- list()
for (nm in c("TF24", "FF16", "K93")) {
  r <- readRDS(sprintf("probes/out/baseline-%s.rds", nm))
  dd[[nm]] <- audit(r, nm)
}

cat("\n--- TF24: where the drift lives ---\n")
d <- dd[["TF24"]]
byt <- d |> group_by(time) |> summarise(drift = sum(drift), .groups = "drop") |>
  arrange(desc(abs(drift)))
cat("top 8 times by |summed drift|:\n"); print(as.data.frame(head(byt, 8)), digits = 4)
cat("\ndrift vs gap width (interior pairs):\n")
d$bin <- cut(d$dh, c(-Inf, 1e-5, 1e-4, 1e-3, 1e-2, Inf))
print(as.data.frame(d |> group_by(bin) |>
  summarise(n = n(), mean_drift = mean(drift), sum_drift = sum(drift),
            max_abs = max(abs(drift)), .groups = "drop")), digits = 4)

cat("\n--- storage leaving [0, S_max] ---\n")
for (nm in c("TF24")) {
  r <- readRDS(sprintf("probes/out/baseline-%s.rds", nm))
  s <- r$species
  cat(sprintf("%s: min storage=%.4g  frac(storage<0)=%.4f  n rows=%d\n",
              nm, min(s$storage), mean(s$storage < 0), nrow(s)))
  neg <- s[s$storage < 0, ]
  cat(sprintf("   first time storage<0: %.4g   distinct nodes affected: %d\n",
              min(neg$time), length(unique(neg$node))))
}
