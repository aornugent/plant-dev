# The prize: with each case's d(b) and cost known, the cheapest schedule whose scored
# errors are all under a target. Spacing h(b) = s_band (w(b)/|d(b)|)^(1/3), w the cost of
# a node born at b, clipped to the scorer's range; nodes equidistributed within each gap.
source("/home/user/plant-dev/harness/schedule/anyscore.R")
build <- function(cd, s, smooth) { p <- cd$pilot; ends <- sort(unique(c(0, p$edges, H))); cf <- coef(cd$rowsfit)
  w0 <- cf[["n"]] + cf[["life"]] * H / 2; d0 <- median(abs(cd$P$m / (6 * cd$P$h^3)), na.rm = TRUE)
  S <- c(); for (i in seq_len(length(ends) - 1)) { a <- ends[i]; b <- ends[i + 1]
    if (p$shut((a + b) / 2) > 0.5) { S <- c(S, a); next }
    x <- seq(a, b, length.out = 41); xm <- (x[-1] + x[-41]) / 2
    band <- findInterval(xm, c(0, p$b1, 10, 40)); w <- pmax(cf[["n"]] + cf[["life"]] * (H - xm), cf[["life"]] * 0.5)
    h <- s[band] * ((w / w0) / pmax({v <- abs(smooth(xm)); v[!is.finite(v)] <- 0; v} / d0, 1e-3))^(1 / 3)
    cap <- ifelse(xm < p$b1, p$b1 / 12, ifelse(xm < 20, 100 / 365, 280 / 365)); h <- pmin(h, cap)
    cum <- c(0, cumsum(diff(x) / h)); n <- max(1, ceiling(tail(cum, 1)))
    S <- c(S, approx(cum, x, seq(0, tail(cum, 1), length.out = n + 1))$y[-(n + 1)]) }
  sort(unique(round(S, 10))) }
for (case in commandArgs(TRUE)) { cd <- prepare(case)
  P <- cd$P[order(cd$P$mid), ]; dd <- P$m / (6 * P$h^3)
  # d smoothed over neighbouring panels (the finest per birth date), so h does not chase single panels
  sm <- function(x) { f <- cd$dens(x); stats::filter(abs(f), rep(1 / 3, 3), sides = 2) |> (\(v) ifelse(is.na(v), abs(f), v))() }
  cost <- function(S) run_cost(predict(cd$rowsfit, data.frame(n = length(S), life = sum(H - S))), TRUE)
  worst <- function(S) max(abs(sim(cd, S, case)$err))
  best <- NULL
  for (target in c(0.5, 0.33)) { best <- NULL
    for (sF in exp(seq(log(0.03), log(0.6), length.out = 7))) for (sA in exp(seq(log(0.03), log(0.6), length.out = 7))) for (sB in exp(seq(log(0.03), log(0.6), length.out = 7))) {
      S <- build(cd, c(sF, sA, sB), sm); w <- worst(S); if (w <= target) { c0 <- cost(S); if (is.null(best) || c0 < best$cost) best <- list(cost = c0, worst = w, n = length(S), s = c(sF, sA, sB), S = S) } }
    if (is.null(best)) { cat(case, target, "none\n"); next }
    ref <- sapply(c("loc_G0", "loc_G1"), function(n) { x <- run(sprintf("%s_%s", n, case)); c(cost(x$node_times), worst(x$node_times)) })
    cat(sprintf("%-13s target %.2f: best %.0f s (%d nodes, worst %.2f, before b1 %d, b1-10 %d, after 10 %d) | G0 %.0f (%.2f) G1 %.0f (%.2f)\n", case, target,
      best$cost, best$n, best$worst, sum(best$S < cd$b1), sum(best$S >= cd$b1 & best$S < 10), sum(best$S >= 10), ref[1, 1], ref[2, 1], ref[1, 2], ref[2, 2])) } }
