# Criterion 1 (prereg.txt): PI + chain seeds against the monolithic ladder at matched J
# error, long drought, tied tolerance, uniform 108.
#   Rscript matched.R [pi_prefix=pics]
P <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pi"
Jstar <- 12.6687135
args <- commandArgs(TRUE)
prefix <- if (length(args)) args[1] else "pics"
# The monolithic ladder (partition/logs/mono_*.log, tied_1e-5_soil1.log) and its nudges here.
mono <- data.frame(tol = c(1e-3, 3e-4, 1e-4, 3e-5, 1e-5),
                   J = c(12.663678859, 12.668755154, 12.669177141, 12.668554505, 12.668779336),
                   cost = c(4362846, 5098073, 5948875, 7063344, 8421474))
add <- function(d, name) {
  f <- file.path(P, "runs", paste0(name, ".rds"))
  if (!file.exists(f)) return(d)
  r <- readRDS(f)
  rbind(d, data.frame(tol = r$tol, J = r$J, cost = r$counts$members))
}
for (n in c("base_2.85e-5", "base_3.15e-5")) mono <- add(mono, n)
pi <- mono[0, ]
for (n in paste0(prefix, "_", c("1e-4", "3.15e-5", "3e-5", "2.85e-5", "1e-5"))) pi <- add(pi, n)
for (d in c("mono", "pi")) {
  x <- get(d); x$err <- x$J / Jstar - 1; x$ratio <- abs(x$err) / x$tol
  x <- x[order(-x$tol), ]; assign(d, x)
}
cat("monolithic:\n"); print(transform(mono, err = sprintf("%+.3g", err), ratio = signif(ratio, 3)), row.names = FALSE)
cat(prefix, ":\n"); print(transform(pi, err = sprintf("%+.3g", err), ratio = signif(ratio, 3)), row.names = FALSE)

# log-log interpolation, extrapolated linearly from the two nearest points
loglog <- function(x, y, at) {
  o <- order(x); x <- log(x[o]); y <- log(y[o]); a <- log(at)
  if (a < x[1]) i <- 1 else if (a > x[length(x)]) i <- length(x) - 1 else i <- max(1, min(findInterval(a, x), length(x) - 1))
  exp(y[i] + (y[i + 1] - y[i]) * (a - x[i]) / (x[i + 1] - x[i]))
}
inrange <- function(x) x[x$tol >= 1e-5 * (1 - 1e-9) & x$tol <= 1e-4 * (1 + 1e-9), ]
m <- inrange(mono); p <- inrange(pi)
if (nrow(p) >= 2) {
  cm <- max(m$ratio); cp <- max(p$ratio)
  E0 <- cm * 3e-5
  tol_p <- E0 / cp
  Cm <- loglog(m$tol, m$cost, 3e-5); Cp <- loglog(p$tol, p$cost, tol_p)
  cat(sprintf("\n(A) bound reading: c_mono %.3f, c_pi %.3f; E0 = c_mono 3e-5 = %.3g; PI reaches it at tol %.3g%s\n",
              cm, cp, E0, tol_p, if (tol_p < min(p$tol) || tol_p > max(p$tol)) " (extrapolated)" else ""))
  cat(sprintf("    cost there %.4g against the monolith's %.4g at 3e-5: S_A = %.1f%%\n", Cp, Cm, 100 * (1 - Cp / Cm)))
  # the same with the median ratio, as a check on the envelope's draw
  cm2 <- median(m$ratio); cp2 <- median(p$ratio)
  Cp2 <- loglog(p$tol, p$cost, cm2 * 3e-5 / cp2)
  cat(sprintf("    with median ratios (%.3f, %.3f): S = %.1f%%\n", cm2, cp2, 100 * (1 - Cp2 / Cm)))
  # at equal tol, for reference
  for (t in c(1e-4, 3e-5, 1e-5)) if (any(abs(p$tol / t - 1) < 1e-9) && any(abs(m$tol / t - 1) < 1e-9))
    cat(sprintf("    at equal tol %g: cost %.4g against %.4g (%.1f%%)\n", t, p$cost[abs(p$tol / t - 1) < 1e-9],
                m$cost[abs(m$tol / t - 1) < 1e-9], 100 * (1 - p$cost[abs(p$tol / t - 1) < 1e-9] / m$cost[abs(m$tol / t - 1) < 1e-9])))
}
# (B) direct: each PI rung's |error| on the monolith's monotone bracket 1e-4, 3e-5, 1e-5
br <- mono[mono$tol %in% c(1e-4, 3e-5, 1e-5), ]
cat("\n(B) direct reading on the monolith's bracket (|err| 3.66e-5 / 1.26e-5 / 5.2e-6):\n")
for (i in seq_len(nrow(pi))) {
  e <- abs(pi$err[i])
  Cm <- loglog(abs(br$err), br$cost, e)
  inside <- e >= min(abs(br$err)) && e <= max(abs(br$err))
  cat(sprintf("    %s tol %.3g: |err| %.3g, cost %.4g; the monolith at that error %.4g%s: S_B = %.1f%%\n",
              prefix, pi$tol[i], e, pi$cost[i], Cm, if (inside) "" else " (extrapolated)", 100 * (1 - pi$cost[i] / Cm)))
}
# The 3e-5 triple's RMS error per law
trip <- function(x) x[x$tol > 2.8e-5 & x$tol < 3.2e-5, ]
for (d in c("mono", "pi")) {
  x <- trip(get(d))
  if (nrow(x) == 3) cat(sprintf("%s at 3e-5 x {0.95, 1, 1.05}: RMS error %.3g, mean cost %.4g\n", d, sqrt(mean(x$err^2)), mean(x$cost)))
}
