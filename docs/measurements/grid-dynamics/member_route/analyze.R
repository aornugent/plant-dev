# Tables from steps.R's rows, by method and h / tau_eff at the step's start.
#   Rscript analyze.R [steps_ld_ruleA.rds]
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/spike_methods"
args <- commandArgs(TRUE)
file <- if (length(args)) args[1] else "steps_ld_ruleA.rds"
x <- readRDS(file.path(S, file))
# Rule A's weight at the start: the tolerance in force there is 3e-5 times it.
W <- readRDS(file.path(S, if (grepl("epi", file)) "weight_episodic.rds" else "weight_long-drought.rds"))
x$weight <- W$weight[findInterval(x$t0, W$t)]
x$method <- factor(x$method, c("ck", "dp", "tsit", "ssprk", "rodas"))
x$x <- x$h_days / x$tau_eff_d
x$xJ <- x$h_days / x$tau_J_d
EDGES <- c(0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 5, 6, Inf)
x$bin <- cut(x$x, EDGES, right = FALSE)
x$beyond <- x$err_norm > 1
x$beyond100 <- x$err_norm > 100
x$beyond_w <- x$err_norm > x$weight
x$draining <- x$P0 < 0 & x$r0 > 1e-3
x$fail <- x$plant_raise | x$raised
pct <- function(v) sprintf("%5.1f%%", 100 * mean(v))
q <- function(v, p) if (all(is.na(v))) NA else quantile(v, p, na.rm = TRUE, names = FALSE)

cat(sprintf("%d rows: %d starts x %d step lengths x %d methods; members per start %d to %d\n", nrow(x),
            length(unique(x$t0)), length(unique(x$h_days)), nlevels(x$method),
            min(table(x$t0[x$method == "ck" & x$h_days == 7])), max(table(x$t0[x$method == "ck" & x$h_days == 7]))))
cat("\n== The members at the starts (one row per start and member)\n")
s0 <- x[x$method == "ck" & x$h_days == 7, ]
cat(sprintf("tau_eff: min %.2f d, 5%% %.2f, median %.2f, 95%% %.2f, max %.1f; -1/J_SS against tau_eff: median ratio %.3f (5%%-95%% %.3f-%.3f)\n",
            min(s0$tau_eff_d), q(s0$tau_eff_d, 0.05), median(s0$tau_eff_d), q(s0$tau_eff_d, 0.95), max(s0$tau_eff_d),
            median(s0$tau_J_d / s0$tau_eff_d), q(s0$tau_J_d / s0$tau_eff_d, 0.05), q(s0$tau_J_d / s0$tau_eff_d, 0.95)))
cat(sprintf("net production below zero: %s of start-members; of those, fill r0 above 1e-3: %s, above 0.05: %s; rstar median %.2g\n",
            pct(s0$P0 < 0), pct(s0$r0[s0$P0 < 0] > 1e-3), pct(s0$r0[s0$P0 < 0] > 0.05), median(s0$rstar)))
print(aggregate(cbind(n = 1, deficit = P0 < 0, r0_med = r0, tau_eff_med = tau_eff_d) ~ invader, s0,
                function(v) if (length(v) && all(v %in% 0:1)) sum(v) else median(v)))

cat("\n== Per method and h / tau_eff: share of steps that fail (plant would raise, or a rating went\n")
cat("   non-finite), that end beyond the tied 3e-5 norm and beyond 100 x it; the lowest pool\n")
cat("   fill at a stage; mortality's error (|d mu|, a survival factor); offspring error over the\n")
cat("   member's offspring at t = 40\n")
for (m in levels(x$method)) {
  xm <- x[x$method == m, ]
  cat(sprintf("-- %s (%d member ratings a step)\n", m, xm$evals[1]))
  tab <- do.call(rbind, lapply(split(xm, xm$bin, drop = TRUE), function(b) data.frame(
    n = nrow(b), fail = pct(b$fail), beyond = pct(b$beyond), beyond_w = pct(b$beyond_w), beyond100 = pct(b$beyond100),
    min_r = sprintf("%.3g", min(b$min_r, na.rm = TRUE)),
    mort_err_med = sprintf("%.2g", median(b$err_mort_abs, na.rm = TRUE)),
    mort_err_max = sprintf("%.2g", max(b$err_mort_abs, na.rm = TRUE)),
    off_err_max = sprintf("%.2g", max(b$err_off_O40, na.rm = TRUE)))))
  print(tab)
}

