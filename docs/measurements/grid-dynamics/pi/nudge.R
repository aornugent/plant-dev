# Criteria 3 and 4 (prereg.txt): the fixed-step lma elasticity of each run, by central
# differences at u = 1e-5 on its own accepted steps (PROGRAM with THETA=lma), and the
# tolerance nudges' moves in ln J and in the elasticity against eps/3.
#   Rscript nudge.R
P <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pi"
u <- 1e-5
J_of <- function(name) {
  f <- file.path(P, "runs", paste0(name, ".rds"))
  if (file.exists(f)) readRDS(f)$J else NA
}
E_of <- function(name) {
  Jp <- J_of(paste0("frozen_", name, "_+")); Jm <- J_of(paste0("frozen_", name, "_-"))
  # the baseline at 3e-5 is bit-identical to tied_3e-5, whose replays are logged
  if (name == "base_3e-5" && is.na(Jp)) { Jp <- 12.667923702; Jm <- 12.669185516 }
  log(Jp / Jm) / (log1p(u) - log1p(-u))
}
eps <- c(lnJ = 0.025, E = 0.087)
out <- list()
V <- if (length(commandArgs(TRUE))) commandArgs(TRUE)[1] else "pics"
for (law in c("base", V)) {
  E0 <- E_of(paste0(law, "_3e-5")); J0 <- J_of(paste0(law, "_3e-5"))
  cat(sprintf("%-4s 3e-5: J %.9f, elasticity %.5f\n", law, J0, E0))
  for (k in c("2.85e-5", "3.15e-5")) {
    n <- paste0(law, "_", k)
    dJ <- log(J_of(n) / J0); dE <- E_of(n) - E0
    out[[length(out) + 1]] <- data.frame(law, tol = k, dlnJ = dJ, dE = dE)
    cat(sprintf("     %s: J %.9f, d ln J %+.3g (%.3g of eps/3), elasticity %.5f, dE %+.3g (%.3g of eps/3)\n",
                k, J_of(n), dJ, abs(dJ) / (eps[["lnJ"]] / 3), E_of(n), dE, abs(dE) / (eps[["E"]] / 3)))
  }
}
d <- do.call(rbind, out)
d <- d[complete.cases(d), ]
if (nrow(d)) {
  m <- aggregate(cbind(dlnJ = abs(dlnJ), dE = abs(dE)) ~ law, d, max)
  cat("largest |move| over the two nudges:\n"); print(m, row.names = FALSE)
  if (all(c("base", V) %in% m$law)) {
    b <- m[m$law == "base", ]; p <- m[m$law == V, ]
    worse <- (p$dlnJ > b$dlnJ && p$dlnJ > eps[["lnJ"]] / 30) || (p$dE > b$dE && p$dE > eps[["E"]] / 30)
    cat("criterion 4 (nudge no worse):", if (is.na(worse)) "incomplete" else if (worse) "WORSE" else "holds", "\n")
  }

}
E_b <- E_of("base_3e-5"); E_p <- E_of(paste0(V, "_3e-5"))
cat(sprintf("criterion 3: |E_%s - E_base| = %.3g against 0.05 eps = %.3g: %s\n", V, abs(E_p - E_b), 0.05 * eps[["E"]],
            if (abs(E_p - E_b) <= 0.05 * eps[["E"]]) "holds" else "fails"))
