# plant-116 figure: invader fitness ln R0' against the lma multiplier at the
# resident's equilibrium birth rate b* (landscape.csv, from landscape-run.R on
# B105 and B95), with the reverse sweep's d ln R0'/d ln lma on B95 drawn as
# short tangents.
library(ggplot2)
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-116"
d <- read.csv(file.path(here, "landscape.csv"))
d$leaf <- ifelse(d$build == "B95", "invader's own leaf (B95)", "resident's leaf (B105)")
g <- d[!is.na(d$dlnR0_dlnlma), ]
half <- 0.045                                     # half-length of a tangent in ln(multiplier)
tan <- do.call(rbind, lapply(seq_len(nrow(g)), function(i) {
  x <- log(g$multiplier[i]) + c(-1, 1) * half
  data.frame(id = i, multiplier = exp(x), lnR0 = g$lnR0[i] + g$dlnR0_dlnlma[i] * (x - log(g$multiplier[i])))
}))
pal <- c("invader's own leaf (B95)" = "#0072B2", "resident's leaf (B105)" = "#E69F00")
ends <- do.call(rbind, lapply(split(d, d$leaf), function(x) x[which.min(x$multiplier), ]))
p <- ggplot(d, aes(multiplier, lnR0, colour = leaf)) +
  geom_hline(yintercept = 0, colour = "grey75") +
  geom_line(linewidth = 0.8) +
  geom_path(data = tan, aes(multiplier, lnR0, group = id), inherit.aes = FALSE,
            colour = "#D55E00", linewidth = 1.6) +
  geom_point(data = g, aes(multiplier, lnR0), inherit.aes = FALSE, colour = "#D55E00", size = 1.8) +
  geom_text(data = ends, aes(label = leaf), hjust = 0, vjust = c(2.2, -1.2), size = 3.4, show.legend = FALSE) +
  scale_x_log10(breaks = c(0.5, 0.7, 1, 1.4, 2)) +
  scale_colour_manual(values = pal, guide = "none") +
  labs(x = "invader's lma, as a multiple of the resident's (log scale)", y = "ln R0'",
       title = "An invader's own leaf raises its fitness below the resident's lma; the sweep's slope follows the curve",
       subtitle = sprintf(paste("TF24 fitness stand at b* = %.4f (ode_tol 1e-6); orange: d ln R0'/d ln lma from the invasion's",
                                "\nreverse sweep on B95, drawn as tangents"), d$bstar[1])) +
  theme_minimal(base_size = 12) +
  theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot")
ragg::agg_png(file.path(here, "landscape.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p); invisible(dev.off())
print(g[, c("multiplier", "R0", "lnR0", "dlnR0_dlnlma", "central_difference", "cpu_s")])
w <- reshape(d[, c("build", "multiplier", "lnR0")], idvar = "multiplier", timevar = "build", direction = "wide")
w$diff <- w$lnR0.B95 - w$lnR0.B105
print(w[w$multiplier %in% c(0.5, 0.7, 0.9, 1, 1.1, 1.4, 2), ], row.names = FALSE)
