# Where Runge-Kutta steps overshoot on a pool's test equation y' = -y/T: for a step
# h = xT from y = 1, the value at each stage (where the rates are evaluated) and
# the step's result. For each method it reports where a stage first turns
# negative, where the result does, where the step loses stability, and the lowest
# stage on given step lengths at the pool's relaxation time of 7 days. The
# explicit methods are tableaux, Cash-Karp's, Dormand-Prince's and the ARK's from
# harness/ark436.R; SSPRK(10,4) runs its low-storage form, and RODAS its stages
# with the exact Jacobian. Each method's order is read off its step's
# factor against exp(z) near z = 0, which checks the coefficients.
#
#   [DAYS=15,26] Rscript harness/stability.R
here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
ark <- new.env()
sys.source(file.path(here, "ark436.R"), envir = ark)
TAU_S <- 7

lower <- function(rows) {
  s <- length(rows)
  A <- matrix(0, s, s)
  for (i in seq_len(s)) A[i, seq_along(rows[[i]])] <- rows[[i]]
  A
}

# Stage values Y solve (I - zA) Y = 1 for y' = (z/h) y.
tableau <- function(A, b, evals) {
  list(evals = evals, run = function(z) {
    Y <- solve(diag(nrow(A)) - z * A, rep(1, nrow(A)))
    list(stages = Y, result = 1 + z * sum(b * Y))
  })
}

# Ketcheson (2008): ten stages, each a forward-Euler step of h/6 or a combination.
ssprk104 <- list(evals = 10, run = function(z) {
  q1 <- 1; q2 <- 1; stages <- numeric(0)
  for (i in 1:5) { stages <- c(stages, q1); q1 <- q1 + z / 6 * q1 }
  q2 <- q2 / 25 + 9 / 25 * q1
  q1 <- 15 * q2 - 5 * q1
  for (i in 6:9) { stages <- c(stages, q1); q1 <- q1 + z / 6 * q1 }
  stages <- c(stages, q1)
  list(stages = stages, result = q2 + 3 / 5 * q1 + z / 10 * q1)
})

# odelia's RODAS (Hairer & Wanner's rodas.f, METH = 1), on y' = lambda y with its
# exact Jacobian: each stage solves (1/gamma - z) k_i = z arg_i + sum_j c_ij k_j.
rodas <- local({
  gamma <- 0.25
  a <- lower(list(numeric(0), 1.544, c(0.9466785280815826, 0.2557011698983284),
                  c(3.314825187068521, 2.896124015972201, 0.9986419139977817),
                  c(1.221224509226641, 6.019134481288629, 12.53708332932087,
                    -0.6878860361058950)))
  cc <- lower(list(numeric(0), -5.6688, c(-2.430093356833875, -0.2063599157091915),
                   c(-0.1073529058151375, -9.594562251023355, -20.47028614809616),
                   c(7.496443313967647, -10.24680431464352, -33.99990352819905,
                     11.70890893206160),
                   c(8.083246795921522, -7.981132988064893, -31.52159432874371,
                     16.31930543123136, -6.058818238834054)))
  list(evals = 6, run = function(z) {
    k <- numeric(6); args <- numeric(6)
    for (i in 1:6) {
      args[i] <- if (i <= 5) 1 + sum(a[i, seq_len(i - 1)] * k[seq_len(i - 1)])
                 else args[5] + k[5]
      k[i] <- (z * args[i] + sum(cc[i, seq_len(i - 1)] * k[seq_len(i - 1)])) / (1 / gamma - z)
    }
    list(stages = args, result = args[6] + k[6])
  })
})

methods <- list(
  "forward Euler" = tableau(matrix(0, 1, 1), 1, 1),
  "Heun (SSPRK2)" = tableau(lower(list(0, 1)), c(1/2, 1/2), 2),
  "SSPRK(3,3)" = tableau(lower(list(0, 1, c(1/4, 1/4))), c(1/6, 1/6, 2/3), 3),
  "Bogacki-Shampine 3(2)" = tableau(lower(list(0, 1/2, c(0, 3/4), c(2/9, 1/3, 4/9))),
                                    c(2/9, 1/3, 4/9, 0), 3),
  "classic RK4" = tableau(lower(list(0, 1/2, c(0, 1/2), c(0, 0, 1))),
                          c(1/6, 1/3, 1/3, 1/6), 4),
  "Fehlberg 4(5)" = tableau(lower(list(0, 1/4, c(3/32, 9/32),
                                       c(1932/2197, -7200/2197, 7296/2197),
                                       c(439/216, -8, 3680/513, -845/4104),
                                       c(-8/27, 2, -3544/2565, 1859/4104, -11/40))),
                            c(25/216, 0, 1408/2565, 2197/4104, -1/5, 0), 6),
  "Cash-Karp 5(4)" = tableau(ark$ACK, ark$bCK, 6),
  "Dormand-Prince 5(4)" = tableau(ark$ADP, ark$bDP, 6),
  "Tsitouras 5(4)" = tableau(lower(list(0, 0.161,
                                        c(-0.008480655492356989, 0.335480655492357),
                                        c(2.897153057105493, -6.359448489975075, 4.3622954328695815),
                                        c(5.325864828439257, -11.748883564062828, 7.4955393428898365,
                                          -0.09249506636175525),
                                        c(5.86145544294642, -12.92096931784711, 8.159367898576159,
                                          -0.071584973281401, -0.028269050394068383),
                                        c(0.09646076681806523, 0.01, 0.4798896504144996,
                                          1.379008574103742, -3.290069515436081, 2.324710524099774))),
                             c(0.09646076681806523, 0.01, 0.4798896504144996, 1.379008574103742,
                               -3.290069515436081, 2.324710524099774, 0), 6),
  "ARK4(3)6L explicit part" = tableau(ark$AE, ark$b, 6),
  "SSPRK(10,4)" = ssprk104,
  "RODAS (implicit)" = rodas)

# The first x in (0, hi] where f holds, scanned then bisected.
first <- function(f, hi, by = 1e-3) {
  xs <- seq(by, hi, by)
  hit <- vapply(xs, f, TRUE)
  i <- which(hit)[1]
  if (is.na(i)) return(NA_real_)
  lo <- xs[i] - by
  up <- xs[i]
  for (k in 1:60) {
    m <- (lo + up) / 2
    if (f(m)) up <- m else lo <- m
  }
  up
}

order_of <- function(m) {
  e <- vapply(c(-0.1, -0.05), function(z) abs(m$run(z)$result - exp(z)), 0)
  round(log2(e[1] / e[2])) - 1
}

days <- as.numeric(strsplit(Sys.getenv("DAYS", "15,26"), ",")[[1]])
out <- do.call(rbind, lapply(names(methods), function(name) {
  m <- methods[[name]]
  stage <- first(function(x) min(m$run(-x)$stages) <= 0, 60)
  res <- first(function(x) m$run(-x)$result <= 0, 60)
  unstable <- first(function(x) abs(m$run(-x)$result) > 1, 60)
  row <- data.frame(method = name, order = order_of(m), evals = m$evals,
                    stage_negative = sprintf("%.2f", stage),
                    per_eval = sprintf("%.2f", stage / m$evals),
                    result_negative = sprintf("%.2f", res),
                    unstable = sprintf("%.2f", unstable))
  for (d in days) row[[sprintf("lowest_%gd", d)]] <- sprintf("%+.2f", min(m$run(-d / TAU_S)$stages))
  row
}))
print(out, row.names = FALSE)
