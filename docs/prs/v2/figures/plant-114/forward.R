# plant-114 performance: forward CPU of the synthetic record's stand on B97
# (no sort) and B107 (sort), five interleaved pairs (forward-run.csv).
library(ggplot2)
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-114"
d <- read.csv(file.path(here, "forward-run.csv"))
d$arm <- ifelse(d$build == "B97", "B97: every crown at every knot", "B107: sorted, running total")
d$arm <- factor(d$arm, levels = c("B97: every crown at every knot", "B107: sorted, running total"))
m <- aggregate(cpu_s ~ arm, d, median)
p <- ggplot(d, aes(arm, cpu_s)) +
  geom_line(aes(group = rep), colour = "grey75") +
  geom_point(aes(colour = arm), size = 3) +
  geom_errorbar(data = m, aes(ymin = cpu_s, ymax = cpu_s), width = 0.25, colour = "grey20") +
  scale_colour_manual(values = c("#D55E00", "#0072B2"), guide = "none") +
  labs(x = NULL, y = "forward run, user + system CPU (s)",
       title = sprintf("The sort cuts forward CPU by %.1f%% (medians); four of five pairs by 4-6%%",
                       -100 * (m$cpu_s[2] / m$cpu_s[1] - 1)),
       subtitle = "Synthetic record's stand, 429 introductions, ode_tol 1e-4, 12 016 steps on both;\nrun order B97, B107, five times; lines join each pair, bars mark medians;\nthe axis does not start at 0") +
  theme_minimal(base_size = 12) + theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot")
ragg::agg_png(file.path(here, "forward.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p); invisible(dev.off())
w <- reshape(d[, c("rep", "build", "cpu_s")], idvar = "rep", timevar = "build", direction = "wide")
cat(sprintf("pairs B107/B97 - 1: %s; J identical across builds: %s; accepted %s\n",
            paste(sprintf("%+.1f%%", 100 * (w$cpu_s.B107 / w$cpu_s.B97 - 1)), collapse = " "),
            paste(unique(d$J), collapse = " vs "), paste(unique(d$accepted), collapse = "/")))
