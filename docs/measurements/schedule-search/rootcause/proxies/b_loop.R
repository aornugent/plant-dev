# b_loop.R: loop policies replayed offline on the E6-family ladder (pre-registration B in
# notes.md). Spacing r is relative to E6's committed run. Modes: meas (stored rungs,
# interpolated in r^2 between them), clean (e_c r^2 plus jitter), order (e_c r^p, p
# scattered about 2). Usage: Rscript b_loop.R PASS NDRAW [policy file]
args <- commandArgs(TRUE); PASS <- if (length(args)) args[1] else "1"; ND <- if (length(args) > 1) as.integer(args[2]) else 10
PO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/proxies"
D <- readRDS(file.path(PO, "lad.rds")); L <- D$L; Q <- D$Q; EPS <- D$EPS; M <- D$M_unit[Q]; ALL <- names(L)
EL <- setdiff(Q, "lnJ"); rms <- function(x) sqrt(mean(x^2)); NQ <- length(Q)
SEC <- 113e-6; SWEEP <- 3.27; cost <- function(rows, grad = TRUE) rows * SEC * (1 + if (grad) SWEEP else 0)
RG <- c(x = 1.6, c = 1, f = 1 / 1.6)
CS <- lapply(ALL, function(cs) { l <- L[[cs]]; E <- t(sapply(names(RG), function(k) (l$runs[[k]]$q - l$ref) / EPS))
  list(case = cs, E = E, lrows = log(sapply(names(RG), function(k) l$runs[[k]]$rows)), lprox = log(sapply(names(RG), function(k) l$runs[[k]]$proxy)),
       Sel = rms(l$runs$x$q[EL] / EPS[EL]), Wc = max(abs(E["c", ])),
       lmi = log(sapply(names(RG), function(k) { S <- l$runs[[k]]$S; m <- (head(S, -1) + S[-1]) / 2; h <- diff(S) * 365; max(h[m < 20 & l$pilot$shut(m) < 0.5]) }))) })
names(CS) <- ALL
# log-log piecewise linear through the rungs, end segments extended
lli <- function(r, ly) { lr <- log(r); if (lr >= 0) ly[["c"]] + lr * (ly[["x"]] - ly[["c"]]) / log(1.6) else ly[["c"]] + lr * (ly[["f"]] - ly[["c"]]) / log(1 / 1.6) }
G <- function(ci, r) cost(exp(lli(r, CS[[ci]]$lrows)), TRUE); Fw <- function(ci, r) cost(exp(lli(r, CS[[ci]]$lrows)), FALSE)
P <- function(ci, r) exp(lli(r, CS[[ci]]$lprox))
Pinv <- function(ci, target) { g <- exp(seq(log(0.3), log(4), length.out = 2000)); v <- vapply(g, function(r) P(ci, r), 0); g[which.min(abs(log(v) - log(target)))] }
# LOCO scales: committed W per unit of S_el (P5), plain (P0), per unit |ln J error| (P4)
B5 <- B0 <- B4 <- numeric(length(ALL)); names(B5) <- names(B0) <- names(B4) <- ALL
for (cs in ALL) { o <- setdiff(ALL, cs); B5[cs] <- exp(mean(log(sapply(o, function(z) CS[[z]]$Wc / CS[[z]]$Sel)))); B0[cs] <- exp(mean(log(sapply(o, function(z) CS[[z]]$Wc))))
  B4[cs] <- exp(mean(log(sapply(o, function(z) CS[[z]]$Wc / abs(CS[[z]]$E["c", "lnJ"]))))) }
SIGI <- 0.020; SIGM <- 0.09
noise <- function(ci, d, r) { set.seed(ci * 1e7 + d * 1e4 + round(r * 1000)); rnorm(NQ, 0, SIGI) + SIGM * rnorm(1) * M }
porder <- function(ci, d) { set.seed(5e8 + ci * 1e4 + d); pmin(3, pmax(1.2, rnorm(NQ, 2, 0.3))) }
RLIM <- list(meas = c(1 / 1.6, 1.6), clean = c(0.5, 2.0), order = c(0.5, 2.0))
err_at <- function(ci, r, mode, d) { E <- CS[[ci]]$E
  if (mode == "meas") { k <- which(abs(r - RG) < 1e-6); if (length(k)) return(E[k, ])
    if (r > 1) { w <- (1.6^2 - r^2) / (1.6^2 - 1); a <- E["c", ]; b <- E["x", ] } else { w <- (r^2 - 1.6^-2) / (1 - 1.6^-2); a <- E["c", ]; b <- E["f", ] }
    return(w * a + (1 - w) * b + sqrt(max(0, 1 - w^2 - (1 - w)^2)) * noise(ci, d, r)) }
  if (mode == "clean") return(E["c", ] * r^2)
  E["c", ] * r^porder(ci, d) }
