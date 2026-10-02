# T1: for every attempt of the three coupled runs, one Cash-Karp step of the same
# size on the soil chain alone (no uptake), from the coupled run's soil state at
# the attempt's start, under the driver's soil weights (max norm, level tol |y1| +
# 1e-4 tol, TOL_SOIL = 1). Saves a per-attempt table per run; t1_report.R reads it.
#
#   nice -n 10 Rscript DEV/rej_class/t1_chain.R      (about a minute)
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
W <- "/home/user/plant-dev/.claude/worktrees/agent-a4dae3c2572021890"
O <- file.path(D, "rej_class")
Sys.setenv(PLANT_LIB = file.path(D, "lib_v12t"))
source(file.path(W, "harness", "long_drought.R"))
tab <- new.env()
sys.source(file.path(W, "harness", "ark436.R"), envir = tab)
source(file.path(D, "pi", "analyse.R"))   # load_run(), classify(); runs nothing without args

theta_s <- 0.428; K_sat <- 163.0411; q <- 2 * 6.57 + 3; b_inf <- 8; dz <- 1.5 / 5
env <- mkenv("long-drought")
rain_at <- function(t) pmax(0, env$extrinsic_drivers_evaluate_range("rainfall", t))
# The chain's rates for n states at once (rows), as harness/soil_chain.R has them.
chain_rates <- function(th, rain) {
  out <- K_sat * (pmin(pmax(th, 0), theta_s) / theta_s)^q
  (cbind(rain * pmax(0, 1 - (th[, 1] / theta_s)^b_inf), out[, 1:4, drop = FALSE]) - out) / dz
}
# One Cash-Karp step per row, summed as the driver's combine() does: the nonzero
# terms in ascending stage, then one h.
combine <- function(y, a, k, h) {
  nz <- which(a != 0)
  if (length(nz) == 1L) return(y + (a[nz] * h) * k[[nz]])
  s <- a[nz[1]] * k[[nz[1]]]
  for (m in nz[-1]) s <- s + a[m] * k[[m]]
  y + h * s
}
ck_chain <- function(y0, t0, h, tol, atol) {
  k <- list(chain_rates(y0, rain_at(t0)))
  for (i in 2:6) {
    Y <- combine(y0, tab$ACK[i, ], k, h)
    k[[i]] <- chain_rates(Y, rain_at(t0 + tab$cCK[i] * h))
  }
  y1 <- combine(y0, tab$bCK, k, h)
  e <- combine(0, tab$bCK - tab$dCK, k, h)
  r <- abs(e) / (tol * abs(y1) + atol)
  list(y1 = y1, ratio = r, rmax = apply(r, 1, max), layer = max.col(r, ties.method = "first"))
}

DAY <- 1 / 365
for (name in c("pics_3e-5", "pi_3e-5", "base_3e-5")) {
  x <- load_run(name); run <- x$run; a <- x$a; st <- run$st
  stopifnot(run$tol == 3e-5)
  tol <- run$tol; atol <- 1e-4 * tol
  d <- classify(run, a)
  # The coupled soil state at each attempt's start: the accepted step ending there.
  i0 <- match(a$t0, st$time)
  stopifnot(all(!is.na(i0) | a$t0 == 0))
  soil_cols <- paste0("soil_", 1:5)
  y0 <- matrix(0.214, nrow(a), 5)
  y0[!is.na(i0), ] <- as.matrix(st[i0[!is.na(i0)], soil_cols])
  ch <- ck_chain(y0, a$t0, a$h, tol, atol)
  # The coupled attempt's binding layer, where the soil binds.
  M <- ifelse(a$thrown == 1, NA, a$members / 6)
  layer <- ifelse(d$part == "soil", a$index - 9 * M, NA)
  # Knot, its rain change, and the attempt's place after it.
  knots <- sort(unique(run$knots))
  rain <- run$rain
  rain_day <- function(t) rain[pmin(pmax(floor(t / DAY + 1e-9) + 1, 1), length(rain))]
  k <- findInterval(a$t0 + 1e-12, knots)
  kt <- ifelse(k > 0, knots[pmax(k, 1)], NA)
  before <- rain_day(kt - 0.5 * DAY); after <- rain_day(kt + 0.5 * DAY)
  change <- ifelse(before == 0 & after > 0, "starts", ifelse(before > 0 & after == 0, "stops",
                   ifelse(after > before, "rises", "falls")))
  acc <- a$rejected == 0
  n_since <- ave(as.numeric(acc), k, FUN = function(v) c(0, cumsum(v)[-length(v)]))
  # The attempt just before in the log, and the accepted one before each attempt.
  prev_acc <- c(NA, head(cummax(ifelse(acc, seq_len(nrow(a)), 0)), -1))
  prev_acc[!is.na(prev_acc) & prev_acc == 0] <- NA
  out <- data.frame(row = seq_len(nrow(a)), t0 = a$t0, h = a$h, rej = d$rej, cls = d$cls, part = d$part,
                    try = a$try, final = a$final, since = d$since, n_since, knot = kt, change,
                    rain_before = before, rain_after = after,
                    ratio = a$ratio, layer, chain = ch$rmax, chain_layer = ch$layer,
                    x_soil = a$x_soil, proposal = a$proposal, r_set = a$r_set, f_set = a$f_set,
                    crossed = a$crossed, members = a$members, prev = prev_acc)
  for (j in 1:5) out[[paste0("chain_r", j)]] <- ch$ratio[, j]
  for (j in 1:5) out[[paste0("theta", j)]] <- y0[, j]
  out$rain_t0 <- rain_at(a$t0)
  out$rain_t1 <- rain_at(a$t0 + a$h)
  saveRDS(out, file.path(O, paste0("t1_", name, ".rds")))
  cat(sprintf("%s: %d attempts, %d rejected; saved\n", name, nrow(out), sum(out$rej)))
}
