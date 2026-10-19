# Accepted steps and rate evaluations against the store's drainage K, for plain
# Cash-Karp and substepped (share 0.1), each at the cheapest tolerance in a sweep
# that lands within 1e-6 of a reference (plain Cash-Karp at 1e-12) at t = 2.
#   cd <odelia checkout at bfa32cf>; R_LIBS=<its build> Rscript <this file>
here <- dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))))
csv <- file.path(here, "steps_vs_stiffness.csv")
target <- 1e-6
if (!file.exists(csv)) {
  source(file.path(here, "toy_module.R"))
  Ks <- 10^seq(1, 5, by = 0.5)
  tols <- 10^seq(-3, -10, by = -0.5)
  rows <- list()
  for (K in Ks) {
    p <- store_pars; p[3] <- K
    ref <- counted_run(-1, 1e-12, 2, p, store_y)$y
    for (arm in c("plain", "substepped")) {
      for (tol in tols) {
        r <- counted_run(if (arm == "plain") -1 else 0.1, tol, 2, p, store_y)
        rows[[length(rows) + 1]] <- data.frame(
          K = K, arm = arm, tol = tol, error = max(abs(r$y - ref)), steps = r$steps,
          full = r$full, sub = r$sub)
      }
    }
  }
  write.csv(do.call(rbind, rows), csv, row.names = FALSE)
}

library(ggplot2)
d <- read.csv(csv)
best <- do.call(rbind, lapply(split(d, list(d$K, d$arm)), function(x) {
  x <- x[x$error <= target, ]
  x[which.min(x$steps), ]
}))
write.csv(best, file.path(here, "steps_vs_stiffness_matched.csv"), row.names = FALSE)
long <- rbind(
  data.frame(K = best$K, arm = best$arm, panel = "accepted steps", n = best$steps),
  data.frame(K = best$K, arm = best$arm, panel = "rate evaluations", n = best$full),
  data.frame(K = best$K[best$arm == "substepped"], arm = "store alone",
             panel = "rate evaluations", n = best$sub[best$arm == "substepped"]))
cols <- c(plain = "#D55E00", substepped = "#0072B2", "store alone" = "#0072B2")
lt <- c(plain = "solid", substepped = "solid", "store alone" = "22")
lab <- do.call(rbind, lapply(split(long, list(long$panel, long$arm), drop = TRUE),
                             function(x) x[which.max(x$K), ]))
lab$text <- ifelse(lab$arm == "store alone", "substepped,\nthe store's\nrates alone", ifelse(lab$panel == "rate evaluations", paste0(lab$arm, ",\nwhole System"), as.character(lab$arm)))
p <- ggplot(long, aes(K, n, colour = arm, linetype = arm)) +
  geom_line(linewidth = 0.8) + geom_point(size = 2) +
  geom_text(data = lab, aes(label = text), hjust = 0, nudge_x = 0.08, size = 3.3,
            lineheight = 0.9, show.legend = FALSE) +
  facet_wrap(~panel, scales = "free_y") +
  scale_x_log10("store drainage K (stiffness grows as the square root)",
                breaks = 10^(1:5), labels = c("10", "100", "1e3", "1e4", "1e5"),
                expand = expansion(mult = c(0.03, 0.55))) +
  scale_y_log10(NULL, labels = function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)) +
  scale_colour_manual(values = cols, guide = "none") +
  scale_linetype_manual(values = lt, guide = "none") +
  labs(title = "Substepped, steps stop growing with stiffness, and cost more below K = 300",
       subtitle = "Toy of test-substeps.R to t = 2, each arm at its cheapest tolerance within 1e-6 of a 1e-12 reference. odelia bfa32cf") +
  theme_minimal(base_size = 12) +
  theme(plot.background = element_rect(fill = "white", colour = NA),
        panel.grid.minor = element_blank(), strip.text = element_text(hjust = 0, size = 11),
        plot.title = element_text(size = 13), plot.subtitle = element_text(size = 9, colour = "#6E6E6E"))
ragg::agg_png(file.path(here, "steps_vs_stiffness.png"), width = 8, height = 4.5, units = "in", res = 200)
print(p)
invisible(dev.off())
