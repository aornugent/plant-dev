# Figures for docs/reports/13-carried-state-invalidates-the-compression-term.md
#
# Run from the plant-dev root:   Rscript probes/30-figures.R
#
# Reads only .rds and .log files already in probes/out/; runs no simulation and
# does not load `plant`.  Writes SVG (cairo) into docs/reports/figures/, or PNG
# at 144 dpi if cairo is unavailable.  Set PLANT_FIG_FORMAT=png to force PNG.
#
# Every plotted value is checked against the report's tables at the end of this
# script; `Rscript probes/30-figures.R` prints the checks and stops on failure.
#
# ONE EXCEPTION to "regenerated from data on disk": the five extra
# finite-difference step sizes in Figure 7 come from the report's Appendix B
# table, because probes/16-eps.R prints its sweep and persists nothing.  The
# 1e-6 estimate and the required quantity that anchor that figure ARE read from
# probes/out/window-TF24.rds and are checked against Appendix B (see VERIFY).

setwd("/home/user/plant-dev")
suppressMessages(library(dplyr))

FIGDIR <- "docs/reports/figures"
dir.create(FIGDIR, showWarnings = FALSE, recursive = TRUE)

FMT <- Sys.getenv("PLANT_FIG_FORMAT", "")
if (!nzchar(FMT)) FMT <- if (isTRUE(capabilities("cairo"))) "svg" else "png"
message("figure format: ", FMT,
        if (FMT == "svg") "  (grDevices::svg, cairo)" else "  (png, res = 144)")

dev_open <- function(name, width, height, pointsize = 8) {
  f <- file.path(FIGDIR, paste0(name, ".", FMT))
  if (FMT == "svg") svg(f, width = width, height = height, pointsize = pointsize,
                        bg = "white")
  else png(f, width = width, height = height, units = "in", res = 144,
           pointsize = pointsize, bg = "white", type = "cairo")
  f
}

## ---------------------------------------------------------------- palette --
## One colour per coordinate, used identically in every figure.  Okabe-Ito,
## colourblind-safe; no red/green pairing carries meaning on its own, and every
## series is also distinguished by line type or plotting symbol.
COL_H   <- "#D55E00"   # density in height        (uncorrected; the shipped solver)
COL_B   <- "#0072B2"   # density in birth date    (corrected)
COL_REF <- "#111111"   # the reference: required quantity, or the individual-based oracle
COL_AUX <- "#009E73"   # the fraction-preserving perturbation (diagnostic only)
COL_ALT <- "#CC79A7"   # stem density, the quantity that does not reconcile
COL_GRY <- "#8C8C8C"
PCH_H   <- 16          # filled circle
PCH_B   <- 15          # filled square
fade    <- function(col, a) adjustcolor(col, alpha.f = a)

panel <- function(mar = c(2.9, 3.4, 1.1, 0.6)) {
  par(mar = mar, mgp = c(2.0, 0.45, 0), tcl = -0.22, las = 1, bty = "l",
      cex.axis = 0.95, cex.lab = 1.0, lend = "butt", ljoin = "mitre")
}
tag <- function(s) mtext(s, side = 3, adj = 0, line = 0.15, font = 2, cex = 0.95)
log10lab <- function(p) parse(text = paste0("10^", p))

## ------------------------------------------------------------------- data --
refine <- readRDS("probes/out/refine.rds")
stand  <- readRDS("probes/out/stand.rds")
oracle <- readRDS("probes/out/oracle-ibm.rds")
win    <- readRDS("probes/out/window-TF24.rds")
excess <- readRDS("probes/out/excess-scm.rds")

NINTRO <- c(141, 281, 561)

off_of <- function(model, bd) {
  d <- refine[refine$model == model & refine$birth_date == bd, ]
  d$offspring[match(NINTRO, d$n_intro)]
}

## The decoupling control (report section 1, test 3) is only in the probe logs.
decouple_gap <- function() {
  ln <- c(readLines("probes/out/22-decouple.log", warn = FALSE),
          readLines("probes/out/23-decouple-l2.log", warn = FALSE))
  ln <- grep("^storage carried, reads nothing", ln, value = TRUE)
  num <- function(pat) as.numeric(sub(paste0(".*", pat, "=\\s*([0-9.eE+-]+).*"), "\\1", ln))
  d <- data.frame(n = num("n"), height = num("height"), birth = num("birth"),
                  printed = num("relative gap"))
  d <- d[match(NINTRO, d$n), ]
  stopifnot(all(abs(abs(d$birth - d$height) / abs(d$height) - d$printed) < 5e-4 * d$printed))
  abs(d$birth - d$height) / abs(d$height)
}

## Pooled individual-based ensemble: 8 replicates at 4 m2, 6 at 16 m2, 2 at 64 m2.
ibm_leaf <- rbind(oracle$out[["4"]]$L[, , 1],
                  oracle$out[["16"]]$L[, , 1],
                  oracle$out[["64"]]$L[, , 1])