crit <- function(err, sest) { est <- abs(sest); big <- pmax(abs(err), est) > 1 / 3
  ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  c(C1 = all(abs(err) <= 1), C2 = all(est[abs(err) > 0.5] > 0.25), C3 = if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE, C5 = all(est <= 1)) }

# STRESS: the loop decides on perturbed values (truth + the scorer's miss, shared by a
# case's runs, + 0.04 eps per run); C1 and the reads are judged against the truth.
# NOISE=coord: miss 0.025 shared + 0.04 per run (the scorer's STRESS draw); NOISE=jit:
# the measured jitter only, 0.020 per quantity + 0.09 along M, no miss.
NOISE <- Sys.getenv("NOISE", "coord"); STRESS <- 1
MISS <- if (NOISE == "coord") 0.025 else 0; RUNSD <- if (NOISE == "coord") 0.04 else SIGI; SIGMP <- if (NOISE == "coord") 0 else SIGM
miss <- function(ci, d) { set.seed(7e8 + ci * 1e4 + d); rnorm(NQ, 0, MISS) }
pert <- function(ci, d, r) { set.seed(9e8 + ci * 1e7 + d * 1e4 + round(r * 1000)); rnorm(NQ, 0, RUNSD) + SIGMP * rnorm(1) * M }
# One policy on one case and draw. The last run is the answer for loops; E6 keeps its own
# rule (commit the coarse run when every estimate is under tau). Loop estimates use the
# spacing ratio, e_k = (Q_{k-1} - Q_k)/(R^2 - 1), R = r_{k-1}/r_k.
simulate <- function(pol, ci, d, mode) {
  lim <- RLIM[[mode]]; cl <- function(r) min(max(r, lim[1]), lim[2]); T <- 0; rs <- c(); out_rng <- 0; ms <- if (STRESS) miss(ci, d) else 0
  grun <- function(r) { r <- cl(r); if (!any(abs(rs - r) < 1e-9)) T <<- T + G(ci, r); rs <<- c(rs, r); if (r > 1.6 + 1e-9 || r < 1 / 1.6 - 1e-9) out_rng <<- out_rng + 1
    e <- err_at(ci, r, mode, d); list(e = e, v = e + if (STRESS) ms + pert(ci, d, r) else 0) }
  est_ratio <- function(ra, va, rb, vb) (va - vb) / ((ra / rb)^2 - 1)
  pair_fine <- function(ra, ea, rb, eb) { s <- P(ci, rb) / P(ci, ra); (ea - eb) * s / (1 - s) }
  pair_coarse <- function(ra, ea, rb, eb) { s <- P(ci, rb) / P(ci, ra); (ea - eb) / (1 - s) }
  inter <- c()
  fin <- function(e, est, r, k, Rlast) { cr <- crit(e, est); Tf <- 2 * G(ci, r); waste <- T - G(ci, r)
    list(T = T + Tf, waste = waste, pass = all(cr), cr = cr, W = max(abs(e)), Wq = Q[which.max(abs(e))], est = max(abs(est)),
      r = r, k = k, Rlast = Rlast, ampM = SIGM / (Rlast^2 - 1), ampI = 0.024 / (Rlast^2 - 1), read = median((est / e)[abs(e) > 0.2]), out_rng = out_rng,
      interrupt_ok = if (length(inter)) all(inter) else NA, ok = TRUE) }
  if (pol$type == "E6") { ra <- cl(pol$r1); rb <- cl(ra / pol$R2); if (abs(ra - rb) < 1e-9) return(list(ok = FALSE)); A <- grun(ra); B <- grun(rb)
    est <- pair_coarse(ra, A$v, rb, B$v); if (all(abs(est) < pol$tau)) return(fin(A$e, est, ra, 2, ra / rb)); return(fin(B$e, pair_fine(ra, A$v, rb, B$v), rb, 2, ra / rb)) }
  if (pol$type == "fwd") { r1f <- cl(pol$rf1); r2f <- cl(pol$rf2); T <- T + Fw(ci, r1f) + Fw(ci, r2f)
    a <- err_at(ci, r1f, mode, d)[["lnJ"]] + if (STRESS) ms[1] + pert(ci, d, r1f)[1] else 0; b <- err_at(ci, r2f, mode, d)[["lnJ"]] + if (STRESS) ms[1] + pert(ci, d, r2f)[1] else 0
    K <- abs((a - b) / ((r1f / r2f)^2 - 1)) / r2f^2
    rb <- cl(sqrt(pol$t2 / (B4[[ci]] * K))); ra <- cl(rb * pol$R2); rb <- min(rb, ra / pol$R2); A <- grun(ra) }
  else { ra <- cl(pol$r1); A <- grun(ra)
    rb <- switch(pol$sel, fix = ra / pol$R2, P5 = sqrt(pol$t2 / (B5[[ci]] * CS[[ci]]$Sel)), P0 = sqrt(pol$t2 / B0[[ci]]))
    rb <- min(rb, ra / pol$Rmin); rb <- max(rb, ra / 2) }
  rb <- cl(rb); if (rb >= ra - 1e-9) return(list(ok = FALSE))
  hist <- list(list(r = ra, v = A$v))
  flag <- function(ra, rb, B, est) { hist[[length(hist) + 1]] <<- list(r = rb, v = B$v); n <- length(hist); R <- ra / rb
    f_int <- exp(lli(ra, CS[[ci]]$lmi)) < 110; f_noise <- SIGM / (R^2 - 1) < 1 / 3
    f_order <- NA; if (n >= 3) { a <- hist[[n - 2]]; b <- hist[[n - 1]]; d1 <- a$v - b$v; d2 <- b$v - B$v; law <- (a$r^2 - b$r^2) / (b$r^2 - rb^2)
      q <- sqrt(sum(d1^2) / sum(d2^2)) / law; f_order <- q > 0.5 && q < 2 && sum(d1 * d2) / sqrt(sum(d1^2) * sum(d2^2)) >= 0.9 }
    pr <- max(abs(est)) / (B5[[ci]] * CS[[ci]]$Sel * rb^2); f_prox <- pr > 0.5 && pr < 2
    cr <- crit(B$e, est); valid <- f_int && f_noise && f_prox && (is.na(f_order) || f_order)
    if (DUMP) { NF <<- NF + 1; FLAGS[[NF]] <<- c(pol = pol$ix, mode = match(mode, c("meas", "clean", "order")), case = ci, d = d, i = n, r = rb, R = R, f_int = f_int, f_noise = f_noise, f_order = as.numeric(f_order), f_prox = f_prox,
      valid = valid, C23 = cr[["C2"]] && cr[["C3"]], C1 = cr[["C1"]], W = max(abs(B$e)), est = max(abs(est)), read = median((est / B$e)[abs(B$e) > 0.2])) } }
  B <- grun(rb); est <- est_ratio(ra, A$v, rb, B$v); k <- 2; Kprev <- NA; flag(ra, rb, B, est)
  while (max(abs(est)) >= pol$tau && k < pol$kmax) {
    cr <- crit(B$e, est); inter <- c(inter, cr[["C2"]] && cr[["C3"]])
    Kh <- max(abs(est)) / rb^2; if (pol$damp == "blend" && !is.na(Kprev)) Kh <- sqrt(Kh * Kprev); Kprev <- max(abs(est)) / rb^2
    rn <- sqrt(pol$t / Kh)
    if (pol$damp == "none") rn <- min(rn, rb / 1.02) else rn <- max(min(rn, rb / pol$Rmin), rb / 2)
    rn <- cl(rn); if (rn >= rb - 1e-9) break
    Nn <- grun(rn); est <- est_ratio(rb, B$v, rn, Nn$v); flag(rb, rn, Nn, est); Rl <- rb / rn; ra <- rb; A <- B; rb <- rn; B <- Nn; k <- k + 1 }
  fin(B$e, est, rb, k, ra / rb) }

