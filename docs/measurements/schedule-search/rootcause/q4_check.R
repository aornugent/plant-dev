# q4_check.R: the check run's estimate against the truth on every stored committed/check
# pair, and cheaper estimators of the committed run's error tested leave-one-case-out:
# ln J alone from a finer forward-only run, scaled per quantity; and a-priori magnitude.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
pairs <- list()
add <- function(cn, fn, fam) { ic <- which(TAB$name == cn & TAB$grad & !TAB$bad); jf <- which(TAB$name == fn & TAB$grad & !TAB$bad)
  if (length(ic) && length(jf)) pairs[[length(pairs) + 1]] <<- data.frame(c = TAB$id[ic[1]], f = TAB$id[jf[1]], fam = fam, case = TAB$case[ic[1]], build = TAB$build[ic[1]], tol = TAB$tol[ic[1]]) }
for (cn in TAB$name[grepl("^val_.*_c_", TAB$name)]) add(cn, sub("_c_", "_f_", cn), sub("^val_(.*)_c_.*$", "\\1", cn))
for (cs in ALL) { add(sprintf("P_insc_%s", cs), sprintf("P_insf_%s", cs), "P_ins"); add(sprintf("P_ins3c_%s", cs), sprintf("P_ins3f_%s", cs), "P_ins3"); add(sprintf("P_mid_%s", cs), sprintf("P_midf2_%s", cs), "P_mid") }
for (cs in c("dry", "long-drought", "episodic-lma")) { add(sprintf("AG_a09c_%s", cs), sprintf("AG_a09f_%s", cs), "AG_a09"); add(sprintf("AG_insc_%s", cs), sprintf("AG_insf_%s", cs), "AG_ins") }
add("AG_mid_dry", "AG_midf_dry", "AG_mid"); add("AG_a09c_dry", "AG_a09fg_dry", "AG_a09fg"); add("AG_a09c_long-drought", "AG_a09fg_long-drought", "AG_a09fg")
PR <- do.call(rbind, pairs); PR <- PR[!is.na(PR$case), ]
PCTX <- lapply(setNames(ALL, ALL), pilot_ctx)
res <- list(); EST <- list()
for (i in seq_len(nrow(PR))) { p <- PR[i, ]; ec <- err_of(p$c); ef <- err_of(p$f); if (is.null(ec) || is.null(ef)) next
  k <- intersect(names(ec), names(ef)); if (any(!is.finite(ec[k])) || length(k) < 40) next
  sc <- alg$proxy_err(PCTX[[p$case]], sort(RR[[p$c]]$S)); sf <- alg$proxy_err(PCTX[[p$case]], sort(RR[[p$f]]$S)); s <- sf / sc
  d <- ec[k] - ef[k]; est <- d / (1 - s)
  EST[[i]] <- list(k = k, ec = ec[k], ef = ef[k], est = est, s = s)
  big <- pmax(abs(ec[k]), abs(est)) > 1 / 3; ok3 <- abs(est) >= abs(ec[k]) / 2 & abs(est) <= 2 * abs(ec[k]) & sign(est) == sign(ec[k])
  res[[i]] <- data.frame(p, s = s, nc = length(RR[[p$c]]$S), nf = length(RR[[p$f]]$S), rms_c = sqrt(mean(ec[k]^2)), worst_c = max(abs(ec[k])), rms_f = sqrt(mean(ef[k]^2)),
    rms_est = sqrt(mean(est^2)), worst_est = max(abs(est)), corr = cor(est, ec[k]), nbig = sum(big), read = if (any(big)) mean(ok3[big]) else NA,
    C3 = if (any(big)) sum(!ok3[big]) <= max(1, floor(0.2 * sum(big))) else TRUE, C2 = all(abs(est)[abs(ec[k]) > 0.5] > 0.25),
    lnJ_c = ec["lnJ"], lnJ_est = est["lnJ"], alongM_c = sum(ec[k] * M_unit[k]), alongM_est = sum(est * M_unit[k])) }
R <- do.call(rbind, res); EST <- EST[!vapply(EST, is.null, TRUE)]
cat(nrow(R), "pairs over", length(unique(R$case)), "cases\n")
sm <- function(z, lab) cat(sprintf("  %-34s n %3d | C3 pass %3.0f%% (read median %.2f) | C2 pass %3.0f%% | corr(est, err) median %.2f | rms est/err median %.2f [%.2f, %.2f] | lnJ est/err median %.2f\n",
  lab, nrow(z), 100 * mean(z$C3), median(z$read, na.rm = TRUE), 100 * mean(z$C2), median(z$corr), median(z$rms_est / z$rms_c), quantile(z$rms_est / z$rms_c, 0.1), quantile(z$rms_est / z$rms_c, 0.9), median(z$lnJ_est / z$lnJ_c)))
cat("\n== the check's estimate (c - f)/(1 - s) of the committed run's error, s from the pilot proxy\n")
sm(R, "all pairs"); for (b in unique(R$build)) sm(R[R$build == b, ], paste("build", b))
for (tl in sort(unique(R$tol))) sm(R[R$tol == tl, ], sprintf("tol %g", tl))
for (cs in ALL) sm(R[R$case == cs, ], cs)
for (fm in c("a09", "a09p", "a10", "c5t", "a04t", "P_ins", "P_mid", "AG_a09", "ins75", "insk")) if (any(R$fam == fm)) sm(R[R$fam == fm, ], paste("family", fm))
saveRDS(list(R = R, EST = EST), file.path(OUT, "q4_check.rds"))
