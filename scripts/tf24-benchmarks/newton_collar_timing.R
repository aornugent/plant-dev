# T6 Slice 1 R2 check: does the gradient root-find cut the dominant per-cohort
# leaf-solve cost? The leaf operating-point solve is the O(M) hotspot, so a
# whole-solve wall-clock ratio OFF vs ON is a faithful system-level proxy for the
# eval-count reduction (GSS ~10-15 profit evals -> TOMS748 ~5-8 gradient evals).
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant", export_all=TRUE, quiet=TRUE)})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
ctrl <- function(newton) control(ode_method="rkck", ode_tol_rel=1e-6, ode_tol_abs=1e-6,
                                  newton_collar_solve=newton)
b <- readRDS(file.path(datadir, "intense_storms.rds"))
nd <- min(length(b$rain), round(12*365)); b$rain <- b$rain[seq_len(nd)]; tmax <- (nd-1)/365
mkenv <- function(){ e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall",(0:(nd-1))/365,b$rain); e }
mkp <- function(){ p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax
  add_strategies(p, trait_matrix(0.0825,"lma"), birth_rate=1) }
timeit <- function(newton){ t <- system.time(scm <- run_scm(mkp(), mkenv(), ctrl(newton)))["elapsed"]
  list(t=as.numeric(t), J=scm$offspring_production) }
# one warm run each first (JIT/caches), then the measured run
invisible(timeit(FALSE)); invisible(timeit(TRUE))
off <- timeit(FALSE); on <- timeit(TRUE)
cat(sprintf("intense_storms 12yr:  GSS %.1fs (J=%.4e)   Newton %.1fs (J=%.4e)   speedup=%.2fx\n",
            off$t, off$J, on$t, on$J, off$t/on$t)); flush(stdout())
cat("ALLDONE\n")