ibm_grid <- oracle$grid

arm  <- function(a) stand[stand$arm == a, ]
at   <- function(d, col, t) d[[col]][vapply(t, function(x) which.min(abs(d$time - x)), 1L)]
h_arm <- arm("height"); b_arm <- arm("birth-date")

## Interior cohort pairs, whole run, TF24.  The `node < max(node)` filter is the
## one probes/09-window.R uses, so the era medians match the report's table.
interior <- win |> filter(node < max(node), is.finite(C), is.finite(A), dh > 0)
op_by_state <- interior |> group_by(time) |> summarise(
  n = n(), A50 = median(A), A25 = quantile(A, .25), A75 = quantile(A, .75),
  B50 = median(B), C50 = median(C), C25 = quantile(C, .25), C75 = quantile(C, .75),
  .groups = "drop")

## Excess of the corrected solver over the pooled ensemble mean (section 6.2),
## at the five ages the report tabulates.
EX_AGES <- c(1, 1.5, 2, 2.5, 3)
ex_keep <- excess$ages %in% EX_AGES
ex_pool <- vapply(EX_AGES, function(a)
  mean(ibm_leaf[, which.min(abs(ibm_grid - a))]), 0)
ex_scm  <- lapply(excess$scm, function(v) v[ex_keep])
ex_pct  <- lapply(ex_scm, function(v) 100 * (v / ex_pool - 1))
## Richardson limit from the observed successive-difference ratio.
ex_ratio <- (ex_scm[["141"]] - ex_scm[["281"]]) / (ex_scm[["281"]] - ex_scm[["561"]])
ex_rich  <- ex_scm[["561"]] + (ex_scm[["561"]] - ex_scm[["281"]]) / (ex_ratio - 1)
ex_rich_pct <- 100 * (ex_rich / ex_pool - 1)

## The patch state Appendix B is evaluated on: nearest recorded state to age 2,
## interior nodes only, which is the filter probes/16-eps.R uses.
b_state <- win[abs(win$time - win$time[which.min(abs(win$time - 2))]) < 1e-12, ]
b_int   <- b_state$node < max(b_state$node) & is.finite(b_state$C)
EPS_A_1E6 <- median(b_state$A[b_int])          # -0.270178, Appendix B row `1e-6`
EPS_C     <- median(b_state$C[b_int])          # +0.031827, "median magnitude 0.0318"

## Appendix B step-size sweep.  Transcribed from the report's table: the
## generating probe (probes/16-eps.R) prints these and saves nothing.  The
## `1e-6` row is checked against EPS_A_1E6 below.
eps_tab <- data.frame(
  eps      = c(1e-3,      1e-4,      1e-5,      1e-6,      1e-7,      1e-8),
  estimate = c(-0.269644, -0.270122, -0.270173, -0.270178, -0.270179, -0.270178),
  change   = c(5.5e-3,    5.5e-4,    5.0e-5,    NA,        5.0e-6,    5.2e-6),
  distance = c(0.3015,    0.3019,    0.3020,    0.3020,    0.3020,    0.3020))

## ======================================================================== ##
## Figure 1.  Offspring production under schedule refinement (section 1).
## ======================================================================== ##
f1 <- dev_open("fig-01-schedule-convergence", 7.0, 2.9, pointsize = 9)
par(mfrow = c(1, 2))

hh <- off_of("TF24", FALSE); bb <- off_of("TF24", TRUE)

panel()
plot(NA, xlim = c(130, 610), ylim = c(38, 470), log = "xy", axes = FALSE,
     xlab = "cohort introductions in the schedule",
     ylab = "lifetime offspring production")
axis(1, at = NINTRO, labels = NINTRO)
axis(2, at = c(40, 60, 100, 200, 400))
abline(h = bb[3], col = fade(COL_B, 0.55), lty = 2, lwd = 1)
lines(NINTRO, hh, col = COL_H, lwd = 1.9); points(NINTRO, hh, col = COL_H, pch = PCH_H, cex = 1.0)
lines(NINTRO, bb, col = COL_B, lwd = 1.9); points(NINTRO, bb, col = COL_B, pch = PCH_B, cex = 0.95)
text(150, bb[3] * 1.13, sprintf("own limit %.1f", bb[3]), col = COL_B, cex = 0.82, adj = 0)
arrows(561, hh[3] * 1.10, 561, hh[3] * 1.42, length = 0.045, col = COL_H, lwd = 1.2)
text(561, hh[3] * 1.50, "still moving", col = COL_H, cex = 0.82, adj = c(0.9, 0))
legend(x = 133, y = 215, bty = "n", cex = 0.85, seg.len = 1.6,
       legend = c("density in height (uncorrected)", "density in birth date (corrected)"),
       col = c(COL_H, COL_B), pch = c(PCH_H, PCH_B), lwd = 1.9)
