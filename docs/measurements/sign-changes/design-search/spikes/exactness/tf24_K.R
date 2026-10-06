# TF24, long drought, 108 uniform nodes: replay the recorded plain program at 1e-4
# with Cash-Karp from R. On each step where some node's net production changes sign
# among its start, stages and end, read P along the step's fourth-order dense
# output (48 points) and compare estimates of K, the positive part's quadrature
# error over the step, against K along the dense output.
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_rr", .libPaths())); suppressMessages(library(plant))
here <- "/home/user/plant-dev/harness"; source(file.path(here, "long_drought.R"))
tab <- new.env(); sys.source(file.path(here, "ark436.R"), envir = tab)
A <- tab$ACK; bw <- tab$bCK; cc <- tab$cCK; BCK4 <- tab$BCK4
eta <- 1e-4
LIFE <- as.numeric(Sys.getenv("LIFE", LIFETIME))
p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
times <- uniform_times(108); p$node_schedule_times <- list(times)
ct <- control(); ct$ode_tol_rel <- 1e-4; ct$ode_tol_abs <- 1e-8; ct$node_density_in_birth_date <- TRUE
env <- mkenv(SCEN)
patch <- plant:::Patch("TF24", "TF24_Env")(p, env, ct)
program <- readRDS("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sc/runs/program_plain.rds")$st
NW <- 8; NE <- 11
nnodes <- function(y) { n <- (length(y) - NE) / NW; stopifnot(n == round(n)); n }
production <- function(y) patch$ode_aux[13 * (seq_len(nnodes(y)) - 1) + 3]
WHERE <- ""
NCLAMP <- 0
ev <- function(y, t) tryCatch(patch$derivs(y, t), error = function(e) {
  pool <- NW * (seq_len(nnodes(y)) - 1) + 6
  if (!any(y[pool] < 0)) { message(sprintf("raise at t=%.10g (%s): %s", t, WHERE, conditionMessage(e))); return(NULL) }
  NCLAMP <<- NCLAMP + 1; y[pool] <- pmax(y[pool], 0)
  tryCatch(patch$derivs(y, t), error = function(e2) { message("raise after clamp: ", conditionMessage(e2)); NULL }) })
