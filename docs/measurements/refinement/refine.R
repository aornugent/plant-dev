# Estimate-driven refinement. Rscript refine.R RECORD TAG START.rds [TRAIT_REL]
args <- commandArgs(TRUE); rec <- args[1]; tag <- args[2]; start <- args[3]; rel <- if (length(args) > 3) args[4] else ""
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
R <- file.path(D, "schedtest/refine"); setwd("/home/user/plant-dev")
times <- readRDS(start); log_f <- file.path(R, paste0(tag, "_", rec, ".log"))
for (k in 0:5) {
  name <- sprintf("ref_%s_%s_p%d", tag, rec, k); tf <- file.path(R, paste0(name, "_times.rds")); saveRDS(times, tf)
  system2(file.path(A, "one.sh"), c(name, rec, "MODE=map", paste0("TIMES=", tf), "COARSE=odd", if (nzchar(rel)) paste0("TRAIT_REL=", rel)))
  x <- run(name); b <- nd(x); j <- x$dropped
  e <- own_drop(b, j) / sum(b$w * b$offspring) + colSums(x$light + x$soil) / x$stand$J
  est <- sum(e) / 3; abs_est <- sum(abs(e)) / 3
  cat(sprintf("pass %d: %d nodes, %.0f rows, ln J %.6f, estimate %+.5f (abs %.5f)\n", k, length(times), x$stand$rows, log(x$stand$J), est, abs_est), file = log_f, append = TRUE)
  dl <- if (k > 0) abs(log(x$stand$J) - lnJ_prev) else Inf; lnJ_prev <- log(x$stand$J)
  if ((abs_est < 0.0125 && (Sys.getenv("GUARD") != "1" || dl < 0.025 / 4)) || k == 5) break
  o <- order(-abs(e)); take <- o[seq_len(which(cumsum(abs(e[o])) >= 0.7 * sum(abs(e)))[1])]
  t <- x$node_times; d <- j[take]
  times <- sort(unique(c(t, (t[d - 1] + t[d]) / 2, (t[d] + t[d + 1]) / 2)))
}
