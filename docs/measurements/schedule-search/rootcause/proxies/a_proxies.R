# a_proxies.R: candidate a-priori proxies for the per-case error constant, scored on the
# E6-family ladder (pre-registration A in notes.md). Every scalar proxy gets one scale
# factor fitted leave-one-case-out; reads are predicted / true.
PO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/proxies"
D <- readRDS(file.path(PO, "lad.rds")); L <- D$L; Q <- D$Q; EPS <- D$EPS; ALL <- names(L)
SEC <- 113e-6; SWEEP <- 3.27; cost <- function(rows, grad = TRUE) rows * SEC * (1 + if (grad) SWEEP else 0)
rms <- function(x) sqrt(mean(x^2)); EL <- setdiff(Q, "lnJ")
err <- function(cs, k) (L[[cs]]$runs[[k]]$q - L[[cs]]$ref) / EPS
RUNG <- c("x", "c", "f", "f12", "x12")

# ---- pilot features per case
pil <- function(cs) { p <- L[[cs]]$pilot; n <- p$nodes; b1 <- p$b1
  pd <- exp(-0.00605 * n$birth^2); est <- head(p$nodes$birth * 0 + 1, nrow(n))  # uniform weight per pilot node
  w <- n$nrr * pd; shareF <- sum(w[n$birth < b1]) / sum(w)
  i <- n$birth < b1; Lf <- -1 / coef(lm(log(n$nrr[i]) ~ n$birth[i]))[[2]]
  ed <- p$edges; cr <- p$creation; op <- cr$rate > 0.01; rr <- rle(op); e <- cumsum(rr$lengths)
  cl <- cr$end[e][-length(e)][op[e][-length(e)]]; ncl <- sum(cl > b1 & cl < 10)
  list(J = p$J, b1 = b1, shareF = shareF, L = Lf, Dd = shareF * ncl / (10 - b1)) }
PF <- lapply(setNames(ALL, ALL), pil)

# ---- per-run proxy values
hF <- function(S, b1) { s <- S[S <= b1 + 1e-9]; mean(diff(s)) }
hI <- function(S, cs) { p <- L[[cs]]$pilot; m <- (head(S, -1) + S[-1]) / 2; h <- diff(S); k <- m > p$b1 & m < 10 & p$shut(m) < 0.5; median(h[k]) }
prox <- function(cs, k) { r <- L[[cs]]$runs[[k]]; pf <- PF[[cs]]; S <- r$S; c0 <- L[[cs]]$runs$c; x0 <- L[[cs]]$runs$x
  ratio <- r$proxy / c0$proxy                                       # the a09 shrink from c to this run
  Sel <- rms((x0$q[EL]) / EPS[EL])
  sc <- c0$proxy / x0$proxy; p4 <- abs(x0$q["lnJ"] - c0$q["lnJ"]) / (1 / sc - 1) / EPS["lnJ"]
  P2F <- hF(S, pf$b1)^2 / 12 * pf$shareF / pf$L^2
  P2I <- (hI(S, cs) * 365 / 70)^2 * pf$Dd
  c(P0 = ratio, P1 = r$proxy / pf$J^0.6, P2F = P2F, P2I = P2I, P3 = P2F * Sel, P3a = r$proxy / pf$J^0.6 * Sel,
    P4 = unname(p4) * ratio, P4s = unname(p4) * ratio * Sel, P5 = Sel * ratio, P5d = unname(abs(x0$q["a_dG2"] / EPS["a_dG2"])) * ratio,
    P2FIs = NA) }
COST <- c(P0 = 0, P1 = 0, P2F = 0, P2I = 0, P2FI = 0, P3 = 0.75, P3a = 0.75, P4 = 0.41, P4s = 1.16, P5 = 0.75, P5d = 0.75, P2FIs = 0.75, P6a = 0.75, P6b = 1.47)

# table of runs
R <- do.call(rbind, lapply(ALL, function(cs) do.call(rbind, lapply(intersect(RUNG, names(L[[cs]]$runs)), function(k) {
  e <- err(cs, k); data.frame(case = cs, run = k, r = L[[cs]]$runs[[k]]$r, W = max(abs(e)), wq = Q[which.max(abs(e))], rmse = rms(e), t(prox(cs, k))) }))))
