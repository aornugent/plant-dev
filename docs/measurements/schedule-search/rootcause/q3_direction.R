# q3_direction.R: is the error low-dimensional? SVD of error vectors (eps units) across
# distinct runs and cases, per case, and of reference-free c - f moves; and whether ln J's
# error predicts the size of the dominant direction.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
FT <- readRDS(file.path(OUT, "feat.rds")); meta <- FT$meta; E <- FT$E
ok <- meta$build == "L19" & complete.cases(E) & meta$rms <= 1.5
X <- E[ok, ]; mt <- meta[ok, ]
sv <- function(X, lab) { s <- svd(X); f <- s$d^2 / sum(s$d^2)
  cat(sprintf("%-34s runs %4d | variance share PC1..5: %s\n", lab, nrow(X), paste(sprintf("%.2f", f[1:5]), collapse = " "))); s }
top <- function(v, k = 8) paste(sprintf("%s %+.2f", Q[order(-abs(v))][1:k], v[order(-abs(v))][1:k]), collapse = ", ")
cat("== pooled (lib19 class, all tolerances, rms <= 1.5)\n")
s <- sv(X, "pooled uncentred")
for (i in 1:3) cat(sprintf("  PC%d: %s | cos with M %+.2f\n", i, top(s$v[, i]), sum(s$v[, i] * M_unit)))
PC <- s$v[, 1:3]; rownames(PC) <- Q
cat("\n== by tolerance class / by case\n")
for (tl in sort(unique(mt$tol))) { i <- mt$tol == tl; if (sum(i) >= 8) { z <- sv(X[i, , drop = FALSE], sprintf("tol %g", tl)); cat(sprintf("     cos(PC1, pooled PC1) %+.2f, PC1 cos M %+.2f\n", sum(z$v[, 1] * PC[, 1]), sum(z$v[, 1] * M_unit))) } }
for (cs in ALL) { i <- mt$case == cs; if (sum(i) < 8) next; z <- sv(X[i, , drop = FALSE], cs)
  cat(sprintf("     PC1 cos pooled PC1 %+.2f PC2 %+.2f | cos M %+.2f | %s\n", sum(z$v[, 1] * PC[, 1]), sum(z$v[, 1] * PC[, 2]), sum(z$v[, 1] * M_unit), top(z$v[, 1], 5))) }
cat("\n== committed-quality runs only (tol 1e-4, rms <= 0.5): how many directions carry 90%?\n")
i <- mt$tol == 1e-4 & mt$rms <= 0.5; z <- sv(X[i, ], "tol 1e-4, rms <= 0.5"); cat("  PCs for 90%:", which(cumsum(z$d^2) / sum(z$d^2) >= 0.9)[1], "\n")
for (k in 1:3) cat(sprintf("  PC%d: %s | cos M %+.2f\n", k, top(z$v[, k]), sum(z$v[, k] * M_unit)))
# Leave-one-case-out: fit PC1-2 on nine cases, how much of the tenth's error do they hold?
cat("\n== leave-one-case-out: share of a held-out case's squared error in the other cases' top-k PCs\n")
for (cs in ALL) { tr <- X[i & mt$case != cs, ]; te <- X[i & mt$case == cs, , drop = FALSE]; if (!nrow(te)) next
  v <- svd(tr)$v; sh <- vapply(1:5, function(k) sum((te %*% v[, 1:k])^2) / sum(te^2), 0)
  cat(sprintf("  %-13s n %3d | k=1..5: %s\n", cs, nrow(te), paste(sprintf("%.2f", sh), collapse = " "))) }
