# For pairs of nested rungs (coarse, fine) of run_record outputs: per quantity, in
# eps, the fine rung's error against the graded reference, the companion's estimate
# (a third of the move) over that error, and the extrapolated answer's error.
# Medians by role outside the small four, the share of quantities whose estimate is
# at least the error, the max errors, and the asked quantities one by one.
# Usage: Rscript pair_scores.R name=coarse.rds,fine.rds ...
wt <- "/home/user/plant-dev/.claude/worktrees/agent-a2ac0b96ecd6256ba"
cg <- file.path(wt, "docs/measurements/creation-grid")
eps <- read.csv(file.path(wt, "docs/measurements/eps.csv")); eps <- eps[eps$unit != "curvature in lma", ]
small <- c("a_st3", "a_d0", "omega", "a_l1")
asked <- c("invader lma", "invader a_dG2", "invader hmat", "invader stem_P50", "invader rho", "invader recruitment_decay",
           "invader a_y", "invader a_bio", "invader a_f1", "invader a_l2", "invader theta", "invader jmax_25",
           "resident ln J", "resident lma")
eps_of <- function(role, trait) { e <- eps$eps[eps$role == role & eps$trait == trait]; if (length(e)) e[1] else NA }
quantities <- function(x) {
  out <- c()
  for (role in c("stand", "invader")) {
    if (is.null(x[[role]]$elasticity)) next
    r <- if (role == "stand") "resident" else "invader"
    tr <- c("ln J", sub("^1[.]", "", names(x[[role]]$elasticity)))
    v <- c(log(x[[role]]$J), unname(x[[role]]$elasticity)) / vapply(tr, function(t) eps_of(r, t), 0)
    names(v) <- paste(r, tr); out <- c(out, v)
  }
  out[is.finite(out)]
}
g2 <- quantities(readRDS(file.path(cg, "ld_G2_full.rds"))); g3 <- quantities(readRDS(file.path(cg, "ld_G3_full.rds")))
ref <- g3 + (g3 - g2) / 3
per <- list()
for (a in commandArgs(TRUE)) {
  kv <- strsplit(a, "=")[[1]]; f <- strsplit(kv[2], ",")[[1]]
  qa <- quantities(readRDS(f[1])); qb <- quantities(readRDS(f[2]))
  k <- Reduce(intersect, list(names(qa), names(qb), names(ref))); k <- k[!(sub("^(resident|invader) ", "", k) %in% small)]
  err <- qb[k] - ref[k]; est <- abs(qa[k] - qb[k]) / 3; ext <- qb[k] + (qb[k] - qa[k]) / 3 - ref[k]
  role <- sub(" .*", "", k)
  per[[kv[1]]] <- data.frame(q = k, err = err, comp = est / abs(err), ext = ext)
  for (r in c("resident", "invader")) {
    s <- role == r; big <- s & abs(err) > 0.05
    cat(sprintf("%-16s %-8s fine error median %.3f max %.3f | companion median %.2f (estimate >= error on %d/%d) | extrapolated median %.3f max %.3f\n",
                kv[1], r, median(abs(err[s])), max(abs(err[s])), median((est / abs(err))[big]), sum(est[big] >= abs(err[big])), sum(big),
                median(abs(ext[s])), max(abs(ext[s]))))
  }
}
cat("\nthe asked quantities: fine error / companion over error / extrapolated error, in eps\n")
tab <- sapply(per, function(d) { d <- d[match(asked, d$q), ]; sprintf("%+.3f / %.2f / %+.3f", d$err, d$comp, d$ext) })
rownames(tab) <- asked
print(noquote(tab))
