# ff16_score.R: FF16 under off and all (ff16.R outputs). J per schedule against the
# Richardson reference of H and HH under off; the two-species and height-coordinate J;
# each node's final height and offspring moves at S0; J's change at S0 split by birth-date
# band (weight x offspring per node).
SU <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/summing"
arg <- commandArgs(TRUE); B <- if (length(arg)) arg[1] else "all"
a <- readRDS(file.path(SU, "ff16/ff16_off.rds")); b <- readRDS(file.path(SU, sprintf("ff16/ff16_%s.rds", B)))
cat(sprintf("rule: %s (file ff16_%s)\n", b$rule, B))
J <- function(r, k) r$one[[k]]$J
ref <- J(a, "HH") + (J(a, "HH") - J(a, "H")) / 3; refa <- J(b, "HH") + (J(b, "HH") - J(b, "H")) / 15
cat(sprintf("one species, birth date. Reference (off H, HH, Richardson order 2): %.6f; all's own (H, HH, order 4): %.6f\n", ref, refa))
cat(sprintf("off order from S0/H/HH: %.2f; all: %.2f\n", log2((J(a, "S0") - J(a, "H")) / (J(a, "H") - J(a, "HH"))), log2((J(b, "S0") - J(b, "H")) / (J(b, "H") - J(b, "HH")))))
for (k in c("C", "S0", "H", "HH")) cat(sprintf("  %-2s nodes %3d | off J %s (ln err %+.4f, %d steps) | all J %.6f (ln err %+.4f, %d steps) | all - off ln %+.4f\n", k, length(a$schedules[[k]]),
  if (is.na(J(a, k))) "failed  " else sprintf("%.6f", J(a, k)), log(J(a, k) / ref), a$one[[k]]$steps, J(b, k), log(J(b, k) / ref), b$one[[k]]$steps, log(J(b, k) / J(a, k))))
if (!is.null(a$one$C$error)) cat("  off at C failed:", substr(a$one$C$error, 1, 140), "\n")
cat(sprintf("two species (default schedules), birth date: off %s | all %s | rel move %s\n", paste(sprintf("%.7f", a$two$J), collapse = " "), paste(sprintf("%.7f", b$two$J), collapse = " "),
  paste(sprintf("%+.2e", b$two$J / a$two$J - 1), collapse = " ")))
if (!is.null(a$two_HH)) { r2 <- a$two_HH$J + (a$two_HH$J - a$two_H$J) / 3
  for (k in c("two", "two_H", "two_HH")) cat(sprintf("  two species %-6s ln error off %s | %s %s\n", k, paste(sprintf("%+.4f", log(a[[k]]$J / r2)), collapse = " "), B, paste(sprintf("%+.4f", log(b[[k]]$J / r2)), collapse = " "))) }
cat(sprintf("height coordinate (default control): one %s identical %s; two identical %s\n", format(a$height_one$J, digits = 12), identical(a$height_one$J, b$height_one$J), identical(a$height_two$J, b$height_two$J)))
s0 <- a$one$S0$species[[1]]; s1 <- b$one$S0$species[[1]]
h0 <- s0$state["height", ]; h1 <- s1$state["height", ]; f0 <- s0$state["offspring_produced_survival_weighted", ]; f1 <- s1$state["offspring_produced_survival_weighted", ]
w0 <- head(s0$w, -1); w1 <- head(s1$w, -1); bb <- s0$birth
cat(sprintf("S0 nodes: final height rel move max %.2e (median %.2e); offspring per recruit rel move median %.2e, max %.2e; negative weights under all %d (at b = %s)\n",
  max(abs(h1 / h0 - 1)), median(abs(h1 / h0 - 1)), median(abs(f1 / f0 - 1)), max(abs(f1 / f0 - 1)), sum(w1 < 0), paste(signif(bb[w1 < 0], 3), collapse = ", ")))
cat(sprintf("S0 width ratios at joins: %d joins with ratio 2 (the default doubles its spacing), pairs straddling one: see below\n", sum(abs(diff(bb)[-1] / head(diff(bb), -1) - 2) < 1e-6)))
bands <- c(0, 0.05, 1, 3, 8, 20, Inf); g <- cut(bb, bands, right = FALSE)
tab <- data.frame(band = levels(g), nodes = as.vector(table(g)), share_off = tapply(w0 * f0, g, sum) / sum(w0 * f0),
  weight_move = tapply(w1 * f0 - w0 * f0, g, sum) / sum(w0 * f0), fate_move = tapply(w1 * (f1 - f0), g, sum) / sum(w0 * f0))
print(format(tab, digits = 3), row.names = FALSE)
cat(sprintf("sum: weight part %+.4f, fate (field) part %+.4f of J_off (J's own S_D, density and birth-rate factors cancel in the ratio)\n", sum(tab$weight_move), sum(tab$fate_move)))
i <- order(-abs(w1 * f1 - w0 * f0))[1:6]
print(data.frame(b = signif(bb[i], 4), w_off = signif(w0[i], 3), w_all = signif(w1[i], 3), f_off = signif(f0[i], 3), f_all = signif(f1[i], 3), f_prev = signif(f0[pmax(i - 1, 1)], 3), f_next = signif(f0[pmin(i + 1, length(f0))], 3)), row.names = FALSE)