tag("(a)")

panel()
plot(NA, xlim = c(130, 610), ylim = c(0.66, 1.045), log = "x", axes = FALSE,
     xlab = "cohort introductions in the schedule",
     ylab = "fraction of own value at 561 introductions")
axis(1, at = NINTRO, labels = NINTRO)
axis(2, at = seq(0.7, 1.0, by = 0.1))
abline(h = 1, col = COL_GRY, lty = 3)
lines(NINTRO, hh / hh[3], col = COL_H, lwd = 1.9)
points(NINTRO, hh / hh[3], col = COL_H, pch = PCH_H, cex = 1.0)
lines(NINTRO, bb / bb[3], col = COL_B, lwd = 1.9)
points(NINTRO, bb / bb[3], col = COL_B, pch = PCH_B, cex = 0.95)
pct <- function(v, dp) sprintf(paste0("%+.", dp, "f%%"), 100 * diff(v) / v[-3])
xm <- sqrt(NINTRO[-3] * NINTRO[-1])
text(xm, (hh / hh[3])[-3] * 0.96, pct(hh, 1), col = COL_H, cex = 0.82, adj = c(0.5, 1))
text(xm, (bb / bb[3])[-3] + 0.017, pct(bb, 2), col = COL_B, cex = 0.82, adj = c(0.5, 0))
tag("(b)")
invisible(dev.off())

## ======================================================================== ##
## Figure 3.  Gap between the two coordinates under refinement (section 1).
## ======================================================================== ##
f3 <- dev_open("fig-03-coordinate-gap", 3.5, 3.3, pointsize = 8)
panel(mar = c(2.9, 3.6, 0.7, 0.6))

gap_of <- function(m) abs(off_of(m, TRUE) - off_of(m, FALSE)) / abs(off_of(m, FALSE))
g_tf <- gap_of("TF24"); g_dec <- decouple_gap()
g_ff <- gap_of("FF16"); g_k9 <- gap_of("K93")

plot(NA, xlim = c(130, 610), ylim = c(4e-5, 20), log = "xy", axes = FALSE,
     xlab = "cohort introductions in the schedule",
     ylab = "relative gap between the two coordinates")
axis(1, at = NINTRO, labels = NINTRO)
axis(2, at = 10^(-4:1), labels = log10lab(-4:1))
## second-order guide: a factor of four per halving of the cohort spacing
seg <- 6e-2 / c(1, 4, 16)
lines(NINTRO, seg, col = COL_GRY, lty = 2, lwd = 1)
text(147, seg[1] * 1.7, "second order", col = COL_GRY, cex = 0.78, adj = c(0, 0))
draw <- function(y, col, lty, pch) {
  lines(NINTRO, y, col = col, lwd = 1.9, lty = lty)
  points(NINTRO, y, col = col, pch = pch, cex = 1.0, bg = "white")
}
draw(g_tf,  COL_H,   1, PCH_H)
draw(g_dec, COL_H,   2, 21)
draw(g_ff,  COL_REF, 1, 17)
draw(g_k9,  COL_GRY, 1, 18)
legend("bottomleft", inset = c(0.005, 0.005), bty = "n", cex = 0.78, seg.len = 1.8,
       legend = c("TF24, store gates growth", "TF24, store decoupled", "FF16", "K93"),
       col = c(COL_H, COL_H, COL_REF, COL_GRY), lty = c(1, 2, 1, 1),
       pch = c(PCH_H, 21, 17, 18), pt.bg = "white", lwd = 1.9)
invisible(dev.off())

## ======================================================================== ##
## Figure 2.  The individual-based comparison (Appendix E).
## ======================================================================== ##
f2 <- dev_open("fig-02-oracle-comparison", 7.0, 3.1, pointsize = 9)
par(mfrow = c(1, 2))

kw   <- ibm_grid >= 0.5 & ibm_grid <= 5
gw   <- ibm_grid[kw]
mw   <- colMeans(ibm_leaf[, kw])
sw   <- apply(ibm_leaf[, kw], 2, sd)
tw   <- h_arm$time >= 0.5 & h_arm$time <= 5

panel()
plot(NA, xlim = c(0.5, 5), ylim = c(1e-5, 3), log = "y", axes = FALSE,
     xlab = "patch age (yr)",
     ylab = expression("leaf area above ground level  (" * m^2 ~ m^-2 * ")"))
axis(1, at = c(0.5, 1, 2, 3, 4, 5))
axis(2, at = 10^(-5:0), labels = log10lab(-5:0))
for (k in seq_len(nrow(ibm_leaf)))
  lines(gw, ibm_leaf[k, kw], col = fade(COL_REF, 0.22), lwd = 0.6)
