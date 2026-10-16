# D1's per-record table from the lib2 records (d1.R run with the top layer's
# potential kept per solve): the Determined step, its nodes, where in the step,
# the top layer's potential there against the main stages', and the ceiling.
# Usage: Rscript d1_table.R <OUTDIR>
source("/home/user/plant-dev/docs/measurements/kinks/jump-census/d1_lib.R")
out_dir <- commandArgs(TRUE)[1]
for (tag in c("long-wet", "wet-adG2", "ld-105")) {
  d <- load_d1(file.path(out_dir, sprintf("d1_%s_psi.rds", tag)))
  so <- d$so; ev <- d$ev; rows <- d$rows; nt <- d$x$node_times
  K <- JUMP[["determined"]]
  sq <- sequences(d, K); nd <- vapply(sq, `[[`, 0, "node"); r <- unique(vapply(sq, `[[`, 0, "step"))
  det <- so[so$kind == K, ]
  main <- so[so$row %in% c(r - 1, r) & so$node %in% nd & so$slot <= 5 & !so$boundary, ]
  main <- main[(main$row == r) | (main$slot == 5), ]
  ce <- ev[ev$ceiling != 0, ]
  cat(sprintf("== %s: Determined step(s) %s, t %.5f-%.5f, h %.2f d; recorded %d of census %d (%d in sign-change iterates, by difference)\n",
              tag, paste(r, collapse = ","), rows$time[r] - rows$step_size[r], rows$time[r], rows$step_size[r] * 365,
              nrow(det), d$x$operating_points[["determined"]], d$x$operating_points[["determined"]] - nrow(det)))
  cat(sprintf("   nodes %d-%d of %d alive (births %.3f-%.3f, ages %.0f-%.0f d); per node %s Determined evaluations of %s\n",
              min(nd), max(nd), rows$nodes[r], min(nt[nd + 1]), max(nt[nd + 1]),
              min((rows$time[r] - nt[nd + 1]) * 365), max((rows$time[r] - nt[nd + 1]) * 365),
              paste(range(vapply(sq, `[[`, 0, "n_K")), collapse = "-"), paste(range(vapply(sq, function(o) nrow(o$e), 0)), collapse = "-")))
  cat(sprintf("   Determined at u %s (first split substep ends at the sign change, u %.3f-%.3f); kinds met in the same substep: %s\n",
              paste(sort(unique(round(det$u, 3))), collapse = ","), min(d$bl$u[d$bl$row == r & d$bl$u > 0.1]),
              max(d$bl$u[d$bl$row == r]), paste(unique(vapply(sq, `[[`, "", "others")), collapse = ";")))
  cat(sprintf("   top layer psi (MPa) at the Determined solves %.4g-%.4g (median %.4g); at the main stages of those nodes, u 0 / 0.2 / 0.3 / 0.6 / 1: %s\n",
              min(det$psi_top), max(det$psi_top), median(det$psi_top),
              paste(vapply(c(0, 0.2, 0.3, 0.6, 1), function(u) {
                m <- if (u == 0) main[main$row == r - 1, ] else main[main$row == r & abs(main$u - u) < 1e-9 & main$slot <= 4, ]
                sprintf("%.3g", median(m$psi_top)) }, ""), collapse = " / ")))
  per_row <- table(ce$row)
  cat(sprintf("   ceiling: %d evaluations (layers %s) in rows %s (t %s), counts %s; slots %s; census psi reads %d\n",
              nrow(ce), paste(unique(unlist(lapply(ce$ceiling, function(v) which(bitwAnd(v, 2^(0:9)) > 0)))), collapse = ","),
              paste(names(per_row), collapse = ","), paste(round(rows$time[as.integer(names(per_row))], 4), collapse = ","),
              paste(per_row, collapse = ","), paste(unique(ce$slot), collapse = ","), d$x$clamps[["soil_potential_ceiling"]]))
  cat(sprintf("   ceiling evaluations holding Determined %d of %d; Determined solves in an evaluation with a layer the node roots in at the ceiling %d of %d (%.1f%%); rooted masks %s\n",
              sum(ce$k5 > 0), nrow(ce), sum(bitwAnd(det$rooted, det$ceiling) != 0), nrow(det),
              100 * mean(bitwAnd(det$rooted, det$ceiling) != 0), paste(unique(det$rooted), collapse = ",")))
}
