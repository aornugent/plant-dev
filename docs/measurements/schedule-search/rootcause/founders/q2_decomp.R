# q2_decomp.R CASE...: exact split of a founder's ln nrr against founder 0's:
#   ln nrr_j - ln nrr_0 = [ln F_j - ln F_0]                      (lifetime seed output)
#                       + [ln <S_0>_{dF_j} - ln <S_0>_{dF_0}]      (when j reproduces, on founder 0's survival)
#                       + [ln <S_j>_{dF_j} - ln <S_0>_{dF_j}]      (j's own extra mortality)
# with <S>_{dF} the seed-weighted mean survival, from the trajectories (F = 'fecundity').
# S includes the patch's survival P(t)/P(b) (Weibull, shape 2, lifetime 40: P = exp(-0.006043 t^2)),
# which the offspring rate carries (node.h offspring_dt_dfecundity_rate); its 1/P(b) is in 'own'.
FO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
for (cs in commandArgs(TRUE)) { x <- readRDS(file.path(FO, "runs", sprintf("traj_%s.rds", cs))); T <- x$traj; t <- T$time; b <- T$birth; nb <- length(b)
  Pt <- exp(-0.006043 * t^2)
  S0 <- exp(-T$mortality[, 1]) * Pt
  mean_S <- function(S, F) { dF <- diff(F); ok <- !is.na(dF) & dF > 0; Sm <- (head(S, -1) + tail(S, -1)) / 2; sum(Sm[ok] * dF[ok]) / sum(dF[ok]) }
  medF <- function(F) { Ff <- max(F, na.rm = TRUE); i <- which(F >= Ff / 2)[1]; t[i] }
  lnr <- log(x$stand$nodes$nrr[seq_len(nb)])
  cat(sprintf("== %s\n birth | d ln nrr | seed output | timing on S_0 | own mortality | sum | t median seed | founder 0's M at it | hazard there\n", cs))
  F0 <- T$fecundity[, 1]; base <- c(log(max(F0, na.rm = TRUE)), log(mean_S(S0, F0)))
  rows <- list()
  for (j in unique(round(seq(1, nb, length.out = 9)))) { Fj <- T$fecundity[, j]; Sj <- exp(-T$mortality[, j]) * Pt / exp(-0.006043 * b[j]^2); Sj[is.na(Sj)] <- 1
    p1 <- log(max(Fj, na.rm = TRUE)) - base[1]; p2 <- log(mean_S(S0, Fj)) - base[2]; p3 <- log(mean_S(Sj, Fj)) - log(mean_S(S0, Fj))
    tm <- medF(Fj)
    cat(sprintf(" %.3f | %+6.2f | %+6.2f | %+6.2f | %+6.2f | %+6.2f | %5.2f | %5.2f | %.3f\n", b[j], lnr[j] - lnr[1], p1, p2, p3, p1 + p2 + p3, tm, approx(t, T$mortality[, 1], tm)$y, 2 * 0.006043 * tm))
    rows[[length(rows) + 1]] <- c(b = b[j], d = lnr[j] - lnr[1], seed = p1, timing = p2, own = p3, tmed = tm) }
  saveRDS(do.call(rbind, rows), file.path(FO, sprintf("q2_decomp_%s.rds", cs))) }
