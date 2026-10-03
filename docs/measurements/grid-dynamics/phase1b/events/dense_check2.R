# How far each dense output is from the state it stands for, on every crossing
# step of a grid (a step across which a member's net production changes sign):
# at u = 1/4, 1/2, 3/4 the interpolant against one step of the same pair of
# length u h from the step's start, each component in units of the error weight
# the controller holds it to at the step's end. The field a split member reads
# is the soil and every member that does not cross in that step.
#   PLANT_LIB=... METHOD=dp TOL=1e-4 GRID=run.rds OUT=dc.rds [STEPS=Inf] \
#     Rscript harness/dense_check2.R
GRID <- Sys.getenv("GRID")
OUTF <- Sys.getenv("OUT")
STEPS <- as.numeric(Sys.getenv("STEPS", "Inf"))
Sys.setenv(TF24_DOMAIN_TOL = "1e9")
source("harness/ark_prototype.R")
kinds <- c("cubic", "quintic", if (method == "dp") "dp4" else "ck4")
program <- readRDS(GRID)$st
level_of <- function(y, dydt, h) ct$ode_tol_rel * (ct$ode_a_y * abs(y) + ct$ode_a_dydt * abs(h * dydt)) + ct$ode_tol_abs
sv$t <- 0; sv$h_last <- ct$ode_step_size_initial; sv$zone_until <- -Inf; sv$Pdot <- numeric()
rows <- list(); seen <- 0
t_start <- proc.time()[["elapsed"]]
for (k in seq_along(times)) {
  patch$introduce_new_node(1L, times[k])
  sv$y <- patch$ode_state; sv$dydt <- rates(sv$y, sv$t); sv$P <- production(sv$y); sv$K <- klass(sv$y)
  t_end <- if (k < length(times)) times[k + 1] else LIFETIME
  for (i in which(program$time > sv$t & program$time <= t_end)) {
    h <- program$h[i]
    a <- attempt(sv$t, sv$y, sv$dydt, h)
    if (is.null(a)) stop(sprintf("a replayed step raised at t = %.17g", sv$t))
    f <- which(sign(a$P) != sign(sv$P))
    if (length(f) && seen < STEPS) {
      seen <- seen + 1
      y0 <- sv$y; f0 <- sv$dydt; y1 <- a$y; f1 <- a$rates
      lev <- level_of(y1, f1, h)
      soil_i <- soil(y0); M <- (length(y0) - 10) %/% 9
      member_i <- setdiff(seq_len(9 * M), as.vector(outer(1:9, 9 * (f - 1), "+")))
      pool_i <- intersect(member_i, pool_of(y0))
      ratio_step <- max(abs(a$yerr) / abs(lev))
      x_soil <- h * lambda_soil(y0, sv$t) / BETA
      interps <- lapply(kinds, function(kd) dense_of(sv$t, y0, f0, a, h, kd))
      names(interps) <- kinds
      for (u in c(0.25, 0.5, 0.75)) {
        r <- attempt(sv$t, y0, f0, u * h)
        if (is.null(r)) next
        for (kd in kinds) {
          if (is.null(interps[[kd]])) next
          err <- abs(interps[[kd]](u) - r$y) / abs(lev)
          rows[[length(rows) + 1]] <- data.frame(row = i, t = sv$t, h_days = 365 * h, u = u, kind = kd,
            crossing = length(f), step_ratio = ratio_step, soil = max(err[soil_i]),
            members = if (length(member_i)) max(err[member_i]) else 0,
            storage = if (length(pool_i)) max(err[pool_i]) else 0, x_soil = x_soil)
        }
      }
    }
    sv$t <- program$time[i]; sv$y <- a$y; sv$dydt <- a$rates; sv$P <- a$P; sv$K <- a$K
  }
}
d <- do.call(rbind, rows)
d$field <- pmax(d$soil, d$members)
saveRDS(d, OUTF)
cat(sprintf("%s grid at tol %g: %d crossing steps, %d steps replayed, %.0f s; median h %.3g days, step ratio median %.3g, h |lambda| / beta median %.2f\n",
            method, tol, seen, nrow(program), proc.time()[["elapsed"]] - t_start,
            median(d$h_days[d$kind == kinds[1] & d$u == 0.5]), median(d$step_ratio[d$kind == kinds[1] & d$u == 0.5]),
            median(d$x_soil[d$kind == kinds[1] & d$u == 0.5])))
cat("the interpolant's error in error weights; field = max(soil, members not crossing); per step, the max over u:\n")
for (kd in kinds) {
  x <- d[d$kind == kd, ]
  per_step <- tapply(x$field, x$row, max)
  per_soil <- tapply(x$soil, x$row, max)
  per_mem <- tapply(x$members, x$row, max)
  cat(sprintf("  %-7s steps over 1: %d of %d (soil %d, members %d); field median %.3g, 90%% %.3g, 99%% %.3g, max %.3g; storage max %.3g\n",
              kd, sum(per_step > 1), length(per_step), sum(per_soil > 1), sum(per_mem > 1),
              median(per_step), quantile(per_step, 0.9), quantile(per_step, 0.99), max(per_step),
              max(x$storage)))
  for (u in c(0.25, 0.5, 0.75)) {
    y <- x[x$u == u, ]
    cat(sprintf("     u = %.2f: soil median %.3g, max %.3g; members median %.3g, max %.3g; field / step ratio median %.3g, 90%% %.3g\n",
                u, median(y$soil), max(y$soil), median(y$members), max(y$members),
                median(y$field / pmax(y$step_ratio, 1e-12)), quantile(y$field / pmax(y$step_ratio, 1e-12), 0.9)))
  }
}