lines(gw, mw, col = COL_REF, lwd = 2.1)
lines(h_arm$time[tw], h_arm$lai0[tw], col = COL_H, lwd = 1.9)
lines(b_arm$time[tw], b_arm$lai0[tw], col = COL_B, lwd = 1.9)
legend("bottomright", inset = c(0.01, 0.02), bty = "n", cex = 0.82, seg.len = 1.8,
       legend = c("individual-based replicates (16)", "ensemble mean",
                  "density in height (uncorrected)", "density in birth date (corrected)"),
       col = c(fade(COL_REF, 0.4), COL_REF, COL_H, COL_B),
       lwd = c(0.8, 2.1, 1.9, 1.9))
tag("(a)")

panel()
ar <- gw >= 1
plot(NA, xlim = c(1, 5), ylim = c(0, 3.2), axes = FALSE,
     xlab = "patch age (yr)", ylab = "leaf area / ensemble mean")
axis(1, at = 1:5); axis(2, at = 0:3)
polygon(c(gw[ar], rev(gw[ar])),
        c((mw + sw)[ar] / mw[ar], rev((mw - sw)[ar] / mw[ar])),
        col = fade(COL_REF, 0.10), border = NA)
abline(h = 1, col = COL_REF, lwd = 1.2)
lines(gw[ar], at(h_arm, "lai0", gw[ar]) / mw[ar], col = COL_H, lwd = 1.9)
points(gw[ar], at(h_arm, "lai0", gw[ar]) / mw[ar], col = COL_H, pch = PCH_H, cex = 0.8)
lines(gw[ar], at(b_arm, "lai0", gw[ar]) / mw[ar], col = COL_B, lwd = 1.9)
points(gw[ar], at(b_arm, "lai0", gw[ar]) / mw[ar], col = COL_B, pch = PCH_B, cex = 0.75)
legend("topright", inset = c(0.01, 0.02), bty = "n", cex = 0.82,
       legend = expression("ensemble mean" %+-% "1 s.d."),
       fill = fade(COL_REF, 0.10), border = NA)
tag("(b)")
invisible(dev.off())

## ======================================================================== ##
## Figure 5.  Where the error lives, over the whole run (section 4).
## ======================================================================== ##
f5 <- dev_open("fig-05-error-window", 3.5, 4.3, pointsize = 8)
par(mfrow = c(2, 1))

kk  <- h_arm$time >= 0.3
tt  <- h_arm$time[kk]
r_la <- (h_arm$lai0 / b_arm$lai0)[kk]
r_hm <- (h_arm$hmax / b_arm$hmax)[kk]
r_st <- (h_arm$stems / b_arm$stems)[kk]
mature <- function(y) { rect(25, y[1], 110, y[2], col = "#F2F2F2", border = NA) }

panel(mar = c(0.9, 3.4, 1.1, 0.6))
plot(NA, xlim = c(0.3, 110), ylim = c(0.88, 2.62), log = "x", axes = FALSE,
     xlab = "", ylab = "uncorrected / corrected")
mature(c(0.88, 2.62))
axis(1, at = c(0.3, 1, 3, 10, 30, 100), labels = FALSE)
axis(2, at = seq(1.0, 2.5, by = 0.5))
abline(h = 1, col = "#CFCFCF", lwd = 0.8)
lines(tt, r_la, col = COL_REF, lwd = 2.0)
lines(tt, r_hm, col = COL_GRY, lwd = 1.5, lty = 5)
pk <- which.max(r_la)
points(tt[pk], r_la[pk], pch = 21, col = COL_REF, bg = "white", cex = 0.9)
text(tt[pk] * 1.25, r_la[pk] - 0.05, sprintf("%.2f at %.1f yr", r_la[pk], tt[pk]),
     cex = 0.82, adj = c(0, 1))
text(105, 2.5, "mature stand", col = COL_GRY, cex = 0.8, adj = 1)
legend("topleft", inset = c(0.0, 0.0), bty = "n", cex = 0.82, seg.len = 2.2,
       legend = c("leaf area above ground level", "canopy height"),
       col = c(COL_REF, COL_GRY), lty = c(1, 5), lwd = c(2.0, 1.5))
tag("(a)")

panel(mar = c(2.9, 3.4, 1.0, 0.6))
plot(NA, xlim = c(0.3, 110), ylim = c(0.09, 3.4), log = "xy", axes = FALSE,
     xlab = "patch age (yr)", ylab = "uncorrected / corrected")
mature(c(0.09, 3.4))
axis(1, at = c(0.3, 1, 3, 10, 30, 100), labels = c("0.3", "1", "3", "10", "30", "100"))
axis(2, at = c(0.1, 0.2, 0.5, 1, 2), labels = c("0.1", "0.2", "0.5", "1", "2"))
abline(h = 1, col = "#CFCFCF", lwd = 0.8)
lines(tt, r_st, col = COL_ALT, lwd = 2.0)
legend("bottomleft", inset = c(0.0, 0.0), bty = "n", cex = 0.82, seg.len = 1.8,
       legend = "stem density", col = COL_ALT, lty = 1, lwd = 2.0)
