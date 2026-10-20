# The root vulnerability integral G(psi) and its derivative in root_P50 past the curve's
# dry end, on phylloptim master (0.10.3) and PHYLLOPTIM-18 (0.10.4, 4026aad),
# both against odelia 0.8.0. Data from sweeps.R, run once per build:
#   Rscript sweeps.R <master lib> <odelia lib> master <dir>/master
#   Rscript sweeps.R <branch lib> <odelia lib> branch <dir>/branch
# then the two *_G.csv files stacked into root_integral.csv.
here <- dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))))
library(ggplot2)
d <- read.csv(file.path(here, "root_integral.csv"))
d$refused[is.na(d$refused)] <- ""
b <- subset(d, build == "branch" & psi >= 4)
m <- subset(d, build == "master" & psi >= 4)
dry_end <- b$dry_end[1]
# Where the last knot's tangent reaches G(inf): the table's cap.
tan <- subset(b, psi > dry_end + 0.01 & G < G_inf - 1e-9)
slope <- diff(range(tan$G)) / diff(range(tan$psi))
cap <- max(tan$psi) + (b$G_inf[1] - tan$G[which.max(tan$psi)]) / slope
refused_from <- min(m$psi[m$refused != ""])
grey <- "#6E6E6E"; blue <- "#0072B2"; verm <- "#D55E00"
long <- rbind(
  data.frame(psi = b$psi, y = b$G, what = "line", panel = "G(psi), the table's value"),
  data.frame(psi = b$psi, y = b$deriv, what = "line", panel = "dG / d root_P50"))
fd <- subset(b, abs((psi * 20) - round(psi * 20)) < 1e-9 & round(psi * 20) %% 4 == 0)
fd <- data.frame(psi = fd$psi, y = fd$fd, panel = "dG / d root_P50")
long$panel <- factor(long$panel, levels = c("G(psi), the table's value", "dG / d root_P50"))
fd$panel <- factor(fd$panel, levels = levels(long$panel))
ann <- data.frame(
  panel = factor(c("G(psi), the table's value", "G(psi), the table's value", "dG / d root_P50", "dG / d root_P50"),
                 levels = levels(long$panel)),
  psi = c(dry_end - 0.08, cap + 0.08, 4.9, refused_from + 0.12),
  y = c(3.25, 3.25, 0.52, 0.85),
  hjust = c(1, 0, 0, 0),
  label = c(sprintf("last knot\n%.2f MPa", dry_end), sprintf("tangent reaches G(inf)\n%.2f MPa", cap),
            "line: this branch's derivative\ncircles: central difference\nof the table in root_P50",
            "master refused every\nderivative here: stem_curve_domain"),
  colour = c(grey, grey, blue, verm))
p <- ggplot() +
  annotate("rect", xmin = refused_from, xmax = Inf, ymin = -Inf, ymax = Inf, fill = verm, alpha = 0.10) +
  geom_vline(xintercept = c(dry_end, cap), colour = grey, linewidth = 0.4, linetype = "22") +
  geom_line(data = long, aes(psi, y), colour = blue, linewidth = 0.8) +
  geom_point(data = fd, aes(psi, y), shape = 21, size = 1.8, colour = "#000000", fill = "white", stroke = 0.5) +
  geom_text(data = ann, aes(psi, y, label = label, hjust = hjust), colour = ann$colour, size = 3.1,
            lineheight = 0.9, vjust = 0) +
  facet_wrap(~panel, ncol = 1, scales = "free_y") +
  scale_x_continuous("soil or collar suction psi (MPa)", breaks = 4:10) +
  scale_y_continuous(NULL) +
  labs(title = "Past the last knot the derivative follows the table; master refused it",
       subtitle = "root_P50 3.4 MPa, root_c 2.680147 (plant's TF24 root), 400 knots; phylloptim 4026aad and master, odelia 0.8.0") +
  theme_minimal(base_size = 12) +
  theme(plot.background = element_rect(fill = "white", colour = NA), panel.grid.minor = element_blank(),
        strip.text = element_text(hjust = 0, size = 11), plot.title = element_text(size = 13),
        plot.subtitle = element_text(size = 9, colour = grey))
ragg::agg_png(file.path(here, "root_integral.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p)
invisible(dev.off())
