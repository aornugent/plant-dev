# Estimate-driven refinement. Rscript refine.R RECORD TAG START.rds [TRAIT_REL]
args <- commandArgs(TRUE); rec <- args[1]; tag <- args[2]; start <- args[3]; rel <- if (length(args) > 3) args[4] else ""
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
R <- file.path(D, "schedtest/refine"); setwd("/home/user/plant-dev")
eps_tab <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
eps_res <- function(q) { e <- eps_tab$eps[eps_tab$role == "resident" & eps_tab$trait == q & eps_tab$unit != "curvature in lma"]
  max(if (length(e)) e[1] else NA, 0.01, na.rm = TRUE) }
times <- readRDS(start); log_f <- file.path(R, paste0(tag, "_", rec, ".log"))
kmax <- as.integer(Sys.getenv("KMAX", "5"))
for (k in 0:kmax) {
  name <- sprintf("ref_%s_%s_p%d", tag, rec, k); tf <- file.path(R, paste0(name, "_times.rds")); saveRDS(times, tf)
  system2(file.path(A, "one.sh"), c(name, rec, "MODE=map", paste0("TIMES=", tf), "COARSE=odd", if (nzchar(rel)) paste0("TRAIT_REL=", rel), strsplit(Sys.getenv("EXTRA"), " ")[[1]]))
  x <- run(name); b <- nd(x); j <- x$dropped
  e <- own_drop(b, j) / sum(b$w * b$offspring) + colSums(x$light + x$soil) / x$stand$J
  est <- sum(e) / 3; abs_est <- sum(abs(e)) / 3
  cat(sprintf("pass %d: %d nodes, %.0f rows, ln J %.6f, estimate %+.5f (abs %.5f)\n", k, length(times), x$stand$rows, log(x$stand$J), est, abs_est), file = log_f, append = TRUE)
  dl <- if (k > 0) abs(log(x$stand$J) - lnJ_prev) else Inf; lnJ_prev <- log(x$stand$J)
  # GUARD=2: also every resident elasticity moved less than eps/4 since the last pass.
  el <- x$stand$elasticity; names(el) <- sub("^1\\.", "", names(el))
  el <- el[!names(el) %in% c("S_D", "a_f3", "recruitment_decay")]
  ee <- vapply(names(el), function(q) eps_res(q), 0)
  de <- if (k > 0) max(abs(el - el_prev[names(el)]) / ee) else Inf; el_prev <- el
  cat(sprintf("        ln J moved %.3f eps, largest elasticity move %.3f eps\n", dl / 0.025, de), file = log_f, append = TRUE)
  g <- Sys.getenv("GUARD")
  if ((abs_est < 0.0125 && (g == "" || dl < 0.025 / 4) && (g != "2" || de < 0.25)) || k == kmax) break
  o <- order(-abs(e)); take <- o[seq_len(which(cumsum(abs(e[o])) >= 0.7 * sum(abs(e)))[1])]
  t <- x$node_times; d <- j[take]
  times <- sort(unique(c(t, (t[d - 1] + t[d]) / 2, (t[d] + t[d + 1]) / 2)))
}