tag("(b)")
invisible(dev.off())

## ======================================================================== ##
## Figure 4.  The three operators through the run (section 2.2).
## ======================================================================== ##
f4 <- dev_open("fig-04-operators", 3.5, 3.3, pointsize = 8)
panel(mar = c(2.9, 3.4, 0.7, 0.6))

o <- op_by_state
plot(NA, xlim = c(0.5, 110), ylim = c(-0.36, 1.02), log = "x", axes = FALSE,
     xlab = "patch age (yr)",
     ylab = expression("estimate of " * d * italic(g) / d * italic(h) ~ "(" * yr^-1 * ")"))
sg <- o$A50 * o$C50 < 0
rect(min(o$time[sg]), -0.36, max(o$time[sg]), 1.02, col = "#F2F2F2", border = NA)
axis(1, at = c(0.5, 1, 3, 10, 30, 100), labels = c("0.5", "1", "3", "10", "30", "100"))
axis(2, at = seq(-0.25, 1.0, by = 0.25))
polygon(c(o$time, rev(o$time)), c(o$C25, rev(o$C75)), col = fade(COL_REF, 0.12), border = NA)
polygon(c(o$time, rev(o$time)), c(o$A25, rev(o$A75)), col = fade(COL_H, 0.14), border = NA)
abline(h = 0, col = COL_GRY, lty = 3)
lines(o$time, o$C50, col = COL_REF, lwd = 2.0)
lines(o$time, o$B50, col = COL_AUX, lwd = 1.5, lty = 2)
lines(o$time, o$A50, col = COL_H,   lwd = 2.0)
text(sqrt(min(o$time[sg]) * max(o$time[sg])), 1.0, "opposite sign",
     cex = 0.8, col = COL_GRY, adj = c(0.5, 1))
legend("topright", inset = c(0.01, 0.02), bty = "n", cex = 0.8, seg.len = 1.8,
       legend = c("required quantity", "fraction-preserving perturbation",
                  "single-individual perturbation"),
       col = c(COL_REF, COL_AUX, COL_H), lty = c(1, 2, 1), lwd = c(2.0, 1.5, 2.0))
invisible(dev.off())

## ======================================================================== ##
## Figure 7.  The perturbation is resolved but wrong (Appendix B).
## ======================================================================== ##
f7 <- dev_open("fig-07-step-size", 7.0, 2.8, pointsize = 9)
par(mfrow = c(1, 2))

panel(mar = c(2.9, 3.8, 1.1, 0.6))
plot(NA, xlim = c(6e-9, 2e-3), ylim = c(-0.30, 0.07), log = "x", axes = FALSE,
     xlab = "finite-difference step in height (m)",
     ylab = expression("estimate of " * d * italic(g) / d * italic(h) ~ "(" * yr^-1 * ")"))
axis(1, at = 10^(-8:-3), labels = log10lab(-8:-3))
yt <- seq(-0.30, 0.05, by = 0.05)
axis(2, at = yt, labels = sprintf("%.2f", yt))
abline(h = EPS_C, col = COL_REF, lwd = 1.6)
text(6e-9, EPS_C + 0.012, sprintf("required quantity  %+.4f", EPS_C),
     col = COL_REF, cex = 0.82, adj = 0)
lines(eps_tab$eps, eps_tab$estimate, col = COL_H, lwd = 1.9)
points(eps_tab$eps, eps_tab$estimate, col = COL_H, pch = PCH_H, cex = 1.0)
xa <- 3e-6
arrows(xa, eps_tab$estimate[4], xa, EPS_C, code = 3, length = 0.04,
       col = COL_GRY, lwd = 1.1)
text(xa * 1.5, mean(c(eps_tab$estimate[4], EPS_C)),
     sprintf("%.3f", EPS_C - eps_tab$estimate[4]), cex = 0.85, adj = c(0, 0.5))
text(2e-3, eps_tab$estimate[1] - 0.022, "single-individual perturbation",
     col = COL_H, cex = 0.82, adj = 1)
tag("(a)")

panel(mar = c(2.9, 3.8, 1.1, 0.6))
plot(NA, xlim = c(6e-9, 2e-3), ylim = c(2e-6, 1), log = "xy", axes = FALSE,
     xlab = "finite-difference step in height (m)",
     ylab = expression("magnitude  (" * yr^-1 * ")"))
