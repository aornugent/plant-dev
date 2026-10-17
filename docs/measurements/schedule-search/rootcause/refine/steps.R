# steps.R TOL TARGET CASE...: the tool replayed run by run from stored runs. At each run its
# estimate and the share variant (measured remainders + E1 x the unmeasured regions' |ln J|
# shares) against the run's true error: worst, cos, C1-C5 at the target; and each region's
# moves (4 x second / first: 1 is order 2).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R")
a <- commandArgs(TRUE); tol <- as.numeric(a[1]); tg <- as.numeric(a[2]); cases <- a[-(1:2)]
noise <- if (tol >= 1e-4) 0.024 else 0.012
crit <- function(err, sest) { est <- abs(sest); big <- pmax(abs(err), est) > 1 / 3
  ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  c(C1 = all(abs(err) <= 1), C2 = all(est[abs(err) > 0.5] > 0.25), C3 = if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE,
    C5 = all(est <= 1), miss = sum(!ok3), n = sum(big)) }
cosv <- function(x, y) sum(x * y) / sqrt(sum(x^2) * sum(y^2))
REQ <- tempfile(); out <- list(); hon <- list()
for (cs in cases) { cr <- case_of_refine(cs, tol); R <- ref_ladder(cs); k <- 2
  repeat { t <- tryCatch(refine_schedule(cr, target = tg, max_runs = k, noise = noise), need_run = function(e) NULL)
    if (is.null(t) || nrow(t$history) < k) break
    err <- (t$answer - R$ref) / EPS; meas <- names(t$remainder)
    sh <- t$regions$share; names(sh) <- t$regions$region
    est_sh <- if (k == 2) t$E1 else Reduce(`+`, t$remainder, 0 * t$E1) + t$E1 * sum(sh[setdiff(REGIONS, meas)])
    for (v in c("tool", "share")) { e <- if (v == "tool") t$estimate else est_sh; c5 <- crit(err / tg, e / tg)
      out[[length(out) + 1]] <- data.frame(case = cs, run = k, region = tail(t$history$region, 1), rows = tail(t$history$rows, 1), variant = v,
        W = max(abs(err)) / tg, est_max = max(abs(e)) / tg, cos = cosv(err, e), read = median((e / err)[abs(err) > 0.2 * tg]),
        C1 = c5[["C1"]], C2 = c5[["C2"]], C3 = c5[["C3"]], C5 = c5[["C5"]], miss = c5[["miss"]], n = c5[["n"]]) }
    if (k == 2 && all(abs(t$E1) < tg)) break
    k <- k + 1 }
  for (g in names(t$moves)) { mv <- t$moves[[g]]; for (j in seq_along(mv)) { m <- mv[[j]]
    r4 <- if (j > 1) { big <- abs(mv[[j - 1]]) > 3 * noise; if (any(big)) 4 * sqrt(mean(m[big]^2)) / sqrt(mean(mv[[j - 1]][big]^2)) else NA } else NA
    hon[[length(hon) + 1]] <- data.frame(case = cs, region = g, move = j, rms = sqrt(mean(m^2)), max = max(abs(m)), q = Q[which.max(abs(m))],
      lnJ = m[["lnJ"]], ratio4 = r4, cos_prev = if (j > 1) cosv(m, mv[[j - 1]]) else NA) } } }
TB <- do.call(rbind, out); options(width = 220); print(TB, digits = 3)
if (length(hon)) { cat("\nmoves by region\n"); print(do.call(rbind, hon), digits = 3) }
saveRDS(list(tab = TB, hon = if (length(hon)) do.call(rbind, hon)), file.path(RO, sprintf("steps_%s_%g.rds", tag_of_tol(tol), tg)))
