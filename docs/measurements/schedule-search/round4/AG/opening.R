# opening.R RUN CASE: the forward check. E(t) recorded on a libAG run against the lib19
# pilot's instant gate g(t): the 10-90% rise of E after each g opening (g edges from the
# pilot), and the run's J and steps against lib19's run of the same schedule.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
a <- commandArgs(TRUE); x <- readRDS(file.path(AGR, paste0(a[1], ".rds"))); cs <- a[2]; G <- x$gate; G <- G[!duplicated(G$time, fromLast = TRUE), ]
et <- edge_table(cs); cr <- creation_of(cs)
rise <- function(t0, t1) { z <- G[G$time >= t0 & G$time <= t1, ]; if (nrow(z) < 3) return(c(NA, NA)); e0 <- z$E[1]; e1 <- max(z$E); if (e1 - e0 < 0.2) return(c(NA, NA))
  t10 <- z$time[which(z$E >= e0 + 0.1 * (e1 - e0))[1]]; t90 <- z$time[which(z$E >= e0 + 0.9 * (e1 - e0))[1]]; c((t90 - t10) * 365, e1 - e0) }
op <- et[et$opening & et$spell > 60, ]
r <- t(vapply(op$b, function(b) rise(b, b + 60 / 365), c(0, 0)))
gr <- vapply(op$b, function(b) { z <- cr[cr$start >= b - 1 / 365 & cr$start <= b + 60 / 365, ]; g0 <- min(z$rate); g1 <- max(z$rate); (z$start[which(z$rate >= g0 + 0.9 * (g1 - g0))[1]] - z$start[which(z$rate >= g0 + 0.1 * (g1 - g0))[1]]) * 365 }, 0)
cat(sprintf("%s: openings into spells > 60 d: %d; E 10-90%% rise median %.1f d (range %.1f-%.1f, %d measured); instant g 10-90%% median %.2f d\n", a[1], nrow(op), median(r[, 1], na.rm = TRUE), min(r[, 1], na.rm = TRUE), max(r[, 1], na.rm = TRUE), sum(!is.na(r[, 1])), median(gr, na.rm = TRUE)))
# E against the offline filter of lib19's pilot g
w <- 0.05; Ef <- numeric(nrow(cr)); e <- cr$rate[1]; for (i in seq_len(nrow(cr))) { h <- cr$end[i] - cr$start[i]; e <- cr$rate[i] + (e - cr$rate[i]) * exp(-h / w); Ef[i] <- e }
k <- G$time > 0.5 & G$time < 25; Ei <- approx(cr$end, Ef, G$time[k])$y
cat(sprintf("E on libAG vs filtered lib19 pilot g (0.5-25 y): rms diff %.3f, max %.3f, corr %.4f; E range %.3f-%.3f\n", sqrt(mean((G$E[k] - Ei)^2)), max(abs(G$E[k] - Ei)), cor(G$E[k], Ei), min(G$E), max(G$E)))
y <- if (length(a) > 2) ag_run(a[3]) else NULL
if (!is.null(y)) cat(sprintf("J libAG %.6f vs lib19 %.6f (%+.2f%%); steps %d vs %d; rows %.0fk vs %.0fk; cpu %.0f vs %.0f\n", x$stand$J, y$stand$J, 100 * (x$stand$J / y$stand$J - 1), length(x$stand$times), length(y$stand$times), x$stand$rows / 1e3, y$stand$rows / 1e3, cpu_of(x), cpu_of(y)))
