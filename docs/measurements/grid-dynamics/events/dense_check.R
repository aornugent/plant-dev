# How far the split's dense output (the cubic Hermite interpolant of a step's
# end states and rates) is from the state it stands for, on the crossing steps
# of the 1e-4 grid: at u = 1/4, 1/2, 3/4 of each of the first STEPS crossing
# steps, the interpolant against one Cash-Karp step of length u h from the
# step's start (local error O((u h)^6)), each component in units of the error
# weight the controller holds it to. The step's own error ratio is the scale.
E <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events"
Sys.setenv(PLANT_LIB = file.path(E, "lib"), NODES = "108", TOL = "1e-4", ATOL = "1e-4", METHOD = "ck",
           TF24_DOMAIN_TOL = "1e9")
source(file.path(E, "harness", "ark_prototype.R"))
STEPS <- as.integer(Sys.getenv("STEPS", "60"))
program <- readRDS(file.path(E, "runs", "g_1e-4.rds"))$st
level_of <- function(y, dydt, h) ct$ode_tol_rel * (ct$ode_a_y * abs(y) + ct$ode_a_dydt * abs(h * dydt)) + ct$ode_tol_abs
sv$t <- 0; sv$h_last <- ct$ode_step_size_initial; sv$zone_until <- -Inf; sv$Pdot <- numeric()
rows <- list(); seen <- 0
for (k in seq_along(times)) {
  patch$introduce_new_node(1L, times[k])
  sv$y <- patch$ode_state; sv$dydt <- rates(sv$y, sv$t); sv$P <- production(sv$y); sv$K <- klass(sv$y)
  t_end <- if (k < length(times)) times[k + 1] else LIFETIME
  for (i in which(program$time > sv$t & program$time <= t_end)) {
    h <- program$h[i]
    a <- attempt(sv$t, sv$y, sv$dydt, h)
    f <- which(sign(a$P) != sign(sv$P))
    if (length(f)) {
      seen <- seen + 1
      y0 <- sv$y; f0 <- sv$dydt; y1 <- a$y; f1 <- a$rates
      lev <- level_of(y1, f1, h)
      soil_i <- soil(y0); M <- (length(y0) - 10) %/% 9
      member_i <- setdiff(seq_len(9 * M), as.vector(outer(1:9, 9 * (f - 1), "+")))
      ratio_step <- max(abs(a$yerr) / abs(lev))
      for (u in c(0.25, 0.5, 0.75)) {
        yH <- (1 + 2 * u) * (1 - u)^2 * y0 + u * (1 - u)^2 * h * f0 + u^2 * (3 - 2 * u) * y1 + u^2 * (u - 1) * h * f1
        r <- attempt(sv$t, y0, f0, u * h)
        err <- abs(yH - r$y) / abs(lev)
        rows[[length(rows) + 1]] <- data.frame(row = i, t = sv$t, h_days = 365 * h, u = u, crossing = length(f),
          step_ratio = ratio_step, soil = max(err[soil_i]), members = max(err[member_i]),
          storage = max(err[intersect(member_i, pool_of(y0))]), h_lambda_beta = h * lambda_soil(y0, sv$t) / BETA)
      }
    }
    sv$t <- program$time[i]; sv$y <- a$y; sv$dydt <- a$rates; sv$P <- a$P; sv$K <- a$K
    if (seen >= STEPS) break
  }
  if (seen >= STEPS) break
}
d <- do.call(rbind, rows)
saveRDS(d, file.path(E, "runs", "dense_check.rds"))
cat(sprintf("%d crossing steps from t = %.3f to %.3f; median h %.3g days, h |lambda| / beta median %.2f\n",
            seen, min(d$t), max(d$t), median(d$h_days), median(d$h_lambda_beta)))
cat("the interpolant's error in units of each component's error weight (the step's own estimate is at most 1.1):\n")
for (u in c(0.25, 0.5, 0.75)) {
  x <- d[d$u == u, ]
  cat(sprintf("  u = %.2f: soil median %.3g, 90%% %.3g, max %.3g; other members median %.3g, max %.3g (storage max %.3g); step ratio median %.3g\n",
              u, median(x$soil), quantile(x$soil, 0.9), max(x$soil), median(x$members), max(x$members),
              max(x$storage), median(x$step_ratio)))
}
