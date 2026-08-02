# Report 11 predicts the missing term is (dg/ds)(ds/dh) = (dg/ds) f/g, which
# diverges like 1/g wherever growth stalls.  Test that directly: the realised
# growth rate over each recorded interval, against the conservation drift rate.
suppressMessages({library(plant); library(dplyr)})
setwd("/home/user/plant-dev")

r <- readRDS("probes/out/baseline-TF24.rds")
p <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
s1 <- p$strategies[[1]]

d <- r$species |> arrange(time, node) |> group_by(time) |>
  mutate(h_below = c(height[-1], r$height_0), lowest = node == max(node),
         dh = height - h_below, N = density * dh) |> ungroup()

al <- plant:::TF24_strategy_expand_allometry(s1, d$height, d$area_heartwood, d$mass_heartwood)
d$mass_sapwood <- al$mass_sapwood
d$S_max <- s1$pars$a_st1 * d$mass_sapwood
d$rel  <- pmin(pmax(d$storage, 0) / d$S_max, 1)
d$gate <- 1 / (1 + exp(-(d$rel - s1$pars$a_st2) / 0.1))

d <- d |> filter(!lowest, is.finite(log_density), N > 0) |>
  arrange(node, time) |> group_by(node) |>
  mutate(drift = log(N) - lag(log(N)) + (mortality - lag(mortality)),
         dt = time - lag(time), g = (height - lag(height)) / dt) |> ungroup() |>
  filter(is.finite(drift), dt > 0, is.finite(g))
d$rate <- d$drift / d$dt

cat("reserve fraction r over the run:\n")
print(summary(d$rel), digits = 3)
cat("growth gate G:\n"); print(summary(d$gate), digits = 3)
cat(sprintf("frac of cohort-times with r pinned at 0: %.3f\n", mean(d$rel <= 0)))
cat(sprintf("frac with g <= 0 (not growing): %.3f\n", mean(d$g <= 0)))

cat("\n--- drift rate vs realised growth rate ---\n")
pos <- d |> filter(g > 0)
pos$gbin <- cut(pos$g, c(0, 1e-4, 1e-3, 1e-2, 1e-1, Inf))
print(as.data.frame(pos |> group_by(gbin) |>
  summarise(n = n(), med_g = median(g), med_rate = median(rate),
            med_absrate = median(abs(rate)), med_dh = median(dh),
            med_r = median(rel), .groups = "drop")), digits = 3)
ok <- pos$rate != 0
fit <- lm(log(abs(rate)) ~ log(g), data = pos[ok, ])
cat(sprintf("slope of log|drift rate| on log(g): %.3f  (report 11 predicts -1)  R2=%.3f  n=%d\n",
            coef(fit)[2], summary(fit)$r.squared, sum(ok)))

cat("\n--- and against the gap width, for comparison ---\n")
fit2 <- lm(log(abs(rate)) ~ log(dh), data = pos[ok & pos$dh > 0, ])
cat(sprintf("slope on log(dh): %.3f  R2=%.3f\n", coef(fit2)[2], summary(fit2)$r.squared))
fit3 <- lm(log(abs(rate)) ~ log(g) + log(dh), data = pos[ok & pos$dh > 0, ])
cat("joint model coefficients:\n"); print(round(coef(fit3), 3))
cat(sprintf("joint R2=%.3f\n", summary(fit3)$r.squared))
saveRDS(d, "probes/out/divergence-TF24.rds")
