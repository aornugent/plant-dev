# The stand at its demographic equilibrium (prereg.txt).
#   OUTD=... Rscript analyze.R
x <- readRDS(file.path(Sys.getenv("OUTD"), "eq.rds"))
runs <- do.call(rbind, lapply(x$runs, function(r) as.data.frame(r[c("role", "b", "lma_rel", "J", "f", "secs", "steps", "splits")])))
print(runs, digits = 8)
e <- x$equilibrium
cat(sprintf("\nb* %.8g; f'(x*) %.5f; m = d ln J / d ln b %.5f; secant runs %d\n",
            e$b_star, e$f_slope, e$multiplier, e$runs))
cat(sprintf("P1 (secant <= 8 runs): %s\n", if (e$runs <= 8) "holds" else "fails"))
fx <- c(runs$f[1:2], runs$f[runs$role == "fixed"])
cat("fixed point |f|:", sprintf("%.3e", abs(fx)), "\n")
ratios <- abs(fx[-1] / fx[-length(fx)])
cat("ratios:", sprintf("%.3f", ratios), "\n")
m <- abs(e$multiplier)
n_fixed <- if (abs(tail(fx, 1)) < 1e-5) which(abs(fx) < 1e-5)[1] else
  length(fx) + ceiling(log(1e-5 / abs(tail(fx, 1))) / log(m))
cat(sprintf("P2 (fixed point >= 2x secant): %d runs (%s) against %d: %s\n", n_fixed,
            if (abs(tail(fx, 1)) < 1e-5) "counted" else "extrapolated at m",
            e$runs, if (n_fixed >= 2 * e$runs) "holds" else "fails"))
s1 <- runs$secs[1]
sb <- runs$secs[runs$role == "b_star"]
cat(sprintf("P3 (run at b* within 30%% of b = 1): %.0f s against %.0f s (%+.0f%%): %s\n",
            sb, s1, 100 * (sb / s1 - 1), if (abs(sb / s1 - 1) <= 0.3) "holds" else "fails"))
ph <- x$phases
w1 <- ph$walk_1$secs; w5 <- ph$walk_5$secs
cat(sprintf("P4 (five-invader walk 4-6 x one): %.0f s against %.0f s (%.2f): %s\n",
            w5, w1, w5 / w1, if (w5 / w1 >= 4 && w5 / w1 <= 6) "holds" else "fails"))
R <- x$stand$J / e$b_star
cat(sprintf("P5 (J' = J(b*)/b*): %.10f against %.10f (%+.2e): %s\n", x$invader$J, R,
            x$invader$J / R - 1, if (abs(x$invader$J / R - 1) <= 1e-6) "holds" else "fails"))
if (!is.null(x$ift)) {
  cat(sprintf("P6 (IFT move <= a tenth): d ln b*/d ln lma %.4f; f held %+.3e, moved %+.3e (%.3f): %s\n",
              x$ift$d_ln_b_d_ln_lma, x$ift$f_held, x$ift$f_moved,
              abs(x$ift$f_moved / x$ift$f_held),
              if (abs(x$ift$f_moved) <= abs(x$ift$f_held) / 10) "holds" else "fails"))
}
cat(sprintf("P7: stand sweep %.0f s = %.2f forwards; invader sweep %.0f s = %.2f walks; five-invader sweep %s s = %s single sweeps\n",
            ph$stand_sweep$secs, ph$stand_sweep$secs / sb, ph$invader_sweep$secs,
            ph$invader_sweep$secs / w1,
            if (!is.null(ph$walk_5_sweep)) sprintf("%.0f", ph$walk_5_sweep$secs) else "NA",
            if (!is.null(ph$walk_5_sweep)) sprintf("%.2f", ph$walk_5_sweep$secs / ph$invader_sweep$secs) else "NA"))
cat(sprintf("splits: at b = 1 %s, at b* %s; steps %d and %d\n", runs$splits[1],
            runs$splits[runs$role == "b_star"], runs$steps[1], runs$steps[runs$role == "b_star"]))
cat("\ninvaders over lma x e^(-0.1..0.1), J':", sprintf("%.6f", x$invaders5$J), "\n")
el <- x$stand$elasticity; ei <- x$invader$elasticity
if (!is.null(el) && !is.null(ei)) {
  cat("\nelasticities at b*, stand (total, field moving) and invader (field held):\n")
  for (n in names(el)) cat(sprintf("  %-28s %+.6f %+.6f\n", n, el[[n]], ei[[n]]))
}
if (length(x$failures)) { cat("\nfailures:\n"); print(x$failures) }
