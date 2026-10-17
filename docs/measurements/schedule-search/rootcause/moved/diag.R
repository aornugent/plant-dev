# diag.R: does a ratio from one gradient run at the moved theta (S_el, S_raw, S_med) predict
# the growth W_mp / W_pp, and does a per-quantity rescale of the parent's check estimate
# (est_q |E_mq / E_pq|) read the moved error? Offline on saved runs.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
PO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/proxies"
MV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/moved"
D <- readRDS(file.path(PO, "lad.rds")); L <- D$L; Q <- D$Q; EPS <- D$EPS
EL <- setdiff(Q, "lnJ")
ratios <- function(qm, qp) c(S_el = sqrt(mean((qm[EL] / EPS[EL])^2)) / sqrt(mean((qp[EL] / EPS[EL])^2)),
  S_raw = sqrt(mean(qm[EL]^2)) / sqrt(mean(qp[EL]^2)), S_med = median(abs(qm[EL]) / abs(qp[EL])))
W <- function(e) max(abs(e)); rms <- function(e) sqrt(mean(e^2))
c3n <- function(err, est) { big <- pmax(abs(err), abs(est)) > 1 / 3
  ok <- abs(est) >= abs(err) / 2 & abs(est) <= 2 * abs(err) & sign(est) == sign(err)
  sprintf("%d/%d%s", sum(ok & big), sum(big), if (sum(!ok & big) <= max(1, floor(0.2 * sum(big)))) " pass" else " FAIL") }
read <- function(est, err) { j <- abs(err) > 0.2; median(est[j] / err[j]) }
PAIRS <- list(c("dry", "dry-p50"), c("long-wet", "wet-adG2"), c("episodic", "episodic-lma"))
cat("== shared grid: moved run on the parent grid against the parent's committed run\n")
P1 <- list()
for (pr in PAIRS) { pa <- pr[1]; mo <- pr[2]
  x <- readRDS(file.path(MV, "runs", sprintf("mv_%s_on_%s.rds", mo, pa))); qm <- quantities(x)[Q]; qp <- L[[pa]]$runs$c$q
  e_mp <- (qm - L[[mo]]$ref) / EPS; e_pp <- (qp - L[[pa]]$ref) / EPS
  R <- L[[pa]]$runs; est_f <- (R$c$q - R$f$q) / EPS / (1 - R$f$proxy / R$c$proxy)
  rq <- abs(qm / qp); rq[["lnJ"]] <- 1                 # ln J's error kept at the parent's size
  est_r <- est_f * rq
  r <- ratios(qm, qp); g <- c(W = W(e_mp) / W(e_pp), rms = rms(e_mp) / rms(e_pp))
  P1[[mo]] <- c(gW = g[["W"]], grms = g[["rms"]], r)
  cat(sprintf("%-13s growth W %.2f rms %.2f | S_el %.2f S_raw %.2f S_med %.2f | J ratio %.3g\n", mo, g[1], g[2], r[1], r[2], r[3], x$stand$J / exp(qp[["lnJ"]])))
  cat(sprintf("   parent check -> e_mp: read %.2f C3 %s W read %.2f | rescaled per quantity: read %.2f C3 %s W read %.2f corr %.2f | rescaled by S_el: W read %.2f\n",
    read(est_f, e_mp), c3n(e_mp, est_f), W(est_f) / W(e_mp), read(est_r, e_mp), c3n(e_mp, est_r), W(est_r) / W(e_mp), cor(est_r, e_mp), W(est_f) * r[["S_el"]] / W(e_mp)))
  o <- order(-abs(e_mp))[1:5]
  print(data.frame(q = Q[o], e_mp = round(e_mp[o], 2), e_pp = round(e_pp[o], 2), E_m = signif(qm[o], 3), E_p = signif(qp[o], 3), ratio = round(rq[o], 2), est = round(est_f[o], 2), est_r = round(est_r[o], 2)), row.names = FALSE) }
P1 <- do.call(rbind, P1); print(round(P1, 2))
cat("\n== own-grid rung pairs (x, c, f): W growth against the ratios from those runs\n")
P2 <- list()
for (pr in PAIRS) for (k in c("x", "c", "f")) { pa <- pr[1]; mo <- pr[2]; qm <- L[[mo]]$runs[[k]]$q; qp <- L[[pa]]$runs[[k]]$q
  g <- W((qm - L[[mo]]$ref) / EPS) / W((qp - L[[pa]]$ref) / EPS); r <- ratios(qm, qp)
  P2[[paste(mo, k)]] <- c(gW = g, r) }
P2 <- do.call(rbind, P2); print(round(P2, 2))
for (v in c("S_el", "S_raw", "S_med")) cat(sprintf("  cor(log %s, log growth) over 9 rungs %.2f; over 3 shared-grid %.2f\n", v, cor(log(P2[, v]), log(P2[, "gW"])), cor(log(P1[, v]), log(P1[, "gW"]))))
saveRDS(list(P1 = P1, P2 = P2), file.path(MV, "diag.rds"))
