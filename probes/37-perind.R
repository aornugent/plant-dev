# Both solvers reduce, at t=1, to lambda * int_0^1 S(u) a(u) du with negligible
# competition (LAI ~ 0.004).  They disagree by ~14%.  So compare the integrands
# directly: leaf area and survival as a function of individual age, node by node
# in the SCM and individual by individual in the IBM.
source("probes/lib.R"); setwd("/home/user/plant-dev")

p <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))

ibm_reg <- function(area, tend, offset = 0.5) {
  set.seed(11); pp <- p; pp$patch_area <- area; pp$max_patch_lifetime <- tend
  dt <- 1/area; aa <- seq(offset*dt, tend, by = dt)
  ty  <- plant:::extract_RcppR6_template_types(pp, "Parameters")
  obj <- do.call(plant:::StochasticPatchRunner, ty)(pp, Environment("TF24"), Control())
  sc  <- plant:::NodeSchedule(1); sc$max_time <- tend; sc$set_times(aa, 1)
  obj$node_schedule <- sc
  while (!obj$complete) obj$run_next()
  sp <- obj$patch$species[[1]]
  inds <- sp$individuals; alive <- sp$is_alive
  data.frame(age = obj$patch$time - aa[seq_along(inds)], alive = alive,
             a = vapply(inds, function(i) i$compute_competition(0), 0),
             h = vapply(inds, function(i) i$state("height"), 0),
             mort = vapply(inds, function(i) i$state("mortality"), 0),
             t = obj$patch$time, area = area)
}

scm_nodes <- function(target, bd = TRUE) {
  ct <- Control(); ct$node_density_in_birth_date <- bd
  scm <- scm_collect(p, "TF24", ct)
  tm <- vapply(seq_along(scm$history), function(k) scm$history[[k]]$time, 0)
  k <- which.min(abs(tm - target)); ph <- scm$history[[k]]; sp <- ph$species[[1]]
  data.frame(age = ph$time - sp$node_times,
             dens = exp(sp$log_densities),
             f = vapply(sp$nodes, function(n) n$compute_competition(0), 0),
             a = vapply(sp$nodes, function(n) n$individual$compute_competition(0), 0),
             h = vapply(sp$nodes, function(n) n$individual$state("height"), 0),
             mort = vapply(sp$nodes, function(n) n$individual$state("mortality"), 0),
             t = ph$time)
}

for (TT in c(1, 3)) {
  cat(sprintf("\n################ t = %g ################\n", TT))
  ib <- ibm_reg(32, TT)
  sc <- scm_nodes(TT)
  cat(sprintf("IBM  A=32: t=%.5f  n=%d alive=%d  sum(a)/A = %.6f\n",
              ib$t[1], nrow(ib), sum(ib$alive), sum(ib$a[ib$alive])/32))
  cat(sprintf("SCM      : t=%.5f  nodes=%d  competition=%.6f\n\n", sc$t[1], nrow(sc),
              sum(diff(sc$t[1]-rev(sc$age))*0)+NA_real_ ))
  # compare a(u) at matched ages by interpolating the SCM integrand
  ages <- ib$age
  a_scm <- approx(sc$age, sc$a, ages, rule=2)$y
  s_scm <- approx(sc$age, exp(-sc$mort), ages, rule=2)$y
  h_scm <- approx(sc$age, sc$h, ages, rule=2)$y
  o <- order(-ages)
  cat(sprintf("%8s %12s %12s %8s | %10s %10s %8s | %10s %10s\n",
      "age","a_IBM","a_SCM","ratio","h_IBM","h_SCM","ratio","surv_IBM","surv_SCM"))
  for (i in o[seq(1, length(o), by = max(1, floor(length(o)/16)))])
    cat(sprintf("%8.4f %12.4e %12.4e %8.4f | %10.5f %10.5f %8.4f | %10.5f %10.5f\n",
        ages[i], ib$a[i], a_scm[i], ib$a[i]/a_scm[i], ib$h[i], h_scm[i], ib$h[i]/h_scm[i],
        exp(-ib$mort[i]), s_scm[i]))
  cat(sprintf("\n  sum a_IBM/A = %.6f   sum a_SCM(at same ages)/A = %.6f   ratio %.4f\n",
      sum(ib$a[ib$alive])/32, sum(a_scm)/32, sum(ib$a[ib$alive])/sum(a_scm)))
  cat(sprintf("  SCM node ages: n=%d, range [%.5f, %.5f]; first 6 ages %s\n",
      nrow(sc), min(sc$age), max(sc$age), paste(sprintf("%.5f", head(sort(sc$age)),4), collapse=" ")))
  cat(sprintf("  SCM trapz over its own nodes of dens*a: %.6f\n",
      { s <- sc[order(sc$age),]; x <- s$t[1]-s$age; ff <- s$f
        sum(diff(rev(x))*(head(rev(ff),-1)+tail(rev(ff),-1)))/2 }))
}