combine <- function(y, a, k, h) {
  nz <- which(a != 0)
  if (length(nz) == 1L) return(y + a[nz] * h * k[[nz]])
  s <- a[nz[1]] * k[[nz[1]]]
  for (m in nz[-1]) s <- s + a[m] * k[[m]]
  y + h * s
}
gfun <- function(P) 0.5 * sqrt(P * P + eta * eta)
Gint <- function(P) (P * sqrt(P * P + eta * eta) + eta * eta * asinh(P / eta)) / 4
# The integral of g along the piecewise-linear path through (u, P), exact per piece.
int_pl <- function(u, P) {
  du <- diff(u); a <- P[-length(P)]; b <- P[-1]; d <- b - a
  small <- abs(d) < 1e-9 * (abs(a) + abs(b) + eta)
  val <- ifelse(small, gfun((a + b) / 2), (Gint(b) - Gint(a)) / ifelse(small, 1, d))
  sum(du * val)
}
QE <- c(0, 0.3, 0.6, 0.875, 1); QVE <- solve(outer(QE, 0:4, `^`))
ufine <- seq(0, 1, length.out = 513)
K_quartic <- function(vals, Pst) {
  co <- QVE %*% vals
  int_pl(ufine, as.vector(outer(ufine, 0:4, `^`) %*% co)) - sum(bw * gfun(Pst))
}
M <- 48; ud <- (0:M) / M
WSL <- sapply(ufine, function(u) as.vector(colSums(BCK4 * ((1:4) * u^(0:3)))))
dense_w <- function(u) as.vector(colSums(BCK4 * (u^(1:4))))
WD <- sapply(ud, dense_w)  # 7 x (M+1)
rows <- list(); nstep <- 0; ncross <- 0
t <- 0; t0clock <- proc.time()[3]
for (kk in seq_along(times)) {
  if (times[kk] >= LIFE) break
  patch$introduce_new_node(1L, times[kk])
  y <- patch$ode_state; k1 <- ev(y, t); P0 <- production(y)
  t_end <- if (kk < length(times)) min(times[kk + 1], LIFE) else LIFE
  for (i in which(program$time > t & program$time <= t_end)) {
    h <- program$h[i]
    K <- matrix(0, length(y), 6); K[, 1] <- k1; kl <- list(k1); Pst <- matrix(0, length(P0), 6); Pst[, 1] <- P0
    for (s in 2:6) {
      Y <- combine(y, A[s, ], kl, h)
      WHERE <- sprintf("step %d stage %d", i, s); ks <- ev(Y, t + cc[s] * h); if (is.null(ks)) stop("stage raised"); K[, s] <- ks; kl[[s]] <- ks; Pst[, s] <- production(Y)
    }
    y1 <- combine(y, bw, kl, h); WHERE <- sprintf("step %d end", i); f1 <- ev(y1, program$time[i]); if (is.null(f1)) stop("end raised"); P1 <- production(y1)
    allP <- cbind(Pst, P1)
    cr <- which(apply(allP, 1, function(v) length(unique(sign(v))) > 1))
    if (length(cr)) {
      ncross <- ncross + 1
      KK <- cbind(K, f1)
      Pd <- matrix(0, length(P0), M + 1); Pd[, 1] <- P0; Pd[, M + 1] <- P1
      for (q in 2:M) { yd <- y + h * as.vector(KK %*% WD[, q]); WHERE <- sprintf("step %d dense %d", i, q); Pd[, q] <- if (is.null(ev(yd, t + ud[q] * h))) NA else production(yd) }
      for (jj in seq_len(nrow(Pd))) if (anyNA(Pd[jj, ])) Pd[jj, ] <- approx(ud[!is.na(Pd[jj, ])], Pd[jj, !is.na(Pd[jj, ])], ud)$y
      for (j in cr) {
        Kd <- int_pl(ud, Pd[j, ]) - sum(bw * gfun(Pst[j, ]))
        Ke <- K_quartic(c(Pst[j, c(1, 3, 4, 6)], P1[j]), Pst[j, ])
        Kl <- int_pl(c(0, 1), c(P0[j], P1[j])) - sum(bw * gfun(Pst[j, ]))
        Ks <- K_quartic(Pst[j, c(1, 3, 4, 6, 5)], Pst[j, ])
        Kslope <- int_pl(ufine, as.vector(c(Pst[j, ], P1[j]) %*% WSL)) - sum(bw * gfun(Pst[j, ]))
        sgn <- which(diff(sign(Pd[j, ])) != 0)
        ustar <- if (length(sgn)) ud[sgn[1]] else NA
        stage_err <- max(abs(Pst[j, c(3, 4, 6)] - approx(ud, Pd[j, ], cc[c(3, 4, 6)])$y))
        rows[[length(rows) + 1]] <- c(t = t, node = j, born = times[j], h = h, s = P1[j] - P0[j],
          ustar = ustar, nroots = length(sgn), Kd = Kd, Ke = Ke, Kl = Kl, Ks = Ks, Kslope = Kslope, P1 = Pst[j, 1], P2 = Pst[j, 2], P3 = Pst[j, 3], P4 = Pst[j, 4], P5 = Pst[j, 5], P6 = Pst[j, 6], Pe = P1[j], stage_err = stage_err,
          range = diff(range(Pd[j, ])))
      }
    }
    nstep <- nstep + 1
    t <- program$time[i]; y <- y1; k1 <- f1; P0 <- P1
  }
}
D <- as.data.frame(do.call(rbind, rows))
saveRDS(D, sprintf("tf24_K_%g.rds", LIFE))
cat(sprintf("clamped evaluations %d\n", NCLAMP)); cat(sprintf("steps %d, crossing steps %d, crossing node-steps %d, secs %.0f\n", nstep, ncross, nrow(D), proc.time()[3] - t0clock))
