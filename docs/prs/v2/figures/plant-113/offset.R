# plant-113 performance figure: accepted steps, rejected steps and CPU against the
# relaxation offset, each relative to offset 0 on the same build (B97), and the
# change in ln J from offset 0, on plant's reference regimes and the synthetic
# record's stand (offset-run.csv, from offset-run.R; CPU is the median over
# repeats where a configuration was run more than once).
library(ggplot2)
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-113"
d <- read.csv(file.path(here, "offset-run.csv"))
d <- d[d$build == "B97", ]
a <- aggregate(cbind(J, accepted, rejected, cpu_s) ~ scenario + offset_days, d, median)
base <- a[a$offset_days == 0, ]
m <- merge(a, base, by = "scenario", suffixes = c("", "0"))
long <- rbind(
  data.frame(m[, c("scenario", "offset_days")], metric = "accepted steps / offset 0", value = m$accepted / m$accepted0),
  data.frame(m[, c("scenario", "offset_days")], metric = "rejected steps / offset 0", value = m$rejected / m$rejected0),
  data.frame(m[, c("scenario", "offset_days")], metric = "CPU / offset 0", value = m$cpu_s / m$cpu_s0),
  data.frame(m[, c("scenario", "offset_days")], metric = "ln J - ln J at offset 0", value = log(m$J) - log(m$J0)))
long$metric <- factor(long$metric, levels = unique(long$metric))
long$scenario <- factor(long$scenario, levels = c("synthetic", "wet", "drought", "seasonal", "shaded", "clamped"))
write.csv(long, file.path(here, "offset.csv"), row.names = FALSE)
pal <- c(synthetic = "#000000", wet = "#0072B2", drought = "#D55E00", seasonal = "#009E73",
         shaded = "#CC79A7", clamped = "#E69F00")
ends <- long[long$offset_days == 28, ]
eps <- data.frame(metric = factor("ln J - ln J at offset 0", levels = levels(long$metric)),
                  y = c(-0.025, 0.025))
p <- ggplot(long, aes(offset_days, value, colour = scenario)) +
  geom_vline(xintercept = 7, colour = "grey80", linewidth = 2) +
  geom_hline(data = eps, aes(yintercept = y), linetype = 3, colour = "grey50") +
  geom_line(linewidth = 0.7) + geom_point(size = 1.6) +
  geom_text(data = ends[ends$metric == "accepted steps / offset 0", ], aes(label = scenario),
            hjust = -0.15, size = 3, show.legend = FALSE) +
  facet_wrap(~metric, scales = "free_y", nrow = 1) +
  scale_x_continuous(breaks = c(0, 7, 14, 28), expand = expansion(mult = c(0.05, 0.35))) +
  scale_colour_manual(values = pal, guide = "none") +
  labs(x = "storage_relaxation_offset (days)", y = NULL,
       title = "A week's offset removes most rejected steps and costs little in J",
       subtitle = paste("B97; synthetic: 40-yr stand, 108 introductions, ode_tol 1e-3; regimes: 10-yr stands,",
                        "93 introductions, ode_tol 1e-4;\ndotted: ln J's tolerance 0.025; grey bar: the default, 7 d")) +
  theme_minimal(base_size = 11) +
  theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot", strip.text = element_text(size = 9.5))
ragg::agg_png(file.path(here, "offset.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p); invisible(dev.off())
print(reshape(a[, c("scenario", "offset_days", "accepted", "rejected", "cpu_s")], idvar = "scenario",
              timevar = "offset_days", direction = "wide"))
