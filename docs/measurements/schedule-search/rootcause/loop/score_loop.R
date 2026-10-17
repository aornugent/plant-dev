# score_loop.R RESERVE...: the real loop's results (loop_RESERVE.rds) against the truth: C1-C5,
# T = sum of runs + 2 x final (rows model), runs, the final spacing against the ladder's s*,
# the map flag's hits; the loop re-decided under stress draws (both noise models) and E6 as
# built under the same noise models.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/loop/loop_run.R")
RES <- as.numeric(commandArgs(TRUE)); if (!length(RES)) RES <- 0.15
ND <- as.integer(Sys.getenv("ND", "1000")); r <- 1.6; rms <- function(x) sqrt(mean(x^2))
LADS <- readRDS(file.path(LO, "score_lad.rds"))
lli <- function(x0, x, y) { o <- order(x); x <- log(x[o]); y <- log(y[o]); i <- min(max(findInterval(log(x0), x), 1), length(x) - 1)
  exp(y[i] + (log(x0) - x[i]) * (y[i + 1] - y[i]) / (x[i + 1] - x[i])) }
inv <- function(y0, x, y) { g <- exp(seq(log(0.2), log(5), length.out = 4000)); v <- vapply(g, lli, 0, x, y); g[which.min(abs(log(v) - log(y0)))] }
# Every stored run of a case, keyed by s.
store_of <- function(cs) { f <- list.files(file.path(LO, "runs"), sprintf("^ep[0-9.]+_%s\\.rds$", gsub("([.-])", "\\\\\\1", cs)))
  ss <- as.numeric(sub(sprintf("^ep([0-9.]+)_%s\\.rds$", gsub("([.-])", "\\\\\\1", cs)), "\\1", f))
  st <- list(); for (s in ss) { x <- ep_read(cs, s); if (!is.null(x)) st[[sprintf("%.6f", s)]] <- ep_summary(cs, x) }; st }
e6_stress <- function(ec, ef, s6, d, nz, cid) { set.seed(cid * 1e5 + d * 7 + (nz == "jit") + 3)
  if (nz == "coord") { ms <- rnorm(length(Q), 0, 0.025); vc <- ec + ms + rnorm(length(Q), 0, 0.04); vf <- ef + ms + rnorm(length(Q), 0, 0.04) }
  else { vc <- ec + rnorm(length(Q), 0, 0.02) + 0.09 * rnorm(1) * M; vf <- ef + rnorm(length(Q), 0, 0.02) + 0.09 * rnorm(1) * M }
  g <- (vc - vf) / (1 - s6); if (all(abs(g) < 1)) all(crit(ec, g)) else all(crit(ef, (vc - vf) * s6 / (1 - s6))) }
