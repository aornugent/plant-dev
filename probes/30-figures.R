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
win    <- readRDS("probes/out/window-TF24.rds")
excess <- readRDS("probes/out/excess-scm.rds")

NINTRO <- c(141, 281, 561)

off_of <- function(model, bd) {
  d <- refine[refine$model == model & refine$birth_date == bd, ]
  d$offspring[match(NINTRO, d$n_intro)]
}

## ------------------------------------------------------- Figure 1 sources --
## 48-report.rds carries the fixed-schedule series extended to 1121 (2241 on
## K93), the schedule_eps sweep, and the Richardson limits.  55-timing.rds is
## the idle-machine wall clock for section 6.5.
rep48  <- readRDS("probes/out/48-report.rds")
timing <- readRDS("probes/out/55-timing.rds")

## The series feeding the limits come from probes/43-fixed-series.R, which builds
## a fresh SCM per run; those runs are bit-reproducible (see the note below on
## the sweep, which is not).
series <- function(model, a) {
  d <- rep48$fixed[rep48$fixed$model == model & rep48$fixed$arm == a, ]
  d[order(d$n), c("n", "value")]
}
## Three-point Richardson on the last three points, using the ratio the series
## itself shows rather than an assumed order.  Reproduces all six stored limits.
richardson <- function(v, force_order = NA) {
  m <- length(v); x <- v[(m - 2):m]
  r <- if (is.na(force_order)) (x[2] - x[1]) / (x[3] - x[2]) else 2^force_order
  x[3] + (x[3] - x[2]) / (r - 1)
}
lim_of  <- function(model, a, force_order = NA)
  richardson(series(model, a)$value, force_order)
tail_order <- function(model, a) {
  v <- series(model, a)$value; m <- length(v)
  log2((v[m - 1] - v[m - 2]) / (v[m] - v[m - 1]))
}

TF_N   <- series("TF24", "height")$n
tf_ht  <- series("TF24", "height")$value
tf_bd  <- series("TF24", "birth-date")$value
lim_ht <- lim_of("TF24", "height")
lim_bd <- lim_of("TF24", "birth-date")
## Relative gap between the two arms' extrapolated limits, per strategy.
MODELS   <- c("K93", "FF16", "TF24")
lim_gap  <- vapply(MODELS, function(m)
  abs(lim_of(m, "birth-date") - lim_of(m, "height")) / abs(lim_of(m, "height")), 0)

