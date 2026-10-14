# The merge probes (round 3) against a04t's committed run: moves and the interval anatomy.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
rd <- function(n) readRDS(file.path(R, paste0(n, ".rds")))
for (cs in c("dry", "dry-flat", "long-drought")) { base <- if (cs == "long-drought") "val_a04t_c_long-drought" else sprintf("val_a04t_c_%s", cs); xb <- rd(base); ref <- refq(cs); qb <- quantities(xb)
  for (pn in grep(sprintf("^probe_m.*_%s$", cs), sub("\\.rds$", "", list.files(R)), value = TRUE)) { x <- rd(pn); q <- quantities(x); k <- Reduce(intersect, list(names(ref), names(q), names(qb))); e <- eps_vec(k)
    mv <- (q[k] - qb[k]) / e; S <- x$node_times; Sb <- xb$node_times; A <- anatomy(S[S < 25], cs); ex <- exposure(A)
    cat(sprintf("%-26s vs %-24s n %3d -> %3d, tol %g/%g | move max %.2f (%s) rms %.3f lnJ %+.3f | Xg %.4f Xs %.4f\n", pn, base, length(Sb), length(S), xb$setting$tol, x$setting$tol, max(abs(mv)), k[which.max(abs(mv))], sqrt(mean(mv^2)), mv["lnJ"], ex[1], ex[2])) } }