axis(1, at = 10^(-8:-3), labels = log10lab(-8:-3))
axis(2, at = 10^(-6:0), labels = log10lab(-6:0))
lines(eps_tab$eps, eps_tab$distance, col = COL_REF, lwd = 1.9)
points(eps_tab$eps, eps_tab$distance, col = COL_REF, pch = 17, cex = 0.95)
ok <- !is.na(eps_tab$change)
lines(eps_tab$eps[ok], eps_tab$change[ok], col = COL_H, lwd = 1.9, lty = 2)
points(eps_tab$eps[ok], eps_tab$change[ok], col = COL_H, pch = PCH_H, cex = 1.0)
arrows(1e-3, eps_tab$change[1] * 1.35, 1e-3, eps_tab$distance[1] * 0.72,
       code = 3, length = 0.04, col = COL_GRY, lwd = 1.1)
text(8.5e-4, sqrt(eps_tab$change[1] * eps_tab$distance[1]),
     sprintf("%.0fx", eps_tab$distance[1] / eps_tab$change[1]), cex = 0.85, adj = 1)
legend("left", inset = c(0.02, 0.02), bty = "n", cex = 0.82, seg.len = 1.8,
       legend = c(expression("distance from the required quantity"),
                  expression("largest change from the value at " * 10^-6 * " m")),
       col = c(COL_REF, COL_H), lty = c(1, 2), pch = c(17, PCH_H), lwd = 1.9)
tag("(b)")
invisible(dev.off())

## ======================================================================== ##
## Figure 6.  The corrected solver's residual excess is not resolution (6.2).
## ======================================================================== ##
f6 <- dev_open("fig-06-excess-refinement", 7.0, 2.9, pointsize = 9)
par(mfrow = c(1, 2))

lty_n <- c("141" = 1, "281" = 2, "561" = 3)
pch_n <- c("141" = 16, "281" = 17, "561" = 15)

panel()
plot(NA, xlim = c(0.9, 3.1), ylim = c(0, 23), axes = FALSE,
     xlab = "patch age (yr)",
     ylab = "excess over the ensemble mean (%)")
axis(1, at = EX_AGES); axis(2, at = seq(0, 20, by = 5))
abline(h = 0, col = "#CFCFCF", lwd = 0.8)
for (nm in names(lty_n)) {
  lines(EX_AGES, ex_pct[[nm]], col = COL_B, lwd = 1.7, lty = lty_n[[nm]])
  points(EX_AGES, ex_pct[[nm]], col = COL_B, pch = pch_n[[nm]], cex = 0.85)
}
lines(EX_AGES, ex_rich_pct, col = COL_REF, lwd = 1.0, lty = 1)
legend("topleft", inset = c(0.02, 0.0), bty = "n", cex = 0.82, seg.len = 1.9,
       legend = c("141 introductions", "281", "561", "Richardson limit"),
       col = c(COL_B, COL_B, COL_B, COL_REF), lty = c(lty_n, 1),
       pch = c(pch_n, NA), lwd = c(1.7, 1.7, 1.7, 1.2))
tag("(a)")

panel()
plot(NA, xlim = c(0.9, 3.1), ylim = c(0.012, 1.0), log = "y", axes = FALSE,
     xlab = "patch age (yr)",
     ylab = "distance from the Richardson limit (% points)")
axis(1, at = EX_AGES)
axis(2, at = c(0.02, 0.05, 0.1, 0.2, 0.5, 1), labels = c("0.02", "0.05", "0.1", "0.2", "0.5", "1"))
for (nm in names(lty_n)) {
  y <- ex_pct[[nm]] - ex_rich_pct
  lines(EX_AGES, y, col = COL_B, lwd = 1.7, lty = lty_n[[nm]])
  points(EX_AGES, y, col = COL_B, pch = pch_n[[nm]], cex = 0.85)
}
for (nm in c("141", "281", "561"))
  text(3.06, (ex_pct[[nm]] - ex_rich_pct)[5], nm, col = COL_B, cex = 0.8, adj = c(1, -0.6))
tag("(b)")
invisible(dev.off())

## ======================================================================== ##
## VERIFY.  Every plotted value against the report's own tables.
## ======================================================================== ##
FAIL <- 0L
## `sig`: the report prints this value to `sig` significant figures, so half a
## unit in the last printed place is the whole tolerance the comparison allows.
## `ulp = 1` allows a full unit, and is used only where the report has clearly
## rounded twice (to four figures, then to three) -- see the three cells noted
## below.  Nothing here is loosened to make a real disagreement pass.
chk <- function(what, got, want, tol = NULL, sig = NULL, ulp = 0.5) {
  if (is.null(tol))
    tol <- ulp * 10^(floor(log10(abs(want))) - sig + 1) * (1 + 1e-9)
  ok <- all(abs(got - want) <= tol)
  if (!ok) FAIL <<- FAIL + 1L
  cat(sprintf("  [%s] %-62s %s\n", if (ok) "ok" else "FAIL", what,
              paste(signif(got, 6), collapse = " ")))
}
cat("\nverification against docs/reports/13-carried-state-invalidates-the-compression-term.md\n")

