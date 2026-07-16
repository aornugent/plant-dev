#!/usr/bin/env Rscript
# Gate-0 check A (#6): does the mass-chart / geometric-compression transport
# stay bounded at the DEFAULT growth clamp (growth_eps=1e-4)?
#
# node.h:247 keeps the FD/upwind stencil because feeding the EXACT analytic
# d_x g into log_density_dt is unstable -- it only stays bounded with the clamp
# inflated to ~5e-2 (a ~6% K93 demography change). The mass chart's claim (#6 §3)
# is that d_x g never enters the rate at all: the neighbour-secant geometric
# compression carries it, and that path is stable at the default clamp. The
# node_geometric_compression control flag toggles exactly that path (species.h
# :267 sets -dgdh from the neighbour secant; node.h:173 seeds mortality only), so
# this is a direct test of the claim -- no clamp inflation available from R
# (growth_eps is constexpr), which is the point: it must be bounded AS-IS.

suppressMessages({library(odelia); Sys.setenv(TESTTHAT_PARALLEL="false")
  pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE)})

run_k93 <- function(geometric, lifetime = 35.10667) {
  p0 <- scm_base_parameters("K93"); p0$max_patch_lifetime <- lifetime
  p1 <- add_strategies(p0, trait_matrix(0.059, "b_0"), birth_rate = 20)
  ctrl <- Control(); ctrl$node_geometric_compression <- geometric
  scm <- run_scm(p1, Environment("K93"), ctrl)
  sp <- scm$patch$species[[1]]
  ldr <- matrix(sp$ode_rates, ncol = 5, byrow = TRUE)[, 5]  # log_density_dt per cohort
  list(ld = sp$log_densities, ldr = ldr,
       n = sp$size, offspring = scm$offspring_production)
}

cat("=== Gate-0 A: mass-chart (geometric compression) forward stability ===\n")
cat(sprintf("growth_eps (clamp) = 1e-4 (default, NOT inflated)\n\n"))

fd  <- run_k93(FALSE)   # default: FD/upwind stencil
geo <- run_k93(TRUE)    # mass-chart TransportGeometry: neighbour secant

for (nm in c("FD stencil (default)", "geometric / mass chart")) {
  r <- if (nm == "FD stencil (default)") fd else geo
  finite <- all(is.finite(r$ld)) && all(is.finite(r$ldr))
  cat(sprintf("%-24s cohorts=%3d  max|log n|=%.2f  max|d log n/dt|=%.3f  finite=%s\n",
              nm, r$n, max(abs(r$ld)), max(abs(r$ldr)), finite))
}

# boundedness verdict + the documented ~0.2% forward shift
cat(sprintf("\ngeometric path bounded (no density runaway) = %s\n",
            all(is.finite(geo$ld)) && all(is.finite(geo$ldr)) &&
            max(abs(geo$ld)) < 1e3))
cat(sprintf("offspring_production: FD=%.6f  geometric=%.6f  rel.diff=%.3f%%\n",
            fd$offspring, geo$offspring,
            100*abs(geo$offspring - fd$offspring)/abs(fd$offspring)))

# Stress it: a longer horizon (more cohorts + more shading, where node.h says the
# EXACT-analytic path blows up). If geometric stays bounded here, the claim holds.
cat("\n--- stress: longer horizon (more shading) ---\n")
for (L in c(50, 80, 110)) {
  ok <- tryCatch({
    g <- run_k93(TRUE, lifetime = L)
    b <- all(is.finite(g$ld)) && max(abs(g$ld)) < 1e3
    sprintf("cohorts=%d max|log n|=%.1f bounded=%s", g$n, max(abs(g$ld)), b)
  }, error = function(e) paste0("ERROR: ", conditionMessage(e)))
  cat(sprintf("  lifetime=%3d: %s\n", L, ok))
}
