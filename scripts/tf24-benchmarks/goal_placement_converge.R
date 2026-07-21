# Rung 2, schedule-neutral convergence study. The placement test measured error
# vs a default-densified reference, which is biased toward default/uniform node
# locations. Here: for each family (default / uniform / g-mass), refine the node
# count 1x -> 2x -> 4x and report J at each level. Reference-free reading:
#   - successive |J(2N)-J(N)|, |J(4N)-J(2N)| = self-convergence rate per family;
#   - whether the families agree at 4x = whether the limit is schedule-independent.
# If g-mass's J converges faster (smaller successive deltas) or the families
# disagree at 4x with g-mass nearest a Richardson limit, goal-oriented placement
# funds; if uniform converges just as well, uniform is the lever. Two informative
# scenarios: long_horizon (g-mass lost) and whiplash (g-mass won).
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                                     export_all = TRUE, quiet = TRUE)})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
ctrl <- control(ode_method = "rkck", ode_tol_rel = 1e-6, ode_tol_abs = 1e-6)
jobs <- list(long_horizon = 30, whiplash = 16)

run_sched <- function(mkpars, mkenv, sched) {
  scm <- SCM("TF24","TF24_Env")(mkpars(), mkenv(), ctrl)
  scm$set_node_schedule_times(list(sort(unique(sched)))); scm$run()
  sp <- scm$patch$species[[1]]
  list(J=sum(scm$offspring_production),
       g = sp$net_reproduction_ratio_by_node * sp$patch_densities, tau = sp$node_times)
}
place_by_density <- function(tau, d, N, tmax, floor_frac = 0.05) {
  d <- pmax(d, 0); d <- d + floor_frac * max(d)
  fine <- seq(0, tmax, length.out = 5000); dd <- approx(tau, d, fine, rule = 2)$y
  cdf <- cumsum(dd); cdf <- cdf / cdf[length(cdf)]
  nodes <- approx(cdf, fine, seq(0, 1, length.out = N), rule = 2, ties = "ordered")$y
  nodes[1] <- 0; nodes[N] <- tmax; sort(unique(nodes))
}

for (nm in names(jobs)) {
  years <- jobs[[nm]]
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years*365))
  rain <- b$rain[seq_len(nd)]; times <- (0:(nd-1))/365; tmax <- max(times)
  mkenv  <- function(){ e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
  mkpars <- function(){ p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax
    add_strategies(p, trait_matrix(0.0825,"lma"), birth_rate=1) }
  scm0 <- SCM("TF24","TF24_Env")(mkpars(), mkenv(), ctrl); scm0$run()
  base <- scm0$patch$species[[1]]$node_times; N <- length(base)
  pilot <- run_sched(mkpars, mkenv, base)   # g density for g-mass family

  cat(sprintf("\n== %s (%dyr, N=%d) ==\n", nm, years, N))
  cat(sprintf("%-9s %-13s %-13s %-13s\n", "family", "J(N)", "J(2N)", "J(4N)"))
  fams <- list(
    default = function(mult) { d <- base
      if (mult>1) { d <- numeric(0); for(i in seq_len(length(base)-1)) d <- c(d, seq(base[i],base[i+1],length.out=mult+1)[-(mult+1)]); d <- c(d, base[length(base)]) }; d },
    uniform = function(mult) seq(0, tmax, length.out = N*mult),
    gmass   = function(mult) place_by_density(pilot$tau, abs(pilot$g), N*mult, tmax)
  )
  Jtab <- list()
  for (fn in names(fams)) {
    Js <- sapply(c(1,2,4), function(m) run_sched(mkpars, mkenv, fams[[fn]](m))$J)
    Jtab[[fn]] <- Js
    cat(sprintf("%-9s %-13.6e %-13.6e %-13.6e\n", fn, Js[1], Js[2], Js[3])); flush(stdout())
  }
  # successive relative change (self-convergence) at 4x
  for (fn in names(fams)) {
    Js <- Jtab[[fn]]
    cat(sprintf("   %-9s d(2N,N)=%.3f d(4N,2N)=%.3f\n", fn,
                abs(Js[2]-Js[1])/abs(Js[2]), abs(Js[3]-Js[2])/abs(Js[3])))
  }
  saveRDS(Jtab, file.path(outdir, paste0("converge_", nm, ".rds")))
}
cat("ALLDONE\n")
