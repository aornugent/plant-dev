# Ladder item 1: validate the ghost (zero-feedback probe) against the real
# member. plant's run_mutant IS the ghost: it replays a probe strategy against
# the resident's cached (u,s)(t) field with no feedback, pinned to the resident
# ode times. Experiment:
#   resident   = single strategy A (0.0825), run with save_RK45_cache
#   ghost(A)   = run_mutant(A) against resident field   -> sanity (expect ~match)
#   ghost(B)   = run_mutant(B=0.09) against resident field
#   real(B)    = B as a co-resident in a two-strategy run [A,B] (B feeds back)
# frozen-field error = |J_ghost(B) - J_real(B)| / J_real(B), plus the g(tau)
# profiles. The Oracle predicts the error is O(B's mass fraction) and vanishes
# at rho->0 crossings.

options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                     export_all = TRUE, quiet = TRUE)
})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
nm <- "intense_storms"; years <- as.numeric(Sys.getenv("GHOST_YEARS", "12"))
b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
nd <- min(length(b$rain), round(years * 365))
rain <- b$rain[seq_len(nd)]; times <- (0:(nd - 1)) / 365; tmax <- max(times)
mkenv <- function() { e <- Environment("TF24")
  e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
base_p <- function() { p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax; p }
CACHE <- control(ode_method="rkck", ode_tol_rel=1e-6, ode_tol_abs=1e-6, save_RK45_cache=TRUE)
PLAIN <- control(ode_method="rkck", ode_tol_rel=1e-6, ode_tol_abs=1e-6)

g_of <- function(sp) list(tau = sp$node_times,
                          g = sp$net_reproduction_ratio_by_node * sp$patch_densities)
gcmp <- function(A, B) {  # relative L1 distance of g(tau) on a common grid
  tm <- max(c(A$tau, B$tau)); grid <- seq(0, tm, length.out = 3000)
  ga <- approx(A$tau, A$g, grid, rule=2)$y; gb <- approx(B$tau, B$g, grid, rule=2)$y
  sum(abs(ga - gb)) / sum(abs(gb))
}

resident_scm <- function() run_scm(add_strategies(base_p(), trait_matrix(0.0825,"lma"), birth_rate=1), mkenv(), CACHE)

# resident A
res <- resident_scm(); J_res <- sum(res$offspring_production)
cat(sprintf("resident A: J=%.6e n=%d\n", J_res, length(res$patch$species[[1]]$node_times))); flush(stdout())

# sanity: ghost(A) against resident field
s1 <- resident_scm(); s1$run_mutant(add_strategies(base_p(), trait_matrix(0.0825,"lma"), birth_rate=1))
J_ghostA <- sum(s1$offspring_production)
cat(sprintf("ghost(A): J=%.6e  rel gap vs resident = %.3e\n", J_ghostA, abs(J_ghostA-J_res)/J_res)); flush(stdout())

# ghost(B=0.09) against resident A field
s2 <- resident_scm(); s2$run_mutant(add_strategies(base_p(), trait_matrix(0.09,"lma"), birth_rate=1))
J_ghostB <- sum(s2$offspring_production); gB_ghost <- g_of(s2$patch$species[[1]])
cat(sprintf("ghost(B): J=%.6e n=%d\n", J_ghostB, length(gB_ghost$tau))); flush(stdout())

# real(B): two-strategy resident [A, B], B feeds back
real <- tryCatch({
  p2 <- add_strategies(add_strategies(base_p(), trait_matrix(0.0825,"lma"), birth_rate=1),
                       trait_matrix(0.09,"lma"), birth_rate=1)
  scm2 <- run_scm(p2, mkenv(), PLAIN)
  list(J = scm2$offspring_production[2], g = g_of(scm2$patch$species[[2]]),
       Jvec = scm2$offspring_production)
}, error = function(e) { cat("real(B) two-species FAILED:", conditionMessage(e), "\n"); NULL })

cat("\n===RESULT===\n")
cat(sprintf("sanity ghost(A) vs resident A: rel J gap = %.3e (harness check; ~0 good)\n",
    abs(J_ghostA-J_res)/J_res))
if (!is.null(real)) {
  relJ <- abs(J_ghostB - real$J)/abs(real$J)
  relg <- gcmp(gB_ghost, real$g)
  cat(sprintf("FROZEN-FIELD ERROR (probe B): J ghost=%.6e real=%.6e  relJ=%.3f  rel g(tau) L1=%.3f\n",
      J_ghostB, real$J, relJ, relg))
  cat(sprintf("  (context: J_A=%.3e J_B=%.3e in the co-resident run; B mass fraction ~ %.3f)\n",
      real$Jvec[1], real$Jvec[2], real$Jvec[2]/sum(real$Jvec)))
  saveRDS(list(ghostB=gB_ghost, realB=real$g, J_ghostB=J_ghostB, J_realB=real$J),
          file.path(outdir, "ghost_validate.rds"))
}
cat("ALLDONE\n")