DUMP <- nzchar(Sys.getenv("DUMP")); FLAGS <- vector("list", 2e6); NF <- 0
# ---- policy grid
grid <- list(); add <- function(...) grid[[length(grid) + 1]] <<- list(...)
add(type = "E6", r1 = 1, R2 = 1.6, tau = 1, name = "E6")
for (r1 in c(0.8, 1, 1.28, 1.6)) for (R2 in c(1.25, 1.4, 1.6)) for (tau in c(0.7, 0.8, 0.9, 1)) add(type = "E6", r1 = r1, R2 = R2, tau = tau)
for (r1 in c(1, 1.28, 1.6, 2)) for (sel in c("fix", "P5", "P0")) for (v in if (sel == "fix") c(1.25, 1.4, 1.6, 2) else c(0.4, 0.55, 0.7))
  for (tau in c(0.7, 0.8, 0.9, 1)) for (t in c(0.5, 0.7)) for (dm in list(c("none", 1.25), c("clip", 1.25), c("clip", 1.5), c("blend", 1.25), c("blend", 1.5)))
    add(type = "loop", r1 = r1, sel = sel, R2 = if (sel == "fix") v else NA, t2 = if (sel == "fix") NA else v, tau = tau, t = t, damp = dm[1], Rmin = as.numeric(dm[2]), kmax = 4)
