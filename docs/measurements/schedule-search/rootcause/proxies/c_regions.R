# c_regions.R: can the loop locate the error? Region error vectors on disk (founders on c
# for all ten; closing strips, interiors, opening side, late and the b1 edge on dry,
# dry-flat, dry-p50, long-wet), G + 1 axis fits, one-pair fits with directions from other
# cases, a Gaussian split with proxy priors, and the T of the per-region optimum
# against one global scale (pre-registration C in notes.md).
PO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/proxies"
RC <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause"
D <- readRDS(file.path(PO, "lad.rds")); L <- D$L; Q <- D$Q; EPS <- D$EPS; ALL <- names(L); M <- D$M_unit[Q]
A <- readRDS(file.path(PO, "a_proxies.rds")); EL <- setdiff(Q, "lnJ")
rms <- function(x) sqrt(mean(x^2)); nrm <- function(x) sqrt(sum(x^2)); cosv <- function(a, b) sum(a * b) / nrm(a) / nrm(b)
SEC <- 113e-6; SWEEP <- 3.27; G1 <- function(rows) rows * SEC * (1 + SWEEP)
quant <- function(x) { e <- unname(x$stand$elasticity); names(e) <- sub("^1\\.", "", names(x$stand$elasticity)); c(lnJ = log(x$stand$J), e)[Q] }
rd <- function(f) if (file.exists(f)) { x <- readRDS(f); list(q = quant(x), rows = x$stand$rows) }
err <- function(cs, run) (run$q - L[[cs]]$ref) / EPS
c_of <- function(cs) L[[cs]]$runs$c; f_of <- function(cs) L[[cs]]$runs$f
ec <- function(cs) err(cs, c_of(cs)); ef <- function(cs) err(cs, f_of(cs))

# ---- region vectors
RV <- list(); RUNS <- list()
for (cs in ALL) RV[[cs]] <- list(F = L[[cs]]$F)
for (cs in c("dry", "dry-p50", "dry-flat", "long-wet")) { res <- rd(file.path(RC, "closing/runs", sprintf("cl_res_%s.rds", cs))); if (is.null(res)) next
  RUNS[[cs]] <- list(res = res); RV[[cs]]$C <- (c_of(cs)$q - res$q) / EPS
  for (k in c("F2", "I2", "I4", "O4", "L4", "B")) { x <- rd(file.path(RC, "p50/runs", sprintf("p5_%s_%s.rds", k, cs))); if (is.null(x)) next; RUNS[[cs]][[k]] <- x
    mv <- (x$q - res$q) / EPS; RV[[cs]][[switch(k, F2 = "Fres", I2 = "I", I4 = "I4", O4 = "O", L4 = "Lt", B = "B")]] <- -mv * switch(k, F2 = 4 / 3, I2 = 4 / 3, B = 1, 16 / 15) } }
cat("== Region vectors on disk (rms, eps)\n"); for (cs in names(RV)) cat(sprintf("%-13s %s\n", cs, paste(sprintf("%s %.3f", names(RV[[cs]]), sapply(RV[[cs]], rms)), collapse = "  ")))

# (1) transfer: founders across the ten; I, O, C across cases
cat("\n== (1) Founders' directions across cases (cos)\n"); FM <- sapply(ALL, function(cs) RV[[cs]]$F); CF <- outer(ALL, ALL, Vectorize(function(a, b) cosv(FM[, a], FM[, b]))); dimnames(CF) <- list(ALL, ALL); print(round(CF, 2))
hc <- cutree(hclust(as.dist(1 - CF)), 2); cat("families by clustering:", paste(sprintf("%s:%d", ALL, hc), collapse = " "), "\n")
for (g in c("C", "I", "O", "Fres")) { cs <- names(RV)[vapply(RV, function(z) !is.null(z[[g]]), TRUE)]; if (length(cs) < 2) next
  cat(sprintf("%s across %s:\n", g, paste(cs, collapse = ", "))); m <- outer(cs, cs, Vectorize(function(a, b) cosv(RV[[a]][[g]], RV[[b]][[g]]))); dimnames(m) <- list(cs, cs); print(round(m, 2)) }

