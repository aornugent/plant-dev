# plant-116 figure: invader fitness ln R0' against the invader's lma, as a
# multiple of the resident's, every other parameter the resident's, at the
# resident's equilibrium birth rate b* (landscape.csv, from landscape-run.R on
# B105 and B95). The reverse sweep's d ln R0'/d ln lma on B95 is drawn as short
# tangents. Two panels with their own y scales, either side of the resident.
library(ggplot2)
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-116"
d <- read.csv(file.path(here, "landscape.csv"))
d$leaf <- ifelse(d$build == "B95", "invader's own leaf (this PR)", "resident's leaf (before this PR)")
side <- function(m) factor(ifelse(m <= 1, "lma at or below the resident's", "lma above the resident's"),
                           levels = c("lma at or below the resident's", "lma above the resident's"))
d$side <- side(d$multiplier)
g <- d[!is.na(d$dlnR0_dlnlma) & abs(d$multiplier - 1) > 1e-9, ]
tan <- do.call(rbind, lapply(seq_len(nrow(g)), function(i) {
  half <- if (g$multiplier[i] < 1) 0.06 else 0.012 * 60 / abs(g$dlnR0_dlnlma[i])
  x <- log(g$multiplier[i]) + c(-1, 1) * min(half, 0.06)
  data.frame(id = i, multiplier = exp(x), side = g$side[i],
             lnR0 = g$lnR0[i] + g$dlnR0_dlnlma[i] * (x - log(g$multiplier[i])))
}))
pal <- c("invader's own leaf (this PR)" = "#0072B2", "resident's leaf (before this PR)" = "#E69F00")
lab <- data.frame(multiplier = c(0.52, 0.52), lnR0 = c(6.7, 3.2), side = side(c(0.5, 0.5)),
                  leaf = names(pal))
p <- ggplot(d, aes(multiplier, lnR0, colour = leaf)) +
  geom_hline(yintercept = 0, colour = "grey75") +
  geom_line(linewidth = 0.8) +
  geom_path(data = tan, aes(multiplier, lnR0, group = id), inherit.aes = FALSE,
            colour = "#D55E00", linewidth = 1.5) +
  geom_point(data = g, aes(multiplier, lnR0), inherit.aes = FALSE, colour = "#D55E00", size = 1.8) +
  geom_text(data = lab, aes(label = leaf), hjust = 0, size = 3.4, show.legend = FALSE) +
  facet_wrap(~side, scales = "free") +
  scale_x_log10(breaks = c(0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.25, 1.6, 2)) +
  scale_colour_manual(values = pal, guide = "none") +
  labs(x = "invader's lma as a multiple of the resident's, every other trait the resident's (log scale)", y = "ln R0'",
       title = "An invader's own leaf moves ln R0' by up to 1.7; the sweep's slope follows the curve",
       subtitle = sprintf(paste("TF24 fitness stand at b* = %.4f, ode_tol 1e-6; orange: d ln R0'/d ln lma from",
                                "the invasion's\nreverse sweep as tangents, within 2e-5 of a central difference",
                                "away from the steep drop near 1"), d$bstar[1])) +
  theme_minimal(base_size = 11) +
  theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot")
ragg::agg_png(file.path(here, "landscape.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p); invisible(dev.off())
print(d[!is.na(d$dlnR0_dlnlma), c("multiplier", "R0", "lnR0", "dlnR0_dlnlma", "central_difference", "cpu_s")])
w <- reshape(d[, c("build", "multiplier", "lnR0")], idvar = "multiplier", timevar = "build", direction = "wide")
w$diff <- w$lnR0.B95 - w$lnR0.B105
cat(sprintf("largest |diff| %.3f at x%.3f; over m < 1: %.3f..%.3f\n", max(abs(w$diff)),
            w$multiplier[which.max(abs(w$diff))], min(w$diff[w$multiplier < 1]), max(w$diff[w$multiplier < 1])))
