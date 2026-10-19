# plant-113: the rate the storage pool relaxes at, lambda/(1 + lambda o), against
# its own rate lambda, for several offsets o, with the largest rate an explicit
# Cash-Karp step of size h keeps stable (|R(-h rate)| <= 1 to h rate = 3.73) at
# the synthetic run's median and 90th-percentile accepted step (offset-run.csv,
# B97, offset 7 d). The rug is the lambda of every cohort under 1 m at each
# stop of the first 12 years of that run (relax-run.csv). Writes relax.csv.
library(ggplot2)
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-113"
A <- matrix(0, 6, 6); A[2, 1] <- 1/5; A[3, 1:2] <- c(3/40, 9/40)
A[4, 1:3] <- c(3/10, -9/10, 6/5); A[5, 1:4] <- c(-11/54, 5/2, -70/27, 35/27)
A[6, 1:5] <- c(1631/55296, 175/512, 575/13824, 44275/110592, 253/4096)
b <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)
R <- function(z) 1 + z * sum(b * solve(diag(6) - z * A, rep(1, 6)))
y <- seq(0, 6, by = 1e-4)
limit <- y[which(abs(vapply(-y, R, 0)) > 1)[1] - 1]
stage_ok <- y[which(vapply(-y, function(z) min(solve(diag(6) - z * A, rep(1, 6))), 0) < 0)[1] - 1]
runs <- read.csv(file.path(here, "offset-run.csv"))
s7 <- runs[runs$scenario == "synthetic" & runs$offset_days %in% 7, ][1, ]
steps <- c(median = s7$median_step_d, p90 = s7$p90_step_d)
lam <- 10^seq(0, 4, length.out = 400)
curves <- do.call(rbind, lapply(c(0, 1, 3, 7, 28), function(o)
  data.frame(offset_days = o, lambda = lam, rate = lam / (1 + lam * o / 365))))
write.csv(curves, file.path(here, "relax.csv"), row.names = FALSE)
seen <- read.csv(file.path(here, "relax-run.csv"))
hl <- data.frame(h = steps, rate = limit * 365 / steps,
                 label = sprintf("stable limit at the %s step, %.1f d", c("median", "90th-percentile"), steps))
ends <- curves[curves$lambda == max(lam), ]
ends$label <- ifelse(ends$offset_days == 0, "offset 0", sprintf("%g d", ends$offset_days))
pal <- c("0" = "#D55E00", "1" = "#E69F00", "3" = "#009E73", "7" = "#0072B2", "28" = "#CC79A7")
p <- ggplot(curves, aes(lambda, rate, colour = factor(offset_days))) +
  geom_hline(data = hl, aes(yintercept = rate), linetype = 2, colour = "grey45") +
  geom_text(data = hl, aes(x = 1, y = rate, label = label), inherit.aes = FALSE,
            hjust = 0, vjust = -0.4, size = 3.3, colour = "grey30") +
  geom_line(linewidth = 0.9) +
  geom_rug(data = seen, aes(x = lambda), inherit.aes = FALSE, sides = "b", alpha = 0.08,
           length = unit(0.03, "npc")) +
  geom_text(data = ends, aes(label = label), hjust = -0.1, size = 3.5, show.legend = FALSE) +
  scale_x_log10(breaks = 10^(0:4), labels = c("1", "10", "100", "1000", "10 000"),
                expand = expansion(mult = c(0.02, 0.12))) +
  scale_y_log10(breaks = 10^(0:4), labels = c("1", "10", "100", "1000", "10 000")) +
  scale_colour_manual(values = pal, guide = "none") +
  labs(x = expression("the pool's own rate " * lambda * " = (charge + drain) / storage_max  (yr"^-1*")"),
       y = expression("rate it relaxes at, " * lambda / (1 + lambda * o) * "  (yr"^-1*")"),
       title = "The offset caps the pool's rate at 1/o, below an explicit step's limit",
       subtitle = sprintf(paste("Cash-Karp: stable to h x rate = %.2f, stages non-negative to %.2f; dashed: steps of the",
                                "\nsynthetic record's stand on B97; rug: lambda of its cohorts under 1 m, first 12 years"),
                          limit, stage_ok)) +
  theme_minimal(base_size = 12) + theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot")
ragg::agg_png(file.path(here, "relax.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p); invisible(dev.off())
cat(sprintf("limit %.4f, stages %.4f; steps %s d; lambda quantiles 50/90/99/max %s\n", limit, stage_ok,
            paste(sprintf("%.2f", steps), collapse = "/"),
            paste(sprintf("%.0f", quantile(seen$lambda, c(.5, .9, .99, 1))), collapse = "/")))
