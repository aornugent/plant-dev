# Accepted steps against the store's drainage K for plain Cash-Karp, the
# weak-coupling trigger (a956c01) and trigger C (d663a2b), each at its fewest
# steps within 1e-6 of a plain 1e-12 run at t = 2. Data: steps_vs_stiffness.csv,
# written by steps_vs_stiffness_counts.R (see its header).
#   Rscript steps_vs_stiffness.R
here <- dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))))
library(ggplot2)
d <- read.csv(file.path(here, "steps_vs_stiffness.csv"))
target <- 1e-6
best <- do.call(rbind, lapply(split(d, list(d$K, d$arm), drop = TRUE), function(x) {
  x <- x[x$error <= target, ]
  x[which.min(x$steps), ]
}))
best <- best[order(best$arm, best$K), ]
write.csv(best, file.path(here, "steps_vs_stiffness_matched.csv"), row.names = FALSE)
names <- c(plain = "plain Cash-Karp", weak = "weak-coupling trigger", C = "this PR")
best$label <- factor(names[best$arm], levels = names)
cols <- setNames(c("#009E73", "#D55E00", "#0072B2"), names)
shapes <- setNames(c(16, 17, 15), names)
ends <- do.call(rbind, lapply(split(best, best$label), function(x) x[which.max(x$K), ]))
# The weak-coupling trigger ends beside trigger C; set its label above.
ends$nudge_y <- ifelse(ends$arm == "weak", 1.15, ifelse(ends$arm == "C", 0.87, 1))
p <- ggplot(best, aes(K, steps, colour = label, shape = label)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 2.4) +
  geom_text(data = ends, aes(y = steps * nudge_y, label = label), hjust = 0,
            nudge_x = 0.1, size = 3.4, colour = "#1A1A1A", show.legend = FALSE) +
  scale_x_log10("drainage rate K of the water layers (their stiffness grows as its square root)",
                breaks = 10^(1:5), labels = c("10", "100", "1e3", "1e4", "1e5"),
                expand = expansion(mult = c(0.03, 0.42))) +
  scale_y_log10("accepted steps", breaks = c(10, 30, 100, 300, 1000, 3000),
                labels = function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)) +
  scale_colour_manual(values = cols, guide = "none") +
  scale_shape_manual(values = shapes, guide = "none") +
  labs(title = "Substeps only where the water layers are stiff: plain steps up to K = 100",
       subtitle = "Toy of test-substeps.R to t = 2; fewest steps within 1e-6 of a plain 1e-12 run. odelia a956c01, d663a2b") +
  theme_minimal(base_size = 12) +
  theme(plot.background = element_rect(fill = "white", colour = NA),
        panel.grid.minor = element_blank(),
        plot.title = element_text(size = 12.5), plot.subtitle = element_text(size = 9, colour = "#6E6E6E"))
ragg::agg_png(file.path(here, "steps_vs_stiffness.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p)
invisible(dev.off())
