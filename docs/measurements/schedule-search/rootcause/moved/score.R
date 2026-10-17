# score.R: each moved case on its parent's committed grid (e_mp), beside the same moved
# case on its own committed grid (e_mm) and the parent on its own (e_pp), all in eps
# against each case's own reference; the reserve r = 1 - W_pp / W_mp; and whether the
# parent's own estimates (x-c pair, E6's check) read e_mp.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
PO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/proxies"
MV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/moved"
AR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
D <- readRDS(file.path(PO, "lad.rds")); L <- D$L; Q <- D$Q; EPS <- D$EPS; M <- D$M_unit[Q]
crit <- function(err, sest) { est <- abs(sest); big <- pmax(abs(err), est) > 1 / 3
  ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  c(C1 = all(abs(err) <= 1), C2 = all(est[abs(err) > 0.5] > 0.25),
    C3 = if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE, C5 = all(est <= 1)) }
c3n <- function(err, est) { big <- pmax(abs(err), abs(est)) > 1 / 3
  ok <- abs(est) >= abs(err) / 2 & abs(est) <= 2 * abs(err) & sign(est) == sign(err); sprintf("%d/%d", sum(ok & big), sum(big)) }
read <- function(est, err) { j <- abs(err) > 0.2; if (any(j)) median(est[j] / err[j]) else NA }
cosv <- function(a, b) sum(a * b) / sqrt(sum(a^2) * sum(b^2))
W <- function(e) max(abs(e)); rms <- function(e) sqrt(mean(e^2))
desc <- function(tag, e) sprintf("  %-22s W %.2f (%s) rms %.3f along M %+.2f ln J %+.2f", tag, W(e), Q[which.max(abs(e))], rms(e), sum(e * M), e[["lnJ"]])

# Guards G2 (setting equal but TIMES) and G3 (forward rerun bit-identical).
g3 <- readRDS(file.path(MV, "runs", "g3_fwd_episodic-lma.rds")); s3 <- readRDS(file.path(AR, "val_insk_c_episodic-lma.rds"))
cat(sprintf("G3 forward rerun of episodic-lma on its own grid: J %.15g vs saved %.15g, identical %s; steps %d vs %d\n",
  g3$stand$J, s3$stand$J, identical(g3$stand$J, s3$stand$J), length(g3$stand$times), length(s3$stand$times)))

