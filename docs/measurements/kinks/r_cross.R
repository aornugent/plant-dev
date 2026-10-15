x <- readRDS(Sys.getenv("TRAJ", "traj.rds")); st <- list(eta = 12, a_l1 = 5.44, a_l2 = 0.306, theta = 1/4669, rho = 608, a_st1 = 0.1, a_st2 = 0.1, rooting_depth_max = 1.5)
eta <- st$eta; eta_c <- 1 - 2/(1 + eta) + 1/(1 + 2*eta)
cat("names:", paste(head(names(x$rows[[1]]), 10), collapse=" "), "\n")
t <- vapply(x$rows, `[[`, 0, "time")
S <- lapply(x$rows, `[[`, "state")
nn <- (lengths(S) - 10) / 9
cat("rows", length(t), "max nodes", max(nn), "\n")
N <- max(nn); H <- R <- matrix(NA, length(t), N)
for (i in seq_along(t)) if (nn[i] > 0) {
  m <- matrix(S[[i]][1:(9*nn[i])], 9)
  h <- m[1, ]; s <- m[6, ]
  al <- (h / st$a_l1)^(1 / st$a_l2)
  smax <- st$a_st1 * al * st$theta * h * eta_c * st$rho
  H[i, 1:nn[i]] <- h; R[i, 1:nn[i]] <- s / smax
}
# r crossing a_st2 = 0.1, and how long r takes from 0.2 to 0.0 or back (band of G)
a <- st$a_st2; cr <- 0; dur <- c(); hs <- c()
for (j in 1:N) {
  r <- R[, j]; ok <- !is.na(r); tt <- t[ok]; r <- r[ok]; if (length(r) < 3) next
  sgn <- sign(r - a); k <- which(diff(sgn) != 0); cr <- cr + length(k)
  for (q in k) {
    # time spent in the band |r - a| < 0.1 around this crossing
    lo <- q; while (lo > 1 && abs(r[lo] - a) < 0.1) lo <- lo - 1
    hi <- q + 1; while (hi < length(r) && abs(r[hi] - a) < 0.1) hi <- hi + 1
    dur <- c(dur, (tt[hi] - tt[lo]) * 365); hs <- c(hs, (tt[q + 1] - tt[q]) * 365)
  }
}
cat(sprintf("r crossings of a_st2: %d over %d nodes\n", cr, N))
cat("time across 0 < r < 0.2 (days, bracketing rows), quantiles:\n"); print(quantile(dur, c(.1, .25, .5, .75, .9)))
cat("length of the step holding the crossing (days):\n"); print(quantile(hs, c(.1, .5, .9)))
# rooting depth cap: first row each node is past 1.5 m
hc <- apply(H, 2, function(h) { k <- which(h > st$rooting_depth_max); if (length(k)) t[k[1]] else NA })
cat(sprintf("nodes passing rooting_depth_max %.2f m: %d of %d\n", st$rooting_depth_max, sum(!is.na(hc)), N))
# tallest node changes identity
top <- apply(H, 1, function(h) if (all(is.na(h))) NA else which.max(h))
cat("changes of the tallest node:", sum(diff(top[!is.na(top)]) != 0), "\n")
# heights crossing each other anywhere (adjacent order breaks)
br <- apply(H, 1, function(h) { h <- h[!is.na(h)]; if (length(h) < 2) 0 else sum(diff(h) > 0) })
cat("rows with a broken height order:", sum(br > 0), "of", length(t), "\n")
# Width in time of G's band: 0.1 in r over |dr/dt| at the crossing, and the same for
# mortality's scale 1/a_dG2 = 0.05 read where r < 0.15.
wd <- c(); hh <- c(); up <- c()
for (j in 1:N) {
  r <- R[, j]; ok <- !is.na(r); tt <- t[ok]; r <- r[ok]; if (length(r) < 3) next
  k <- which(diff(sign(r - a)) != 0)
  for (q in k) { rate <- abs(r[q + 1] - r[q]) / ((tt[q + 1] - tt[q]) * 365)
    wd <- c(wd, 0.1 / rate); hh <- c(hh, (tt[q + 1] - tt[q]) * 365); up <- c(up, r[q + 1] > r[q]) }
}
cat("G's width in time at each crossing, days (0.1 / |dr/dt| over the step holding it):\n")
print(quantile(wd, c(.1, .25, .5, .75, .9)))
cat("falling:", sum(!up), " rising:", sum(up), "\n")
cat("share of crossings whose width is under the step holding it:", mean(wd < hh), "\n")
cat("median width falling", median(wd[!up]), "rising", median(wd[up]), "\n")
