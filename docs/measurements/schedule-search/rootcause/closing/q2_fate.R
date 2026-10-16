# q2_fate.R CASE [RUN]: the resolved run's per-recruit fate near each closing edge (after b1,
# before 25). ln nrr at c - {36,...,0} d and the gap probes c + {2,5,10} d, relative to c - 36 d;
# slopes per day over [-36,-11], [-11,-2], [-2,0] and [0,+10]; the pilot's establishment rate
# pr (relative to its mean over [-36,-11]) at c - {11, 4.5, 2, 1, 0.5} d; the days since the
# last rain over 1 mm at c; spell and gap lengths.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
a <- commandArgs(TRUE); cs <- a[1]; nm <- if (length(a) > 1) a[2] else sprintf("cl_res_%s", cs)
x <- rd(nm); b <- x$stand$nodes$birth; g <- log(x$stand$nodes$nrr)
cr <- PIL[[cs]]$cr; prr <- function(t) cr$rate[pmax(1, findInterval(t, cr$start))]
rain <- rain_rec(cs)
et <- edge_table(cs); ce <- et[!et$opening & et$b > PIL[[cs]]$b1, ]
off <- c(-36, -28, -21, -15.5, -11, -7.5, -4.5, -2, 0, 2, 5, 10)
rows <- lapply(seq_len(nrow(ce)), function(i) { c0 <- ce$b[i]; v <- sapply(off, function(o) { j <- which(abs(b - (c0 + o / 365)) < 1e-6); if (length(j)) g[j[1]] else NA })
  sl <- function(p, q) (v[off == q] - v[off == p]) / (q - p)
  base <- mean(prr(c0 - seq(11, 36, by = 0.25) / 365))
  dry_days <- { d <- floor(c0 * 365); k <- max(which(rain[seq_len(d)] > 1)); d - k }
  data.frame(edge = c0, spell = ce$spell[i], gap = ce$gap[i], dry_days = dry_days, t(setNames(v - v[1], sprintf("g%+g", off))), check.names = FALSE,
    s_far = sl(-36, -11) * 1e3, s_mid = sl(-11, -2) * 1e3, s_end = sl(-2, 0) * 1e3, s_gap = sl(0, 10) * 1e3,
    pr11 = prr(c0 - 11 / 365) / base, pr4.5 = prr(c0 - 4.5 / 365) / base, pr2 = prr(c0 - 2 / 365) / base, pr1 = prr(c0 - 1 / 365) / base, pr0.5 = prr(c0 - 0.5 / 365) / base) })
R <- do.call(rbind, rows); saveRDS(R, file.path(CL, sprintf("q2_fate_%s.rds", nm)))
print(format(R, digits = 2), row.names = FALSE)
L <- R[R$spell > 60, ]
cat(sprintf("\nspells > 60 d (n %d): median slopes (1e-3 ln nrr per day): far %.2f mid %.2f end %.2f gap %.2f | median ln nrr rise over last 11 d %+.3f, last 36 d %+.3f | pr at -4.5/-2/-1/-0.5 d: %.2f %.2f %.2f %.2f\n",
  nrow(L), median(L$s_far, na.rm = TRUE), median(L$s_mid, na.rm = TRUE), median(L$s_end, na.rm = TRUE), median(L$s_gap, na.rm = TRUE), median(L$`g+0` - L$`g-11`, na.rm = TRUE), median(L$`g+0`, na.rm = TRUE),
  median(L$pr4.5), median(L$pr2), median(L$pr1), median(L$pr0.5)))
# Curvature (1e-4 ln nrr per day^2) from the slopes' midpoints: over [-23.5, -6.5] d and
# [-6.5, +5] d (the latter only where the gap probes exist).
L$k_far <- (L$s_mid - L$s_far) / 17 * 10; L$k_edge <- (L$s_gap - L$s_mid) / 11.5 * 10
print(format(L[, c("edge", "spell", "gap", "dry_days", "s_far", "s_mid", "s_end", "s_gap", "k_far", "k_edge")], digits = 2), row.names = FALSE)
cat(sprintf("curvature > 0 on %d of %d long spells (k_far); median k_far %.2f, k_edge %.2f (n %d), median k_edge/k_far %.2f\n",
  sum(L$k_far > 0, na.rm = TRUE), sum(!is.na(L$k_far)), median(L$k_far, na.rm = TRUE), median(L$k_edge, na.rm = TRUE), sum(!is.na(L$k_edge)), median(L$k_edge / L$k_far, na.rm = TRUE)))