for (rf in list(c(1.6, 1), c(2, 1.6))) for (t2 in c(0.4, 0.55, 0.7)) for (R2 in c(1.4, 1.6)) for (tau in c(0.8, 0.9))
  add(type = "fwd", rf1 = rf[1], rf2 = rf[2], t2 = t2, R2 = R2, tau = tau, t = 0.7, damp = "clip", Rmin = 1.25, kmax = 4)
pname <- function(p) if (!is.null(p$name)) p$name else if (p$type == "E6") sprintf("E6s r1=%.2f R=%.2f tau=%.1f", p$r1, p$R2, p$tau) else if (p$type == "fwd")
  sprintf("fwd %.1f/%.1f t2=%.2f R=%.1f tau=%.1f", p$rf1, p$rf2, p$t2, p$R2, p$tau) else
  sprintf("loop r1=%.2f %s=%.2f tau=%.1f t=%.1f %s Rmin=%.2f", p$r1, p$sel, if (p$sel == "fix") p$R2 else p$t2, p$tau, p$t, p$damp, p$Rmin)
for (i in seq_along(grid)) { grid[[i]]$id <- pname(grid[[i]]); grid[[i]]$ix <- i }
if (length(args) > 2) { keep <- readLines(args[3]); grid <- grid[vapply(grid, function(p) p$id %in% keep, TRUE)] }