# (2) conditioning on one case
cat("\n== (2) Regions on one case: cos matrix and condition number of the unit-direction matrix\n")
for (cs in c("dry", "dry-flat", "long-wet", "dry-p50")) { z <- RV[[cs]]; g <- intersect(c("F", "C", "I", "O", "Lt", "B"), names(z)); U <- sapply(g, function(k) z[[k]] / nrm(z[[k]]))
  cat(cs, "\n"); print(round(crossprod(U), 2)); for (sub in list(c("F", "C"), c("F", "I"), c("I", "C"), c("F", "I", "C"), intersect(c("F", "I", "C", "O"), g))) if (all(sub %in% g))
    cat(sprintf("   kappa(%s) = %.1f\n", paste(sub, collapse = "+"), kappa(U[, sub, drop = FALSE], exact = TRUE))) }

# G + 1 axis fits on res (dry, dry-flat)
cat("\n== G + 1 axis runs on res: predicted e_res against the truth\n")
crit <- function(err, sest) { est <- abs(sest); big <- pmax(abs(err), est) > 1 / 3
  ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  c(C2 = all(est[abs(err) > 0.5] > 0.25), C3 = if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE) }
amp <- function(h2) { cr <- sum(1 / (1 - h2)); sqrt(cr^2 + sum((1 / (1 - h2))^2)) }   # sd of sum_g K_g per unit run jitter
for (cs in c("dry", "dry-flat")) { z <- RV[[cs]]; eres <- err(cs, RUNS[[cs]]$res)
  for (g in list(c("Fres", "I"), c("Fres", "I", "O"), c("Fres", "I", "O", "Lt"), c("Fres", "I", "O", "Lt", "B"))) { pred <- Reduce(`+`, z[g]); h2 <- vapply(g, function(k) switch(k, Fres = 0.25, I = 0.25, B = 0, 1 / 16), 0)
    cr <- crit(eres, pred); cat(sprintf("%-9s G=%d %-16s resid rms %.3f (e_res rms %.3f) cos %.2f C2 %s C3 %s amp %.2f (x0.024 = %.3f; x0.09 along M = %.2f)\n", cs, length(g), paste(g, collapse = "+"),
      rms(eres - pred), rms(eres), cosv(eres, pred), cr[["C2"]], cr[["C3"]], amp(h2), 0.024 * amp(h2), 0.09 * amp(h2))) }
  if (!is.null(z$I4)) cat(sprintf("          order check: I from I2 vs I4: rms diff %.3f (I rms %.3f), cos %.2f, root_P50 %.2f vs %.2f\n", rms(z$I - z$I4), rms(z$I4), cosv(z$I, z$I4), z$I[["root_P50"]], z$I4[["root_P50"]])) }
cat(sprintf("single pairs for comparison: E6's coarse estimate amp %.2f, last-run estimate at R=1.6 amp %.2f\n", sqrt(2) / (1 - 1 / 2.56), sqrt(2) / (2.56 - 1)))
# the coordinator's mixed design: run 2 refines F x2 and I x1.4, run 3 the reverse (G = 2, three runs)
mix <- function(a, b) { X <- rbind(c(1, 1, 1), c(1, 1 / a^2, 1 / b^2), c(1, 1 / b^2, 1 / a^2)); W <- solve(X); w <- W[2, ] + W[3, ]; sqrt(sum(w^2)) }
cat(sprintf("mixed design (F x2, I x1.4 / reverse): amp of the base run's error %.2f; axis (x2 each) %.2f\n", mix(2, 1.4), amp(c(0.25, 0.25))))

