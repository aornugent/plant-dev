# splits.R: where the per-node count of sign-change splits changes between neighbours, on the
# uniform references and the closing fate map, against the pilot's edges.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/layout.R")
REFS <- list(`flat-al1125` = file.path(SC, "heldout/runs/ref_flat-al1125_u857.rds"), `episodic-lma` = file.path(SC, "refine/runs/ref_episodic-lma_u857.rds"),
  `dry-lma125` = file.path(SC, "refine/runs/ref_dry-lma125_u857.rds"), dry = file.path(SC, "closing/runs/cl_map_dry.rds"))
for (cs in names(REFS)) { r <- readRDS(REFS[[cs]])$stand; b <- r$nodes$birth; s <- r$splits; ea <- edges_all(cs); p <- pilot_of(cs)
  ch <- which(diff(s) != 0); mid <- (b[ch] + b[ch + 1]) / 2
  near <- vapply(seq_along(ch), function(i) any(ea$b >= b[ch[i]] - 1e-9 & ea$b <= b[ch[i] + 1] + 1e-9) |
    any(abs(ea$b - mid[i]) < 1.5 * (b[ch[i] + 1] - b[ch[i]])), TRUE)
  cl <- vapply(seq_along(ch), function(i) { d <- ea$b - mid[i]; j <- which.min(abs(d)); if (ea$opening[j]) "opening" else "shutting" }, "")
  late <- mid > 25
  cat(sprintf("%-13s nodes %4d | splits range %d-%d | changes %3d: next to an edge %3d (%.0f%%; at openings %d, shuttings %d) | away from edges %d (of them after 25 y %d, in shut gaps %d, before b1 %d)\n",
    cs, length(b), min(s), max(s), length(ch), sum(near), 100 * mean(near), sum(near & cl == "opening"), sum(near & cl == "shutting"), sum(!near),
    sum(!near & late), sum(!near & p$shut(mid) > 0.5), sum(!near & mid < p$b1))) }
