# score_d.R: layout D's run and its pinned drop per case, against refine's references.
# err = (Q_D - ref)/eps; the drop's estimate e = (Q_drop - Q_D)/3/eps; C1-C5 at eps; reads;
# beside them E6 committed's error on the same reference, and costs.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
E <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence"
crit <- function(err, sest) { est <- abs(sest); big <- pmax(abs(err), est) > 1 / 3
  ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  c(C1 = all(abs(err) <= 1), C2 = all(est[abs(err) > 0.5] > 0.25),
    C3 = if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE, C5 = all(est <= 1), n3 = sum(big), miss3 = sum(!ok3)) }
read_of <- function(err, est, lo) { k <- abs(err) > lo; if (any(k)) median(est[k] / err[k]) else NA }
cosv <- function(a, b) sum(a * b) / sqrt(sum(a^2) * sum(b^2))
top <- function(v, n = 5) { o <- order(-abs(v))[1:n]; paste(sprintf("%s %+.2f", names(v)[o], v[o]), collapse = ", ") }
out <- list(); det <- list()
for (cs in c("dry", "long-wet", "episodic-lma")) {
  f1 <- file.path(E, "runs", sprintf("D_%s.rds", cs)); f2 <- file.path(E, "runs", sprintf("Dd_%s.rds", cs))
  if (!file.exists(f1) || !file.exists(f2)) next
  a <- readRDS(f1); d <- readRDS(f2); if (is.null(a$stand$elasticity) || is.null(d$stand$elasticity)) next
  R <- ref_ladder(cs); qa <- qv(a); qd <- qv(d); err <- (qa - R$ref) / EPS; est <- (qd - qa) / 3 / EPS
  e6 <- e6_runs(cs)$x0; e6err <- (qv(e6) - R$ref) / EPS; k <- setdiff(names(err), "lnJ")
  cr <- crit(err, est)
  out[[cs]] <- data.frame(case = cs, ref = R$rungs, ref_own = max(abs(R$own)), nodes = length(a$node_times), drop_nodes = length(d$node_times),
    steps_same = identical(a$stand$times, d$stand$times), worst = max(abs(err)), worst_q = names(err)[which.max(abs(err))], rms = sqrt(mean(err^2)),
    est_max = max(abs(est)), lnJ_err = err[["lnJ"]], lnJ_est = est[["lnJ"]], cos = cosv(err[k], est[k]), read = read_of(err, est, 0.2),
    t(cr), e6_worst = max(abs(e6err)), e6_rms = sqrt(mean(e6err^2)), cos_D_e6 = cosv(err[k], e6err[k]),
    cpu_run = a$stand$cpu + a$sweep_cpu, cpu_drop = d$stand$cpu + d$sweep_cpu, rows_run = a$stand$rows, rows_drop = d$stand$rows,
    e6_rows = e6$stand$rows)
  det[[cs]] <- list(err = err, est = est, e6err = e6err)
  cat(sprintf("%s: err top %s\n   est top %s\n   E6 committed top %s\n", cs, top(err), top(est), top(e6err))) }
tab <- do.call(rbind, out); options(width = 250); print(format(tab, digits = 3), row.names = FALSE)
saveRDS(list(tab = tab, det = det), file.path(E, "score_d.rds"))
