# pairs.R: score committed/check pairs on dry under either gate, with s fixed (nested
# bisection, 1/4) or from the pilot's proxy (the ratio checks), and their errors along M.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
XR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out/runs"
ld <- function(n) { for (d in c(XR, AGR, file.path(POUT, "runs"), R)) { f <- file.path(d, paste0(n, ".rds")); if (file.exists(f)) return(readRDS(f)) }; NULL }
M <- { p <- quantities(ld("P_in10_dry")); b <- quantities(rd_run("a09", "c", "dry")); k <- intersect(names(p), names(b)); (p[k] - b[k]) / eps_vec(k) }
score <- function(cn, fn, gate, s = NULL, cs = "dry") { xc <- ld(cn); xf <- ld(fn); if (is.null(xc) || is.null(xf) || is.null(xf$stand$elasticity)) return(cat(sprintf("%-28s missing\n", paste(cn, fn))))
  ref <- if (gate == "AG") ref_ag(cs) else refq(cs); qc <- quantities(xc); qf <- quantities(xf); k <- Reduce(intersect, list(names(ref), names(qc), names(qf))); e <- eps_vec(k)
  ec <- (qc[k] - ref[k]) / e; ef <- (qf[k] - ref[k]) / e; d <- (qc[k] - qf[k]) / e
  sh <- if (is.null(s)) { p <- pilot_of(cs); alg$proxy_err(p, xf$node_times) / alg$proxy_err(p, xc$node_times) } else s
  coarse <- all(abs(d / (1 - sh)) < 1); err <- if (coarse) ec else ef; sest <- if (coarse) d / (1 - sh) else d * sh / (1 - sh); cr <- crit(err, sest)
  big <- pmax(abs(err), abs(sest)) > 1 / 3; ok3 <- abs(sest[big]) >= abs(err[big]) / 2 & abs(sest[big]) <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  u <- M[k] / sqrt(sum(M[k]^2)); rows <- function(x) run_cost(x$stand$rows, TRUE)
  cat(sprintf("%-30s %s n %3d/%3d s %.2f | %s %s | worst %.2f (%s) | c %.2f/%.3f f %.2f/%.3f | M: c %+.2f f %+.2f (shrink %.2f) | C3 %d/%d%s | read %.2f | T %4.0f\n",
    paste(cn, fn), gate, length(xc$node_times), length(xf$node_times), sh, if (coarse) "coarse" else "fine  ", if (all(cr)) "pass" else paste("FAIL", paste(names(cr)[!cr], collapse = "")),
    max(abs(err)), k[which.max(abs(err))], max(abs(ec)), sqrt(mean(ec^2)), max(abs(ef)), sqrt(mean(ef^2)), sum(ec * u), sum(ef * u), sum(ec * u) / sum(ef * u),
    sum(ok3), sum(big), if (any(!ok3)) paste0(" miss ", paste(k[big][!ok3], collapse = ",")) else "", median((d / (1 - sh) / ec)[abs(ec) > 0.2]),
    rows(xc) + rows(xf) + 2 * rows(if (coarse) xc else xf))) }
score("val_a09_c_dry", "val_a09_f_dry", "19"); score("P_insc_dry", "P_insf_dry", "19"); score("P_ins3c_dry", "P_ins3f_dry", "19")
score("AG_a09c_dry", "AG_a09f_dry", "AG"); score("AG_insc_dry", "AG_insf_dry", "AG")
cat("-- nested, s = 1/4\n")
score("AG_a09c_dry", "AG_a09nb_dry", "AG", 0.25); score("P_ins3c_dry", "X_ins3nb_dry", "19", 0.25); score("AG_insc_dry", "AG_insnb_dry", "AG", 0.25)
score("P_insc_dry", "X_insnb_dry", "19", 0.25); score("val_a09h_c_dry", "X_a09nb3_dry", "19", 0.25); score("val_a09_c_dry", "X_a09nb_dry", "19", 0.25)
