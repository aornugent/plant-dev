# What the invaders' thinned schedule (every third introduction) does to the
# sensing matrix: the pool's first 8 members replayed on all 108 introductions
# (case <thin>-full) against the same 8 rows of the thinned runs (<thin>).
#   Rscript quadrature_check.R seasonal
RUNS <- "/home/a/.claude/jobs/9d586e52/tmp/d066/runs"
HERE <- "/home/a/dev/plant-dev/.claude/worktrees/agent-aff6cbd1ac6c0084f/spikes/field-dimension-066"
TRAITS <- c("lma", "rho", "hmat", "K_s", "rooting_depth_max", "vcmax_25")
cols <- c("lnb", TRAITS)
n <- 8
THIN <- commandArgs(TRUE)[1]
FULL <- paste0(THIN, "-full")
rd <- function(case, name) readRDS(file.path(RUNS, case, paste0(name, ".rds")))
dphi <- function(case) sapply(cols, function(c)
  (rd(case, paste0(c, "_p"))$lnR[1:n] - rd(case, paste0(c, "_m"))$lnR[1:n]) / 0.4)
thin <- dphi(THIN)
full <- dphi(FULL)
e_null <- rd(FULL, "null_b")$lnR - rd(FULL, "base")$lnR
sv_t <- svd(thin); sv_f <- svd(full)
# Principal angles between the leading k-dimensional left subspaces.
angles <- sapply(1:4, function(k) {
  s <- svd(crossprod(sv_t$u[, 1:k, drop = FALSE], sv_f$u[, 1:k, drop = FALSE]))$d
  acos(pmin(1, min(s))) * 180 / pi
})
out <- list(thin = thin, full = full, sv_thin = sv_t$d, sv_full = sv_f$d,
            angles_deg = angles, e_null_full = e_null,
            level_thin = rd(THIN, "base")$lnR[1:n],
            level_full = rd(FULL, "base")$lnR,
            resident_F = rd(FULL, "base")$F)
saveRDS(out, file.path(HERE, sprintf("quadrature_check_%s.rds", THIN)))
f6 <- function(x) paste(formatC(x, digits = 3, format = "g"), collapse = "  ")
E <- thin - full
cat("sv of thin - full:", f6(svd(E)$d), " rel to full sv1:", f6(svd(E)$d / sv_f$d[1]), "\n")
cat("identity, full schedule: invader 1", out$level_full[1], "resident", out$resident_F, "\n")
cat("level shift thin - full:", f6(out$level_thin - out$level_full), "\n")
cat("null_b rms on the full schedule:", sqrt(mean(e_null^2)), "\n")
cat("entrywise |thin - full| / |full|, rms:", sqrt(sum((thin - full)^2) / sum(full^2)), "\n")
cat("by column:", f6(sqrt(colSums((thin - full)^2) / colSums(full^2))), "\n")
cat("sv thin:", f6(sv_t$d), "\n rel:", f6(sv_t$d / sv_t$d[1]), "\n")
cat("sv full:", f6(sv_f$d), "\n rel:", f6(sv_f$d / sv_f$d[1]), "\n")
cat("largest principal angle (deg) between leading k left subspaces, k = 1..4:", f6(angles), "\n")
cat("right vectors 1-3, thin:\n"); print(round(sv_t$v[, 1:3], 3))
cat("right vectors 1-3, full:\n"); print(round(sv_f$v[, 1:3], 3))
