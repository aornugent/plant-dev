# cls.R: each class bisection of a09's committed run on dry, per gate: its move along M
# and off M (rms), against the whole halving (a09nb) and the committed run's own error.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
XR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out/runs"
ld <- function(n) { for (d in c(XR, AGR, file.path(POUT, "runs"), R)) { f <- file.path(d, paste0(n, ".rds")); if (file.exists(f)) return(readRDS(f)) }; NULL }
M <- { p <- quantities(ld("P_in10_dry")); b <- quantities(rd_run("a09", "c", "dry")); k <- intersect(names(p), names(b)); (p[k] - b[k]) / eps_vec(k) }
for (g in c("AG", "19")) { base <- if (g == "AG") ld("AG_a09c_dry") else rd_run("a09", "c", "dry"); ref <- if (g == "AG") ref_ag("dry") else refq("dry")
  qb <- quantities(base); k <- Reduce(intersect, list(names(ref), names(qb), names(M))); e <- eps_vec(k); u <- M[k] / sqrt(sum(M[k]^2)); err <- (qb[k] - ref[k]) / e
  cat(sprintf("%s: committed error along M %+.2f, off M rms %.3f\n", g, sum(err * u), sqrt(mean((err - sum(err * u) * u)^2))))
  nm <- if (g == "AG") c(sprintf("AG_a09b%s_dry", c("O", "C", "G", "S", "I", "F")), "AG_a09nb_dry") else c(sprintf("X_a09b%s_dry", c("O", "C", "G", "S", "I", "F")), "X_a09nb_dry")
  tot <- 0; totoff <- rep(0, length(k))
  for (n in nm) { x <- ld(n); if (is.null(x) || is.null(x$stand$elasticity)) next; mv <- (quantities(x)[k] - qb[k]) / e; on <- sum(mv * u); off <- mv - on * u
    if (!grepl("nb", n)) { tot <- tot + on; totoff <- totoff + off }
    cat(sprintf("   %-14s n %3d | move along M %+.3f | off M rms %.3f | its error along M %+.2f | ln J move %+.4f\n", n, length(x$node_times), on, sqrt(mean(off^2)), sum((err + mv) * u), log(x$stand$J / base$stand$J) / 0.025)) }
  cat(sprintf("   sum of classes along M %+.3f, off M rms %.3f\n", tot, sqrt(mean(totoff^2)))) }
