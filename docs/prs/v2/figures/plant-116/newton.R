# plant-116: Newton's |ln J - ln b| per run, from newton.csv (newton-run.R on B95).
library(ggplot2)
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-116"
d <- read.csv(file.path(here, "newton.csv"))
d$tol <- factor(sprintf("ode_tol %.0e", d$tol), levels = c("ode_tol 1e-04", "ode_tol 1e-06"))
last <- do.call(rbind, lapply(split(d, d$tol), function(x) x[nrow(x), ]))
pal <- c("ode_tol 1e-04" = "#E69F00", "ode_tol 1e-06" = "#0072B2")
p <- ggplot(d, aes(run, abs(excess), colour = tol)) +
  geom_line(linewidth = 0.8) + geom_point(size = 2.2) +
  geom_text(data = last, aes(label = tol), hjust = -0.15, size = 3.6, show.legend = FALSE) +
  scale_y_log10(breaks = 10^seq(-11, 1, 2), labels = function(x) sprintf("1e%d", round(log10(x)))) +
  scale_x_continuous(breaks = 1:10, limits = c(1, 11.6)) +
  scale_colour_manual(values = pal, guide = "none") +
  labs(x = "Newton run (one resident run and one sweep each)", y = "|ln J - ln b|",
       title = "Newton reaches |ln J - ln b| near 1e-10 in seven runs",
       subtitle = paste("TF24 fitness stand (6 yr, hmat 6 m, 12 introductions, rain 1 m/yr), B95, from b = 10;",
                        "\nslope from the birth-rate column; at 1e-4 it stops falling below 1e-9")) +
  theme_minimal(base_size = 12) + theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot")
ragg::agg_png(file.path(here, "newton.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p); invisible(dev.off())
x <- d$excess[d$tol == "ode_tol 1e-06"]; r <- abs(x[-1] / x[-length(x)])
cat("ratio of successive |ln J - ln b| at 1e-6:", sprintf("%.3f", r), "\n")