PAIRS <- list(c("dry", "dry-p50"), c("long-wet", "wet-adG2"), c("episodic", "episodic-lma"))
out <- list(); QQ <- list()
for (pr in PAIRS) { pa <- pr[1]; mo <- pr[2]
  f <- file.path(MV, "runs", sprintf("mv_%s_on_%s.rds", mo, pa)); if (!file.exists(f)) { cat(mo, ": run missing\n"); next }
  x <- readRDS(f); if (is.null(x$stand$elasticity)) { cat(mo, ": no gradient\n"); next }
  own <- readRDS(file.path(AR, sprintf("val_insk_c_%s.rds", mo))); par <- readRDS(file.path(AR, sprintf("val_insk_c_%s.rds", pa)))
  se <- x$setting$env; so <- own$setting$env; k <- setdiff(names(se), "TIMES")
  g2 <- identical(se[k], so[k]) && identical(x$setting[c("regime", "seed", "tol", "atol")], own$setting[c("regime", "seed", "tol", "atol")])
  g1 <- identical(x$node_times, par$node_times)
  q <- quantities(x)[Q]
  e_mp <- (q - L[[mo]]$ref) / EPS; e_mm <- (L[[mo]]$runs$c$q - L[[mo]]$ref) / EPS; e_pp <- (L[[pa]]$runs$c$q - L[[pa]]$ref) / EPS
  # The parent's estimates of its own committed error, from its saved x, c, f runs.
  R <- L[[pa]]$runs; s_c <- R$c$proxy / R$x$proxy; s_f <- R$f$proxy / R$c$proxy
  est_x <- (R$x$q - R$c$q) / EPS / (1 / s_c - 1); est_f <- (R$c$q - R$f$q) / EPS / (1 - s_f)
  # The moved case's own estimates on its own grid, for comparison.
  Rm <- L[[mo]]$runs; est_fm <- (Rm$c$q - Rm$f$q) / EPS / (1 - Rm$f$proxy / Rm$c$proxy); est_xm <- (Rm$x$q - Rm$c$q) / EPS / (1 / (Rm$c$proxy / Rm$x$proxy) - 1)
  cat(sprintf("\n== %s on %s's grid (nodes %d; own grid %d) | G1 TIMES = parent's %s | G2 setting = own run's but TIMES %s\n", mo, pa, length(x$node_times), length(own$node_times), g1, g2))
  cat(sprintf("  rows %.0f (parent %.0f, x %.3f; own %.0f) | steps %d (parent %d, own %d) | cpu fwd %.0f s, sweep %.0f s | J %.8g (own %.8g, ref %.8g)\n",
    x$stand$rows, par$stand$rows, x$stand$rows / par$stand$rows, own$stand$rows, length(x$stand$times), length(par$stand$times), length(own$stand$times),
    x$stand$cpu, x$sweep_cpu, x$stand$J, own$stand$J, exp(L[[mo]]$ref[["lnJ"]])))
  cat(desc("e_mp moved, parent grid", e_mp), "\n", desc("e_mm moved, own grid", e_mm), "\n", desc("e_pp parent, parent grid", e_pp), "\n", sep = "")
  g <- W(e_mp) / W(e_pp); gr <- rms(e_mp) / rms(e_pp)
  cat(sprintf("  growth W_mp/W_pp %.2f -> reserve %.2f | rms ratio %.2f -> reserve %.2f | rebuild effect W_mp/W_mm %.2f, rms %.2f\n",
    g, max(0, 1 - 1 / g), gr, max(0, 1 - 1 / gr), W(e_mp) / W(e_mm), rms(e_mp) / rms(e_mm)))
  cat(sprintf("  cos(e_mp, e_mm) %.2f, rms diff %.3f | cos(e_mp, e_pp) %.2f, rms diff %.3f, W diff %.2f | cos(e_mm, e_pp) %.2f\n",
    cosv(e_mp, e_mm), rms(e_mp - e_mm), cosv(e_mp, e_pp), rms(e_mp - e_pp), W(e_mp - e_pp), cosv(e_mm, e_pp)))
  tr <- function(tag, est, err) { cr <- crit(err, est)
    cat(sprintf("  %-28s read %5.2f corr %5.2f C3 %-5s W read %.2f | C1 %s C2 %s C3 %s C5 %s\n", tag, read(est, err), cor(est, err), c3n(err, est), W(est) / W(err), cr[1], cr[2], cr[3], cr[4])) }
  tr("parent x-c -> e_pp (own)", est_x, e_pp); tr("parent x-c -> e_mp", est_x, e_mp)
  tr("parent check -> e_pp (own)", est_f, e_pp); tr("parent check -> e_mp", est_f, e_mp)
  tr("moved check -> e_mm (own)", est_fm, e_mm); tr("moved x-c -> e_mm (own)", est_xm, e_mm)
  # Worst quantities on the parent grid.
  o <- order(-abs(e_mp))[1:6]
  print(data.frame(q = Q[o], e_mp = round(e_mp[o], 2), e_mm = round(e_mm[o], 2), e_pp = round(e_pp[o], 2), est_check = round(est_f[o], 2), est_xc = round(est_x[o], 2)), row.names = FALSE)
  out[[mo]] <- data.frame(moved = mo, parent = pa, W_mp = W(e_mp), W_mm = W(e_mm), W_pp = W(e_pp), rms_mp = rms(e_mp), rms_mm = rms(e_mm), rms_pp = rms(e_pp),
    M_mp = sum(e_mp * M), M_mm = sum(e_mm * M), M_pp = sum(e_pp * M), reserve_W = max(0, 1 - 1 / g), reserve_rms = max(0, 1 - 1 / gr),
    cos_mp_mm = cosv(e_mp, e_mm), cos_mp_pp = cosv(e_mp, e_pp), read_f = read(est_f, e_mp), corr_f = cor(est_f, e_mp), C3_f = c3n(e_mp, est_f),
    read_x = read(est_x, e_mp), corr_x = cor(est_x, e_mp), C3_x = c3n(e_mp, est_x), rows = x$stand$rows, rows_par = par$stand$rows, g1 = g1, g2 = g2)
  QQ[[mo]] <- data.frame(moved = mo, q = Q, e_mp = e_mp, e_mm = e_mm, e_pp = e_pp, est_f = est_f, est_x = est_x) }
O <- do.call(rbind, out); rownames(O) <- NULL
saveRDS(list(O = O, Q = do.call(rbind, QQ)), file.path(MV, "score.rds"))
cat("\n== summary\n"); print(O[, 1:15], digits = 3); print(O[, c(1, 16:ncol(O))], digits = 3)
