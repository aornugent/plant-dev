# score_r5.R: round 5's real test at 1e-4. Per case: G5's error against the reference, its
# pinned odd replay's estimate (Q_G5o - Q_G5)/3, C1-C5 at 0.88 eps, read and cos; the short
# spells' true error (4/3)(Q_G5 - Q_G5b); nodes, real rows and CPU against E6 committed and
# E6 committed + check; on dry, G5 at 1e-4 against Bga at 3e-5.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
EV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence"; R5 <- file.path(EV, "r5")
TAU <- 0.88
crit <- function(err, sest, tau = TAU) { est <- abs(sest); big <- pmax(abs(err), est) > tau / 3
  ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  c(C1 = all(abs(err) <= tau), C2 = all(est[abs(err) > tau / 2] > tau / 4), C3 = if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE,
    C5 = all(est <= tau), n3 = sum(big), miss3 = sum(!ok3)) }
read_of <- function(err, est, lo = 0.2) { k <- abs(err) > lo; if (any(k)) median(est[k] / err[k]) else NA }
cosv <- function(a, b) sum(a * b) / sqrt(sum(a^2) * sum(b^2))
top <- function(v, n = 5) { o <- order(-abs(v))[1:n]; paste(sprintf("%s %+.2f", names(v)[o], v[o]), collapse = ", ") }
rr <- function(nm, dir = file.path(R5, "runs")) { f <- file.path(dir, paste0(nm, ".rds")); if (!file.exists(f)) return(NULL); x <- readRDS(f); if (is.null(x$stand$elasticity)) NULL else x }
SO <- "storage_relaxation_offset"; out <- list(); det <- list()
for (cs in c("dry", "long-wet", "episodic-lma", "dry-flat", "epi-adG208")) { g <- rr(paste0("G5_", cs)); o <- rr(paste0("G5o_", cs)); if (is.null(g) || is.null(o)) next
  R <- ref_ladder(cs); qg <- qv(g); err <- (qg - R$ref) / EPS; est <- (qv(o) - qg) / 3 / EPS; k <- setdiff(names(err), "lnJ"); cr <- crit(err, est)
  e6 <- e6_runs(cs); e6err <- (qv(e6$x0) - R$ref) / EPS; e6f <- (qv(e6$x1) - R$ref) / EPS
  row <- data.frame(case = cs, ref = R$rungs, ref_own = max(abs(R$own)), nodes = length(g$node_times), nodes_e6c = length(e6$S0), nodes_e6f = length(e6$S1),
    worst = max(abs(err)), worst_q = names(err)[which.max(abs(err))], rms = sqrt(mean(err^2)), root_P50 = err[["root_P50"]], storage_offset = err[[SO]], lnJ = err[["lnJ"]],
    est_max = max(abs(est)), cos = cosv(err[k], est[k]), read = read_of(err, est), rms_err_minus_est = sqrt(mean((err - est)^2)), t(cr), false_accept = !cr[["C1"]] && cr[["C5"]],
    e6c_worst = max(abs(e6err)), e6c_rms = sqrt(mean(e6err^2)), e6f_worst = max(abs(e6f)),
    rows = g$stand$rows, rows_rep = o$stand$rows, rows_x_e6c = g$stand$rows / e6$x0$stand$rows, run_rep_x_e6c = (g$stand$rows + o$stand$rows) / e6$x0$stand$rows,
    run_rep_x_e6cf = (g$stand$rows + o$stand$rows) / (e6$x0$stand$rows + e6$x1$stand$rows), e6cf_x_e6c = (e6$x0$stand$rows + e6$x1$stand$rows) / e6$x0$stand$rows,
    steps_x_e6c = length(g$stand$times) / length(e6$x0$stand$times), cpu = g$stand$cpu + g$sweep_cpu, cpu_rep = o$stand$cpu + o$sweep_cpu,
    rep_cpu_share = (o$stand$cpu + o$sweep_cpu) / (g$stand$cpu + g$sweep_cpu), pinned = identical(g$stand$times, o$stand$times))
  d <- list(err = err, est = est, e6err = e6err)
  b <- rr(paste0("G5b_", cs)); if (!is.null(b)) { es <- (4 / 3) * (qg - qv(b)) / EPS; d$e_short <- es
    row$short_true_max <- max(abs(es)); row$short_true_q <- names(es)[which.max(abs(es))]; row$short_true_rms <- sqrt(mean(es^2)); row$err_minus_short_worst <- max(abs(err - es)) }
  if (cs == "dry") { bga <- rr("Bga_dry", file.path(EV, "runs")); mv <- (qg - qv(bga)) / EPS; d$move_vs_Bga <- mv; row$vs_Bga3e5_max <- max(abs(mv)); row$vs_Bga3e5_rms <- sqrt(mean(mv^2)) }
  out[[cs]] <- row; det[[cs]] <- d
  cat(sprintf("%s: err %s\n   est %s\n   E6 c %s\n", cs, top(err), top(est), top(e6err)))
  if (!is.null(d$e_short)) cat(sprintf("   short spells' true error %s\n", top(d$e_short)))
  if (!is.null(d$move_vs_Bga)) cat(sprintf("   G5 (1e-4) - Bga (3e-5) %s\n", top(d$move_vs_Bga))) }
tab <- do.call(rbind, lapply(out, function(r) { for (n in setdiff(unique(unlist(lapply(out, names))), names(r))) r[[n]] <- NA; r }))
options(width = 250); print(format(t(tab), digits = 3), quote = FALSE)
saveRDS(list(tab = tab, det = det), file.path(R5, "score_r5.rds"))
