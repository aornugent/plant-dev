# D1's tables from d1.R's per-case rds files: where the jump kinds sit, how bunched,
# whether each step holding one also holds a change of kind, and the ceiling's
# coincidence with them.
# Usage: Rscript summarise2.R <OUTDIR> [tag ...]
source("/home/user/plant-dev/docs/measurements/kinks/jump-census/d1_lib.R")
a <- commandArgs(TRUE)
out_dir <- a[1]
tags <- if (length(a) > 1) a[-1] else c("long-wet", "wet-adG2", "ld-105")
SLOT <- c("stage", "stage", "stage", "stage", "stage", "end", "end-before-split", "sample",
          "split-substep", "sign-change")
options(width = 220)
summ <- list()
for (tag in tags) {
  d <- load_d1(file.path(out_dir, sprintf("d1_%s.rds", tag)))
  x <- d$x; so <- d$so; ev <- d$ev; rows <- d$rows
  cat(sprintf("\n==== %s: J %.15g saved %.15g rel %.1e; steps %d; times identical %s; attempts %s; block counts ok %s\n",
              tag, x$J, x$J_saved, x$J_rel, x$steps, x$times_identical,
              paste(range(x$attempts), collapse = "-"), d$block_count_ok))
  op <- x$operating_points; un <- x$unstored
  rec <- c(`boundary-root-crit` = sum(ev$k4), determined = sum(ev$k5), `hydraulic-shutdown` = sum(ev$k6))
  cat("solves (census / recorded / unrecorded outside search / inside sign-change search):\n")
  for (nm in names(rec)) cat(sprintf("  %-19s %5d / %5d / %5d / %5d\n", nm, op[[nm]], rec[[nm]],
                                     un[nm, "other"], un[nm, "search"]))
  cat(sprintf("  recorded K solves by slot: %s\n", paste(vapply(names(JUMP), function(nm)
    paste0(nm, " [", paste(names(table(SLOT[so$slot[so$kind == JUMP[[nm]]] + 1])),
                           table(SLOT[so$slot[so$kind == JUMP[[nm]]] + 1]), collapse = " "), "]"), ""), collapse = "; ")))
  res_t <- list()
  for (nm in names(JUMP)) {
    K <- JUMP[[nm]]
    h <- so[so$kind == K, ]
    if (!nrow(h)) { cat(sprintf("-- %s: none recorded\n", nm)); next }
    sq <- sequences(d, K)
    hb <- h[h$boundary, ]
    if (nrow(hb)) cat(sprintf("-- %s on the boundary node: %d solves in rows %s (t %s), slots %s\n", nm, nrow(hb),
                              paste(unique(hb$row), collapse = ","), paste(round(unique(hb$time), 4), collapse = ","),
                              paste(names(table(SLOT[hb$slot + 1])), table(SLOT[hb$slot + 1]), collapse = " ")))
    if (!length(sq)) { cat(sprintf("-- %s: %d recorded solves, none on an introduced node\n", nm, nrow(h))); next }
    st <- data.frame(step = vapply(sq, `[[`, 0, "step"), node = vapply(sq, `[[`, 0, "node"),
                     split = vapply(sq, `[[`, TRUE, "split"), n_K = vapply(sq, `[[`, 0, "n_K"),
                     n_eval = vapply(sq, function(o) nrow(o$e), 0),
                     all_K = vapply(sq, `[[`, TRUE, "all_K"), change = vapply(sq, `[[`, TRUE, "change"),
                     in_substep = vapply(sq, `[[`, TRUE, "change_in_substep"),
                     others = vapply(sq, `[[`, "", "others"))
    st$t <- rows$time[st$step]; st$h_days <- rows$step_size[st$step] * 365
    st$birth <- x$node_times[st$node + 1]; st$age_d <- (st$t - st$birth) * 365
    steps <- aggregate(cbind(n_K, nodes = 1, change, in_substep) ~ step, st, sum)
    steps$t <- rows$time[steps$step]; steps$h_days <- rows$step_size[steps$step] * 365
    steps$solves_in_row <- vapply(steps$step, function(r) sum(h$row == r), 0)
    hb <- h[h$boundary, ]
    cat(sprintf("-- %s: %d recorded solves (%d on the boundary node, %d at sign changes); (step, node) pairs %d in %d steps, %d with t <= 25 (%d of the pairs with b <= 25)\n",
                nm, nrow(h), nrow(hb), sum(h$slot == 9), nrow(st), nrow(steps), sum(steps$t <= 25), sum(st$birth <= 25)))
    cat(sprintf("   per step: K evaluations median %g, max %d; nodes median %g, max %d; h median %.2f d, range %.2f-%.2f d\n",
                median(steps$n_K), max(steps$n_K), median(steps$nodes), max(steps$nodes),
                median(steps$h_days), min(steps$h_days), max(steps$h_days)))
    cat(sprintf("   pairs: split %d of %d; K throughout %d; change of kind in the step %d (inside one (sub)step %d); others met: %s\n",
                sum(st$split), nrow(st), sum(st$all_K), sum(st$change), sum(st$in_substep),
                paste(names(table(st$others)), table(st$others), collapse = "; ")))
    cat(sprintf("   steps holding a change: %d of %d (inside one (sub)step: %d)\n",
                sum(steps$change > 0), nrow(steps), sum(steps$in_substep > 0)))
    nd <- aggregate(cbind(pairs = 1, n_K) ~ node, st, sum)
    nd$birth <- x$node_times[nd$node + 1]
    nd$t_from <- tapply(st$t, st$node, min)[as.character(nd$node)]
    nd$t_to <- tapply(st$t, st$node, max)[as.character(nd$node)]
    nd$age_d <- paste(round(tapply(st$age_d, st$node, min)[as.character(nd$node)], 1),
                      round(tapply(st$age_d, st$node, max)[as.character(nd$node)], 1), sep = "-")
    cat(sprintf("   nodes: %d distinct; per node pairs (steps) median %g max %d\n", nrow(nd), median(nd$pairs), max(nd$pairs)))
    print(nd[order(nd$birth), ], row.names = FALSE, digits = 6)
    # Clusters: runs of consecutive steps.
    s_sorted <- sort(unique(st$step)); cl <- cumsum(c(1, diff(s_sorted) > 1))
    cat(sprintf("   clusters of consecutive steps: %d; sizes %s\n", max(cl), paste(table(cl), collapse = " ")))
    print(head(st[order(st$step), c("step", "t", "h_days", "node", "birth", "age_d", "split", "n_eval", "n_K", "all_K", "change", "in_substep", "others")], 40), row.names = FALSE, digits = 5)
    res_t[[nm]] <- list(pairs = st, steps = steps, nodes = nd)
  }
  # The ceiling.
  ce <- ev[ev$ceiling != 0, ]
  lay <- table(unlist(lapply(ce$ceiling, function(v) which(bitwAnd(v, 2^(0:9)) > 0))))
  det <- so[so$kind == JUMP[["determined"]], ]
  det_ce <- mean(det$ceiling != 0); det_cr <- mean(bitwAnd(det$rooted, det$ceiling) != 0)
  cat(sprintf("-- ceiling: %d evaluations with a layer at the ceiling (census %d psi reads); layers %s; slots %s\n",
              nrow(ce), x$clamps[["soil_potential_ceiling"]], paste(names(lay), lay, collapse = " "),
              paste(names(table(SLOT[ce$slot + 1])), table(SLOT[ce$slot + 1]), collapse = " ")))
  if (nrow(ce)) {
    tr <- sort(unique(ce$row)); cl <- cumsum(c(1, diff(tr) > 1))
    spans <- tapply(rows$time[tr], cl, function(v) sprintf("%.4f-%.4f", min(v), max(v)))
    cat(sprintf("   rows %d in %d runs: %s\n", length(tr), max(cl), paste(spans, collapse = ", ")))
  }
  cat(sprintf("   evaluations at the ceiling holding a Determined solve: %d of %d; Determined solves (%d) in an evaluation with a layer at the ceiling %.3f; with a layer the node roots in %.3f\n",
              sum(ce$k5 > 0), nrow(ce), nrow(det), det_ce, det_cr))
  if (nrow(det)) {
    cat("   Determined solves' rooted / ceiling masks:\n")
    print(table(rooted = det$rooted, ceiling = det$ceiling))
    td <- sort(unique(det$row)); cl <- cumsum(c(1, diff(td) > 1))
    cat(sprintf("   Determined rows %d in %d runs: %s\n", length(td), max(cl),
                paste(tapply(rows$time[td], cl, function(v) sprintf("%.4f-%.4f", min(v), max(v))), collapse = ", ")))
  }
  summ[[tag]] <- list(kinds = res_t, ceiling = ce, det_ce = det_ce, det_cr = det_cr)
}
saveRDS(summ, file.path(out_dir, "summary2.rds"))