# (3) one pair, directions from other cases. Ten cases, G = 2: founders (PC1 of the other
# cases' F, sign free) and the rest (PC1 of the other cases' e_c - F). Truth: F, e_c - F.
cat("\n== (3) One pair (c - f) located with directions from other cases\n")
pc1 <- function(Mx) { s <- svd(Mx); s$u[, 1] }
ONE <- list()
for (cs in ALL) { o <- setdiff(ALL, cs); uF <- pc1(sapply(o, function(z) RV[[z]]$F)); uR <- pc1(sapply(o, function(z) ec(z) - RV[[z]]$F))
  s <- f_of(cs)$proxy / c_of(cs)$proxy; est <- (c_of(cs)$q - f_of(cs)$q) / EPS / (1 - s)    # the pair's estimate of e_c
  U <- cbind(uF, uR); cf <- qr.solve(U, est); Fh <- cf[1] * uF; Rh <- cf[2] * uR; Ft <- RV[[cs]]$F; Rt <- ec(cs) - Ft
  covc <- solve(crossprod(U)); ampF <- sqrt(covc[1, 1]) * sqrt(2) / (1 - s)
  ONE[[cs]] <- data.frame(case = cs, cosFR = sum(uF * uR), F_true = nrm(Ft), F_hat = nrm(Fh), ratioF = nrm(Fh) / nrm(Ft), cosF = cosv(Fh, Ft), R_true = nrm(Rt), R_hat = nrm(Rh), cosR = cosv(Rh, Rt),
    fit_resid = nrm(est - U %*% cf) / nrm(est), ampF = ampF, share_true = nrm(Ft)^2 / (nrm(Ft)^2 + nrm(Rt)^2), share_hat = nrm(Fh)^2 / (nrm(Fh)^2 + nrm(Rh)^2)) }
ONE <- do.call(rbind, ONE); print(ONE, digits = 2, row.names = FALSE)
cat(sprintf("founders recovered within x1.5 (norm) and cos >= 0.7 on %d of 10; G + 1 runs (c, fbis, f) measure F with amp %.2f per quantity\n", sum(ONE$ratioF > 2 / 3 & ONE$ratioF < 1.5 & ONE$cosF >= 0.7), 4 / 3 * sqrt(2)))

# (4) Gaussian split: prior sd of each coefficient from part A's LOCO proxies (founders: P3's
# prediction of the founders' worst scaled to a norm; rest: P5's prediction of W less it),
# likelihood from the pair with sd = jitter amp + the LOCO fit residual.
cat("\n== (4) Bayesian split: posterior sd of the founders' share\n")
R <- A$R; Cc <- R[R$run == "c", ]
lo <- function(y, x) vapply(ALL, function(cs) { o <- setdiff(ALL, cs); exp(mean(log(y[o] / x[o]))) * x[cs] }, 0)
FW <- vapply(ALL, function(cs) nrm(RV[[cs]]$F), 0); RW <- vapply(ALL, function(cs) nrm(ec(cs) - RV[[cs]]$F), 0)
pF <- lo(FW, setNames(Cc$P3, Cc$case)); pR <- lo(RW, setNames(Cc$P5, Cc$case))
BAY <- list()
for (cs in ALL) { o <- setdiff(ALL, cs); uF <- pc1(sapply(o, function(z) RV[[z]]$F)); uR <- pc1(sapply(o, function(z) ec(z) - RV[[z]]$F)); U <- cbind(uF, uR)
  s <- f_of(cs)$proxy / c_of(cs)$proxy; est <- (c_of(cs)$q - f_of(cs)$q) / EPS / (1 - s)
  sig <- sqrt((0.024 * sqrt(2) / (1 - s))^2 + median(ONE$fit_resid[ONE$case != cs])^2 * sum(est^2) / length(Q))
  P0 <- diag(c(pF[cs], pR[cs])^2); Sp <- solve(solve(P0) + crossprod(U) / sig^2); mu <- Sp %*% crossprod(U, est) / sig^2
  set.seed(1); sm <- t(as.vector(mu) + t(chol(Sp)) %*% matrix(rnorm(8000), 2)); sh <- sm[, 1]^2 / (sm[, 1]^2 + sm[, 2]^2)
  BAY[[cs]] <- data.frame(case = cs, prior_F = pF[cs], prior_R = pR[cs], post_F = abs(mu[1]), sdF = sqrt(Sp[1, 1]), share_true = ONE$share_true[ONE$case == cs], share_mean = mean(sh), share_sd = sd(sh), corrFR = Sp[1, 2] / sqrt(Sp[1, 1] * Sp[2, 2])) }
