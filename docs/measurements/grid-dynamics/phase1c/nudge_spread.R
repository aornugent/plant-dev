# The +-5% tolerance nudges at 3e-5 on long drought (spot-check ld_2.85e-5 and
# ld_3.15e-5 against ld_3e-5, plant's own control, uniform 108): each quantity's
# larger move, in eps. Sourced by compare_nudge.R; run alone it prints a summary.
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
eps <- read.csv(file.path(WT, "docs/measurements/eps.csv"))
eps <- eps[eps$unit != "curvature in lma", ]
eps_of <- function(role, trait) {
  e <- eps$eps[eps$role == role & eps$trait == trait]
  if (length(e)) e[1] else NA
}
quantities <- function(x) {
  out <- c()
  for (role in c("stand", "invader")) {
    if (is.null(x[[role]]$elasticity)) next
    r <- if (role == "stand") "resident" else "invader"
    tr <- c("ln J", sub("^1[.]", "", names(x[[role]]$elasticity)))
    v <- c(log(x[[role]]$J), unname(x[[role]]$elasticity)) / vapply(tr, function(t) eps_of(r, t), 0)
    names(v) <- paste(r, tr)
    out <- c(out, v)
  }
  out[is.finite(out)]
}
sc <- file.path(WT, "docs/measurements/spot-check")
q3 <- quantities(readRDS(file.path(sc, "ld_3e-5.rds")))
qlo <- quantities(readRDS(file.path(sc, "ld_2.85e-5.rds")))
qhi <- quantities(readRDS(file.path(sc, "ld_3.15e-5.rds")))
n <- Reduce(intersect, list(names(q3), names(qlo), names(qhi)))
nudge <- pmax(abs(qlo[n] - q3[n]), abs(qhi[n] - q3[n]))
if (sys.nframe() == 0L) {
  main <- c("ln J", "lma", "a_dG2", "hmat", "stem_P50", "rho")
  role <- sub(" .*", "", n); tr <- sub("^(resident|invader) ", "", n)
  for (r in c("resident", "invader")) {
    s <- role == r; m <- s & tr %in% main
    o <- order(-nudge[s])[1:6]
    cat(sprintf("%-8s +-5%% nudge at 3e-5: median %.4f, largest %s; main largest %.4f (%s); over 0.08: %d of %d\n", r,
                median(nudge[s]), paste(sprintf("%.3f (%s)", nudge[s][o], tr[s][o]), collapse = ", "),
                max(nudge[m]), tr[m][which.max(nudge[m])], sum(nudge[s] > 0.08), sum(s)))
  }
}
