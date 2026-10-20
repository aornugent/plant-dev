# plant-114: how many pairs of cohorts are out of height order at each stop of
# the run (crossing-share.csv, from crossing-run.R on B97, 429 introductions,
# ode_tol 1e-4). Each stop is an introduction or a rain knot; every light
# build between two stops sees the heights moving between those two states.
library(ggplot2)
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-114"
d <- read.csv(file.path(here, "crossing-share.csv"))
first <- min(d$t[d$pairs_out_of_order > 0])
after <- d[d$t >= first, ]
p <- ggplot(d, aes(t, pairs_out_of_order)) +
  geom_step(colour = "#D55E00", linewidth = 0.6) +
  annotate("text", x = 0.5, y = 4.6, hjust = 0, size = 3.5, colour = "grey25",
           label = sprintf("first crossed at t = %.2f yr;\n%.0f%% of the stops after it\nhave at least one pair",
                           first, 100 * mean(after$pairs_out_of_order > 0))) +
  scale_y_continuous(breaks = 0:5, limits = c(0, 5.2)) +
  labs(x = "time (yr)", y = "pairs out of height order",
       title = sprintf("Crossed pairs accumulate and never uncross: %.0f%% of stops have one", 100 * mean(d$pairs_out_of_order > 0)),
       subtitle = sprintf(paste("Synthetic record's stand, 429 introductions, ode_tol 1e-4, before this PR;",
                                "\n%d stops, at each introduction and rain knot"), nrow(d))) +
  theme_minimal(base_size = 12) +
  theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot")
ragg::agg_png(file.path(here, "share.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p); invisible(dev.off())
cat(sprintf("stops %d, out of order %d (%.1f%%), first %.3f, after first %.1f%%, most %d\n", nrow(d),
            sum(d$pairs_out_of_order > 0), 100 * mean(d$pairs_out_of_order > 0), first,
            100 * mean(after$pairs_out_of_order > 0), max(d$pairs_out_of_order)))
