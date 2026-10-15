# The census table from census.R's per-case rds files.
# Usage: Rscript summarise.R <OUTDIR>
out_dir <- commandArgs(TRUE)[1]
cases <- c("dry", "dry-flat", "dry-p50", "episodic", "episodic-lma", "long-drought",
           "ld-102", "ld-105", "long-wet", "wet-adG2")
r <- lapply(cases, function(k) readRDS(file.path(out_dir, sprintf("census_%s.rds", k))))
op_names <- names(r[[1]]$operating_points)
cl_names <- names(r[[1]]$clamps)
row <- function(x) {
  op <- x$operating_points; cl <- x$clamps
  data.frame(case = x$case, record = x$setting$regime, seed = x$setting$seed,
             trait = x$setting$env[["TRAIT_REL"]], steps = x$steps,
             same_times = x$times_identical, J = x$J, J_rel = x$J_rel,
             solves = sum(op), t(op), t(cl), check.names = FALSE)
}
tab <- do.call(rbind, lapply(r, row))
options(width = 250)
print(tab[, c("case", "record", "seed", "trait", "steps", "same_times", "J", "J_rel", "solves")],
      digits = 15)
print(tab[, c("case", op_names)])
print(tab[, c("case", cl_names)])
jump <- c("determined", "hydraulic-shutdown", "boundary-root-crit")
cat("\nJump kinds as a share of solves:\n")
print(cbind(case = tab$case, signif(tab[, jump] / tab$solves, 3)))
cat("\nAll-zero operating-point kinds:", op_names[colSums(tab[, op_names]) == 0], "\n")
cat("All-zero clamps:", cl_names[colSums(tab[, cl_names]) == 0], "\n")
