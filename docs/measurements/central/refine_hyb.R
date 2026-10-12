# Refinement certified by the hybrid coarsening. Each pass runs the map on H = G plus
# the midpoints of intervals no central drop of G covers; the coarsening drops G's
# central nodes and those midpoints. H's error is sum(e g(l)) over central drops plus
# sum(e)/3 over midpoints. Stop when that is under eps/2; else bisect the intervals of
# G carrying 70% of the |estimate|.  Rscript refine_hyb.R RECORD TAG START.rds FIRST_PASS.rds [TRAIT_REL]
args <- commandArgs(TRUE); rec <- args[1]; tag <- args[2]; G <- readRDS(args[3]); cr <- readRDS(args[4])$stand$creation
rel <- if (length(args) > 4) args[5] else ""
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
H <- file.path(D, "schedtest/hier"); setwd("/home/user/plant-dev"); log_f <- file.path(H, paste0("hyb_", tag, "_", rec, ".log"))
op <- cr$rate > 0.01; r <- rle(op); ee <- cumsum(r$lengths); ed <- cr$end[ee][-length(ee)]
for (k in 0:6) {
  edge <- round(G, 9) %in% round(ed, 9); drop <- logical(length(G)); i <- 2
  while (i < length(G)) { l <- (G[i] - G[i - 1]) / (G[i + 1] - G[i - 1])
    if (!edge[i] && !drop[i - 1] && l >= 0.35 && l <= 0.65) { drop[i] <- TRUE; i <- i + 2 } else i <- i + 1 }
  covered <- logical(length(G) - 1); covered[c(which(drop) - 1, which(drop))] <- TRUE
  hh <- sort(c(G, (head(G, -1) + diff(G) / 2)[!covered])); cc <- sort(G[!drop])
  name <- sprintf("hybl_%s_%s_p%d", tag, rec, k); hf <- file.path(H, paste0(name, "_H.rds")); cf <- file.path(H, paste0(name, "_C.rds")); saveRDS(hh, hf); saveRDS(cc, cf)
  saveRDS(G, file.path(H, paste0(name, "_G.rds")))
  system2(file.path(A, "one.sh"), c(name, rec, "MODE=map", paste0("TIMES=", hf), paste0("COARSE=", cf), if (nzchar(rel)) paste0("TRAIT_REL=", rel), strsplit(Sys.getenv("EXTRA"), " ")[[1]]))
  x <- run(name); b <- nd(x); j <- x$dropped; h <- x$node_times
  e <- own_drop(b, j) / sum(b$w * b$offspring) + colSums(x$light + x$soil) / x$stand$J
  isg <- round(h[j], 9) %in% round(G, 9); l <- (h[j] - h[j - 1]) / (h[j + 1] - h[j - 1])
  est <- e * ifelse(isg, (l^3 + (1 - l)^3) / (3 * l * (1 - l)), 1 / 3)
  cat(sprintf("pass %d: G %d, H %d nodes, %.0f rows, ln J %.6f, estimate for H %+.5f\n", k, length(G), length(hh), x$stand$rows, log(x$stand$J), sum(est)), file = log_f, append = TRUE)
  if (abs(sum(est)) < 0.0125 || k == 6) break
  # Each estimate belongs to G's intervals: a central drop to the two it merges, a midpoint to its own.
  o <- order(-abs(est)); take <- o[seq_len(which(cumsum(abs(est[o])) >= 0.7 * sum(abs(est)))[1])]
  newm <- unlist(lapply(take, function(q) { if (isg[q]) c((h[j[q] - 1] + h[j[q]]) / 2, (h[j[q]] + h[j[q] + 1]) / 2) else h[j[q]] }))
  G <- sort(unique(c(G, newm)))
}
