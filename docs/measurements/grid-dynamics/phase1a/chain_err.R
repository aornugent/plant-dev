# The chain's error, read two ways for one driver run (an OUT of harness_u's driver,
# which records each accepted step's uptake per layer at its end and each entry's):
# - estimated: the soil chain alone, integrated tightly (Cash-Karp at CHAIN_TOL) on the
#   run's own record of uptake, linear in time over each accepted step, against the
#   run's soil at each accepted step's end;
# - measured: the run's soil against the tight monolithic recording (CK, tied, 1e-7)
#   at the times both land on.
#   PLANT_LIB=... [CHAIN_TOL=1e-9] Rscript chain_err.R run.rds [out.rds]
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
source(file.path(D, "phase1a/harness/long_drought.R"))
tab <- new.env()
sys.source(file.path(D, "phase1a/harness/ark436.R"), envir = tab)
args <- commandArgs(TRUE)
run <- readRDS(args[1])
stopifnot(!is.null(run$uptake))
ref <- readRDS(file.path(D, "partition_bias/out/rec_1e-7.rds"))
ctol <- as.numeric(Sys.getenv("CHAIN_TOL", "1e-9"))
env <- mkenv(run$regime)
rain_at <- function(t) max(0, env$extrinsic_drivers_evaluate_range("rainfall", t))
theta_s <- 0.428; K_sat <- 163.0411; q <- 2 * 6.57 + 3; b_inf <- 8; dz <- 1.5 / 5
theta_res <- 0.01
# TF24_Environment::compute_rates for the layers, with the uptake a (per layer) given.
chain <- function(th, t, a) {
  out <- K_sat * (pmin(pmax(th, 0), theta_s) / theta_s)^q
  r <- (c(rain_at(t) * max(0, 1 - (th[1] / theta_s)^b_inf), out[-5]) - out - a) / dz
  r[th <= theta_res & !(r > 0)] <- 0
  r
}
ck <- function(y, t, h, k1, a0, a1, t0, t1) {
  a_at <- function(s) a0 + (a1 - a0) * (s - t0) / (t1 - t0)
  k <- vector("list", 6)
  k[[1]] <- k1
  for (i in 2:6) {
    yi <- y
    for (j in 1:(i - 1)) if (tab$ACK[i, j] != 0) yi <- yi + h * tab$ACK[i, j] * k[[j]]
    s <- t + tab$cCK[i] * h
    k[[i]] <- chain(yi, s, a_at(s))
  }
  y1 <- y; e <- 0
  for (i in 1:6) {
    y1 <- y1 + h * tab$bCK[i] * k[[i]]
    e <- e + h * (tab$bCK[i] - tab$dCK[i]) * k[[i]]
  }
  list(y = y1, e = e)
}
st <- run$st
ent <- run$entry_uptake
th <- rep(0.214, 5)
t <- 0
h <- 1e-6
a_prev <- ent[1, -1]
out <- matrix(NA_real_, nrow(st), 5)
substeps <- 0L
for (k in seq_len(nrow(st))) {
  t0 <- if (k == 1) 0 else st$time[k - 1]
  t1 <- st$time[k]
  e_at <- which(ent[, 1] == t0)
  a0 <- if (length(e_at)) ent[max(e_at), -1] else a_prev
  a1 <- run$uptake[k, ]
  k1 <- chain(th, t0, a0)
  t <- t0
  while (t < t1) {
    final <- t + h >= t1
    hh <- if (final) t1 - t else h
    s <- ck(th, t, hh, k1, a0, a1, t0, t1)
    r <- max(abs(s$e) / (ctol * abs(s$y) + 1e-4 * ctol))
    if (!is.finite(r)) r <- 1e10
    if (r > 1.1 && hh > 1e-9) { h <- hh * max(0.2, 0.9 / r^(1 / 5)); next }
    t <- if (final) t1 else t + hh
    th <- s$y
    substeps <- substeps + 1L
    k1 <- chain(th, t, a1 - (a1 - a0) * (t1 - t) / (t1 - t0))
    if (!final) h <- min(hh * min(5, max(0.2, 0.9 / max(r, 1e-300)^(1 / 5))), 1)
  }
  out[k, ] <- th
  a_prev <- a1
}
run_soil <- as.matrix(st[, paste0("soil_", 1:5)])
est <- run_soil - out
i <- match(st$time, ref$time)
ok <- which(!is.na(i))
meas <- run_soil[ok, ] - ref$soil[i[ok], ]
est_c <- est[ok, ]
mx <- function(m) apply(abs(m), 1, max)
cat(sprintf("%s: %d accepted steps, chain alone %d substeps at %g\n", basename(args[1]), nrow(st), substeps, ctol))
cat(sprintf("  estimated chain error (run - chain alone), all steps: max %.2e, median of per-step max %.2e\n",
            max(abs(est)), median(mx(est))))
cat(sprintf("  at the %d common times: estimated max %.2e, median %.2e | measured (run - 1e-7) max %.2e, median %.2e\n",
            length(ok), max(abs(est_c)), median(mx(est_c)), max(abs(meas)), median(mx(meas))))
cat(sprintf("  correlation of estimated and measured, per layer and time: %.3f; slope %.3f\n",
            cor(as.vector(est_c), as.vector(meas)), coef(lm(as.vector(meas) ~ as.vector(est_c) + 0))))
big <- order(-mx(meas))[1:10]
print(data.frame(t = st$time[ok][big], measured = mx(meas)[big], estimated = mx(est_c)[big]), row.names = FALSE)
if (length(args) > 1) saveRDS(list(time = st$time, chain = out, est = est, ok = ok, meas = meas), args[2])
