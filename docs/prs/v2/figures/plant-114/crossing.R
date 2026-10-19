# plant-114 mechanism figure: the cohorts' heights against birth date at the
# stop where two crowns are furthest out of order (crossing-heights.csv, from
# crossing-run.R on B97), the out-of-order pair marked, with an inset-free zoom
# onto the pair's neighbourhood.
library(ggplot2)
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-114"
d <- read.csv(file.path(here, "crossing-heights.csv"))
d$i <- seq_len(nrow(d))
k <- which(d$crossed)
zoom <- d[d$i >= max(1, min(k) - 4) & d$i <= min(nrow(d), max(k) + 4), ]
zoom$state <- ifelse(zoom$crossed, "out of order", "in order")
pair <- d[d$crossed, ]
p <- ggplot(zoom, aes(birth, height)) +
  geom_line(colour = "grey70") +
  geom_point(aes(colour = state), size = 2.6) +
  geom_text(data = pair, aes(label = sprintf("born %.2f yr\n%.4f m", birth, height)),
            nudge_x = c(-0.06, 0.06)[seq_len(nrow(pair))], hjust = c(1, 0)[seq_len(nrow(pair))],
            size = 3.3, colour = "#D55E00") +
  scale_colour_manual(values = c("in order" = "#0072B2", "out of order" = "#D55E00"), guide = "none") +
  labs(x = "birth date of the cohort (yr)", y = "height (m)",
       title = "A younger cohort stands taller than the one born before it",
       subtitle = sprintf(paste("Synthetic record's stand at t = %.3f yr, B97; the %d cohorts born nearest the pair;",
                                "\nthe stand has %d cohorts, tallest %.2f m"), d$t[1], nrow(zoom), nrow(d),
                          max(d$height))) +
  theme_minimal(base_size = 12) + theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot")
ragg::agg_png(file.path(here, "crossing.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p); invisible(dev.off())
