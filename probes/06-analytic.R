# The drift rate is exactly (cohort-grid stencil) - (sub-grid stencil):
#   d(log N)/dt + mortality = (g_i - g_below)/dh - dg/dh|_S
# and the limit of the first term is the total derivative along the cohort
# curve.  So the difference should equal (dg/dS)(dS/dh) with dS/dh = f/g.
# For TF24, g = C(h) Ppos(h) G(r), so dg/dS = g (1-G) / (w S_max) and the
# growth rate cancels:  difference = (1-G) f / (w S_max).  Test that.
suppressMessages({library(plant); library(dplyr)})
setwd("/home/user/plant-dev")

r  <- readRDS("probes/out/baseline-TF24.rds")
p  <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
s1 <- p$strategies[[1]]
w  <- 0.1                      # storage_gate_width

d <- r$species |> arrange(time, node) |> group_by(time) |>
  mutate(h_below = c(height[-1], r$height_0), lowest = node == max(node),
         dh = height - h_below, N = density * dh) |> ungroup()
al <- plant:::TF24_strategy_expand_allometry(s1, d$height, d$area_heartwood, d$mass_heartwood)
d$S_max <- s1$pars$a_st1 * al$mass_sapwood
d$rel   <- pmin(pmax(d$storage, 0) / d$S_max, 1)
d$G     <- 1 / (1 + exp(-(d$rel - s1$pars$a_st2) / w))

d <- d |> filter(!lowest, is.finite(log_density), N > 0) |>
  arrange(node, time) |> group_by(node) |>
  mutate(drift = log(N) - lag(log(N)) + (mortality - lag(mortality)),
         dt = time - lag(time),
         g  = (height  - lag(height))  / dt,
         f  = (storage - lag(storage)) / dt) |> ungroup() |>
  filter(is.finite(drift), dt > 0, is.finite(g), is.finite(f))
d$rate <- d$drift / d$dt
# predict with midpoint values of the interval
d$pred <- (1 - d$G) * d$f / (w * d$S_max)

ok <- is.finite(d$pred) & is.finite(d$rate)
cat(sprintf("n = %d\n", sum(ok)))
cat(sprintf("Pearson  cor(pred, rate)      = %.4f\n", cor(d$pred[ok], d$rate[ok])))
cat(sprintf("Spearman cor(pred, rate)      = %.4f\n",
            cor(d$pred[ok], d$rate[ok], method = "spearman")))
fit <- lm(rate ~ pred, data = d[ok, ])
cat(sprintf("regression rate ~ pred: slope=%.4f  intercept=%.4g  R2=%.4f\n",
            coef(fit)[2], coef(fit)[1], summary(fit)$r.squared))
cat(sprintf("sign agreement: %.3f\n", mean(sign(d$pred[ok]) == sign(d$rate[ok]))))
cat(sprintf("sum(measured)=%.4g   sum(predicted)=%.4g\n",
            sum(d$rate[ok]*d$dt[ok]), sum(d$pred[ok]*d$dt[ok])))

cat("\n--- does the 1/g divergence exist? drift rate at stalls ---\n")
d$gb <- cut(d$g, c(-Inf, 1e-8, 1e-4, 1e-2, 1, Inf))
print(as.data.frame(d[ok,] |> group_by(gb) |> summarise(n=n(),
   med_g=median(g), med_absrate=median(abs(rate)), med_abspred=median(abs(pred)),
   med_G=median(G), .groups="drop")), digits=3)

cat("\n--- how much of g's own variation does (1-G) explain? ---\n")
cat(sprintf("cor(log|rate|, log(1-G)) = %.3f\n",
   cor(log(abs(d$rate[ok & d$rate!=0])), log(1-d$G[ok & d$rate!=0]))))
saveRDS(d, "probes/out/analytic-TF24.rds")