# P2FI: founders' and interiors' forms in quadrature, weights by LOCO least squares on W^2
fit2 <- function(d, a, b, y) { X <- cbind(d[[a]]^2, d[[b]]^2); co <- pmax(qr.solve(X, y^2), 0); if (all(co == 0)) co <- c(1, 0); co }
for (pr in c("P2FI", "P2FIs")) R[[pr]] <- NA
Sel_of <- function(cs) rms(L[[cs]]$runs$x$q[EL] / EPS[EL])
R$Sel <- vapply(R$case, Sel_of, 0)
for (cs in ALL) { tr <- R$case != cs
  co <- fit2(R[tr, ], "P2F", "P2I", R$W[tr]); R$P2FI[!tr] <- sqrt(co[1] * R$P2F[!tr]^2 + co[2] * R$P2I[!tr]^2)
  d2 <- R; d2$a <- d2$P2F * d2$Sel; d2$b <- d2$P2I * d2$Sel
  co <- fit2(d2[tr, ], "a", "b", R$W[tr]); R$P2FIs[!tr] <- sqrt(co[1] * d2$a[!tr]^2 + co[2] * d2$b[!tr]^2) }
PROX <- c("P0", "P1", "P2F", "P2I", "P2FI", "P3", "P3a", "P4", "P4s", "P5", "P5d", "P2FIs")

# LOCO prediction of W: scale fitted on the other cases' runs (geometric mean of W/proxy)
loco <- function(pr, d = R) { out <- numeric(nrow(d)); for (cs in ALL) { tr <- d$case != cs
  b <- if (pr %in% c("P2FI", "P2FIs")) 1 else exp(mean(log(d$W[tr] / d[[pr]][tr]))); out[!tr] <- b * d[[pr]][!tr] }; out }
for (pr in PROX) R[[paste0("pred_", pr)]] <- loco(pr)

# stopping-rule diagnostics at a margin m: accept when m * pred < 1
stoprule <- function(W, pred, m) { acc <- m * pred < 1
  c(acc = mean(acc), FA = if (any(acc)) mean(W[acc] > 1) else NA, FR = if (any(W <= 1)) mean(!acc[W <= 1]) else NA) }
diag_row <- function(pr, d = R, sub = rep(TRUE, nrow(d))) { pred <- d[[paste0("pred_", pr)]][sub]; W <- d$W[sub]; rd <- pred / W
  t <- W / pred; m100 <- max(t); m90 <- unname(quantile(t, 0.9)); s1 <- stoprule(W, pred, m100); s9 <- stoprule(W, pred, m90)
  cc <- d$run[sub] == "c"; rc <- rd[cc]; names(rc) <- d$case[sub][cc]
  data.frame(proxy = pr, cost = COST[[pr]], med_c = median(rc), lo_c = min(rc), hi_c = max(rc), spread_c = max(rc) / min(rc),
    worst_c = max(pmax(rc, 1 / rc)), worst_case = names(rc)[which.max(pmax(rc, 1 / rc))], medlog_all = median(abs(log(rd))),
    m90 = m90, m100 = m100, acc100_ok = 1 - s1[["FR"]], FA90 = s9[["FA"]], FR90 = s9[["FR"]], spearman_c = cor(pred[cc], W[cc], method = "s")) }
DG <- do.call(rbind, lapply(PROX, diag_row))
# the two pair estimates, on the committed runs only
pairest <- function(cs, kind) { c0 <- L[[cs]]$runs$c
  if (kind == "P6a") { x0 <- L[[cs]]$runs$x; s <- c0$proxy / x0$proxy; (x0$q - c0$q) / EPS / (1 / s - 1) }
  else { f0 <- L[[cs]]$runs$f; s <- f0$proxy / c0$proxy; (c0$q - f0$q) / EPS / (1 - s) } }
for (kind in c("P6a", "P6b")) { W <- R$W[R$run == "c"]; pred <- vapply(ALL, function(cs) max(abs(pairest(cs, kind))), 0); rc <- pred / W; names(rc) <- ALL
  t <- W / pred; s1 <- stoprule(W, pred, max(t))
  DG <- rbind(DG, data.frame(proxy = kind, cost = COST[[kind]], med_c = median(rc), lo_c = min(rc), hi_c = max(rc), spread_c = max(rc) / min(rc),
    worst_c = max(pmax(rc, 1 / rc)), worst_case = names(rc)[which.max(pmax(rc, 1 / rc))], medlog_all = median(abs(log(rc))), m90 = unname(quantile(t, 0.9)), m100 = max(t),
    acc100_ok = 1 - s1[["FR"]], FA90 = NA, FR90 = NA, spearman_c = cor(pred, W, method = "s"))) }
cat("== Worst-quantity reads (committed runs, LOCO scale) and stopping-rule margins over the 44 rungs\n")
print(DG, digits = 3, row.names = FALSE)
cat("\n== Per-case reads of W on the committed run\n")
rc <- sapply(c(PROX), function(pr) { s <- R$run == "c"; setNames(R[[paste0("pred_", pr)]][s] / R$W[s], R$case[s]) })
rc <- cbind(rc, P6a = vapply(ALL, function(cs) max(abs(pairest(cs, "P6a"))), 0) / R$W[R$run == "c"], P6b = vapply(ALL, function(cs) max(abs(pairest(cs, "P6b"))), 0) / R$W[R$run == "c"])
print(round(cbind(W = R$W[R$run == "c"], rc), 2))

