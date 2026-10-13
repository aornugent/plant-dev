# A probe against the run it modifies: per quantity the move in eps, the worst error
# against the reference before and after, and the rows and CPU kept.
#   Rscript merge_cmp.R PROBE_PREFIX BASE_PREFIX CASE...   (e.g. probe_mg10 val_a04t_c dry)
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
EXCLUDED <<- c(EXCLUDED, "rooting_depth_max"); R <- AR; a <- commandArgs(TRUE)
refq <- function(case) if (!is.null(CASES[[case]])) reference(case) else {
  x <- quantities(readRDS(file.path(R, sprintf("ref_%s_u215.rds", case)))); y <- quantities(readRDS(file.path(R, sprintf("ref_%s_u429.rds", case))))
  k <- intersect(names(x), names(y)); extrap(x[k], y[k]) }
for (case in a[-(1:2)]) { fp <- file.path(R, sprintf("%s_%s.rds", a[1], case)); fb <- file.path(R, sprintf("%s_%s.rds", a[2], case))
  if (!file.exists(fp) || !file.exists(fb)) { cat(case, ": missing\n"); next }
  p <- readRDS(fp); b <- readRDS(fb); if (is.null(p$stand$elasticity)) { cat(case, ": incomplete\n"); next }
  ref <- refq(case); qp <- quantities(p); qb <- quantities(b); k <- Reduce(intersect, list(names(ref), names(qp), names(qb))); e <- eps_vec(k)
  mv <- (qp[k] - qb[k]) / e; eb <- (qb[k] - ref[k]) / e; ep <- (qp[k] - ref[k]) / e; o <- order(-abs(mv))[1:3]
  cat(sprintf("%-13s nodes %d/%d rows %.3f cpu %.3f | move max %.2f (%s), rms %.3f, %d over 0.1 | worst err %.2f -> %.2f, rms %.3f -> %.3f\n",
    case, length(p$node_times), length(b$node_times), p$stand$rows / b$stand$rows, run_cost(p$stand$rows, TRUE) / run_cost(b$stand$rows, TRUE),
    max(abs(mv)), paste(sprintf("%s %+.2f", k[o], mv[o]), collapse = ", "), sqrt(mean(mv^2)), sum(abs(mv) > 0.1),
    max(abs(eb)), max(abs(ep)), sqrt(mean(eb^2)), sqrt(mean(ep^2)))) }
