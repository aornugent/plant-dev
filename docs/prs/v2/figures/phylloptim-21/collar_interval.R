# The collar interval's two bounds closing against soil suction, and the
# collar's psi_soil derivative against a central difference of the solve, on phylloptim
# master (0.10.3) and PHYLLOPTIM-18 (0.10.4, 4026aad), both against odelia 0.8.0.
# Data from sweeps.R (see root_integral.R), the two *_collar.csv files stacked
# into collar_interval.csv.
here <- dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))))
library(ggplot2)
d <- read.csv(file.path(here, "collar_interval.csv"))
d$refused[is.na(d$refused)] <- ""
b <- subset(d, build == "branch")
m <- subset(d, build == "master")
grey <- "#6E6E6E"; blue <- "#0072B2"; verm <- "#D55E00"; green <- "#009E73"
refused <- range(m$psi_soil[m$refused != ""])
step <- diff(b$psi_soil[1:2]) / 2
shut <- min(b$psi_soil[b$kind == "hydraulic-shutdown"])
top <- "collar suction less soil suction (MPa)"; bot <- "d collar / d psi_soil"
lv <- c(top, bot)
lines <- rbind(
  data.frame(psi_soil = b$psi_soil, y = b$wet - b$psi_soil, series = "wet bound", panel = top),
  data.frame(psi_soil = b$psi_soil, y = b$dry - b$psi_soil, series = "dry bound", panel = top),
  data.frame(psi_soil = b$psi_soil, y = b$collar - b$psi_soil, series = "collar", panel = top),
  data.frame(psi_soil = b$psi_soil, y = b$deriv, series = "deriv", panel = bot))
lines <- subset(lines, psi_soil < shut)
lines$panel <- factor(lines$panel, levels = lv)
fd <- subset(b, psi_soil < shut & seq_len(nrow(b)) %% 4 == 1)
fd <- data.frame(psi_soil = fd$psi_soil, y = fd$fd, panel = factor(bot, levels = lv))
cols <- c("wet bound" = grey, "dry bound" = "#000000", collar = blue, deriv = blue)
lab <- do.call(rbind, lapply(split(subset(lines, panel == top), lines$series[lines$panel == top]),
                             function(x) x[which.min(x$psi_soil), ]))

ann <- data.frame(
  panel = factor(c(top, bot, bot), levels = lv),
  psi_soil = c(mean(refused), 5.005, refused[2] - 0.01),
  y = c(0.12, 0.62, 0.62),
  hjust = c(0.5, 0, 1),
  colour = c(verm, blue, grey),
  label = c("interval narrower than GSS_tol_abs:\nmaster refused every derivative here",
            "line: this branch's derivative\ncircles: central difference of the solve",
            "dry bound at the root's own\nlimit: the derivative halves"))
p <- ggplot() +
  annotate("rect", xmin = refused[1] - step, xmax = refused[2] + step, ymin = -Inf, ymax = Inf,
           fill = verm, alpha = 0.10) +
  geom_line(data = lines, aes(psi_soil, y, colour = series), linewidth = 0.8) +
  geom_point(data = fd, aes(psi_soil, y), shape = 21, size = 1.8, colour = "#000000",
             fill = "white", stroke = 0.5) +
  geom_text(data = lab, aes(psi_soil - 0.01, y, label = series, colour = series), hjust = 1,
            size = 3.2) +
  geom_text(data = ann, aes(psi_soil, y, label = label, hjust = hjust), colour = ann$colour,
            size = 3.1, lineheight = 0.9, vjust = 0) +
  facet_wrap(~panel, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = cols, guide = "none") +
  scale_x_continuous("soil suction psi_soil (MPa)", expand = expansion(mult = c(0.13, 0.02))) +
  scale_y_continuous(NULL) +
  labs(title = "Where the collar interval closes, the collar's derivative is the mean of its bounds'",
       subtitle = sprintf("One layer; stem_P50 3.4287, root_P50 3.4 MPa; GSS_tol_abs 0.1, 400 knots; shut down from %.3f MPa. 4026aad and master",
                          shut)) +
  theme_minimal(base_size = 12) +
  theme(plot.background = element_rect(fill = "white", colour = NA), panel.grid.minor = element_blank(),
        strip.text = element_text(hjust = 0, size = 11), plot.title = element_text(size = 13),
        plot.subtitle = element_text(size = 8.5, colour = grey))
ragg::agg_png(file.path(here, "collar_interval.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p)
invisible(dev.off())
