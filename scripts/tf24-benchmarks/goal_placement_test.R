# Rung 2, the placement test. The predict test refuted the hierarchical-surplus
# indicator (anti-correlated with the J-error) but showed the absolute J-error
# sits ~entirely at small tau_ins (where J's mass is). So the right indicator is
# the J-mass g itself. Test: does placing nodes by equidistributing |g| (a pilot
# solve's per-slot J-contribution) converge J toward a dense reference faster than
# the default schedule and than uniform refinement, at matched node count?
#
# Per scenario, at matched node count N (= default count):
#   J_default : plant's default schedule
#   J_unif    : N nodes uniform on [0, tmax]
#   J_gmass   : N nodes by inverse-CDF of (|g_pilot| + floor)  -> dense at small tau
#   J_ref     : default densified 4x (reference)
# Report err = |J - J_ref| / |J_ref| for each. g-mass wins if err_gmass << err_default
# at the same N -- that funds goal-oriented placement (with the correct indicator).
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                                     export_all = TRUE, quiet = TRUE)})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
ctrl <- control(ode_method = "rkck", ode_tol_rel = 1e-6, ode_tol_abs = 1e-6)
jobs <- list(extended_drought = 20, dry_to_wet = 20, long_horizon = 30, whiplash = 16)

densify <- function(t, k) { if (k <= 1) return(t); out <- numeric(0)
  for (i in seq_len(length(t)-1)) out <- c(out, seq(t[i], t[i+1], length.out=k+1)[-(k+1)])
  c(out, t[length(t)]) }

run_sched <- function(mkpars, mkenv, sched) {
  scm <- SCM("TF24","TF24_Env")(mkpars(), mkenv(), ctrl)
  scm$set_node_schedule_times(list(sort(unique(sched)))); scm$run()
  sp <- scm$patch$species[[1]]
  list(J=sum(scm$offspring_production), tau=sp$node_times,
       g = sp$net_reproduction_ratio_by_node * sp$patch_densities)
}

# N nodes placed by the inverse-CDF of a density d(tau) (equidistribution), with
# a uniform floor so late-tau still gets representation. Endpoints pinned.
place_by_density <- function(tau, d, N, tmax, floor_frac = 0.05) {
  d <- pmax(d, 0); d <- d + floor_frac * max(d)
  fine <- seq(0, tmax, length.out = 5000)
  dd <- approx(tau, d, fine, rule = 2)$y
  cdf <- cumsum(dd); cdf <- cdf / cdf[length(cdf)]
  q <- seq(0, 1, length.out = N)
  nodes <- approx(cdf, fine, q, rule = 2, ties = "ordered")$y
  nodes[1] <- 0; nodes[N] <- tmax; sort(unique(nodes))
}

cat(sprintf("%-18s %-4s %-11s %-11s %-11s\n", "scenario","N","err_default","err_unif","err_gmass"))
res <- list()
for (nm in names(jobs)) {
  years <- jobs[[nm]]
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years*365))
  rain <- b$rain[seq_len(nd)]; times <- (0:(nd-1))/365; tmax <- max(times)
  mkenv  <- function(){ e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
  mkpars <- function(){ p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax
    add_strategies(p, trait_matrix(0.0825,"lma"), birth_rate=1) }

  scm0 <- SCM("TF24","TF24_Env")(mkpars(), mkenv(), ctrl); scm0$run()
  base <- scm0$patch$species[[1]]$node_times
  N <- length(base)
  pilot <- run_sched(mkpars, mkenv, base)                        # pilot solve -> g
  ref   <- run_sched(mkpars, mkenv, densify(base, 4))           # dense reference

  d_default <- run_sched(mkpars, mkenv, base)
  d_unif    <- run_sched(mkpars, mkenv, seq(0, tmax, length.out = N))
  gmass_sched <- place_by_density(pilot$tau, abs(pilot$g), N, tmax)
  d_gmass   <- run_sched(mkpars, mkenv, gmass_sched)

  err <- function(x) abs(x - ref$J) / abs(ref$J)
  cat(sprintf("%-18s %-4d %-11.4f %-11.4f %-11.4f\n", nm, N,
              err(d_default$J), err(d_unif$J), err(d_gmass$J))); flush(stdout())
  res[[nm]] <- list(N=N, Jref=ref$J, Jdefault=d_default$J, Junif=d_unif$J,
                    Jgmass=d_gmass$J, gmass_sched=gmass_sched)
}
saveRDS(res, file.path(outdir, "goal_placement_test.rds"))
cat("ALLDONE\n")