cat(" Figure 1 / section 1, schedule refinement\n")
chk("offspring, height arm (42.14, 54.80, 59.06)", hh, c(42.14, 54.80, 59.06), 5e-3)
## Report prints 399.09; the datum is 399.0849, i.e. 399.085 to five figures and
## then 399.09.  Double-rounded, so a full unit in the last place is allowed.
chk("offspring, birth-date arm (395.44, 399.09, 400.92)", bb,
    c(395.44, 399.09, 400.92), sig = 5, ulp = 1)
chk("height moves (+30.0%, +7.8%)", 100 * diff(hh) / hh[-3], c(30.0, 7.8), 0.05)
chk("birth-date moves (+0.92%, +0.46%)", 100 * diff(bb) / bb[-3], c(0.92, 0.46), 5e-3)
chk("section 6.4 birth-date fixed-schedule limit 400.9166", bb[3], 400.9166, 5e-4)

cat(" Figure 2 / section 1, relative gap between coordinates\n")
chk("TF24 as shipped (8.38, 6.28, 5.79)", g_tf, c(8.38, 6.28, 5.79), 5e-3)
chk("TF24 store decoupled (0.645, 0.357, 0.0966)", g_dec, c(0.645, 0.357, 0.0966), 1e-3)
chk("TF24 gap falls by 1.3 then 1.1", g_tf[-3] / g_tf[-1], c(1.3, 1.1), 0.05)
chk("FF16 falls by 2.4 then 3.6", g_ff[-3] / g_ff[-1], c(2.4, 3.6), 0.05)
chk("K93 falls by 4.5 then 4.1", g_k9[-3] / g_k9[-1], c(4.5, 4.1), 0.05)
chk("FF16 and K93 agree to 1.2e-3 and 1.4e-4", c(g_ff[3], g_k9[3]), c(1.2e-3, 1.4e-4), 5e-5)

cat(" Figure 3 / Appendix E, individual-based ensemble\n")
ea <- c(1, 1.5, 2, 2.5, 3)
em <- vapply(ea, function(a) mean(ibm_leaf[, which.min(abs(ibm_grid - a))]), 0)
es <- vapply(ea, function(a) sd(ibm_leaf[, which.min(abs(ibm_grid - a))]), 0)
chk("ensemble mean", em, c(0.00361, 0.02286, 0.08532, 0.23143, 0.48279), 5e-6)
chk("ensemble s.d.", es, c(0.00225, 0.01204, 0.03773, 0.08486, 0.15192), 5e-6)
chk("uncorrected", at(h_arm, "lai0", ea), c(0.00628, 0.05035, 0.22926, 0.68229, 1.35999), 5e-6)
chk("corrected",   at(b_arm, "lai0", ea), c(0.00383, 0.02488, 0.09738, 0.27117, 0.58568), 5e-6)
chk("uncorrected ratio (1.74 .. 2.82)", at(h_arm, "lai0", ea) / em,
    c(1.74, 2.20, 2.69, 2.95, 2.82), 5e-3)
chk("corrected ratio (1.06 .. 1.21)", at(b_arm, "lai0", ea) / em,
    c(1.06, 1.09, 1.14, 1.17, 1.21), 5e-3)
chk("uncorrected z (1.2 .. 5.8)", (at(h_arm, "lai0", ea) - em) / es,
    c(1.2, 2.3, 3.8, 5.3, 5.8), 0.05)
chk("corrected z (0.1 .. 0.7)", (at(b_arm, "lai0", ea) - em) / es,
    c(0.1, 0.2, 0.3, 0.5, 0.7), 0.05)
chk("16 replicates", nrow(ibm_leaf), 16, 0)

cat(" Figure 4 / section 4, where the discrepancy is generated\n")
sa <- c(0.75, 1.5, 2.0, 2.5, 3.0, 5.0)
## Two cells of this table are double-rounded: 5.0349e-2 -> 5.035e-2 -> 5.04e-2,
## and 1.1446e-3 -> 1.145e-3 -> 1.15e-3.  The table's own ratio column is
## computed from the unrounded values and matches exactly, below.
chk("leaf area, uncorrected", at(h_arm, "lai0", sa),
    c(1.66e-3, 5.04e-2, 2.29e-1, 6.82e-1, 1.360, 1.762),
    sig = c(3, 3, 3, 3, 4, 4), ulp = 1)
chk("leaf area, corrected", at(b_arm, "lai0", sa),
    c(1.15e-3, 2.49e-2, 9.74e-2, 2.71e-1, 0.586, 1.676),
    sig = c(3, 3, 3, 3, 3, 4), ulp = 1)
chk("leaf area ratio (1.45 .. 1.05)", at(h_arm, "lai0", sa) / at(b_arm, "lai0", sa),
    c(1.45, 2.02, 2.35, 2.52, 2.32, 1.05), sig = 3)
