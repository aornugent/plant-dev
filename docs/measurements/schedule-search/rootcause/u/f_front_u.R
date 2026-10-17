# f_front_u.R PASS: the loop replay on U's ladders (b_loop.R, TAG _U) against E6's real T
# (9287, the proxies round's guard): best feasible policy per family and mode, fronts, and
# (PASS 1) the ids carried to pass 2: the proxies round's 84 plus U's own fronts and the ten
# cheapest feasible per mode and noise.
U <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/u"; PO <- file.path(dirname(U), "proxies")
PASS <- if (length(commandArgs(TRUE))) commandArgs(TRUE)[1] else "1"; E6T <- 9287; keep <- readLines(file.path(PO, "pass2_ids.txt")); op <- options(width = 250)
for (nz in c("coord", "jit")) { z <- readRDS(file.path(U, sprintf("b_loop_pass%s_%s_U.rds", PASS, nz))); z$Trel <- z$T / E6T; z$margin <- 1 - z$Wmax
  z$fam <- ifelse(z$type == "loop", sub("^loop r1=([0-9.]+) (fix|P5|P0)=.*", "loop r1=\\1 \\2", z$id), z$type); z$fam[z$id == "E6"] <- "E6"
  e6p <- if (PASS == "2") readRDS(file.path(PO, sprintf("b_loop_pass2_%s.rds", nz))) else NULL
  for (m in c("meas", "clean", "order")) { y <- z[z$mode == m, ]; cat(sprintf("\n######## %s / %s (pass %s)\n", nz, m, PASS))
    e <- y[y$id == "E6", ]; cat(sprintf("E6 protocol on U's ladder: T %.0f (x E6 real %.3f) pass %.3f all10 %.3f Wmax %.2f fC3 %.2f\n", e$T, e$Trel, e$pass, e$all10, e$Wmax, e$fC3))
    f <- y[y$all10 >= 0.95, ]; f <- f[order(f$T), ]; b <- f[!duplicated(f$fam), ]
    cat("-- best feasible (all ten pass in >= 95% of draws) per family\n"); print(b[, c("fam", "id", "T", "Trel", "pass", "all10", "minpc", "Wmax", "W95", "kmean", "kmax", "fC3", "waste", "ampM", "read")], digits = 3, row.names = FALSE)
    if (nrow(f)) cat(sprintf("-- cheapest feasible: %s | per-case final r: %s\n", f$id[1], f$rfin[1]))
    if (!is.null(e6p)) { w <- e6p[e6p$mode == m & e6p$all10 >= 0.95, ]; w <- w[order(w$T), ]
      if (nrow(w)) cat(sprintf("-- on E6's ladder (proxies round, pass 2): cheapest feasible %s T %.0f (x %.3f)\n", w$id[1], w$T[1], w$T[1] / E6T))
      if (nrow(f)) { j <- match(f$id[1], e6p$id[e6p$mode == m]); if (!is.na(j)) { g <- e6p[e6p$mode == m, ][j, ]; cat(sprintf("   U's cheapest feasible policy on E6's ladder: T %.0f (x %.3f), all10 %.3f\n", g$T, g$T / E6T, g$all10)) } } }
    cat("-- front, T against pass rate\n"); o <- y[order(y$T), ]; best <- -1; fr <- c(); for (i in seq_len(nrow(o))) if (o$pass[i] > best + 1e-9) { fr <- c(fr, i); best <- o$pass[i] }
    print(tail(o[fr, c("id", "T", "Trel", "pass", "all10", "Wmax", "kmean")], 8), digits = 3, row.names = FALSE)
    if (PASS == "1") keep <- c(keep, head(f$id, 10), o$id[fr]) } }
if (PASS == "1") { keep <- unique(keep); writeLines(keep, file.path(U, "pass2_ids_U.txt")); cat(length(keep), "ids for pass 2\n") }
