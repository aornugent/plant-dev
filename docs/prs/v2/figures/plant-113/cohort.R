# plant-113 mechanism figure: one real seedling cohort's relative reserve after
# its production turns negative, at a relaxation offset of 7 d against 0.
# Reads cohort-run.csv (cohort-run.R on B97): the cohort's recorded net
# production P(t) and height(t). The pool's rate is TF24's, written out:
#   charge = P+ (1 - G(r)), drain = P+ - P, lambda = (charge + drain)/S_max,
#   dS/dt = (charge (1 - r) - drain r) / (1 + lambda o),
# with P+ = (P + sqrt(P^2 + 1e-8))/2 and G the logistic at a_st2 = 0.1, width
# 0.1. Integrated by RK4 at 5-minute steps from the run's own state at the
# first stop, both offsets driven by the same recorded P and height; the
# offset-7 curve is checked against the run's own storage state.
library(ggplot2)
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-113"
d <- read.csv(file.path(here, "cohort-run.csv"))
d <- d[!duplicated(d$t), ]
Pf <- approxfun(d$t, d$P, rule = 2); Sm <- approxfun(d$t, d$storage_max, rule = 2)
rate <- function(t, S, o) {
  P <- Pf(t); smax <- Sm(t); r <- S / smax
  Pp <- 0.5 * (P + sqrt(P * P + 1e-8)); G <- 1 / (1 + exp(-(r - 0.1) / 0.1))
  charge <- Pp * (1 - G); drain <- Pp - P
  (charge * (1 - r) - drain * r) / (1 + (charge + drain) / smax * o)
}
integrate_pool <- function(o, h = 5 / (60 * 24 * 365)) {
  t <- seq(min(d$t), max(d$t), by = h); S <- numeric(length(t)); S[1] <- d$storage[1]
  for (i in seq_along(t)[-1]) {
    a <- t[i - 1]; y <- S[i - 1]
    k1 <- rate(a, y, o); k2 <- rate(a + h / 2, y + h / 2 * k1, o)
    k3 <- rate(a + h / 2, y + h / 2 * k2, o); k4 <- rate(a + h, y + h * k3, o)
    S[i] <- y + h / 6 * (k1 + 2 * k2 + 2 * k3 + k4)
  }
  data.frame(t = t, r = S / Sm(t), offset = sprintf("%g d", o * 365))
}
t0 <- d$t[which(d$P < 0)[1]]
curves <- rbind(integrate_pool(7 / 365), integrate_pool(0))
# The pool's own relaxation rate lambda = (charge + drain)/S_max along each
# curve, and the rate it relaxes at, lambda/(1 + lambda o).
lam <- function(t, r) { P <- Pf(t); Pp <- 0.5 * (P + sqrt(P * P + 1e-8))
  G <- 1 / (1 + exp(-(r - 0.1) / 0.1)); (Pp * (1 - G) + Pp - P) / Sm(t) }
curves$lambda <- lam(curves$t, curves$r)
curves$relax <- curves$lambda / (1 + curves$lambda * ifelse(curves$offset == "7 d", 7 / 365, 0))
curves$day <- (curves$t - t0) * 365
curves <- curves[curves$day >= -3 & curves$day <= 40, ]
run <- data.frame(day = (d$t - t0) * 365, r = d$storage / d$storage_max)
run <- run[run$day >= -3 & run$day <= 40, ]
write.csv(curves[seq(1, nrow(curves), by = 12), c("day", "offset", "r", "lambda", "relax")], file.path(here, "cohort.csv"), row.names = FALSE)
check <- approx(curves$day[curves$offset == "7 d"], curves$r[curves$offset == "7 d"], run$day)$y
reach <- sapply(split(curves, curves$offset), function(x) {
  x <- x[x$day >= 0, ]; x$day[which(x$r <= 1 / 20)[1]] })
cat(sprintf("P < 0 from t = %.4f yr; r at the sign change %.3f; days to r = 1/a_dG2 = 0.05: %s; offset-7 curve vs run: max |dr| %.2e\n",
            t0, run$r[which.min(abs(run$day))], paste(names(reach), sprintf("%.2f", reach), collapse = ", "),
            max(abs(check - run$r), na.rm = TRUE)))
for (o in c("0 d", "7 d")) {
  x <- curves[curves$offset == o & curves$day >= 0, ]
  cat(sprintf("offset %s: largest relaxation rate %.0f /yr (time %.1f h) at day %.1f\n", o,
              max(x$relax), 8760 / max(x$relax), x$day[which.max(x$relax)]))
}
lab <- data.frame(day = c(reach[["0 d"]] - 1.8, reach[["7 d"]] + 0.8),
                  r = c(0.03, 0.13), offset = c("0 d", "7 d"), hj = c(1, 0),
                  label = c(sprintf("offset 0: %.1f d", reach[["0 d"]]),
                            sprintf("offset 7 d: %.1f d", reach[["7 d"]])))
pal <- c("0 d" = "#D55E00", "7 d" = "#0072B2")
p <- ggplot(curves, aes(day, r, colour = offset)) +
  geom_hline(yintercept = 0.05, linetype = 2, colour = "grey50") +
  annotate("text", x = 40, y = 0.05, label = "r = 1/a_dG2: low-reserve mortality at 1/e of its maximum",
           hjust = 1, vjust = 1.4, size = 3.3, colour = "grey30") +
  geom_vline(xintercept = 0, colour = "grey70") +
  geom_line(linewidth = 0.9) +
  geom_point(data = run, aes(day, r), inherit.aes = FALSE, colour = "#0072B2", size = 0.9, alpha = 0.6) +
  geom_text(data = lab, aes(label = label, hjust = hj), size = 3.6, show.legend = FALSE) +
  scale_colour_manual(values = pal, guide = "none") +
  scale_y_continuous(limits = c(0, 0.5)) +
  labs(x = "days since the cohort's net production turned negative",
       y = "r = storage / storage_max",
       title = "A 7-day offset slows this seedling's run-down from 8.6 to 21.4 days",
       subtitle = paste0("TF24 cohort born at t = 2.96 yr, synthetic record, this PR; dots: the run (offset 7 d);\n",
                         "lines: its pool integrated from the recorded production at each offset")) +
  theme_minimal(base_size = 12) + theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot")
ragg::agg_png(file.path(here, "cohort.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p); invisible(dev.off())
