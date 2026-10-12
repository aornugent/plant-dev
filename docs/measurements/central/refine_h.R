# Refinement with central coarsenings only. Each pass runs the map on B = bisect(G),
# dropping exactly G's midpoints, so e_i is the move of G's interval i to its bisection:
# B's error is sum(e)/3 and G's is 4/3 of it. Stop when |sum e|/3 < eps/2 and every
# resident elasticity moved < eps/4 since the last pass; else add the midpoints of the
# fewest intervals of G carrying 70% of sum|e|.  Rscript refine_h.R RECORD TAG START.rds [TRAIT_REL]
args <- commandArgs(TRUE); rec <- args[1]; tag <- args[2]; G <- readRDS(args[3]); rel <- if (length(args) > 3) args[4] else ""
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
H <- file.path(D, "schedtest/hier"); setwd("/home/user/plant-dev")
eps_tab <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
eps_res <- function(q) { e <- eps_tab$eps[eps_tab$role == "resident" & eps_tab$trait == q & eps_tab$unit != "curvature in lma"]; max(if (length(e)) e[1] else NA, 0.01, na.rm = TRUE) }
log_f <- file.path(H, paste0(tag, "_", rec, ".log")); el_prev <- NULL
for (k in 0:6) {
  B <- sort(c(G, head(G, -1) + diff(G) / 2)); name <- sprintf("hier_%s_%s_p%d", tag, rec, k)
  gf <- file.path(H, paste0(name, "_G.rds")); bf <- file.path(H, paste0(name, "_B.rds")); saveRDS(G, gf); saveRDS(B, bf)
  system2(file.path(A, "one.sh"), c(name, rec, "MODE=map", paste0("TIMES=", bf), paste0("COARSE=", gf), if (nzchar(rel)) paste0("TRAIT_REL=", rel), strsplit(Sys.getenv("EXTRA"), " ")[[1]]))
  x <- run(name); b <- nd(x); j <- x$dropped
  e <- own_drop(b, j) / sum(b$w * b$offspring) + colSums(x$light + x$soil) / x$stand$J
  el <- x$stand$elasticity; names(el) <- sub("^1\\.", "", names(el)); el <- el[!names(el) %in% c("S_D", "a_f3", "recruitment_decay")]
  de <- if (is.null(el_prev)) Inf else max(abs(el - el_prev[names(el)]) / vapply(names(el), eps_res, 0)); el_prev <- el
  cat(sprintf("pass %d: G %d, B %d nodes, %.0f rows, ln J %.6f, estimate for B %+.5f, for G %+.5f; largest elasticity move %.3f eps\n",
    k, length(G), length(B), x$stand$rows, log(x$stand$J), sum(e) / 3, 4 * sum(e) / 3, de), file = log_f, append = TRUE)
  if ((abs(sum(e)) / 3 < 0.0125 && de < 0.25) || k == 6) break
  o <- order(-abs(e)); take <- o[seq_len(which(cumsum(abs(e[o])) >= 0.7 * sum(abs(e)))[1])]
  # B's dropped node j[i] is the midpoint of G's interval; adding it to G bisects that interval.
  G <- sort(c(G, B[j[take]]))
}
