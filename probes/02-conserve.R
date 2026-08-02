# Count conservation under the sub-grid stencil, and a description of what the
# TF24 baseline stand actually does.  N_j = exp(log_density_j) * (h_j - h_below),
# lowest cohort closing on height_0; mortality is a state, so log N + mortality
# is constant per cohort if individuals are conserved between characteristics.
suppressMessages({library(plant); library(dplyr)})
setwd("/home/user/plant-dev")

counts <- function(r) {
  s <- r$species
  s <- s[order(s$time, s$node), ]
  split(s, s$time) |> lapply(function(d) {
    h_below <- c(d$height[-1], r$height_0)
    d$dh <- d$height - h_below
    d$N  <- exp(d$log_density) * d$dh
    d
  }) |> bind_rows()
}

audit <- function(r) {
  d <- counts(r)
  d <- d[is.finite(d$log_density) & d$N > 0, ]
  d <- d |> arrange(node, time) |> group_by(node) |>
    mutate(drift = log(N) - lag(log(N)) + (mortality - lag(mortality))) |>
    ungroup()
  per <- d |> filter(is.finite(drift)) |> group_by(node) |>
    summarise(tot = sum(drift), .groups = "drop")
  list(summed = sum(per$tot),
       worst  = exp(max(abs(per$tot))),
       worst_node = per$node[which.max(abs(per$tot))],
       n_pairs = sum(is.finite(d$drift)),
       d = d)
}

for (nm in c("TF24", "FF16", "K93")) {
  r <- readRDS(sprintf("probes/out/baseline-%s.rds", nm))
  a <- audit(r)
  cat(sprintf("%-5s summed drift = %+10.4g   worst cohort = %6.3gx (node %d)   pairs=%d\n",
              nm, a$summed, a$worst, a$worst_node, a$n_pairs))
}

cat("\n--- what the TF24 stand does ---\n")
r <- readRDS("probes/out/baseline-TF24.rds")
d <- counts(r)
g <- d |> group_by(time) |>
  summarise(n_nodes = n(), h_max = max(height), h_min = min(height),
            N_tot = sum(N[is.finite(N)]),
            dens_max = max(density[is.finite(density)]),
            stor_min = min(storage), .groups = "drop")
print(as.data.frame(g[round(seq(1, nrow(g), length.out = 14)), ]), digits = 4)

cat("\n--- gap widths (dh) over the whole run ---\n")
dh <- d$dh
cat(sprintf("min=%.3g  median=%.3g  frac<1e-4=%.3f  frac<=0=%.4f  n=%d\n",
            min(dh), median(dh), mean(dh < 1e-4), mean(dh <= 0), length(dh)))
cat("non-descending pairs (dh<0):", sum(dh < 0), "  min dh:", min(dh), "\n")
nd <- d[d$dh < 0, ]
if (nrow(nd)) {
  cat("  are they the boundary (lowest) node?\n")
  low <- d |> group_by(time) |> summarise(lowest = max(node), .groups="drop")
  nd2 <- left_join(nd, low, by = "time")
  cat("  at lowest node:", sum(nd2$node == nd2$lowest), "of", nrow(nd2), "\n")
}
saveRDS(d, "probes/out/counts-TF24.rds")
