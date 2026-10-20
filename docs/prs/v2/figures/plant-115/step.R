# plant-115 mechanism figure: one real Cash-Karp step spanning several rain
# knots (step-run.csv, from step-run.R on B105): the rain the model reads over
# the step, the six stage times at which the plants' rates are evaluated, and
# where each of the soil's substeps ends.
library(ggplot2)
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-115"
d <- read.csv(file.path(here, "step-run.csv"))
rain <- d[d$kind == "rain", ]; knots <- d[d$kind == "knot", ]
stages <- d[d$kind == "stage", ]; ends <- d[d$kind == "substep_end", ]
h <- max(stages$day[stages$value == 5])          # stage 5 is at t0 + h
# The rain over the step, and what the 5th-order weights make of it from the
# six stage times alone (stages 1, 3, 4, 6 carry weight).
f <- approxfun(rain$day, rain$value); x <- seq(0, h, length.out = 20001)
total <- sum(diff(x) * (f(x[-1]) + f(x[-length(x)])) / 2)
seen <- h * sum(c(37/378, 0, 250/621, 125/594, 0, 512/1771) * f(stages$day))
top <- max(rain$value) * 1.08
lane <- function(y) top * y
p <- ggplot() +
  annotate("rect", xmin = 0, xmax = h, ymin = -Inf, ymax = Inf, fill = "grey93") +
  geom_vline(data = knots, aes(xintercept = day), colour = "#56B4E9", linewidth = 0.4) +
  geom_line(data = rain, aes(day, value), colour = "#0072B2", linewidth = 0.9) +
  geom_point(data = stages, aes(day, lane(-0.12)), shape = 25, size = 3.2,
             fill = "#D55E00", colour = "#D55E00") +
  geom_text(data = stages, aes(day, lane(-0.20), label = value), size = 3.2, colour = "#D55E00") +
  geom_point(data = ends, aes(day, lane(-0.32)), shape = 124, size = 4.5, colour = "#009E73") +
  annotate("text", x = h + 0.02 * h, y = lane(c(-0.12, -0.32)), hjust = 0, size = 3.4,
           colour = c("#D55E00", "#009E73"),
           label = c("plants: the six stages", sprintf("soil: %d substep ends", nrow(ends)))) +
  annotate("text", x = 0, y = top, label = sprintf("one step, %.1f days", h), hjust = 0,
           vjust = 1, size = 3.6) +
  scale_x_continuous(expand = expansion(mult = c(0.02, 0.28))) +
  labs(x = "days from the start of the step", y = expression("rainfall (m yr"^-1*")"),
       title = sprintf("The stages see %.0f%% of this step's rain; the soil's substeps land on each knot", 100 * seen / total),
       subtitle = sprintf(paste("Synthetic record's stand, ode_tol 1e-4, no stops, this PR; blue lines: %d knots",
                                "of the daily rain\ninside the step; the plants' rates are taken only at the six stages"),
                          sum(knots$day > 0 & knots$day < h))) +
  theme_minimal(base_size = 12) +
  theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot", panel.grid.minor = element_blank())
ragg::agg_png(file.path(here, "step.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p); invisible(dev.off())
inside <- knots$day[knots$day > 0 & knots$day < h]
miss <- vapply(inside, function(k) min(abs(ends$day - k)), 0)
cat(sprintf("rain over the step %.4f, from the stages %.4f (%.1f%%)\n", total, seen, 100 * seen / total))
cat(sprintf("step %.3f d, %d knots inside, %d substep ends, largest distance knot-to-nearest-end %.2e d\n",
            h, length(inside), nrow(ends), max(miss)))
