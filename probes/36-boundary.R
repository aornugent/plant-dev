# Reconcile Species::compute_competition(0) by hand against the node list, to
# find out exactly which quadrature the SCM is evaluating in birth-date mode --
# in particular what abscissa the closing boundary trapezium uses.
source("probes/lib.R"); setwd("/home/user/plant-dev")

p <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
for (bd in c(TRUE, FALSE)) {
  ct <- Control(); ct$node_density_in_birth_date <- bd
  scm <- scm_collect(p, "TF24", ct)
  tm <- vapply(seq_along(scm$history), function(k) scm$history[[k]]$time, 0)
  cat(sprintf("\n############ node_density_in_birth_date = %s ############\n", bd))
  for (target in c(1, 2, 3)) {
    k  <- which.min(abs(tm - target))
    ph <- scm$history[[k]]; sp <- ph$species[[1]]
    tt <- ph$time
    xs <- sp$node_times
    hs <- vapply(sp$nodes, function(n) n$individual$state("height"), 0)
    fs <- vapply(sp$nodes, function(n) n$compute_competition(0), 0)
    ld <- sp$log_densities
    tot <- sp$compute_competition(0)
    n <- length(xs)
    # abscissa the C++ uses
    ab <- if (bd) xs else -hs
    trap <- sum(diff(ab) * (head(fs,-1) + tail(fs,-1)))/2
    bnd  <- tot - trap
    nb   <- sp$new_node
    fb   <- nb$compute_competition(0)
    hb   <- nb$individual$state("height")
    # what x0 would the code have to use to give this boundary term?
    x0_implied <- ab[n] + 2*bnd/(fs[n] + fb)
    cat(sprintf("\nt=%.4f  nnode=%d  total=%.6f  trap(nodes only)=%.6f  boundary=%+.6f (%+.1f%% of total)\n",
        tt, n, tot, trap, bnd, 100*bnd/tot))
    cat(sprintf("  abscissa range [%.5f, %.5f]   f_last=%.3e  f_boundary=%.3e  h_boundary=%.5f\n",
        ab[1], ab[n], fs[n], fb, hb))
    cat(sprintf("  implied x0 = %.6f   (birth-date closure should be t=%.4f; -h0 closure = %.5f)\n",
        x0_implied, tt, -hb))
    cat(sprintf("  boundary term if x0=t      : %+.6f  -> total %.6f\n",
        (tt-ab[n])*(fs[n]+fb)/2, trap + (tt-ab[n])*(fs[n]+fb)/2))
    cat(sprintf("  boundary term if x0=0      : %+.6f  -> total %.6f\n",
        (0-ab[n])*(fs[n]+fb)/2, trap + (0-ab[n])*(fs[n]+fb)/2))
    cat(sprintf("  last 4 abscissae: %s\n", paste(sprintf("%.5f", tail(ab,4)), collapse=" ")))
    cat(sprintf("  last 4 f        : %s\n", paste(sprintf("%.3e", tail(fs,4)), collapse=" ")))
    cat(sprintf("  last 4 density  : %s\n", paste(sprintf("%.4f", exp(tail(ld,4))), collapse=" ")))
    cat(sprintf("  first 4 abscissae: %s\n", paste(sprintf("%.5f", head(ab,4)), collapse=" ")))
    cat(sprintf("  first 4 f        : %s\n", paste(sprintf("%.3e", head(fs,4)), collapse=" ")))
  }
}
