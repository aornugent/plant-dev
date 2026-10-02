# Errors (in eps) of each quantity on single rungs against the graded reference
# (G3 + (G3 - G2)/3), by role and group outside the small four: median and max |error|.
# Usage: Rscript rung_errors.R name1=file name2=file ...
wt <- "/home/user/plant-dev/.claude/worktrees/agent-a2ac0b96ecd6256ba"
cg <- file.path(wt, "docs/measurements/creation-grid")
eps <- read.csv(file.path(wt, "docs/measurements/eps.csv")); eps <- eps[eps$unit != "curvature in lma", ]
main <- c("ln J", "lma", "rho", "hmat", "stem_P50", "a_dG2"); small <- c("a_st3", "a_d0", "omega", "a_l1")
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
for (a in commandArgs(TRUE)) {
  kv <- strsplit(a, "=")[[1]]; q <- quantities(readRDS(kv[2]))
  k <- intersect(names(q), names(ref)); k <- k[!(sub("^(resident|invader) ", "", k) %in% small)]
  e <- abs(q[k] - ref[k]); role <- sub(" .*", "", k)
  cat(sprintf("%-22s %s | worst %.2f (%s)\n", kv[1], paste(sprintf("%s median %.3f max %.3f", c("resident", "invader"),
              tapply(e, role, median)[c("resident", "invader")], tapply(e, role, max)[c("resident", "invader")]), collapse = "; "),
              max(e), names(e)[which.max(e)]))
}