ALLR <- list()
for (reserve in RES) {
  L <- readRDS(file.path(LO, sprintf("loop_%.2f.rds", reserve))); rows <- list()
  for (cs in names(L)) { z <- L[[cs]]; ref <- ref_of(cs); e6 <- e6_of(cs); cid <- match(cs, c(BANK, HELD))
    err <- (z$q - ref) / EPS; cr <- crit(err, z$est); st <- store_of(cs); lk <- LADS$keep[[cs]]
    Tl <- sum(cost(z$runs$rows)) + 2 * cost(z$runs$rows[abs(z$runs$s - z$s) < 1e-9][1])
    ec6 <- (e6$qc - ref) / EPS; ef6 <- (e6$qf - ref) / EPS; g <- (ec6 - ef6) / (1 - e6$s); c6 <- all(abs(g) < 1)
    T6 <- cost(e6$rc) + cost(e6$rf) + 2 * cost(if (c6) e6$rc else e6$rf); p6 <- all(if (c6) crit(ec6, g) else crit(ef6, (ec6 - ef6) * e6$s / (1 - e6$s)))
    W <- vapply(lk$E, function(e) max(abs(e)), 0); sst <- inv(z$target, c(1.6, 1, 1 / 1.6), W)
    h <- z$history; hits <- sum(!h$map_ok); hit_alone <- sum(!h$map_ok & h$under & h$noise_ok)
    stress <- sapply(c("coord", "jit"), function(nz) { o <- t(vapply(seq_len(ND), function(d) { memo <- new.env(); f <- stress_run(st, ref, d, nz, cid)
        g <- function(s) { k <- sprintf("%.6f", s); if (is.null(memo[[k]])) memo[[k]] <- f(s); memo[[k]] }
        y <- tryCatch(schedule_loop(g, EPS, sel_scale_of(cs), reserve = reserve), error = function(e) NULL)
        if (is.null(y)) return(c(pass = 0, C1 = 0, k = NA, T = NA, s = NA, flag = NA, e6 = NA))
        e <- memo[[sprintf("%.6f", y$s)]]$e; T <- sum(cost(y$runs$rows)) + 2 * cost(y$runs$rows[abs(y$runs$s - y$s) < 1e-9][1])
        c(pass = all(crit(e, y$est)), C1 = all(abs(e) <= 1), k = nrow(y$runs), T = T, s = y$s, flag = any(!y$history$map_ok & y$history$under & y$history$noise_ok),
          e6 = e6_stress(ec6, ef6, e6$s, d, nz, cid)) }, numeric(7))); colMeans(o, na.rm = TRUE) })
    rows[[cs]] <- data.frame(reserve = reserve, case = cs, set = if (cs %in% BANK) "bank" else "held", pred = z$predicted, path = paste(sprintf("%.3f", z$runs$s), collapse = " "),
      k = nrow(z$runs), s = z$s, cap = z$cap, s_star = sst, W = max(abs(err)), Wq = Q[which.max(abs(err))], rms = rms(err), est = max(abs(z$est)),
      read = median((z$est / err)[abs(err) > 0.2]), pass = all(cr), fails = paste(names(cr)[!cr], collapse = ""), T = Tl, T6 = T6, pass6 = p6,
      map_hits = hits, map_alone = hit_alone, st_pass = stress["pass", "coord"], st_C1 = stress["C1", "coord"], st_k = stress["k", "coord"], st_T = stress["T", "coord"],
      st_flag = stress["flag", "coord"], st_e6 = stress["e6", "coord"], stj_pass = stress["pass", "jit"], stj_e6 = stress["e6", "jit"], stj_T = stress["T", "jit"]) }
  TB <- do.call(rbind, rows); rownames(TB) <- NULL; ALLR[[as.character(reserve)]] <- TB
  options(width = 260); cat(sprintf("\n==== reserve %.2f\n", reserve)); print(TB, digits = 3)
  for (st in c("bank", "held")) { X <- TB[TB$set == st, ]; if (!nrow(X)) next
    cat(sprintf("%s: T %.0f against E6 %.0f (x%.3f) | pass %d/%d (E6 %d) | stress coord %.3f (E6 %.3f), jit %.3f (E6 %.3f) | runs mean %.2f max %d | coarser %d, finer %d, start %d | within x1.6 of s* %d | map hits on %d cases (alone %d) | stress T x%.3f\n",
      st, sum(X$T), sum(X$T6), sum(X$T) / sum(X$T6), sum(X$pass), nrow(X), sum(X$pass6), mean(X$st_pass), mean(X$st_e6), mean(X$stj_pass), mean(X$stj_e6),
      mean(X$k), max(X$k), sum(X$s > 1 + 1e-9), sum(X$s < 1 - 1e-9), sum(abs(X$s - 1) < 1e-9), sum(abs(log(X$s / X$s_star)) <= log(1.6)), sum(X$map_hits > 0), sum(X$map_alone > 0), sum(X$st_T) / sum(X$T6))) } }
saveRDS(ALLR, file.path(LO, sprintf("score_loop_%s.rds", paste(sprintf("%.2f", RES), collapse = "_"))))
