# sum_tag.R TAG...: pairs scored as a09 scores, side by side. A TAG is "val:<alg>" (adjmap runs val_<alg>_{c,f}_<case>)
# or "P:<v>" (P_out runs P_<v>{c,f}_<case>). T on the rows model; training five and all ten totals.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
TRAIN <- c("episodic", "dry", "long-wet", "long-drought", "episodic-lma")
load_pair <- function(tag, cs) { p <- strsplit(tag, ":")[[1]]
  f <- if (p[1] == "val") file.path(R, sprintf("val_%s_%s_%s.rds", p[2], c("c", "f"), cs)) else file.path(POUT, "runs", sprintf("P_%s%s_%s.rds", p[2], c("c", "f"), cs))
  if (!all(file.exists(f))) return(NULL); x <- lapply(f, readRDS); if (any(vapply(x, function(y) is.null(y$stand$elasticity), TRUE))) return(NULL); x }
score <- function(cs, xc, xf) { ref <- refq(cs); qc <- quantities(xc); qf <- quantities(xf); k <- Reduce(intersect, list(names(ref), names(qc), names(qf))); e <- eps_vec(k)
  ec <- (qc[k] - ref[k]) / e; ef <- (qf[k] - ref[k]) / e; d <- (qc[k] - qf[k]) / e; p <- pilot_of(cs); sh <- alg$proxy_err(p, xf$node_times) / alg$proxy_err(p, xc$node_times)
  coarse <- all(abs(d / (1 - sh)) < 1); err <- if (coarse) ec else ef; sest <- if (coarse) d / (1 - sh) else d * sh / (1 - sh); cr <- crit(err, sest)
  big <- pmax(abs(err), abs(sest)) > 1 / 3; ok3 <- abs(sest[big]) >= abs(err[big]) / 2 & abs(sest[big]) <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  rc <- function(x) run_cost(x$stand$rows, TRUE); use <- if (coarse) xc else xf
  list(coarse = coarse, pass = all(cr), fail = paste(names(cr)[!cr], collapse = ""), n3 = sprintf("%d/%d", sum(ok3), sum(big)), worst = max(abs(err)), wq = k[which.max(abs(err))],
       rms = sqrt(mean(err^2)), read = median((d / (1 - sh) / ec)[abs(ec) > 0.2]), T = rc(xc) + rc(xf) + 2 * rc(use)) }
tags <- commandArgs(TRUE); tot <- matrix(0, length(tags), 2, dimnames = list(tags, c("all", "train"))); np <- setNames(rep(0, length(tags)), tags); nn <- np
for (cs in ALL) { cat(sprintf("%-13s", cs))
  for (t in tags) { x <- load_pair(t, cs); if (is.null(x)) { cat(sprintf(" | %-8s --", t)); next }; s <- score(cs, x[[1]], x[[2]]); nn[t] <- nn[t] + 1; np[t] <- np[t] + s$pass
    tot[t, ] <- tot[t, ] + c(s$T, if (cs %in% TRAIN) s$T else 0)
    cat(sprintf(" | %s %s %s w %.2f (%s) rms %.3f rd %.2f C3 %s T %4.0f", t, if (s$coarse) "co" else "FI", if (s$pass) "pass" else paste0("FAIL:", s$fail), s$worst, s$wq, s$rms, s$read, s$n3, s$T)) }
  cat("\n") }
for (t in tags) cat(sprintf("%-10s passes %d/%d | T all %.0f, training %.0f\n", t, np[t], nn[t], tot[t, 1], tot[t, 2]))
