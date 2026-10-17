# mk_s.R CASE...: S, the stretches whose interval count does not change with s. Per placed
# stretch the count at s = 1.6, 1, 1/1.6 (U); S* = same count on at least one step. Writes
# the hybrid schedules Uxh (U16, S* laid out as U10) and Ufh (U06, S* as U10), and prints
# the node counts of the fix candidates (n0 = 3, stretch width W).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/u/lib.R")
inside <- function(S, lo, hi) S > lo + 1e-9 & S < hi - 1e-9
swap <- function(S, T, seg) { for (i in seq_len(nrow(seg))) { S <- c(S[!inside(S, seg$lo[i], seg$hi[i])], T[inside(T, seg$lo[i], seg$hi[i])]) }; sort(S) }
for (cs in commandArgs(TRUE)) { p <- pilot_of(cs); G <- lapply(SK, function(s) u_sched(cs, s)); sg <- lapply(G, attr, "seg")
  stopifnot(all(abs(sg[[1]]$lo - sg[[2]]$lo) < 1e-12), all(abs(sg[[3]]$hi - sg[[2]]$hi) < 1e-12))
  n <- sapply(sg, `[[`, "n"); lo <- sg[[2]]$lo; hi <- sg[[2]]$hi; w <- (hi - lo) * 365
  fo <- lo < p$b1 - 1e-9 & lo < 1e-9; post <- !fo
  s1 <- n[, 1] == n[, 2]; s2 <- n[, 2] == n[, 3]; star <- s1 | s2
  # a09 proxy share of the committed rung carried inside S* stretches
  S1 <- as.numeric(G[[2]]); pw <- function(S) { lf <- approxfun(p$nodes$birth, log(pmax(p$nodes$nrr, 1e-300)), rule = 2); a <- head(S, -1); b <- S[-1]; m <- (a + b) / 2
    exp(0.6 * lf(m)) * (p$shut(m) < 0.5) * (b - a)^3 }
  m <- (head(S1, -1) + S1[-1]) / 2; inS <- sapply(m, function(z) any(z > lo[star] & z < hi[star])); wS <- pw(S1)
  cat(sprintf("\n== %s: %d placed stretches (founders %d) | after b1: %d, same count 1.6 vs 1: %d, 1 vs 1/1.6: %d, both: %d, S*: %d (%.0f%%) | median width S* %.0f d, R %.0f d | S* share of the committed rung's proxy %.3f\n",
    cs, nrow(n), sum(fo), sum(post), sum(s1 & post), sum(s2 & post), sum(s1 & s2 & post), sum(star & post), 100 * mean(star[post]), median(w[star & post]), median(w[!star & post]), sum(wS[inS]) / sum(wS)))
  cat("   counts 1.6/1/0.625 of S* stretches (width d):", paste(sprintf("%s(%.0f)", apply(n[star & post, , drop = FALSE], 1, paste, collapse = "/"), w[star & post]), collapse = " "), "\n")
  xh <- swap(as.numeric(G[[1]]), as.numeric(G[[2]]), sg[[2]][star, ]); fh <- swap(as.numeric(G[[3]]), as.numeric(G[[2]]), sg[[2]][star, ])
  stopifnot(all(diff(xh) > 1e-6), all(diff(fh) > 1e-6))
  if (Sys.getenv("NOFIX") == "") saveRDS(xh, file.path(UOUT, "sched", sprintf("Uxh_%s.rds", cs))); saveRDS(fh, file.path(UOUT, "sched", sprintf("Ufh_%s.rds", cs)))
  wide <- star & w >= 90                                    # the wide S* stretches only (Uxw, Ufw)
  saveRDS(swap(as.numeric(G[[1]]), as.numeric(G[[2]]), sg[[2]][wide, ]), file.path(UOUT, "sched", sprintf("Uxw_%s.rds", cs)))
  saveRDS(swap(as.numeric(G[[3]]), as.numeric(G[[2]]), sg[[2]][wide, ]), file.path(UOUT, "sched", sprintf("Ufw_%s.rds", cs)))
  cat(sprintf("   wide S* (>= 90 d): %d stretches\n", sum(wide & post)))
  P <- function(S) alg$proxy_err(p, sort(S)); Px <- P(G[[1]]); Pc <- P(G[[2]]); Pf <- P(G[[3]])
  cat(sprintf("   nodes U x/c/f %d/%d/%d, Uxh %d, Ufh %d | proxy law d1/d2: all %.2f, R only %.2f\n", length(G[[1]]), length(G[[2]]), length(G[[3]]), length(xh), length(fh),
    (Px - Pc) / (Pc - Pf), (P(xh) - Pc) / (Pc - P(fh))))
  if (Sys.getenv("NOFIX") == "") for (n0 in c(1.6, 3)) for (W in c(30, 60, 90)) { V <- lapply(SK, function(s) u_sched(cs, s, n0 = n0, W = W)); nv <- sapply(lapply(V, attr, "seg"), `[[`, "n")
    st <- (nv[, 1] == nv[, 2] | nv[, 2] == nv[, 3]) & post
    cat(sprintf("   fix n0 = %.1f, W = %2d d: nodes %s | S* after b1 %d | proxy law %.2f\n", n0, W, paste(sapply(V, length), collapse = "/"), sum(st), (P(V[[1]]) - P(V[[2]])) / (P(V[[2]]) - P(V[[3]])))) } }
