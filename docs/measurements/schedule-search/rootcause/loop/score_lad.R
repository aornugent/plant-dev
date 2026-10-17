# score_lad.R [CASE...]: E6+'s ladders (s = 1.6, 1, 1/1.6) per case against the truth: order,
# both pairs' reads and C1-C5 (real runs and stress draws), rows against E6 committed, rows
# at E6 committed's worst and rms error, worst / rms error per rung, what neither pair sees,
# the optimum s*, and each run's map against its true ln J error.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/loop/loop_run.R")
args <- commandArgs(TRUE); todo <- if (length(args)) args else c(BANK, HELD)
r <- 1.6; ND <- 1000; rms <- function(x) sqrt(mean(x^2)); cosv <- function(a, b) sum(a * b) / sqrt(sum(a^2) * sum(b^2))
read_of <- function(est, err) median((est / err)[abs(err) > 0.2])
c3n <- function(err, est) { big <- pmax(abs(err), abs(est)) > 1 / 3; ok <- abs(est[big]) >= abs(err[big]) / 2 & abs(est[big]) <= 2 * abs(err[big]) & sign(est[big]) == sign(err[big]); sprintf("%d/%d", sum(ok), sum(big)) }
# The protocol: commit s = 1 when every |est| < 1, else s = 1/1.6 with the fine pair's
# estimate of it. Judged on the true errors.
protocol <- function(est_c, d2v, ec, ef) if (all(abs(est_c) < 1)) list(err = ec, est = est_c, c = TRUE) else list(err = ef, est = d2v / (r^2 - 1), c = FALSE)
# log y against log x, piecewise linear through the points, end segments extended.
lli <- function(x0, x, y) { o <- order(x); x <- log(x[o]); y <- log(y[o]); i <- min(max(findInterval(log(x0), x), 1), length(x) - 1)
  exp(y[i] + (log(x0) - x[i]) * (y[i + 1] - y[i]) / (x[i + 1] - x[i])) }
inv <- function(y0, x, y) { g <- exp(seq(log(0.2), log(5), length.out = 4000)); v <- vapply(g, lli, 0, x, y); g[which.min(abs(log(v) - log(y0)))] }
rows <- list(); keep <- list()
for (cs in todo) {
  xs <- lapply(c(x = 1.6, c = 1, f = 1 / 1.6), function(s) ep_read(cs, s)); if (any(vapply(xs, is.null, TRUE))) { cat(cs, ": rungs missing\n"); next }
  z <- lapply(xs, function(x) ep_summary(cs, x)); ref <- ref_of(cs); e6 <- e6_of(cs)
  E <- lapply(z, function(u) (u$q - ref) / EPS); d1 <- E$x - E$c; d2 <- E$c - E$f
  ec6 <- (e6$qc - ref) / EPS; ef6 <- (e6$qf - ref) / EPS
  po <- log(sqrt(sum(d1^2)) / sqrt(sum(d2^2))) / log(r); kq <- abs(d2) > 0.05; pq <- median(log(abs(d1[kq] / d2[kq])) / log(r))
  est_x <- d1 / (r^2 - 1); est_f <- d2 * r^2 / (r^2 - 1)                    # each pair's estimate of the s = 1 rung's error
  cx <- crit(E$c, est_x); cf <- crit(E$c, est_f); over <- max(abs(E$c)) > 1
  pass_x <- if (over) any(abs(est_x) >= 1) && all(crit(E$f, d2 / (r^2 - 1))) else all(cx)
  pass_f <- if (over) any(abs(est_f) >= 1) && all(crit(E$f, d2 / (r^2 - 1))) else all(cf)
  cid <- match(cs, c(BANK, HELD))
  st <- sapply(c("coord", "jit"), function(nz) { o <- t(vapply(seq_len(ND), function(d) { set.seed(cid * 1e5 + d * 7 + (nz == "jit"))
      if (nz == "coord") { ms <- rnorm(length(Q), 0, 0.025); p <- lapply(1:3, function(i) ms + rnorm(length(Q), 0, 0.04)) }
      else p <- lapply(1:3, function(i) rnorm(length(Q), 0, 0.02) + 0.09 * rnorm(1) * M)
      vx <- E$x + p[[1]]; vc <- E$c + p[[2]]; vf <- E$f + p[[3]]; s6 <- e6$s
      a <- protocol((vx - vc) / (r^2 - 1), vc - vf, E$c, E$f); b <- protocol((vc - vf) * r^2 / (r^2 - 1), vc - vf, E$c, E$f)
      ve6c <- ec6 + p[[2]]; ve6f <- ef6 + p[[3]]; g <- (ve6c - ve6f) / (1 - s6)
      e6r <- if (all(abs(g) < 1)) list(err = ec6, est = g) else list(err = ef6, est = (ve6c - ve6f) * s6 / (1 - s6))
      c(x = all(crit(a$err, a$est)), f = all(crit(b$err, b$est)), e6 = all(crit(e6r$err, e6r$est))) }, logical(3))); colMeans(o) })
  R <- vapply(z, `[[`, 0, "rows"); W <- vapply(E, function(e) max(abs(e)), 0); Rm <- vapply(E, rms, 0)
  W6 <- max(abs(ec6)); r6 <- rms(ec6)
  A <- cbind(d1, d2); res <- E$c - A %*% qr.solve(A, E$c)
  sst <- inv(0.85, c(1.6, 1, 1 / 1.6), W); sst1 <- inv(1, c(1.6, 1, 1 / 1.6), W)
  lnj <- vapply(E, function(e) e[["lnJ"]], 0); mp <- vapply(z, `[[`, 0, "map")
  keep[[cs]] <- list(E = E, d1 = d1, d2 = d2, est_x = est_x, est_f = est_f, ec6 = ec6, ef6 = ef6, R = R, map = mp, ref = ref)
  rows[[cs]] <- data.frame(case = cs, set = if (cs %in% BANK) "bank" else "held", order = po, order_q = pq, cos = cosv(d1, d2),
    read_x = read_of(est_x, E$c), pass_x = pass_x, C3x = c3n(E$c, est_x), fx = paste(names(cx)[!cx], collapse = ""), st_x = st["x", "coord"], stj_x = st["x", "jit"],
    read_f = read_of(est_f, E$c), pass_f = pass_f, C3f = c3n(E$c, est_f), ff = paste(names(cf)[!cf], collapse = ""), st_f = st["f", "coord"], stj_f = st["f", "jit"],
    st_e6 = st["e6", "coord"], stj_e6 = st["e6", "jit"],
    Wx = W[["x"]], Wc = W[["c"]], Wf = W[["f"]], rms_c = Rm[["c"]], Wq = Q[which.max(abs(E$c))], W6 = W6, rms6 = r6,
    rows_x = R[["x"]] / e6$rc, rows_c = R[["c"]] / e6$rc, rows_f = R[["f"]] / e6$rc, rows_e6f = e6$rf / e6$rc,
    at_W6 = lli(W6, W, R) / e6$rc, at_rms6 = lli(r6, Rm, R) / e6$rc, bracket = W6 >= min(W) && W6 <= max(W),
    un_x = rms(E$c - est_x), un_f = rms(E$c - est_f), outside = rms(res), s_star = sst, s_star1 = sst1,
    lnJ_c = lnj[["c"]], map_c = mp[["c"]], map_x = mp[["x"]], map_f = mp[["f"]], lnJ_x = lnj[["x"]], lnJ_f = lnj[["f"]],
    cpu_c = z$c$cpu, Tc = cost(R[["c"]])) }
