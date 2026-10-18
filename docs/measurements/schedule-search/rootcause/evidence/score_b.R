# score_b.R: layout B per case against refine's references. err = (Q_B - ref)/eps; the odd
# replay's estimate (Q_Bo - Q_B)/3/eps, C1-C5 at eps; on dry the even replay's; the short
# spells' true error (4/3)(Q_B - Q_Bb)/eps against the bound 2 |e| P_short / P_rep; rows and
# CPU against E6 committed and E6 committed + check.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
E <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence"
crit <- function(err, sest) { est <- abs(sest); big <- pmax(abs(err), est) > 1 / 3
  ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  c(C1 = all(abs(err) <= 1), C2 = all(est[abs(err) > 0.5] > 0.25),
    C3 = if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE, C5 = all(est <= 1), n3 = sum(big), miss3 = sum(!ok3)) }
read_of <- function(err, est, lo) { k <- abs(err) > lo; if (any(k)) median(est[k] / err[k]) else NA }
cosv <- function(a, b) sum(a * b) / sqrt(sum(a^2) * sum(b^2))
top <- function(v, n = 5) { o <- order(-abs(v))[1:n]; paste(sprintf("%s %+.2f", names(v)[o], v[o]), collapse = ", ") }
rr <- function(nm) { f <- file.path(E, "runs", paste0(nm, ".rds")); if (!file.exists(f)) return(NULL); x <- readRDS(f); if (is.null(x$stand$elasticity)) NULL else x }
out <- list(); det <- list()
for (cs in c("dry", "long-wet", "episodic-lma")) { b <- rr(paste0("B_", cs)); o <- rr(paste0("Bo_", cs)); if (is.null(b) || is.null(o)) next
  L <- readRDS(file.path(E, sprintf("layoutB_%s.rds", cs))); R <- ref_ladder(cs); qb <- qv(b)
  err <- (qb - R$ref) / EPS; est <- (qv(o) - qb) / 3 / EPS; k <- setdiff(names(err), "lnJ"); cr <- crit(err, est)
  e6 <- e6_runs(cs); e6err <- (qv(e6$x0) - R$ref) / EPS
  row <- data.frame(case = cs, nodes = length(b$node_times), worst = max(abs(err)), worst_q = names(err)[which.max(abs(err))], rms = sqrt(mean(err^2)),
    lnJ_err = err[["lnJ"]], lnJ_est = est[["lnJ"]], est_max = max(abs(est)), cos = cosv(err[k], est[k]), read = read_of(err, est, 0.2), t(cr),
    false_accept = !cr[["C1"]] && cr[["C5"]], e6_worst = max(abs(e6err)), e6_rms = sqrt(mean(e6err^2)),
    rows_B = b$stand$rows, rows_e6c = e6$x0$stand$rows, rows_e6f = e6$x1$stand$rows, rows_x_e6c = b$stand$rows / e6$x0$stand$rows,
    rows_x_e6cf = b$stand$rows / (e6$x0$stand$rows + e6$x1$stand$rows), steps_B = length(b$stand$times), steps_e6c = length(e6$x0$stand$times),
    cpu_B = b$stand$cpu + b$sweep_cpu, cpu_rep = o$stand$cpu + o$sweep_cpu, pinned = identical(b$stand$times, o$stand$times))
  d <- list(err = err, est = est, e6err = e6err)
  ev <- rr(paste0("Be_", cs)); if (!is.null(ev)) { d$est_even <- (qv(ev) - qb) / 3 / EPS
    row$even_cos <- cosv(est[k], d$est_even[k]); row$even_rms_ratio <- sqrt(mean(d$est_even^2)) / sqrt(mean(est^2)); row$even_max <- max(abs(d$est_even))
    row$even_cos_err <- cosv(err[k], d$est_even[k]); row$even_read <- read_of(err, d$est_even, 0.2) }
  bb <- rr(paste0("Bb_", cs)); if (!is.null(bb)) { es <- (4 / 3) * (qb - qv(bb)) / EPS; bound <- 2 * abs(est) * L$proxy_short / L$proxy_rep
    big <- abs(es) > 0.1; d$e_short <- es; d$bound <- bound
    row$short_true_max <- max(abs(es)); row$short_true_q <- names(es)[which.max(abs(es))]; row$short_bound_max <- max(bound)
    row$short_n_over_0.1 <- sum(big); row$short_covered <- sum(big & bound >= abs(es)); row$err_minus_short_worst <- max(abs(err - es)) }
  out[[cs]] <- row; det[[cs]] <- d
  cat(sprintf("%s: err top %s\n   est top %s\n   E6 c top %s\n", cs, top(err), top(est), top(e6err)))
  if (!is.null(d$est_even)) cat(sprintf("   even est top %s\n", top(d$est_even)))
  if (!is.null(d$e_short)) cat(sprintf("   short spells' true error top %s\n", top(d$e_short))) }
tab <- do.call(rbind, lapply(out, function(r) { for (n in setdiff(unique(unlist(lapply(out, names))), names(r))) r[[n]] <- NA; r }))
options(width = 250); print(format(t(tab), digits = 3), quote = FALSE)
saveRDS(list(tab = tab, det = det), file.path(E, "score_b.rds"))
