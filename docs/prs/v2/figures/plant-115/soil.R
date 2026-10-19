# plant-115 performance figures from soil-run.csv (soil-run.R): the cost of
# each way of meeting the rain's knots relative to knot stops (soil-cost.png),
# and each arm's ln J against a tight-tolerance reference (soil-accuracy.png).
# Arms at ode_tol 1e-4 on B105 unless named; the reference is knot stops at
# ode_tol 1e-7 on B105.
library(ggplot2)
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-115"
d <- read.csv(file.path(here, "soil-run.csv"))
d$scenario <- factor(d$scenario, levels = c("synthetic", "seasonal"),
                     labels = c("synthetic 41-yr daily record", "seasonal regime"))
lab <- c(stops = "knot stops", free = "substeps, uptake fraction 0", free0.1 = "substeps, uptake fraction 0.1")
pal <- c("knot stops" = "#000000", "substeps, uptake fraction 0" = "#0072B2",
         "substeps, uptake fraction 0.1" = "#009E73", "no stops, base (B107)" = "#D55E00")
fwd <- d[d$build == "B105" & d$tol == 1e-4 & is.na(d$sweep_cpu_s), ]
grd <- d[d$build == "B105" & d$tol == 1e-4 & !is.na(d$sweep_cpu_s), ]
cost <- merge(fwd[, c("scenario", "arm", "accepted", "rejected", "rows", "forward_cpu_s")],
              data.frame(scenario = grd$scenario, arm = grd$arm,
                         gradient_cpu_s = grd$forward_cpu_s + grd$sweep_cpu_s))
cost$evaluations <- 6 * (cost$accepted + cost$rejected)
metrics <- c(accepted = "accepted steps", evaluations = "stand rate\nevaluations", rows = "rows",
             forward_cpu_s = "forward CPU", gradient_cpu_s = "gradient run CPU")
long <- do.call(rbind, lapply(names(metrics), function(v)
  data.frame(cost[, c("scenario", "arm")], metric = metrics[[v]], value = cost[[v]])))
ref <- long[long$arm == "stops", c("scenario", "metric", "value")]
long <- merge(long, ref, by = c("scenario", "metric"), suffixes = c("", "_stops"))
long$ratio <- long$value / long$value_stops
long$metric <- factor(long$metric, levels = unname(metrics))
long$arm <- factor(lab[long$arm], levels = lab)
write.csv(long[, c("scenario", "metric", "arm", "value", "ratio")], file.path(here, "soil-cost.csv"), row.names = FALSE)
p <- ggplot(long, aes(metric, ratio, colour = arm)) +
  geom_hline(yintercept = 1, colour = "grey60") +
  geom_point(size = 3, position = position_dodge(width = 0.5)) +
  facet_wrap(~scenario) +
  scale_y_continuous(limits = c(0, NA), labels = function(x) paste0(x, "x")) +
  scale_colour_manual(values = pal) +
  labs(x = NULL, y = "relative to knot stops", colour = NULL,
       title = "Substepping the soil halves the steps and the gradient's cost on the daily record",
       subtitle = "B105, birth date, ode_tol 1e-4; synthetic: 108 introductions over 40 yr; seasonal: 93 over 10 yr") +
  theme_minimal(base_size = 11) +
  theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot", legend.position = "bottom",
        axis.text.x = element_text(size = 8.5))
ragg::agg_png(file.path(here, "soil-cost.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p); invisible(dev.off())

refs <- d[d$build == "B105" & d$arm == "stops" & d$tol == 1e-7, c("scenario", "lnJ")]
acc <- d[d$tol == 1e-4 & is.na(d$sweep_cpu_s), ]
acc$label <- ifelse(acc$build == "B107", ifelse(acc$arm == "free", "no stops, base (B107)", "knot stops, base (B107)"),
                     lab[acc$arm])
acc <- acc[acc$label != "knot stops, base (B107)", ]
acc <- merge(acc, refs, by = "scenario", suffixes = c("", "_ref"))
acc$error <- abs(acc$lnJ - acc$lnJ_ref)
acc$label <- factor(acc$label, levels = c("no stops, base (B107)", lab))
tight <- merge(d[d$build == "B105" & d$arm == "stops" & d$tol == 1e-6, c("scenario", "lnJ")], refs, by = "scenario")
write.csv(acc[, c("scenario", "build", "arm", "label", "lnJ", "lnJ_ref", "error")], file.path(here, "soil-accuracy.csv"), row.names = FALSE)
q <- ggplot(acc, aes(label, pmax(error, 1e-7), colour = label)) +
  geom_hline(yintercept = 0.025, linetype = 2, colour = "grey40") +
  annotate("text", x = 0.5, y = 0.025, label = "0.025", vjust = -0.4, hjust = 0, size = 3.2, colour = "grey30") +
  geom_point(size = 3.2) +
  facet_wrap(~scenario) +
  scale_y_log10(labels = function(x) format(x, scientific = TRUE)) +
  scale_colour_manual(values = pal, guide = "none") +
  labs(x = NULL, y = "|ln J - ln J_ref|",
       title = "Without stops the base misses rain between stages; substeps do not",
       subtitle = "ode_tol 1e-4; reference: knot stops at ode_tol 1e-7 on B105") +
  theme_minimal(base_size = 11) +
  theme(plot.background = element_rect(fill = "white", colour = NA), plot.title.position = "plot",
        axis.text.x = element_text(size = 8, angle = 15, hjust = 1))
ragg::agg_png(file.path(here, "soil-accuracy.png"), width = 8, height = 4.5, units = "in", res = 200)
print(q); invisible(dev.off())
print(acc[, c("scenario", "label", "lnJ", "error")]); print(tight)
print(cost)