BAY <- do.call(rbind, BAY); print(BAY, digits = 2, row.names = FALSE)

# price of location: per-region optimum against one global scale (ten cases, founders / rest)
cat("\n== Price of location: rows of the cheapest final layout meeting max_q(|F_q| hF^2 + |R_q| hR^2) <= target\n")
PR <- list()
for (cs in ALL) { cc <- c_of(cs); fb <- L[[cs]]$runs$fbis; ff <- f_of(cs); aF <- fb$rows - cc$rows; aR <- (ff$rows - cc$rows) / 0.6 - aF
  rows <- function(hF, hR) cc$rows + aF * (1 / hF - 1) + aR * (1 / hR - 1); Fq <- abs(RV[[cs]]$F); Rq <- abs(ec(cs) - RV[[cs]]$F)
  for (tg in c(1, 0.7)) { g <- seq(0.3, 2.5, by = 0.01); ok_g <- g[vapply(g, function(r) max(Fq * r^2 + Rq * r^2) <= tg, TRUE)]; rg <- max(ok_g)
    best <- c(rows(rg, rg), rg, rg); for (hF in g) { hRmax <- g[vapply(g, function(h) max(Fq * hF^2 + Rq * h^2) <= tg, TRUE)]; if (!length(hRmax)) next; v <- rows(hF, max(hRmax)); if (v < best[1]) best <- c(v, hF, max(hRmax)) }
    PR[[length(PR) + 1]] <- data.frame(case = cs, target = tg, r_global = rg, rows_global = rows(rg, rg), hF = best[2], hR = best[3], rows_opt = best[1], use_saving = 1 - best[1] / rows(rg, rg),
      net_T_saving = (2 * (G1(rows(rg, rg)) - G1(best[1])) - G1(fb$rows)) / (G1(cc$rows) + G1(ff$rows) + 3 * G1(rows(rg, rg)))) } }
PR <- do.call(rbind, PR); print(PR, digits = 3, row.names = FALSE)
for (tg in c(1, 0.7)) { z <- PR[PR$target == tg, ]; cat(sprintf("target %.1f: use rows saved %.1f%% (sum over ten), net T change with the extra fbis run %.1f%% (median per case)\n", tg, 100 * (1 - sum(z$rows_opt) / sum(z$rows_global)), -100 * median(z$net_T_saving))) }
# four regions on res (dry, dry-flat): use rows only [i]
for (cs in c("dry", "dry-flat")) { z <- RV[[cs]]; rr <- RUNS[[cs]]; b <- rr$res$rows; g4 <- c("Fres", "I", "O", "Lt")
  a <- c(Fres = rr$F2$rows - b, I = rr$I2$rows - b, O = (rr$O4$rows - b) / 3, Lt = (rr$L4$rows - b) / 3); K <- sapply(g4, function(k) abs(z[[k]])); fix <- abs(z$B)
  rowsf <- function(h) b + sum(a * (1 / h - 1)); feas <- function(h, tg) max(K %*% h^2 + fix) <= tg
  for (tg in c(1, 0.7)) { gg <- seq(0.5, 4, by = 0.02); rg <- max(gg[vapply(gg, function(r) feas(rep(r, 4), tg), TRUE)])
    set.seed(2); best <- c(rowsf(rep(rg, 4)), rep(rg, 4)); for (it in 1:20000) { h <- exp(runif(4, log(0.5), log(4))); if (feas(h, tg)) { v <- rowsf(h); if (v < best[1]) best <- c(v, h) } }
    cat(sprintf("%-9s target %.1f: global r %.2f rows %.0f; per-region h (F I O L) %s rows %.0f; use saving %.1f%% [i]\n", cs, tg, rg, rowsf(rep(rg, 4)), paste(sprintf("%.2f", best[-1]), collapse = " "), best[1], 100 * (1 - best[1] / rowsf(rep(rg, 4))))) } }
saveRDS(list(RV = RV, ONE = ONE, BAY = BAY, PR = PR), file.path(PO, "c_regions.rds"))
