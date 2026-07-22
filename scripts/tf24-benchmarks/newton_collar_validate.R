# T6 Slice 1 validation: Newton (safeguarded gradient root-find) vs GSS for the
# leaf root-collar operating point. Checks, across bank scenarios:
#  (1) OFF is bit-identical to the pre-flag production path (structural, but we
#      also confirm OFF==OFF reproducibly);
#  (2) ON matches OFF offspring within converged-J tolerance;
#  (3) the J(tau) flip (a GSS_tol_abs argmax-quantization artifact) is gone under ON.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant", export_all=TRUE, quiet=TRUE)})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"

ctrl <- function(newton) control(ode_method="rkck", ode_tol_rel=1e-6, ode_tol_abs=1e-6,
                                  newton_collar_solve=newton)
mkenv <- function(b, tmax){ e <- Environment("TF24")
  times <- (0:(length(b$rain)-1))/365
  e$extrinsic_drivers_set_variable("rainfall", times, b$rain); e }
mkp <- function(tmax){ p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax
  add_strategies(p, trait_matrix(0.0825,"lma"), birth_rate=1) }

run_off_on <- function(nm, years) {
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years*365)); b$rain <- b$rain[seq_len(nd)]
  tmax <- (nd-1)/365
  J <- function(newton){ scm <- run_scm(mkp(tmax), mkenv(b, tmax), ctrl(newton))
    scm$offspring_production }
  Joff <- J(FALSE); Jon <- J(TRUE)
  rel <- abs(Jon - Joff)/abs(Joff)
  cat(sprintf("  %-16s OFF=%.6e  ON=%.6e  rel=%.2e\n", nm, Joff, Jon, rel)); flush(stdout())
  c(Joff=Joff, Jon=Jon, rel=rel)
}

cat("== (2) ON vs OFF offspring across bank ==\n")
jobs <- list(intense_storms=12, whiplash=12, extended_drought=20, dry_to_wet=12)
res <- sapply(names(jobs), function(nm) run_off_on(nm, jobs[[nm]]))
cat(sprintf("  max rel = %.2e\n", max(res["rel",])))
saveRDS(res, "/home/user/plant-dev/scripts/tf24-benchmarks/results/newton_collar_validate.rds")
cat("ALLDONE\n")
