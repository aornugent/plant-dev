# A scorer for any schedule. Each interval's error in ln J is d(b) h^3, with d from the
# case's J maps (finest panel covering b). Each quantity's error is a per-band factor
# times the band's summed |interval error|, the factors fitted on the case's real runs.
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
source("/home/user/plant-dev/harness/schedule/lattice.R")
AR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
BANDS_B <- function(b1) c(0, b1, 10, 40)
map_runs <- function(case) sub("\\.rds$", "", list.files(AR, sprintf("^loc_.*_%s\\.rds$", gsub("-", "\\\\-", case))))
panels_of <- function(case) do.call(rbind, lapply(map_runs(case), function(n) { x <- run(n); if (is.null(x$light) || is.null(x$stand$elasticity)) return(NULL)
  G <- x$node_times; j <- x$dropped; b <- nd(x)
  m <- own_drop(b, j) / sum(b$w * b$offspring) + (colSums(x$light) + colSums(x$soil)) / x$stand$J
  data.frame(run = n, lo = G[j - 1], mid = G[j], hi = G[j + 1], h = (G[j + 1] - G[j - 1]) / 2, m = m) }))
# Density per unit birth date of ln J's error, d = m / (6 h^3): a panel of two intervals h
# errs 2 d h^3 and its merged interval 8 d h^3.
density_fn <- function(P) { P <- P[order(P$h), ]
  function(b) vapply(b, function(x) { i <- which(P$lo <= x & P$hi > x)
    if (length(i)) return(P$m[i[1]] / (6 * P$h[i[1]]^3))
    k <- which.min(abs(P$mid - x)); P$m[k] / (6 * P$h[k]^3) }, 0) }
interval_errors <- function(case, S, dens, shut) { lo <- S[-length(S)]; hi <- S[-1]; mid <- (lo + hi) / 2
  e <- dens(mid) * (hi - lo)^3; e[shut(mid) > 0.5] <- 0; data.frame(lo, hi, mid, e = e / 0.025) }
features <- function(case, S, dens, shut, b1) { ie <- interval_errors(case, S, dens, shut)
  bd <- cut(ie$mid, BANDS_B(b1), right = FALSE); c(lnJ_signed = sum(ie$e), tapply(abs(ie$e), bd, sum)) }
case_data <- function(case) { ref <- reference(case); P <- panels_of(case); dens <- density_fn(P); pe <- pilot_edges(case)
  ns <- sub("\\.rds$", "", list.files(AR, sprintf("^(lat|loc)_%s_.*\\.rds$|^loc_.*_%s\\.rds$", case, case)))
  ns <- ns[!grepl("_l140$", ns)]
  ns <- ns[vapply(ns, function(n) !is.null(run(n)$stand$elasticity), TRUE)]
  rs <- lapply(ns, function(n) { x <- run(n); q <- quantities(x); k <- intersect(names(ref), names(q))
    list(name = n, S = x$node_times, err = (q[k] - ref[k]) / eps_vec(k), X = features(case, x$node_times, dens, pe$shut, pe$b1), rows = x$stand$rows) })
  list(case = case, runs = rs, dens = dens, shut = pe$shut, b1 = pe$b1, P = P) }
fit_kappa <- function(rs, Q) { X <- do.call(rbind, lapply(rs, function(r) r$X[-1])); y <- sapply(rs, function(r) r$err[Q])
  X[is.na(X)] <- 0; ok <- colSums(X) > 0; k <- rep(0, ncol(X)); names(k) <- colnames(X)
  k[ok] <- qr.solve(X[, ok, drop = FALSE], y, tol = 1e-10); k }
predict_err <- function(r, kap) { x <- r$X[-1]; x[is.na(x)] <- 0; sum(kap * x) }