## Adaptive sweep, for the section 6.4 checks.  NOTE: probes/40-lib.R runs every
## refinement iteration after the first on a single reused SCM object, and a run
## after `reset()` does not reproduce the first run on a fresh object.  These
## values are therefore all from the post-reset regime.
sw_arm <- function(model, a) rep48$sw[rep48$sw$model == model & rep48$sw$arm == a, ]
sw_at  <- function(model, a, eps) {
  d <- sw_arm(model, a)
  d[abs(d$eps - eps) < 1e-12, ]
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

## The soil-corrected oracle (Figure 2).  56-oracle128.rds: 128 m2, regular
## arrivals at midpoint placement, 10 mortality seeds paired between two frozen
## soil-water levels that bracket the SCM's own range.  54-final.rds carries the
## matching SCM values at 85, 170 and 340 introductions in both coordinates.
or128   <- readRDS("probes/out/56-oracle128.rds")
final   <- readRDS("probes/out/54-final.rds")
or_ages <- or128$ages
se_of   <- function(m) apply(m, 2, sd) / sqrt(nrow(m))
or_wet  <- colMeans(or128$res$wet); or_wse <- se_of(or128$res$wet)
or_dry  <- colMeans(or128$res$dry); or_dse <- se_of(or128$res$dry)
scm_ht  <- final$S[["ht_340"]]; scm_bd <- final$S[["bd_340"]]

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

## The corrected coordinate's own leaf-area quadrature (section 6.2), at the five
## ages the report discusses.  Only differences between resolutions are used, so
## nothing here depends on what the solver was once compared against.
EX_AGES <- c(1, 1.5, 2, 2.5, 3)
ex_keep <- excess$ages %in% EX_AGES
ex_scm  <- lapply(excess$scm, function(v) v[ex_keep])
ex_ratio <- (ex_scm[["141"]] - ex_scm[["281"]]) / (ex_scm[["281"]] - ex_scm[["561"]])
ex_rich  <- ex_scm[["561"]] + (ex_scm[["561"]] - ex_scm[["281"]]) / (ex_ratio - 1)

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
## Figure 1.  Both arms converge, to limits that do not approach each other.
##
## Extended to 1121 introductions and Richardson-extrapolated.  The height
## coordinate is not under-resolved: it converges, at an observed tail order of
## 2.15, to 60.3 against the corrected coordinate's 401.7 -- a factor of 6.66,
## the height coordinate 85.0% low.  Panel (c) is the control: on the two
## strategies whose growth is a function of size the two limits coincide.
##
## Height-arm values are annotated to three significant figures and both limits
## to the precision the extrapolation supports; forcing second order instead of
## the observed ratio moves them by 6.9e-4 and 1.5e-4 relative.
## ======================================================================== ##
f1 <- dev_open("fig-01-schedule-convergence", 7.0, 2.7, pointsize = 8.5)
par(mfrow = c(1, 3))

panel(mar = c(2.9, 3.5, 1.1, 0.6))
plot(NA, xlim = c(128, 1260), ylim = c(38, 560), log = "xy", axes = FALSE,
     xlab = "cohort introductions in the schedule",
     ylab = "lifetime offspring production")
axis(1, at = TF_N, labels = TF_N)
axis(2, at = c(40, 60, 100, 200, 400))
abline(h = lim_ht, col = COL_H, lty = 2, lwd = 1)
abline(h = lim_bd, col = COL_B, lty = 2, lwd = 1)
lines(TF_N, tf_ht, col = COL_H, lwd = 1.9); points(TF_N, tf_ht, col = COL_H, pch = PCH_H, cex = 0.9)
lines(TF_N, tf_bd, col = COL_B, lwd = 1.9); points(TF_N, tf_bd, col = COL_B, pch = PCH_B, cex = 0.85)
text(1260, lim_ht * 1.08, sprintf("limit %.3g", lim_ht), col = COL_H, cex = 0.8, adj = 1)
text(1260, lim_bd * 1.08, sprintf("limit %.4g", lim_bd), col = COL_B, cex = 0.8, adj = 1)
arrows(196, lim_ht, 196, lim_bd, code = 3, length = 0.04, col = COL_GRY, lwd = 1.1)
text(213, sqrt(lim_ht * lim_bd), sprintf("%.2fx", lim_bd / lim_ht), cex = 0.85, adj = c(0, 0.5))
legend(x = 300, y = 175, bty = "n", cex = 0.8, seg.len = 1.7,
       legend = c("density in height", "density in birth date"),
       col = c(COL_H, COL_B), pch = c(PCH_H, PCH_B), lwd = 1.9)
tag("(a)")

## Successive differences, normalised by each arm's own limit.  These are raw
## data: unlike a distance from a fitted limit they do not depend on the
## extrapolation, so the ratios between them are an honest convergence rate.
panel(mar = c(2.9, 3.7, 1.1, 0.6))
d_ht <- abs(diff(tf_ht)) / lim_ht
d_bd <- abs(diff(tf_bd)) / lim_bd
plot(NA, xlim = c(240, 1320), ylim = c(8e-4, 0.42), log = "xy", axes = FALSE,
     xlab = "cohort introductions in the schedule",
     ylab = "change over the previous halving")
axis(1, at = TF_N[-1], labels = TF_N[-1])
axis(2, at = 10^(-3:-1), labels = log10lab(-3:-1))
gx <- c(281, 1121); gy <- d_ht[1] * (gx / 281)^-2
lines(gx, gy, col = COL_GRY, lty = 2, lwd = 1)
text(1121, gy[2] * 0.55, "second order", col = COL_GRY, cex = 0.78, adj = c(1, 1))
lines(TF_N[-1], d_ht, col = COL_H, lwd = 1.9); points(TF_N[-1], d_ht, col = COL_H, pch = PCH_H, cex = 0.9)
lines(TF_N[-1], d_bd, col = COL_B, lwd = 1.9); points(TF_N[-1], d_bd, col = COL_B, pch = PCH_B, cex = 0.85)
text(1090, d_ht[3] * 2.4, sprintf("order %.2f", tail_order("TF24", "height")),
     col = COL_H, cex = 0.78, adj = c(1, 0))
text(1090, d_bd[3] * 1.7, sprintf("order %.2f", tail_order("TF24", "birth-date")),
     col = COL_B, cex = 0.78, adj = 1)
tag("(b)")

## The control: the same extrapolation applied to the two strategies whose growth
## is a function of size returns one limit, not two.
panel(mar = c(2.9, 3.7, 1.1, 0.9))
plot(NA, xlim = c(0.6, 3.4), ylim = c(2e-7, 40), log = "y", axes = FALSE,
     xlab = "", ylab = "relative gap between the two limits")
axis(1, at = seq_along(MODELS), labels = MODELS, tick = FALSE)
axis(2, at = 10^(-7:1), labels = log10lab(-7:1))
cols <- c(K93 = COL_GRY, FF16 = COL_REF, TF24 = COL_H)
for (k in seq_along(MODELS)) {
  segments(k, 2e-7, k, lim_gap[k], col = cols[MODELS[k]], lwd = 1.6)
  points(k, lim_gap[k], col = cols[MODELS[k]], pch = 16, cex = 1.2)
  v <- signif(lim_gap[k], 2)
  lab <- if (v < 0.01) bquote(.(signif(v / 10^floor(log10(v)), 2)) %*% 10^.(floor(log10(v))))
         else bquote(.(v))
  text(k, lim_gap[k] * 3.0, lab, col = cols[MODELS[k]], cex = 0.78)
}
tag("(c)")
invisible(dev.off())

## ======================================================================== ##
## Figure 2.  The individual-based comparison (Appendix E).
##
## Rebuilt on the soil-corrected oracle.  `StochasticPatch::ode_size()` omits
## `environment.ode_size()` and none of its three ODE accessors forward to the
## environment, so TF24's nine environment states -- five soil layers and four
## cumulative fluxes -- were never integrated and soil water stayed frozen at its
## initial 0.214 for the whole run.  probes/56-oracle128.R runs the oracle at
## 128 m2 with regular arrivals at midpoint placement, 10 mortality seeds paired
## between two soil levels, and soil water frozen at each end of the SCM's own
## range (0.310613 and 0.299220) so the two runs bracket the answer.  The SCM
## columns are at 340 introductions (truncated at 3.5 yr, then twice refined),
## not the 141 of the section 4 table.
## ======================================================================== ##
f2 <- dev_open("fig-02-oracle-comparison", 7.0, 3.0, pointsize = 9)
par(mfrow = c(1, 2))

OA    <- or_ages
or_m  <- (or_wet + or_dry) / 2                    # centre of the soil bracket
band  <- function(lo, hi, col) polygon(c(OA, rev(OA)), c(lo, rev(hi)),
                                       col = col, border = NA)

panel()
plot(NA, xlim = c(0.9, 3.1), ylim = c(3e-3, 2.6), log = "y", axes = FALSE,
     xlab = "patch age (yr)",
     ylab = expression("leaf area above ground level  (" * m^2 ~ m^-2 * ")"))
axis(1, at = OA)
axis(2, at = 10^(-2:0), labels = log10lab(-2:0))
## The oracle is drawn as a wide sheath so that the corrected coordinate lying on
## top of it stays visible as coincidence rather than hiding it.
band(or_dry - or_dse, or_wet + or_wse, fade(COL_REF, 0.20))
lines(OA, or_m, col = fade(COL_REF, 0.45), lwd = 3.6)
lines(OA, scm_ht, col = COL_H, lwd = 1.9); points(OA, scm_ht, col = COL_H, pch = PCH_H, cex = 0.85)
lines(OA, scm_bd, col = COL_B, lwd = 1.5); points(OA, scm_bd, col = COL_B, pch = PCH_B, cex = 0.7)
ha <- c(0, 0.5, 0.5, 0.5, 1); vo <- c(2.1, 1.6, 1.6, 1.6, 1.6)
for (k in seq_along(OA))
  text(OA[k], scm_ht[k] * vo[k], sprintf("%.2f", (scm_ht / or_m)[k]),
       col = COL_H, cex = 0.75, adj = c(ha[k], 0))
legend("bottomright", inset = c(0.01, 0.02), bty = "n", cex = 0.82, seg.len = 1.8,
       legend = c("oracle (individual-based)", "height (uncorrected)",
                  "birth date (corrected)"),
       col = c(fade(COL_REF, 0.45), COL_H, COL_B), pch = c(NA, PCH_H, PCH_B),
       lwd = c(3.6, 1.9, 1.5))
tag("(a)")

panel()
plot(NA, xlim = c(0.95, 3.05), ylim = c(0.9895, 1.0105), axes = FALSE,
     xlab = "patch age (yr)", ylab = "leaf area / oracle")
axis(1, at = OA)
yt <- seq(0.99, 1.01, by = 0.005); axis(2, at = yt, labels = sprintf("%.3f", yt))
band((or_dry - or_dse) / or_m, (or_wet + or_wse) / or_m, fade(COL_REF, 0.10))
band(or_dry / or_m, or_wet / or_m, fade(COL_REF, 0.22))
lines(OA, rep(1, length(OA)), col = COL_REF, lwd = 1.4)
lines(OA, scm_bd / or_m, col = COL_B, lwd = 1.9)
points(OA, scm_bd / or_m, col = COL_B, pch = PCH_B, cex = 0.8)
arrows(1.9, 1.0072, 1.9, 1.0098, length = 0.045, col = COL_H, lwd = 1.3)
text(1.9, 1.0069, sprintf("uncorrected: %.2f to %.2f", min(scm_ht / or_m), max(scm_ht / or_m)),
     col = COL_H, cex = 0.8, adj = c(0.5, 1))
legend("bottomleft", inset = c(0.01, 0.01), bty = "n", cex = 0.78,
       legend = c("soil-water bracket", expression("bracket" %+-% "1 s.e.")),
       fill = c(fade(COL_REF, 0.22), fade(COL_REF, 0.10)), border = NA)
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
## Figure 6.  The perturbation is resolved but wrong (Appendix B).
## ======================================================================== ##
f6 <- dev_open("fig-06-step-size", 7.0, 2.8, pointsize = 9)
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
## VERIFY.  Every plotted value against the report's own tables.
## ======================================================================== ##
FAIL <- 0L
## `sig`: the report prints this value to `sig` significant figures, so half a
## unit in the last printed place is the whole tolerance the comparison allows.
## Nothing here is loosened to make a real disagreement pass.
chk <- function(what, got, want, tol = NULL, sig = NULL, ulp = 0.5) {
  if (is.null(tol))
    tol <- ulp * 10^(floor(log10(abs(want))) - sig + 1) * (1 + 1e-9)
  ok <- all(abs(got - want) <= tol)
  if (!ok) FAIL <<- FAIL + 1L
  cat(sprintf("  [%s] %-62s %s\n", if (ok) "ok" else "FAIL", what,
              paste(signif(got, 6), collapse = " ")))
}
cat("\nverification against docs/reports/13-carried-state-invalidates-the-compression-term.md\n")

cat(" Figure 1 / section 1, both arms converge to different limits\n")
chk("height arm (42.14, 54.80, 59.06, 60.02)", tf_ht,
    c(42.14, 54.80, 59.06, 60.02), sig = 4)
chk("birth-date arm (395.44, 399.08, 400.92, 401.48)", tf_bd,
    c(395.44, 399.08, 400.92, 401.48), sig = 5)
chk("schedule 141, 281, 561, 1121", TF_N, c(141, 281, 561, 1121), 0)
## The limits are recomputed here by three-point Richardson on the last three
## points of each series; these assert that the recomputation reproduces both the
## values probes/48-report.R stored and the figures quoted in section 1.
chk("height limit 60.29 (stored 60.2935822)",
    c(lim_ht, lim_ht), c(60.29, rep48$lims[["TF24 height"]]), c(5e-3, 5e-6))
chk("birth-date limit 401.72 (stored 401.722146)",
    c(lim_bd, lim_bd), c(401.72, rep48$lims[["TF24 birth-date"]]), c(5e-3, 5e-5))
chk("the two limits differ by a factor of 6.66", lim_bd / lim_ht, 6.66, 5e-3)
chk("the height coordinate is 85.0% low", 100 * (1 - lim_ht / lim_bd), 85.0, 0.05)
## The claim the rebuilt figure replaces: the height arm is not unconverged.  Its
## successive differences fall by 2.97 then 4.45, an observed tail order of 2.15.
chk("height successive differences fall by 2.97 then 4.45",
    abs(diff(tf_ht))[-3] / abs(diff(tf_ht))[-1], c(2.97, 4.45), 5e-3)
chk("height observed tail order 2.15", tail_order("TF24", "height"), 2.15, 5e-3)
chk("birth-date observed tail order 1.71", tail_order("TF24", "birth-date"), 1.71, 5e-3)
## Panel (c): the control.  Extrapolated, the two coordinates give one limit on
## the two strategies whose growth is a function of size.
chk("FF16 limits agree to 5.3e-5, K93 to 5.6e-7",
    unname(lim_gap[c("FF16", "K93")]), c(5.3e-5, 5.6e-7), c(5e-7, 5e-9))
chk("TF24 limits differ by 5.66 relative", unname(lim_gap[["TF24"]]), 5.66, 5e-3)
## Both limits are extrapolations.  Forcing second order instead of the observed
## ratio moves them by this much, which is the precision they carry.
chk("limit sensitivity to the assumed order: 6.9e-4 and 1.5e-4",
    c(abs(lim_of("TF24", "height", 2) / lim_ht - 1),
      abs(lim_of("TF24", "birth-date", 2) / lim_bd - 1)), c(6.9e-4, 1.5e-4), 5e-6)

cat(" Figure 2 / Appendix E, the soil-corrected individual-based oracle\n")
chk("oracle, soil wet", or_wet,
    c(0.003823, 0.024858, 0.096986, 0.270120, 0.582605), 5e-7)
chk("oracle, soil dry", or_dry,
    c(0.003812, 0.024774, 0.096644, 0.269167, 0.580676), 5e-7)
chk("oracle standard error (wet)", or_wse,
    c(0.000008, 0.000058, 0.000429, 0.001000, 0.002645), 5e-7)
chk("SCM height coordinate, 340 introductions", scm_ht,
    c(0.006269, 0.050238, 0.228720, 0.680940, 1.359107), 5e-7)
chk("SCM birth-date coordinate, 340 introductions", scm_bd,
    c(0.003817, 0.024795, 0.097054, 0.270304, 0.584000), 5e-7)
chk("height / oracle wet (1.64 .. 2.33)", scm_ht / or_wet,
    c(1.64, 2.02, 2.36, 2.52, 2.33), 5e-3)
chk("height / oracle dry (1.64 .. 2.34)", scm_ht / or_dry,
    c(1.64, 2.03, 2.37, 2.53, 2.34), 5e-3)
chk("birth-date / oracle wet (0.998 .. 1.002)", scm_bd / or_wet,
    c(0.998, 0.997, 1.001, 1.001, 1.002), 5e-4)
chk("birth-date / oracle dry (1.001 .. 1.006)", scm_bd / or_dry,
    c(1.001, 1.001, 1.004, 1.004, 1.006), 5e-4)
## The claim the figure's panel (b) makes: the corrected coordinate lies inside
## the oracle's own uncertainty -- soil bracket widened by one standard error --
## at every one of the five ages, and the uncorrected one at none of them.
chk("corrected inside the oracle band, 5 of 5 ages",
    sum(scm_bd > or_dry - or_dse & scm_bd < or_wet + or_wse), 5, 0)
chk("uncorrected inside the oracle band, 0 of 5 ages",
    sum(scm_ht > or_dry - or_dse & scm_ht < or_wet + or_wse), 0, 0)
chk("10 paired mortality seeds at 128 m2",
    c(nrow(or128$res$wet), nrow(or128$res$dry), or128$area), c(10, 10, 128), 0)
chk("soil-water bracket 0.310613 and 0.299220",
    unname(or128$soil), c(0.310613, 0.299220), 5e-7)
## The ratios annotated on panel (a) are against the centre of the bracket, so
## each must fall inside the table's own wet-to-dry range at that age.
chk("panel (a) ratio labels inside the table's ranges, 5 of 5",
    sum(round(scm_ht / ((or_wet + or_dry) / 2), 2) >= round(scm_ht / or_wet, 2) &
        round(scm_ht / ((or_wet + or_dry) / 2), 2) <= round(scm_ht / or_dry, 2)), 5, 0)
## The three sentences Appendix E draws from the table.
chk("corrected agrees to within 0.6% at every age",
    100 * max(abs(c(scm_bd / or_wet, scm_bd / or_dry) - 1)), 0.6, 0.05)
chk("uncorrected is 1.6 to 2.5 times above",
    c(min(scm_ht / or_wet), max(scm_ht / or_dry)), c(1.6, 2.5), 0.05)
chk("standard error 0.45% at age 3", 100 * or_wse[5] / or_wet[5], 0.45, 5e-3)
## Appendix E says the bracket is "0.30% to 0.35%" wide; the widths are 0.288%
## to 0.353%, so the lower end should read 0.29%.
chk("soil-water bracket 0.29% to 0.35% wide",
    range(100 * (1 - or_dry / or_wet)), c(0.29, 0.35), 5e-3)

cat(" Figure 3 / section 1, relative gap between coordinates\n")
chk("TF24 as shipped (8.38, 6.28, 5.79)", g_tf, c(8.38, 6.28, 5.79), 5e-3)
chk("TF24 store decoupled (0.645, 0.357, 0.0966)", g_dec, c(0.645, 0.357, 0.0966), 1e-3)
chk("TF24 gap falls by 1.3 then 1.1", g_tf[-3] / g_tf[-1], c(1.3, 1.1), 0.05)
chk("FF16 falls by 2.4 then 3.6", g_ff[-3] / g_ff[-1], c(2.4, 3.6), 0.05)
chk("K93 falls by 4.5 then 4.1", g_k9[-3] / g_k9[-1], c(4.5, 4.1), 0.05)
chk("FF16 and K93 agree to 1.2e-3 and 1.4e-4", c(g_ff[3], g_k9[3]), c(1.2e-3, 1.4e-4), 5e-5)

cat(" Figure 4 / section 2.2, the three operators\n")
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

cat(" Figure 5 / section 4, where the discrepancy is generated\n")
sa <- c(0.75, 1.5, 2.0, 2.5, 3.0, 5.0)
chk("leaf area, uncorrected", at(h_arm, "lai0", sa),
    c(1.66e-3, 5.03e-2, 2.29e-1, 6.82e-1, 1.360, 1.762),
    sig = c(3, 3, 3, 3, 4, 4))
chk("leaf area, corrected", at(b_arm, "lai0", sa),
    c(1.14e-3, 2.49e-2, 9.74e-2, 2.71e-1, 0.586, 1.676),
    sig = c(3, 3, 3, 3, 3, 4))
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

cat(" Figure 6 / Appendix B, the step-size study\n")
chk("estimate at 1e-6 from window-TF24.rds vs Appendix B -0.270178",
    EPS_A_1E6, eps_tab$estimate[4], 5e-7)
chk("required quantity median magnitude 0.0318", abs(EPS_C), 0.0318, 5e-5)
chk("distance from the required quantity 0.302",
    median(abs(b_state$A[b_int] - b_state$C[b_int])), 0.3020, 5e-5)
chk("distance 0.302 against variation 0.0055, a factor of 55",
    c(eps_tab$distance[4], eps_tab$change[1], eps_tab$distance[1] / eps_tab$change[1]),
    c(0.302, 0.0055, 55), c(5e-4, 5e-5, 0.5))

cat(" Section 6.2, the corrected coordinate\'s leaf-area quadrature\n")
## Section 6.2 no longer tabulates an excess over the individual-based solver, so
## the four checks against that table are gone.  What remains are its rewritten
## sentences, which are properties of the corrected solver alone: only differences
## between resolutions enter, and a constant bias in the comparator cancels there.
chk("refinement lowers leaf area by 0.29% to 0.33% in total",
    range(100 * (ex_scm[["141"]] - ex_scm[["561"]]) / ex_scm[["141"]]),
    c(0.29, 0.33), 5e-3)
chk("successive-difference ratios 3.98-3.99", range(ex_ratio), c(3.98, 3.99), 5e-3)
chk("observed order 1.99-2.00", range(log2(ex_ratio)), c(1.99, 2.00), 5e-3)
chk("141 introductions within about 0.3% of its own limit",
    range(100 * (ex_scm[["141"]] - ex_rich) / ex_rich), c(0.31, 0.36), 5e-3)

cat(" Section 6.4, adaptive refinement at matched accuracy\n")
## Every value in this block is from the adaptive sweep, which runs each
## refinement iteration after the first on a reused SCM object; see the note in
## the data section.  Held to three significant figures for that reason.
bd02 <- sw_at("TF24", "birth-date", 0.2)
ht02 <- sw_at("TF24", "height", 0.02)
chk("corrected at schedule_eps 0.2 reaches 203 nodes", bd02$n, 203, 0)
chk("corrected relative error 9.97e-4 against its own limit",
    (lim_bd - bd02$value) / lim_bd, 9.97e-4, 5e-6)
chk("uncorrected at its best reaches 204 nodes", ht02$n, 204, 0)
chk("uncorrected relative error 9.67e-4 against its OWN limit",
    (ht02$value - lim_ht) / lim_ht, 9.67e-4, 5e-6)
chk("uncorrected 85.0% low against the correct limit",
    100 * (lim_bd - ht02$value) / lim_bd, 85.0, 0.05)
chk("uncorrected 84.9% to 85.9% low at every schedule_eps tested",
    range(100 * (lim_bd - sw_arm("TF24", "height")$value) / lim_bd),
    c(84.9, 85.9), 0.05)
## Both arms at their cheapest setting, as a ratio of errors against the correct
## limit -- the comparison section 6.4 makes.
chk("corrected cheapest setting 861 times more accurate",
    ((lim_bd - sw_at("TF24", "height", 0.2)$value) / lim_bd) /
      ((lim_bd - bd02$value) / lim_bd), 861, 0.5)
chk("adaptive results 60.35 and 401.317 at 204 and 357 nodes",
    c(ht02$value, sw_at("TF24", "birth-date", 0.02)$value), c(60.35, 401.317), c(5e-3, 5e-4))
chk("ODE steps 6233 and 4468",
    c(ht02$steps, sw_at("TF24", "birth-date", 0.02)$steps), c(6233, 4468), 0)

cat(" Section 6.5, wall clock on an idle machine\n")
tmed <- function(a, eps) median(timing$secs[timing$arm == a & abs(timing$eps - eps) < 1e-12])
t_ht <- tmed("height", 0.02); t_bd <- tmed("birth-date", 0.02); t_bd2 <- tmed("birth-date", 0.2)
chk("medians 146.72, 142.43, 78.46 s", c(t_ht, t_bd, t_bd2),
    c(146.72, 142.43, 78.46), 5e-3)
chk("1.03x at equal schedule_eps, 1.87x at matched accuracy",
    c(t_ht / t_bd, t_ht / t_bd2), c(1.03, 1.87), 5e-3)
chk("seconds per node-step give the per-step factor as 1.46 to 1.50",
    range((t_ht / timing$node_steps[timing$arm == "height"][1]) /
          c(t_bd / timing$node_steps[abs(timing$eps - 0.02) < 1e-12 &
                                     timing$arm == "birth-date"][1],
            t_bd2 / timing$node_steps[abs(timing$eps - 0.2) < 1e-12][1])),
    c(1.46, 1.50), 5e-3)

cat(sprintf("\n%d check(s) failed\n", FAIL))
cat("figures written:\n"); cat(paste0("  ", c(f1, f2, f3, f4, f5, f6), "\n"), sep = "")
if (FAIL > 0L) quit(status = 1L)
