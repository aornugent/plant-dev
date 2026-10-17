# score.R TOL: each case and target from drive_TOL.rds against its reference: the tool's
# final run (C1-C5 in units of target x eps, the estimate's read), runs and rows, the
# regions in order, the estimate's read after every run, each region's second-move
# ratio, and uniform refinement at matched worst error.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R")
NOISE <- as.numeric(Sys.getenv("NOISE", "0.012"))
tol <- as.numeric(commandArgs(TRUE)[1])
D <- do.call(c, lapply(list.files(RO, sprintf("^drive_%s.*\\.rds$", tag_of_tol(tol)), full.names = TRUE), readRDS))
crit <- function(err, sest) { est <- abs(sest); big <- pmax(abs(err), est) > 1 / 3
  ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  c(C1 = all(abs(err) <= 1), C2 = all(est[abs(err) > 0.5] > 0.25),
    C3 = if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE, C5 = all(est <= 1), n3 = sum(big), miss3 = sum(!ok3)) }
read_of <- function(err, est, lo) { k <- abs(err) > lo; if (any(k)) median(est[k] / err[k]) else NA }
cosv <- function(a, b) sum(a * b) / sqrt(sum(a^2) * sum(b^2))
REFS <- list(); rows <- list(); steps <- list(); hon <- list()
for (key in names(D)) { cs <- sub("@.*", "", key); tg <- as.numeric(sub(".*@", "", key)); z <- D[[key]]
  if (is.null(REFS[[cs]])) REFS[[cs]] <- ref_ladder(cs); R <- REFS[[cs]]; own <- max(abs(R$own)); scored <- own < tg / 3
  t <- z$tool; h <- t$history; err <- (t$answer - R$ref) / EPS; cr <- crit(err / tg, t$estimate / tg)
  # The tool's runs, in order, from the backend's store (every run is nested in the last).
  cr_run <- case_of_refine(cs, tol)
  u <- z$uniform; uq <- lapply(seq_len(u$k), function(k) un_run(cs, tol, k)$q)
  uerr <- lapply(uq, function(q) (q - R$ref) / EPS); uW <- vapply(uerr, function(e) max(abs(e)), 0)
  ucr <- crit(uerr[[u$k]] / tg, u$est / tg)
  W <- max(abs(err)); rows_final <- tail(h$rows, 1); rows_total <- sum(h$rows)
  # Uniform's rows at the tool's worst error: log-log in (rows, worst) over its ladder.
  u_at <- if (u$k > 1 || length(uW) > 1) { lr <- log(u$rows[seq_along(uW)]); lw <- log(uW)
    if (W < min(uW)) NA else exp(approx(lw, lr, log(W), rule = 2)$y) } else NA
  rows[[key]] <- data.frame(case = cs, target = tg, ref = R$rungs, own = own, scored = scored, runs = nrow(h),
    order = paste(h$region[-(1:2)], collapse = ">"), nodes = tail(h$nodes, 1), rows_final = rows_final, rows_total = rows_total,
    W = W / tg, W_q = Q[which.max(abs(err))], est_max = max(abs(t$estimate)) / tg, read = read_of(err, t$estimate, 0.2 * tg),
    cos = cosv(err, t$estimate), C1 = cr[["C1"]], C2 = cr[["C2"]], C3 = cr[["C3"]], C5 = cr[["C5"]], n3 = cr[["n3"]], miss3 = cr[["miss3"]],
    pass = all(cr[c("C1", "C2", "C3", "C5")] == 1),
    u_k = u$k, u_done = u$done, u_rows = u$rows[u$k], u_W = uW[u$k] / tg, u_pass = all(ucr[c("C1", "C2", "C3", "C5")] == 1),
    u_rows_at_W = u_at, ratio_at_W = rows_final / u_at)
  # The estimate after every run against that run's true error.
  if (nrow(h) > 2 && key == sprintf("%s@%g", cs, min(as.numeric(sub(".*@", "", names(D)[startsWith(names(D), paste0(cs, "@"))]))))) {
    S <- cr_run$S1; Ek <- t$E1; xk <- cr_run$run(S, map = FALSE)
    for (i in seq_len(nrow(h))[-(1:2)]) { g <- h$region[i]; S <- sort(unique(round(c(S, refine_nodes(S, g, cr_run$edges, cr_run$b1)), 10)))
      xk <- cr_run$run(S, map = TRUE); ek <- (xk$q - R$ref) / EPS
      steps[[length(steps) + 1]] <- data.frame(case = cs, run = i, region = g, rows = xk$rows, W = max(abs(ek)), rms = sqrt(mean(ek^2)),
        est_max = h$est_max[i], map_all = xk$map[["all"]], err_lnJ = ek[["lnJ"]]) } }
  for (g in names(t$moves)) { mv <- t$moves[[g]]; if (length(mv) < 2) next
    for (j in 2:length(mv)) { a <- mv[[j - 1]]; b <- mv[[j]]; big <- abs(a) > 3 * (if (tol >= 1e-4) 0.024 else NOISE)
      hon[[length(hon) + 1]] <- data.frame(case = cs, target = tg, region = g, step = j, ratio4 = if (any(big)) 4 * sqrt(mean(b[big]^2)) / sqrt(mean(a[big]^2)) else NA,
        cos = cosv(a, b), n_big = sum(big), rms1 = sqrt(mean(a^2)), rms2 = sqrt(mean(b^2))) } } }
TB <- do.call(rbind, rows); rownames(TB) <- NULL; options(width = 250)
print(TB, digits = 3)
if (length(steps)) { cat("\nper run: true error against the estimate\n"); print(do.call(rbind, steps), digits = 3) }
if (length(hon)) { cat("\nregion honesty: 4 x second move / first (1 = order 2)\n"); print(do.call(rbind, hon), digits = 3) }
saveRDS(list(tab = TB, steps = if (length(steps)) do.call(rbind, steps), hon = if (length(hon)) do.call(rbind, hon), refs = REFS),
  file.path(RO, sprintf("score_%s.rds", tag_of_tol(tol))))
