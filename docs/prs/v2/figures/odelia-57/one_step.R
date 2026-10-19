# One substepped step of the toy (odelia ODELIA-55, bfa32cf): the store's first
# layer w1 over the step, the six Cash-Karp evaluations, the substep ends, and
# Cash-Karp's own stages at the same step size.
#   cd <odelia checkout at bfa32cf>; R_LIBS=<its build> Rscript <this file>
here <- dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))))
csv <- file.path(here, "one_step.csv")
if (!file.exists(csv)) {
  source(file.path(here, "toy_module.R"))
  # store_pars: a = 1, m = 0.8, K = 1e4, s0 = 200, c = 0.3; store_y: 1, 0.5, 0.5
  run <- counted_run(0.1, 1e-6, 2, store_pars, store_y)
  k <- which.min(abs(run$start - 1.0))
  s <- one_step(0.1, 1e-6, 2, k, store_pars, store_y)
  u <- function(t) (t - s$t0) / s$h
  kind <- s$log_kind
  full <- which(kind == 0)
  # Calls of the subsystem's rates before the first stage are the predictor's:
  # five per substep, plus one at the start of every substep after the first,
  # which sees the state the substep before ended at.
  n <- length(s$ends)
  pred <- which(kind == 1 & seq_along(kind) < full[2])
  stopifnot(length(pred) == 6 * n - 1)
  starts <- pred[5 + 6 * (seq_len(n - 1) - 1) + 1]
  d <- rbind(
    data.frame(series = "reference", u = u(s$ref_t), w1 = s$ref_w1),
    data.frame(series = "evaluation", u = u(s$log_t[full]), w1 = s$log_w1[full]),
    data.frame(series = "substep_end", u = u(s$log_t[starts]), w1 = s$log_w1[starts]),
    data.frame(series = "plain_stage", u = u(s$plain_t), w1 = s$plain_w1))
  plain <- counted_run(-1, 1e-6, 2, store_pars, store_y)
  near <- plain$start > s$t0 - 0.05 & plain$start < s$t0 + 0.05
  d$t0 <- s$t0; d$h <- s$h; d$step <- k; d$substeps <- n
  d$plain_h <- median(plain$size[near])
  write.csv(d, csv, row.names = FALSE)
}

library(ggplot2)
d <- read.csv(csv)
ink <- "#000000"; blue <- "#0072B2"; verm <- "#D55E00"; grey <- "#6E6E6E"
ref <- subset(d, series == "reference")
ev <- subset(d, series == "evaluation")
se <- subset(d, series == "substep_end")
pl <- subset(d, series == "plain_stage")
stage_u <- sort(unique(ev$u))
lo <- min(ref$w1); hi <- max(ref$w1); pad <- 0.18 * (hi - lo)
plain_txt <- sprintf("Cash-Karp alone at this step size:\nstages read w1 = %.3g, %.3g, %.3g;\nthe step ends at %.2g",
                     pl$w1[4], pl$w1[5], pl$w1[6], pl$w1[7])
p <- ggplot() +
  geom_vline(xintercept = stage_u, colour = "grey85", linewidth = 0.4) +
  geom_line(data = ref, aes(u, w1), colour = grey, linewidth = 0.7) +
  geom_rug(data = se, aes(x = u), sides = "b", colour = blue, length = unit(0.03, "npc"),
           linewidth = 0.3) +
  geom_point(data = ev, aes(u, w1), colour = verm, size = 2.6) +
  annotate("text", x = 0.02, y = hi + 0.35 * pad, hjust = 0, vjust = 1, size = 3.4,
           label = plain_txt, colour = ink, lineheight = 0.95) +
  annotate("text", x = 0.63, y = ev$w1[which.min(abs(ev$u - 0.6))] - 0.02 * pad, hjust = 0, size = 3.4,
           colour = verm, label = "the six evaluations\nof the whole System") +
  annotate("text", x = 0.25, y = lo - 0.55 * pad, hjust = 0, size = 3.4, colour = blue,
           label = sprintf("%d substep ends", se$substeps[1])) +
  annotate("text", x = 0.42, y = ref$w1[which.min(abs(ref$u - 0.42))] - 0.1 * pad, hjust = 0,
           size = 3.4, colour = grey, label = "reference, plain Cash-Karp at 1e-12") +
  scale_x_continuous("fraction of the step", breaks = stage_u,
                     labels = c("0", "1/5", "3/10", "3/5", "7/8", "1")) +
  scale_y_continuous("store layer 1, w1", limits = c(lo - 0.8 * pad, hi + 0.4 * pad)) +
  labs(title = sprintf("Substeps carry the stiff store across a step %.0f times Cash-Karp's own",
                       d$h[1] / d$plain_h[1]),
       subtitle = sprintf("Toy of test-substeps.R, K = 1e4, tol 1e-6: step %d at t = %.3f, h = %.4f against plain %.5f",
                          d$step[1], d$t0[1], d$h[1], d$plain_h[1])) +
  theme_minimal(base_size = 12) +
  theme(plot.background = element_rect(fill = "white", colour = NA),
        panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        plot.title = element_text(size = 13), plot.subtitle = element_text(size = 9.5, colour = grey))
ragg::agg_png(file.path(here, "one_step.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p)
invisible(dev.off())
