# f_front.R: pass-2 fronts (200 draws): T against pass rate and against the worst-case
# margin to eps, per noise and mode, and the best feasible policy of each family.
PO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/proxies"
E6T <- 9287
for (nz in c("coord", "jit")) { z <- readRDS(file.path(PO, sprintf("b_loop_pass2_%s.rds", nz))); z$Trel <- z$T / E6T; z$margin <- 1 - z$Wmax
  z$fam <- ifelse(z$type == "loop", sub("^loop r1=([0-9.]+) (fix|P5|P0)=.*", "loop r1=\\1 \\2", z$id), z$type); z$fam[z$id == "E6"] <- "E6"
  for (m in c("meas", "clean", "order")) { y <- z[z$mode == m, ]; cat(sprintf("\n######## %s / %s\n", nz, m))
    e <- y[y$id == "E6", ]; cat(sprintf("E6: T %.0f pass %.3f all10 %.3f Wmax %.2f fC3 %.2f\n", e$T, e$pass, e$all10, e$Wmax, e$fC3))
    cat("-- best feasible (all ten pass in >= 95% of 200 draws) per family\n")
    f <- y[y$all10 >= 0.95, ]; f <- f[order(f$T), ]; b <- f[!duplicated(f$fam), ]
    print(b[, c("fam", "id", "T", "Trel", "pass", "all10", "Wmax", "W95", "kmean", "kmax", "capk", "waste", "ampM", "outr", "read")], digits = 3, row.names = FALSE)
    cat("-- front, T against pass rate\n"); o <- y[order(y$T), ]; best <- -1; fr <- c(); for (i in seq_len(nrow(o))) if (o$pass[i] > best + 1e-9) { fr <- c(fr, i); best <- o$pass[i] }
    print(o[fr, c("id", "T", "Trel", "pass", "all10", "Wmax")], digits = 3, row.names = FALSE)
    cat("-- front among feasible policies, T against worst-case margin 1 - Wmax\n"); o <- f[order(f$T), ]; best <- -Inf; fr <- c(); for (i in seq_len(nrow(o))) if (o$margin[i] > best + 1e-9) { fr <- c(fr, i); best <- o$margin[i] }
    if (length(fr)) print(o[fr, c("id", "T", "Trel", "margin", "W95", "all10", "outr")], digits = 3, row.names = FALSE)
    cat(sprintf("-- forward-first: best pass %.3f (all10 %.2f) at T %.0f\n", max(y$pass[y$type == "fwd"]), y$all10[y$type == "fwd"][which.max(y$pass[y$type == "fwd"])], y$T[y$type == "fwd"][which.max(y$pass[y$type == "fwd"])])) } }