run_grid <- function(grid, modes, nd) { out <- list()
  for (mode in modes) for (p in grid) { if (mode == "meas" && ((!is.null(p$r1) && p$r1 > 1.6) || (p$type == "fwd" && p$rf1 > 1.6))) next
    dr <- if (!STRESS && mode == "meas" && p$type == "E6" && all(c(p$r1, p$r1 / p$R2) %in% RG)) 1 else nd
    res <- lapply(seq_along(ALL), function(ci) lapply(seq_len(dr), function(d) simulate(p, ci, d, mode)))
    if (any(vapply(res, function(z) any(!vapply(z, `[[`, TRUE, "ok")), TRUE))) next
    Tm <- sum(vapply(res, function(z) mean(vapply(z, `[[`, 0, "T")), 0))
    pc <- vapply(res, function(z) mean(vapply(z, `[[`, TRUE, "pass")), 0)
    all10 <- mean(vapply(seq_len(dr), function(d) all(vapply(res, function(z) z[[d]]$pass, TRUE)), TRUE))
    Wmax <- max(vapply(res, function(z) max(vapply(z, `[[`, 0, "W")), 0)); W95 <- quantile(unlist(lapply(res, function(z) vapply(z, `[[`, 0, "W"))), 0.95)
    kmean <- mean(unlist(lapply(res, function(z) vapply(z, `[[`, 0, "k")))); kmax <- max(unlist(lapply(res, function(z) vapply(z, `[[`, 0, "k"))))
    fails <- Reduce(`+`, lapply(res, function(z) Reduce(`+`, lapply(z, function(o) !o$cr)))) / dr
    rfin <- vapply(res, function(z) mean(vapply(z, `[[`, 0, "r")), 0)
    allz <- unlist(res, recursive = FALSE); g <- function(f) vapply(allz, `[[`, 0, f)
    io <- unlist(lapply(allz, `[[`, "interrupt_ok")); io <- io[!is.na(io)]
    out[[length(out) + 1]] <- data.frame(mode = mode, id = p$id, type = p$type, T = Tm, pass = mean(pc), all10 = all10, minpc = min(pc), Wmax = Wmax, W95 = unname(W95),
      kmean = kmean, kmax = kmax, fC1 = fails[["C1"]], fC2 = fails[["C2"]], fC3 = fails[["C3"]], fC5 = fails[["C5"]], rfin = paste(sprintf("%.2f", rfin), collapse = " "),
      waste = sum(vapply(res, function(z) mean(vapply(z, `[[`, 0, "waste")), 0)), ampM = max(g("ampM")), capk = mean(g("k") >= (if (is.null(p$kmax)) 99 else p$kmax)),
      outr = mean(g("out_rng") > 0), interrupt = if (length(io)) mean(io) else NA, read = median(g("read"), na.rm = TRUE), stringsAsFactors = FALSE) }
  do.call(rbind, out) }

t0 <- Sys.time()
# guard: E6 from the stored rungs
S0 <- STRESS; STRESS <- 0; e6 <- lapply(seq_along(ALL), function(ci) simulate(grid[[1]], ci, 1, "meas")); STRESS <- S0
cat(sprintf("E6 replay: T %.0f, pass %d/10, per case T %s\n", sum(vapply(e6, `[[`, 0, "T")), sum(vapply(e6, `[[`, TRUE, "pass")), paste(round(vapply(e6, `[[`, 0, "T")), collapse = " ")))
OUTG <- run_grid(grid, c("meas", "clean", "order"), ND)
cat(sprintf("%d policy-mode rows in %.0f s\n", nrow(OUTG), as.numeric(Sys.time() - t0, units = "secs")))
saveRDS(OUTG, file.path(PO, sprintf("b_loop_pass%s_%s.rds", PASS, NOISE)))
if (DUMP) { FM <- do.call(rbind, FLAGS[seq_len(NF)]); saveRDS(list(F = FM, ids = vapply(grid, `[[`, "", "id"), ix = vapply(grid, `[[`, 0, "ix")), file.path(PO, sprintf("d_flags_pass%s_%s.rds", PASS, NOISE))) }
E6T <- sum(vapply(e6, `[[`, 0, "T"))
for (mode in c("meas", "clean", "order")) { z <- OUTG[OUTG$mode == mode, ]; z$Trel <- z$T / E6T
  cat(sprintf("\n== %s: cheapest policies with every case passing in >= 95%% of draws (all10 >= 0.95)\n", mode))
  f <- z[z$all10 >= 0.95, ]; f <- f[order(f$T), ]; print(head(f[, c("id", "T", "Trel", "pass", "all10", "Wmax", "W95", "kmean", "kmax", "fC1", "fC3", "fC5", "waste", "ampM", "outr", "rfin")], 12), digits = 3, row.names = FALSE)
  cat(sprintf("-- best of each type (feasible)\n")); for (ty in c("E6", "loop", "fwd")) { g <- f[f$type == ty, ]; if (nrow(g)) print(g[1, c("id", "T", "Trel", "all10", "Wmax", "kmean")], digits = 3, row.names = FALSE) else cat(ty, ": none feasible\n") }
  cat("-- front: T against pass rate (non-dominated)\n"); o <- z[order(z$T), ]; best <- -1; fr <- c(); for (i in seq_len(nrow(o))) if (o$pass[i] > best + 1e-9) { fr <- c(fr, i); best <- o$pass[i] }
  print(o[fr, c("id", "T", "Trel", "pass", "all10", "Wmax", "kmean")], digits = 3, row.names = FALSE) }