mt <- h_arm$time > 25
chk("mature leaf-area ratio mean 1.005, range 0.977-1.038",
    c(mean((h_arm$lai0 / b_arm$lai0)[mt]), range((h_arm$lai0 / b_arm$lai0)[mt])),
    c(1.005, 0.977, 1.038), 5e-4)
chk("mature canopy-height ratio mean 0.993, range 0.992-0.995",
    c(mean((h_arm$hmax / b_arm$hmax)[mt]), range((h_arm$hmax / b_arm$hmax)[mt])),
    c(0.993, 0.992, 0.995), 5e-4)
chk("mature stem-density ratio mean 1.35, range 0.37-1.96",
    c(mean((h_arm$stems / b_arm$stems)[mt]), range((h_arm$stems / b_arm$stems)[mt])),
    c(1.35, 0.37, 1.96), 5e-3)

cat(" Figure 5 / section 2.2, the three operators\n")
era <- cut(interior$time, c(0.5, 1, 2, 3))
for (e in levels(era)) {
  k <- which(era == e)
  chk(sprintf("era %s: pool / fraction / required", e),
      c(median(interior$A[k]), median(interior$B[k]), median(interior$C[k])),
      switch(e, "(0.5,1]" = c(0.198, 0.7928, 0.7877),
                "(1,2]"   = c(-0.221, 0.2405, 0.2390),
                "(2,3]"   = c(-0.209, 0.0656, 0.0634)), 5e-4)
}
wi <- interior |> filter(time >= 1.5, time <= 3)
chk("405 interior pairs at ages 1.5-3", nrow(wi), 405, 0)
chk("median gap 2.44 mm", 1000 * median(wi$dh), 2.44, 5e-3)
chk("median estimate -0.2312, median required +0.0674",
    c(median(wi$A), median(wi$C)), c(-0.2312, 0.0674), 5e-5)
chk("estimate 3.4x larger in magnitude", abs(median(wi$A) / median(wi$C)), 3.4, 0.05)
lowest <- interior$node == ave(interior$node, interior$time, FUN = max)
cen <- interior[!lowest, ]
chk("section 2.1: 37 states, 3459 interior pairs",
    c(length(unique(cen$time)), nrow(cen)), c(37, 3459), 0)
chk("min gap 1.6e-5 m, 14.2% below 1e-4 m",
    c(min(cen$dh), 100 * mean(cen$dh < 1e-4)), c(1.6e-5, 14.2), c(5e-7, 0.05))

cat(" Figure 6 / Appendix B, the step-size study\n")
chk("estimate at 1e-6 from window-TF24.rds vs Appendix B -0.270178",
    EPS_A_1E6, eps_tab$estimate[4], 5e-7)
chk("required quantity median magnitude 0.0318", abs(EPS_C), 0.0318, 5e-5)
chk("distance from the required quantity 0.302",
    median(abs(b_state$A[b_int] - b_state$C[b_int])), 0.3020, 5e-5)
chk("distance 0.302 against variation 0.0055, a factor of 55",
    c(eps_tab$distance[4], eps_tab$change[1], eps_tab$distance[1] / eps_tab$change[1]),
    c(0.302, 0.0055, 55), c(5e-4, 5e-5, 0.5))

cat(" Figure 7 / section 6.2, the residual excess\n")
chk("excess at 141 (+5.94 .. +21.31)", ex_pct[["141"]],
    c(5.94, 8.80, 14.13, 17.17, 21.31), 5e-3)
chk("excess at 281 (+5.67 .. +21.03)", ex_pct[["281"]],
    c(5.67, 8.52, 13.83, 16.87, 21.03), 5e-3)
chk("excess at 561 (+5.60 .. +20.96)", ex_pct[["561"]],
    c(5.60, 8.45, 13.75, 16.80, 20.96), 5e-3)
chk("Richardson limit (+5.58 .. +20.94)", ex_rich_pct,
    c(5.58, 8.42, 13.73, 16.77, 20.94), 5e-3)
chk("successive-difference ratios 3.98-3.99", range(ex_ratio), c(3.98, 3.99), 5e-3)
chk("observed order 1.99-2.00", range(log2(ex_ratio)), c(1.99, 2.00), 5e-3)
chk("resolution accounts for 6.0, 4.3, 2.9, 2.3, 1.7 % of the excess",
    100 * (ex_scm[["141"]] - ex_rich) / (ex_scm[["141"]] - ex_pool),
    c(6.0, 4.3, 2.9, 2.3, 1.7), 0.05)

cat(sprintf("\n%d check(s) failed\n", FAIL))
cat("figures written:\n"); cat(paste0("  ", c(f1, f2, f3, f4, f5, f6, f7), "\n"), sep = "")
if (FAIL > 0L) quit(status = 1L)
