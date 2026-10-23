# One rung of a case's reference (validation.md, the held-out recipe): N uniform introductions at
# 3e-5, every quantity. The reference is u429 + (u429 - u215)/3.
#   PLANT_LIB=... Rscript spikes/refine-judged/reference.R CASE N OUTDIR
source(file.path(Sys.getenv("PLANT_DEV", "."), "spikes/refine-judged/refine_judged.R"))
a <- commandArgs(TRUE); case <- a[1]; n <- as.integer(a[2])
dir <- file.path(a[3], case); dir.create(dir, recursive = TRUE, showWarnings = FALSE)
setup <- case_setup(case, tol = 3e-5)
c0 <- Sys.time()
x <- stand_run(setup$p, setup$env, setup$ctrl, uniform_times(n))
x$stand[c("times", "sizes", "input_slopes", "substep_ends")] <- NULL
saveRDS(x, file.path(dir, sprintf("u%d.rds", n)))
message(sprintf("%s u%d: %.1f min", case, n, as.numeric(Sys.time() - c0, units = "mins")))