cat("\n== The same, members draining a pool that holds something (P0 < 0, r0 > 1e-3)\n")
for (m in levels(x$method)) {
  xm <- x[x$method == m & x$draining, ]
  if (!nrow(xm)) next
  cat(sprintf("-- %s\n", m))
  tab <- do.call(rbind, lapply(split(xm, xm$bin, drop = TRUE), function(b) data.frame(
    n = nrow(b), fail = pct(b$fail), beyond = pct(b$beyond), beyond_w = pct(b$beyond_w), beyond100 = pct(b$beyond100),
    min_r = sprintf("%.3g", min(b$min_r, na.rm = TRUE)),
    mort_err_med = sprintf("%.2g", median(b$err_mort_abs, na.rm = TRUE)),
    mort_err_max = sprintf("%.2g", max(b$err_mort_abs, na.rm = TRUE)),
    off_err_max = sprintf("%.2g", max(b$err_off_O40, na.rm = TRUE)))))
  print(tab)
}

cat("\n== The smallest h / tau_eff at which each method fails, ends beyond 3e-5, beyond 100 x, or\n")
cat("   moves mortality by more than 0.025 (the invader's eps in ln J' as a survival factor)\n")
for (m in levels(x$method)) {
  xm <- x[x$method == m, ]
  f <- function(v) if (any(v, na.rm = TRUE)) sprintf("%.2f", min(xm$x[which(v)])) else "-"
  cat(sprintf("%-6s fail %s | beyond %s | beyond the weighted %s | beyond100 %s | |d mu| > 0.025 %s\n", m, f(xm$fail), f(xm$beyond), f(xm$beyond_w),
              f(xm$beyond100), f(xm$err_mort_abs > 0.025)))
}

cat("\n== By step length (days): share failing / beyond 3e-5 / beyond 100x, and the largest |d mu|\n")
for (m in levels(x$method)) {
  xm <- x[x$method == m, ]
  cat(sprintf("%-6s %s\n", m, paste(vapply(split(xm, xm$h_days), function(b)
    sprintf("%2gd %s/%s/%s %.1e", b$h_days[1], pct(b$fail), pct(b$beyond), pct(b$beyond100),
            max(b$err_mort_abs, na.rm = TRUE)), ""), collapse = " | ")))
}

cat("\n== Same (start, member, step): where Dormand-Prince or Tsitouras fails or ends beyond 100x,\n")
cat("   what the others do\n")
w <- reshape(x[, c("t0", "h_days", "invader", "node", "method", "fail", "beyond100", "err_mort_abs")],
             idvar = c("t0", "h_days", "invader", "node"), timevar = "method", direction = "wide")
bad <- (w$fail.dp | w$beyond100.dp) | (w$fail.tsit | w$beyond100.tsit)
cat(sprintf("%d cases; CK fails %d, beyond 100x %d; SSPRK fails %d, beyond 100x %d; RODAS fails %d, beyond 100x %d\n",
            sum(bad), sum(w$fail.ck[bad]), sum(w$beyond100.ck[bad]), sum(w$fail.ssprk[bad]),
            sum(w$beyond100.ssprk[bad]), sum(w$fail.rodas[bad]), sum(w$beyond100.rodas[bad])))

cat("\n== The worst cases by mortality error, per method\n")
for (m in levels(x$method)) {
  xm <- x[x$method == m, ]
  o <- head(order(-ifelse(is.finite(xm$err_mort_abs), xm$err_mort_abs, Inf)), 5)
  print(xm[o, c("t0", "h_days", "invader", "node", "r0", "P0", "tau_eff_d", "x", "min_r", "mort_rate_max",
                "err_mort_abs", "err_off_O40", "plant_raise", "raised", "raise_msg")], row.names = FALSE, digits = 3)
}