cat("\n== reference-free: SVD of c - f moves of every stored algorithm pair (same case, build, tolerance)\n")
pr <- meta[grepl("^val_.*_c_", meta$name) & meta$build %in% c("L19", "S"), ]
D <- do.call(rbind, lapply(seq_len(nrow(pr)), function(j) { f <- sub("_c_", "_f_", pr$name[j]); k <- which(meta$name == f & meta$build == pr$build[j])
  if (!length(k)) { idf <- TAB$id[TAB$name == f & TAB$grad][1]; if (is.na(idf)) return(NULL); qf <- qof(idf)[Q] / EPS } else qf <- NULL
  qc <- qof(pr$id[j])[Q] / EPS; if (is.null(qf)) qf <- qof(meta$id[k[1]])[Q] / EPS; d <- qc - qf; if (any(!is.finite(d))) NULL else d }))
zd <- sv(D, "c - f moves (all algorithms)"); for (k in 1:2) cat(sprintf("  PC%d: %s | cos M %+.2f | cos pooled PC1 %+.2f PC2 %+.2f\n", k, top(zd$v[, k]), sum(zd$v[, k] * M_unit), sum(zd$v[, k] * PC[, 1]), sum(zd$v[, k] * PC[, 2])))
cat("\n== does ln J's error predict the size of the error?\n")
sc <- X %*% PC; lj <- X[, "lnJ"]; rm <- sqrt(rowMeans(X[, -1]^2))
cat(sprintf("  all lib19 (n %d): cor(lnJ err, PC1 score) %+.2f, PC2 %+.2f, PC3 %+.2f | cor(|lnJ|, rms elasticities) %+.2f (Spearman %+.2f)\n", nrow(X), cor(lj, sc[, 1]), cor(lj, sc[, 2]), cor(lj, sc[, 3]), cor(abs(lj), rm), cor(abs(lj), rm, method = "spearman")))
cat(sprintf("  committed quality (n %d): cor(|lnJ|, rms) %+.2f (Spearman %+.2f); cor(lnJ, along M) %+.2f\n", sum(i), cor(abs(lj[i]), rm[i]), cor(abs(lj[i]), rm[i], method = "spearman"), cor(lj[i], X[i, ] %*% M_unit)))
for (cs in ALL) { j <- mt$case == cs & i; if (sum(j) < 6) next
  cat(sprintf("  %-13s n %3d cor(|lnJ|, rms) %+.2f | cor(lnJ, PC1) %+.2f | cor(lnJ, M) %+.2f\n", cs, sum(j), cor(abs(lj[j]), rm[j]), cor(lj[j], sc[j, 1]), cor(lj[j], X[j, ] %*% M_unit))) }
saveRDS(list(PC = PC, sv = s$d), file.path(OUT, "q3_pc.rds"))
cat("\n== committed-quality runs: share of squared error along M, and ln J -> along-M leave-one-case-out\n")
Xi <- X[i, ]; ci <- mt$case[i]; am <- as.vector(Xi %*% M_unit); lji <- Xi[, "lnJ"]
cat(sprintf("  pooled share along M %.2f\n", sum(am^2) / sum(Xi^2)))
r <- r0 <- rep(NA, length(am)); bet <- c()
for (cs in unique(ci)) { tr <- ci != cs; b <- sum(am[tr] * lji[tr]) / sum(lji[tr]^2); bet[cs] <- b; r[!tr] <- am[!tr] - b * lji[!tr]; r0[!tr] <- am[!tr] }
cat(sprintf("  along-M rms %.2f; residual after beta * lnJ (LOCO) %.2f; beta by held-out fit: %s\n", sqrt(mean(am^2)), sqrt(mean(r^2)), paste(sprintf("%.1f", range(bet)), collapse = " to ")))
for (cs in unique(ci)) { j <- ci == cs; cat(sprintf("   %-13s share along M %.2f | own slope along-M/lnJ %+.1f | LOCO residual/raw %.2f\n", cs, sum(am[j]^2) / sum(Xi[j, ]^2), sum(am[j] * lji[j]) / sum(lji[j]^2), sqrt(mean(r[j]^2)) / sqrt(mean(am[j]^2)))) }
