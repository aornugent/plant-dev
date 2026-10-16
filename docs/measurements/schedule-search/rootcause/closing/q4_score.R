# q4_score.R: Q4's strip-only ladders. Zone error of a rung = Q(rung) - Q(resZ), in eps. For the
# proposed ladder (edg2, edg3, edg5) and the inset rule's (insx, committed insk c, insf): the
# errors along M and their ratios against the square law, per-quantity projected ratios, the
# cosine of successive moves, and rms; plus each rung's node count and rows.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
cl <- function(k, cs) { f <- file.path(CL, "runs", sprintf("cl_%s_%s.rds", k, cs)); if (!file.exists(f)) return(NULL); x <- readRDS(f); if (is.null(x$stand$elasticity)) NULL else x }
cosv <- function(a, b) sum(a * b) / sqrt(sum(a^2) * sum(b^2))
for (cs in c("dry", "dry-p50")) { ref <- cl("resZ", cs); if (is.null(ref)) next
  cat(sprintf("== %s (resZ %d nodes; resZ against the committed run's full error: e_resZ %s)\n", cs, length(ref$node_times), fmt(err_run(ref, cs))))
  lad <- list(proposed = list(r = c(3 / 2, 1, 3 / 5), x = list(cl("edg2", cs), cl("edg3", cs), cl("edg5", cs))),
              inset = list(r = c(1.6, 1, 1 / 1.6), x = list(cl("insx", cs), rd(sprintf("val_insk_c_%s", cs)), cl("insf", cs))))
  for (nm in names(lad)) { L <- lad[[nm]]; ok <- !vapply(L$x, is.null, TRUE); if (!any(ok)) next
    E <- lapply(L$x, function(x) if (is.null(x)) NULL else mv_run(x, ref))
    for (i in which(ok)) cat(sprintf("  %-8s rung %.2f: n %3d rows %7.0f | zone error %s\n", nm, L$r[i], length(L$x[[i]]$node_times), L$x[[i]]$stand$rows, fmt(E[[i]])))
    if (all(ok)) { m <- vapply(E, onM, 0); law <- c(L$r[1]^2 / L$r[2]^2, L$r[2]^2 / L$r[3]^2)
      pr <- c(sum(E[[1]] * E[[2]]) / sum(E[[2]]^2), sum(E[[2]] * E[[3]]) / sum(E[[3]]^2))
      cat(sprintf("  %-8s along M: %+.3f / %+.3f / %+.3f | ratios x/c %.2f (law %.2f), c/f %.2f (law %.2f) | projected per-quantity x/c %.2f, c/f %.2f | cos(x-c, c-f) %.2f | rms ratios %.2f, %.2f | lnJ %+.3f / %+.3f / %+.3f\n",
        nm, m[1], m[2], m[3], m[1] / m[2], law[1], m[2] / m[3], law[2], pr[1], pr[2], cosv(E[[1]] - E[[2]], E[[2]] - E[[3]]), r2(E[[1]]) / r2(E[[2]]), r2(E[[2]]) / r2(E[[3]]),
        E[[1]]["lnJ"], E[[2]]["lnJ"], E[[3]]["lnJ"])) } } }