TB <- do.call(rbind, rows); rownames(TB) <- NULL
options(width = 260); print(TB, digits = 3)
for (st in c("bank", "held")) { X <- TB[TB$set == st, ]; if (!nrow(X)) next
  cat(sprintf("\n%s (%d): order median %.2f [%.2f, %.2f] | cos>=0.85 %d | coarse pass %d, stress %.3f / %.3f | fine pass %d, stress %.3f / %.3f | E6 pair stress %.3f / %.3f\n",
    st, nrow(X), median(X$order), min(X$order), max(X$order), sum(X$cos >= 0.85), sum(X$pass_x), mean(X$st_x), mean(X$stj_x), sum(X$pass_f), mean(X$st_f), mean(X$stj_f), mean(X$st_e6), mean(X$stj_e6)))
  cat(sprintf("   Wc <= W6 on %d | rows c / E6 c (summed) %.3f, x %.3f, f %.3f | at E6's worst: median %.3f [%.3f, %.3f] (bracketed %d) | at E6's rms median %.3f | outside span <= 0.06 on %d | s* median %.2f\n",
    sum(X$Wc <= X$W6), sum(X$rows_c * vapply(X$case, function(c) e6_of(c)$rc, 0)) / sum(vapply(X$case, function(c) e6_of(c)$rc, 0)),
    median(X$rows_x), median(X$rows_f), median(X$at_W6), min(X$at_W6), max(X$at_W6), sum(X$bracket), median(X$at_rms6), sum(X$outside <= 0.06), median(X$s_star))) }
cat(sprintf("\nall 18: order median %.2f | coarse stress %.3f | rows x / E6 c median %.3f | map - true lnJ (s = 1): rms %.3f, max %.3f; over all rungs rms %.3f\n", median(TB$order), mean(TB$st_x), median(TB$rows_x),
  rms(TB$map_c - TB$lnJ_c), max(abs(TB$map_c - TB$lnJ_c)), rms(c(TB$map_c - TB$lnJ_c, TB$map_x - TB$lnJ_x, TB$map_f - TB$lnJ_f))))
saveRDS(list(tab = TB, keep = keep), file.path(LO, "score_lad.rds"))