# ---- per-quantity reads. Scalar proxies: pred_q = beta_q * proxy (beta_q LOCO per quantity, on committed runs).
C <- R[R$run == "c", ]; EC <- t(sapply(ALL, function(cs) err(cs, "c")))
pq <- function(pr) { P <- matrix(NA, 10, length(Q), dimnames = list(ALL, Q)); v <- setNames(C[[pr]], C$case)
  for (cs in ALL) { tr <- setdiff(ALL, cs); b <- if (ENV) sqrt(colMeans(EC[tr, , drop = FALSE]^2 / v[tr]^2)) else exp(colMeans(log(abs(EC[tr, , drop = FALSE]) + 1e-3) - log(v[tr]))); P[cs, ] <- b * v[cs] }; P }
ENV <- FALSE
qdiag <- function(P, signed = FALSE) { big <- abs(EC) > 0.2; rd <- if (signed) P[big] / EC[big] else abs(P[big]) / abs(EC[big])
  c(n = sum(big), med = median(rd), medlog = median(abs(log(abs(rd)))), within2 = mean(abs(rd) >= 0.5 & abs(rd) <= 2 & rd > 0), p10 = unname(quantile(rd, 0.1)), p90 = unname(quantile(rd, 0.9))) }
QD <- rbind(t(sapply(PROX, function(pr) qdiag(pq(pr)))),
  P6a = qdiag(t(sapply(ALL, pairest, kind = "P6a"))[, Q], TRUE), P6b = qdiag(t(sapply(ALL, pairest, kind = "P6b"))[, Q], TRUE))
# P5b: |e_q| proportional to |E_q|/eps_q within a case (case factor fitted on that case: shape only)
sp <- vapply(ALL, function(cs) { E <- abs(L[[cs]]$runs$x$q[EL] / EPS[EL]); cor(E, abs(EC[cs, EL]), method = "s") }, 0)
cat("\n== Per-quantity reads on committed runs (|e| > 0.2; scalar proxies unsigned; geometric-mean scale)\n"); print(round(QD, 3))
ENV <- TRUE; QE <- t(sapply(PROX, function(pr) qdiag(pq(pr))))
cat("\n== Per-quantity reads, rms envelope scale per quantity\n"); print(round(QE, 3))
# reads of committed rms (LOCO scale fitted on rms)
rr <- sapply(PROX, function(pr) { if (pr %in% c("P2FI", "P2FIs")) return(rep(NA, 10)); s <- R$run == "c"; o <- numeric(10); names(o) <- ALL
  for (cs in ALL) { tr <- R$case != cs; b <- exp(mean(log(R$rmse[tr] / R[[pr]][tr]))); i <- s & R$case == cs; o[cs] <- b * R[[pr]][i] / R$rmse[i] }; o })
cat("\n== Reads of committed rms (LOCO scale on rms over all rungs)\n"); print(round(rr, 2)); cat("worst misread:", paste(sprintf("%s %.2f", PROX, apply(rr, 2, function(v) max(pmax(v, 1 / v)))), collapse = ", "), "\n")
cat("\n== P5b: Spearman(|E_q|/eps_q, |e_q|) per case:", paste(sprintf("%s %.2f", ALL, sp), collapse = ", "), "| median", round(median(sp), 2), "\n")
# A9: P2I against rest = e_c - F
restW <- vapply(ALL, function(cs) max(abs(err(cs, "c") - L[[cs]]$F)), 0)
cat("\n== A9: rest worst per case:", paste(sprintf("%s %.2f", ALL, restW), collapse = ", "), "\n")
cat(sprintf("   Spearman(P2I, rest worst) %.2f; Spearman(P2I*Sel, rest worst) %.2f; Spearman(P5d, rest worst) %.2f\n", cor(C$P2I, restW, method = "s"), cor(C$P2I * C$Sel, restW, method = "s"), cor(C$P5d, restW, method = "s")))
Fw <- vapply(ALL, function(cs) max(abs(L[[cs]]$F)), 0)
cat(sprintf("   founders' worst F per case: %s\n   Spearman(P2F, F worst) %.2f; Spearman(P3, F worst) %.2f\n", paste(sprintf("%s %.2f", ALL, Fw), collapse = ", "), cor(C$P2F, Fw, method = "s"), cor(C$P3, Fw, method = "s")))
cat("\n== pilot features\n"); print(round(do.call(rbind, lapply(PF, unlist)), 3))
saveRDS(list(R = R, DG = DG, QD = QD, rc = rc, sp = sp, PF = PF), file.path(PO, "a_proxies.rds"))
