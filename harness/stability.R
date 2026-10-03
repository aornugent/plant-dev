# The explicit pairs on a pool's test equation y' = -y/T, from their tableaux: for
# a step h = xT, the stage values and the step's result. Reports where a stage
# first turns negative, where the result does, and where the step loses
# stability, in units of T and in days at the pool's relaxation time of 7 days;
# then, at given step lengths, the lowest stage and the step's factor.
#
#   [DAYS=15,22,26,31,38] Rscript harness/stability.R
TAU_S <- 7
tableau <- list(
  "Cash-Karp" = list(
    A = rbind(c(0, 0, 0, 0, 0, 0),
              c(1/5, 0, 0, 0, 0, 0),
              c(3/40, 9/40, 0, 0, 0, 0),
              c(3/10, -9/10, 6/5, 0, 0, 0),
              c(-11/54, 5/2, -70/27, 35/27, 0, 0),
              c(1631/55296, 175/512, 575/13824, 44275/110592, 253/4096, 0)),
    b = c(37/378, 0, 250/621, 125/594, 0, 512/1771)),
  "Dormand-Prince" = list(
    A = rbind(c(0, 0, 0, 0, 0, 0, 0),
              c(1/5, 0, 0, 0, 0, 0, 0),
              c(3/40, 9/40, 0, 0, 0, 0, 0),
              c(44/45, -56/15, 32/9, 0, 0, 0, 0),
              c(19372/6561, -25360/2187, 64448/6561, -212/729, 0, 0, 0),
              c(9017/3168, -355/33, 46732/5247, 49/176, -5103/18656, 0, 0),
              c(35/384, 0, 500/1113, 125/192, -2187/6784, 11/84, 0)),
    b = c(35/384, 0, 500/1113, 125/192, -2187/6784, 11/84, 0)))

# Stage values Y solve (I - zA) Y = 1 for y' = (z/h) y from y = 1.
stages <- function(tb, z) solve(diag(nrow(tb$A)) - z * tb$A, rep(1, nrow(tb$A)))
result <- function(tb, z) 1 + z * sum(tb$b * stages(tb, z))

# The first x in (0, hi] where f holds, scanned then bisected.
first <- function(f, hi = 6, by = 1e-3) {
  xs <- seq(by, hi, by)
  i <- which(vapply(xs, f, TRUE))[1]
  if (is.na(i)) return(NA_real_)
  lo <- xs[i] - by
  up <- xs[i]
  for (k in 1:60) {
    m <- (lo + up) / 2
    if (f(m)) up <- m else lo <- m
  }
  up
}

out <- do.call(rbind, lapply(names(tableau), function(name) {
  tb <- tableau[[name]]
  stage <- first(function(x) any(stages(tb, -x) <= 0))
  res <- first(function(x) result(tb, -x) <= 0)
  unstable <- first(function(x) abs(result(tb, -x)) > 1)
  data.frame(pair = name,
             stage_negative = sprintf("%.4f (stage %s)", stage,
                                      paste(which(stages(tb, -stage * (1 + 1e-9)) <= 0), collapse = ",")),
             result_negative = sprintf("%.4f", res),
             unstable = sprintf("%.4f", unstable),
             days_stage = sprintf("%.1f", stage * TAU_S),
             days_unstable = sprintf("%.1f", unstable * TAU_S))
}))
print(out, row.names = FALSE)

days <- as.numeric(strsplit(Sys.getenv("DAYS", "15,22,26,31,38"), ",")[[1]])
at <- do.call(rbind, lapply(days, function(d) {
  x <- d / TAU_S
  row <- data.frame(days = d, h_over_T = sprintf("%.2f", x))
  for (name in names(tableau)) {
    tb <- tableau[[name]]
    row[[paste(name, "lowest stage")]] <- sprintf("%+.2f", min(stages(tb, -x)))
    row[[paste(name, "factor")]] <- sprintf("%.3f", result(tb, -x))
  }
  row
}))
print(at, row.names = FALSE)
