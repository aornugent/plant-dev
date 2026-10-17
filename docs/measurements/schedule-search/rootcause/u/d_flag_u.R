# d_flag_u.R (../proxies/d_flag.R on this round's replay): the validity flag on every loop iterate i >= 2 (pre-registration D in notes.md):
# false-valid = P(C2 or C3 fails | valid), false-invalid = P(invalid | C2 and C3 hold),
# from b_loop.R pass 2 (DUMP=1), decisions on perturbed values. Also the a-priori region
# split of the committed run's error against the measured founders' share.
PO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/u"; TAG <- Sys.getenv("TAG", "_U")
MODES <- c("meas", "clean", "order"); ALL <- c("episodic", "dry", "long-wet", "long-drought", "episodic-lma", "dry-flat", "ld-102", "ld-105", "dry-p50", "wet-adG2")
rate <- function(x) sprintf("%.3f (n %d)", mean(x), length(x))
for (nz in c("coord", "jit")) { z <- readRDS(file.path(PO, sprintf("d_flags_pass2_%s%s.rds", nz, TAG))); F <- as.data.frame(z$F); F$id <- z$ids[match(F$pol, z$ix)]; F$coarse <- F$r * F$R
  P2 <- readRDS(file.path(PO, sprintf("b_loop_pass2_%s%s.rds", nz, TAG)))
  cat(sprintf("\n######## noise %s: %d iterates\n", nz, nrow(F)))
  for (m in 1:3) { G <- F[F$mode == m, ]; if (!nrow(G)) next; v <- G$valid == 1; ok <- G$C23 == 1
    cat(sprintf("\n== %s: valid %.3f of iterates; false-valid P(C2/C3 fail | valid) %s; false-invalid P(invalid | C2&C3 hold) %s; P(C2/C3 fail | invalid) %s\n",
      MODES[m], mean(v), if (any(v)) rate(!ok[v]) else "NA", rate(!v[ok]), if (any(!v)) rate(!ok[!v]) else "NA"))
    cat(sprintf("   checks failing: interval %.3f, noise %.3f, order %.3f (of %d with 3+ runs), proxy %.3f; C1 fails when valid %s\n",
      mean(G$f_int == 0), mean(G$f_noise == 0), mean(G$f_order[!is.na(G$f_order)] == 0), sum(!is.na(G$f_order)), mean(G$f_prox == 0), if (any(v)) rate(G$C1[v] == 0) else "NA"))
    cat(sprintf("   D1: interval check with coarse run r >= 1.28: invalid %.3f (n %d); coarse r <= 1.05: invalid %.3f (n %d)\n",
      mean(G$f_int[G$coarse >= 1.28 - 1e-6] == 0), sum(G$coarse >= 1.28 - 1e-6), mean(G$f_int[G$coarse <= 1.05] == 0), sum(G$coarse <= 1.05)))
    # without the interval check: what do the other three catch?
    v2 <- G$f_noise == 1 & G$f_prox == 1 & (is.na(G$f_order) | G$f_order == 1)
    cat(sprintf("   without the interval check: valid %.3f, false-valid %s, false-invalid %s\n", mean(v2), if (any(v2)) rate(!ok[v2]) else "NA", rate(!v2[ok])))
    # final iterates of the cheapest feasible loops
    y <- P2[P2$mode == MODES[m] & P2$type == "loop" & P2$all10 >= 0.95, ]; y <- y[order(y$T), ]
    for (pid in head(y$id, 3)) { H <- G[G$id == pid, ]; last <- !duplicated(paste(H$case, H$d), fromLast = TRUE); Hl <- H[last, ]
      cat(sprintf("   %-55s T %.0f: final iterates valid %.3f; false-invalid %s; false-valid %s; per case valid %s\n", pid, y$T[y$id == pid], mean(Hl$valid),
        rate(Hl$valid[Hl$C23 == 1] == 0), if (any(Hl$valid == 1)) rate(Hl$C23[Hl$valid == 1] == 0) else "NA",
        paste(sprintf("%.2f", tapply(Hl$valid, factor(Hl$case, 1:10), mean)), collapse = " "))) }
    if (FALSE) { for (ci in c(2, 9)) { H <- G[G$case == ci & G$C23 == 1 & !is.na(G$read) & G$read < 0.3, ]
      cat(sprintf("   D2 %s: iterates passing C2/C3 with read < 0.3: %d; flagged invalid %.3f; by interval %.3f, noise %.3f, order %.3f, proxy %.3f\n", ALL[ci], nrow(H), mean(H$valid == 0),
        mean(H$f_int == 0), mean(H$f_noise == 0), mean(H$f_order[!is.na(H$f_order)] == 0), mean(H$f_prox == 0))) } } } }

