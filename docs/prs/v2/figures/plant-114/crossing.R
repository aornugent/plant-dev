# plant-114 mechanism figure: the cohorts' heights against birth date at the
# stop where two crowns are furthest out of order (crossing-heights.csv, from
# crossing-run.R on B97, 429 introductions, ode_tol 1e-4). Left: the whole
# stand, every out-of-order pair marked. Right: the widest pair with the two
# cohorts born before it and the one after (off the scale, 152 mm lower),
# heights relative to the pair's older cohort.
library(ggplot2)
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-114"
d <- read.csv(file.path(here, "crossing-heights.csv"))
d$i <- seq_len(nrow(d))
up <- c(NA, diff(d$height))
w <- which.max(up)                       # the younger member of the widest pair
near <- d[d$i >= w - 3 & d$i <= w + 1, ]
near$value <- 1000 * (near$height - d$height[w - 1])
near$value <- pmax(near$value, -2)   # the next cohort, 152 mm lower, drawn at the panel edge
whole <- d; whole$value <- d$height
panel <- c("the stand: height (m)", sprintf("the widest pair: height - %.4f m (mm)", d$height[w - 1]))
both <- rbind(data.frame(whole[, c("birth", "value", "crossed")], panel = panel[1]),
              data.frame(near[, c("birth", "value", "crossed")], panel = panel[2]))
both$panel <- factor(both$panel, levels = panel)
both$state <- ifelse(both$crossed, "out of order", "in order")
lab <- data.frame(birth = d$birth[w - 2] + 0.01, value = 9.5,
                  panel = factor(panel[2], levels = panel),
                  label = sprintf("born %.2f yr, %.2f mm taller\nthan the cohort born %.0f days before",
                                  d$birth[w], 1000 * up[w], 365 * (d$birth[w] - d$birth[w - 1])))
p <- ggplot(both, aes(birth, value)) +
  geom_line(colour = "grey70") +
  geom_point(aes(colour = state, size = state)) +
  geom_text(data = lab, aes(label = label), hjust = 0, vjust = 0, size = 3.1, colour = "#D55E00") +
  geom_text(data = data.frame(birth = d$birth[w + 1], value = -2, panel = factor(panel[2], levels = panel),
                              label = sprintf("next cohort: %.0f mm lower", -1000 * (d$height[w + 1] - d$height[w - 1]))),
            aes(label = label), hjust = 1, vjust = -0.6, size = 3, colour = "grey40") +
  geom_blank(data = data.frame(birth = d$birth[w], value = c(-2, 12),
                               panel = factor(panel[2], levels = panel))) +
  facet_wrap(~panel, scales = "free") +
  scale_colour_manual(values = c("in order" = "#0072B2", "out of order" = "#D55E00"), guide = "none") +
  scale_size_manual(values = c("in order" = 0.8, "out of order" = 2.4), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.12))) +
  labs(x = "birth date of the cohort (yr)", y = NULL,
       title = "Younger cohorts stand taller than the cohorts born just before them",
       subtitle = sprintf(paste("Synthetic record's stand, 429 introductions, ode_tol 1e-4, before this PR, at t = %.2f yr:",
                                "\n%d cohorts, %d pairs out of order (orange)"), d$t[1], nrow(d),
                          sum(diff(d$height) > 0))) +
  theme_minimal(base_size = 12) +
  theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot")
ragg::agg_png(file.path(here, "crossing.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p); invisible(dev.off())
write.csv(both, file.path(here, "crossing.csv"), row.names = FALSE)
cat(sprintf("t %.4f: %d cohorts, pairs %d, widest %.3f mm born %.4f and %.4f\n", d$t[1], nrow(d),
            sum(diff(d$height) > 0), 1000 * up[w], d$birth[w - 1], d$birth[w]))
