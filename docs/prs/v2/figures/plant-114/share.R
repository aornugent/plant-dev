# plant-114: the share of stops at which the cohorts' heights are out of order,
# by year of the run (crossing-share.csv, from crossing-run.R on B97). Each stop
# is an introduction or a rain knot, and the light is built from the heights
# there at the next stage.
library(ggplot2)
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-114"
d <- read.csv(file.path(here, "crossing-share.csv"))
d$year <- pmin(39, floor(d$t)) + 1
y <- aggregate(cbind(out = pairs_out_of_order > 0, n = 1) ~ year, d, sum)
y$share <- y$out / y$n
p <- ggplot(y, aes(year, share)) +
  geom_col(fill = "#D55E00", width = 0.85) +
  scale_y_continuous(labels = function(x) paste0(round(100 * x), "%"), limits = c(0, 1)) +
  labs(x = "year of the run", y = "stops with heights out of order",
       title = sprintf("Crowns stay crossed for most of the run once they first cross (%.0f%% of stops)",
                       100 * mean(d$pairs_out_of_order > 0)),
       subtitle = sprintf(paste("Synthetic record's stand, 108 introductions, ode_tol 1e-3, B97;",
                                "%d stops (introductions and rain knots), at most %d pairs at once"),
                          nrow(d), max(d$pairs_out_of_order))) +
  theme_minimal(base_size = 12) + theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot")
ragg::agg_png(file.path(here, "share.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p); invisible(dev.off())
write.csv(y, file.path(here, "share.csv"), row.names = FALSE)
