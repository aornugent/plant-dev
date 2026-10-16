# q1_bands.R: where the error sits by birth-date band. (a) G0 with one band bisected
# (founders [0, b1), A [b1, 10), B [10, 20)) on the five training cases at 3e-5: each
# band's error is -4/3 of its bisection move on the square law; the rest (b >= 20, plus
# non-additivity and jitter) is G0's error less the three. (b) Lattice additivity.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
v <- function(nm) qn(nm)[Q] / EPS
sh <- function(x, tot) sprintf("%5.2f (%3.0f%%)", sqrt(mean(x^2)), 100 * sum(x^2) / sum(tot^2))
for (cs in c("dry", "episodic", "episodic-lma", "long-drought", "long-wet")) {
  g0 <- v(sprintf("loc_G0_%s", cs)); e0 <- g0 - REF$L19[[cs]][Q] / EPS
  bands <- sapply(c("F", "A", "B"), function(b) -4 / 3 * (v(sprintf("loc_band%s_%s", b, cs)) - g0))
  rest <- e0 - rowSums(bands)
  cat(sprintf("%-13s G0 n %d err rms %.2f lnJ %+.2f M %+.2f | F %s lnJ %+.2f M %+.2f | A %s lnJ %+.2f M %+.2f | B %s lnJ %+.2f M %+.2f | rest %s lnJ %+.2f M %+.2f\n", cs,
    TAB$n[TAB$name == sprintf("loc_G0_%s", cs)][1], sqrt(mean(e0^2)), e0["lnJ"], sum(e0 * M_unit),
    sh(bands[, "F"], e0), bands["lnJ", "F"], sum(bands[, "F"] * M_unit), sh(bands[, "A"], e0), bands["lnJ", "A"], sum(bands[, "A"] * M_unit),
    sh(bands[, "B"], e0), bands["lnJ", "B"], sum(bands[, "B"] * M_unit), sh(rest, e0), rest["lnJ"], sum(rest * M_unit)))
  # cosines between band contributions: do bands share a direction?
  cm <- cor(cbind(bands, rest = rest)); cat("   cos(F,A) ", round(cm["F", "A"], 2), " cos(A,B) ", round(cm["A", "B"], 2), " cos(F,B) ", round(cm["F", "B"], 2), "\n")
}
# Lattice additivity: e(f, l) against e(f, 70) + e(16, l) - e(16, 70), every stored off-axis point.
cat("\nLattice additivity (off-axis points, eps): rms of e(f,l) - [e(f,70) + e(16,l) - e(16,70)] against rms e(f,l)\n")
for (cs in ALL) { nm <- TAB$name[grepl(sprintf("^lat_%s_f", cs), TAB$name) & TAB$grad]
  for (n in nm) { m <- regmatches(n, regexec("_f([0-9]+)_l([0-9.]+)$", n))[[1]]; f <- m[2]; l <- m[3]; if (f == "16" || l == "70") next
    a <- sprintf("lat_%s_f%s_l70", cs, f); b <- sprintf("lat_%s_f16_l%s", cs, l); c0 <- sprintf("lat_%s_f16_l70", cs)
    if (!all(c(a, b, c0) %in% TAB$name)) next
    pred <- v(a) + v(b) - v(c0); obs <- v(n); ref <- REF$L19[[cs]][Q] / EPS
    cat(sprintf("  %-28s nonadd rms %.3f max %.3f | err rms %.3f\n", n, sqrt(mean((obs - pred)^2)), max(abs(obs - pred)), sqrt(mean((obs - ref)^2)))) } }
